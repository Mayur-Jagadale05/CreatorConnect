import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  none,
  pendingSent,
  pendingReceived,
  connected,
  rejected,
}

class ConnectionRequest {
  final String requestId;
  final String senderUid;
  final String senderName;
  final String senderUsername;
  final String senderEmail;
  final String senderRole;
  final String senderProfilePhoto;
  final String receiverUid;
  final String receiverName;
  final String receiverUsername;
  final String receiverRole;
  final String receiverProfilePhoto;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Interoperability getters
  String get senderProfileImage => senderProfilePhoto;
  String get receiverProfileImage => receiverProfilePhoto;

  ConnectionRequest({
    required this.requestId,
    required this.senderUid,
    required this.senderName,
    required this.senderUsername,
    required this.senderEmail,
    required this.senderRole,
    required this.senderProfilePhoto,
    required this.receiverUid,
    required this.receiverName,
    required this.receiverUsername,
    required this.receiverRole,
    required this.receiverProfilePhoto,
    required this.status,
    this.isRead = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ConnectionRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final senderPhoto = (data['senderProfileImage'] ??
            data['senderProfilePhoto'] ??
            '')
        .toString();
    final receiverPhoto = (data['receiverProfileImage'] ??
            data['receiverProfilePhoto'] ??
            '')
        .toString();

    return ConnectionRequest(
      requestId: doc.id,
      senderUid: data['senderUid']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'Creator',
      senderUsername: data['senderUsername']?.toString() ?? '',
      senderEmail: data['senderEmail']?.toString() ?? '',
      senderRole: data['senderRole']?.toString() ?? 'Creator',
      senderProfilePhoto: senderPhoto,
      receiverUid: data['receiverUid']?.toString() ?? '',
      receiverName: data['receiverName']?.toString() ?? 'Creator',
      receiverUsername: data['receiverUsername']?.toString() ?? '',
      receiverRole: data['receiverRole']?.toString() ?? 'Creator',
      receiverProfilePhoto: receiverPhoto,
      status: data['status']?.toString() ?? 'pending',
      isRead: data['isRead'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'senderEmail': senderEmail,
      'senderRole': senderRole,
      'senderProfilePhoto': senderProfilePhoto,
      'senderProfileImage': senderProfilePhoto,
      'receiverUid': receiverUid,
      'receiverName': receiverName,
      'receiverUsername': receiverUsername,
      'receiverRole': receiverRole,
      'receiverProfilePhoto': receiverProfilePhoto,
      'receiverProfileImage': receiverProfilePhoto,
      'status': status,
      'isRead': isRead,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ConnectionRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _collection =
      _firestore.collection('connection_requests');

  /// Generates a deterministic document ID for any two users
  /// to prevent duplicate active requests in opposite directions.
  static String pairKey(String uidA, String uidB) {
    return (uidA.compareTo(uidB) < 0) ? '${uidA}_$uidB' : '${uidB}_$uidA';
  }

  /// Removes the relationship and its conversation for both users.
  static Future<void> removeConnection({
    required String currentUid,
    required String otherUid,
  }) async {
    if (currentUid.isEmpty || otherUid.isEmpty || currentUid == otherUid) {
      throw ArgumentError('A valid connection pair is required.');
    }
    if (FirebaseAuth.instance.currentUser?.uid != currentUid) {
      throw StateError('You are not authorized to remove this connection.');
    }

    final requestRef = _collection.doc(pairKey(currentUid, otherUid));
    final connectionRef =
        _firestore.collection('connections').doc(requestRef.id);
    final chatRef = _firestore.collection('chats').doc(requestRef.id);
    final currentProfileRef =
        _firestore.collection('Profile_Data').doc(currentUid);
    final otherProfileRef =
        _firestore.collection('Profile_Data').doc(otherUid);

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      final connectionSnapshot = await transaction.get(connectionRef);
      final currentProfileSnapshot = await transaction.get(currentProfileRef);
      final otherProfileSnapshot = await transaction.get(otherProfileRef);

      final wasAccepted =
          requestSnapshot.data()?['status'] == 'accepted' ||
          connectionSnapshot.data()?['status'] == 'accepted';

      transaction.delete(requestRef);
      transaction.delete(connectionRef);
      transaction.delete(chatRef);

      if (wasAccepted) {
        for (final profileSnapshot in [
          currentProfileSnapshot,
          otherProfileSnapshot,
        ]) {
          final count = profileSnapshot.data()?['connectionsCount'];
          if (profileSnapshot.exists && count is num && count > 0) {
            transaction.update(profileSnapshot.reference, {
              'connectionsCount': count - 1,
            });
          }
        }
      }
    });
  }

  /// Sends a connection request from [senderUid] to [receiverUid].
  static Future<void> sendRequest({
    required String senderUid,
    required String senderName,
    required String senderUsername,
    required String senderEmail,
    required String senderRole,
    required String senderProfilePhoto,
    required String receiverUid,
    required String receiverName,
    required String receiverUsername,
    required String receiverRole,
    required String receiverProfilePhoto,
  }) async {
    if (senderUid == receiverUid) {
      throw Exception('You cannot send a connection request to yourself.');
    }

    final docId = pairKey(senderUid, receiverUid);
    final docRef = _collection.doc(docId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (snapshot.exists) {
        final existing = snapshot.data();
        final status = existing?['status']?.toString();

        if (status == 'accepted') {
          throw Exception('You are already connected with this user.');
        }

        if (status == 'pending') {
          final existingSender = existing?['senderUid']?.toString();
          if (existingSender == senderUid) {
            throw Exception('Connection request already sent.');
          } else {
            // The other user already sent a pending request; auto-accept!
            transaction.update(docRef, {
              'status': 'accepted',
              'updatedAt': FieldValue.serverTimestamp(),
            });

            final connectionRef =
                _firestore.collection('connections').doc(docId);
            final userIds = [senderUid, receiverUid]..sort();
            transaction.set(
              connectionRef,
              {
                'connectionId': docId,
                'userIds': userIds,
                'senderUid': existingSender ?? receiverUid,
                'receiverUid': senderUid,
                'status': 'accepted',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
            return;
          }
        }
      }

      // Create new or reset previously rejected request in both collections
      final connectionRef = _firestore.collection('connections').doc(docId);
      final userIds = [senderUid, receiverUid]..sort();

      final requestData = {
        'connectionId': docId,
        'requestId': docId,
        'userIds': userIds,
        'senderUid': senderUid,
        'senderName': senderName,
        'senderUsername': senderUsername,
        'senderEmail': senderEmail,
        'senderRole': senderRole,
        'senderProfilePhoto': senderProfilePhoto,
        'senderProfileImage': senderProfilePhoto,
        'receiverUid': receiverUid,
        'receiverName': receiverName,
        'receiverUsername': receiverUsername,
        'receiverRole': receiverRole,
        'receiverProfilePhoto': receiverProfilePhoto,
        'receiverProfileImage': receiverProfilePhoto,
        'status': 'pending',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.set(connectionRef, requestData, SetOptions(merge: true));
      transaction.set(docRef, requestData, SetOptions(merge: true));
    });
  }

  /// Listens to the connection relationship between [currentUid] and [otherUid].
  static Stream<ConnectionStatus> watchConnectionStatus(
    String currentUid,
    String otherUid,
  ) {
    if (currentUid.isEmpty || otherUid.isEmpty || currentUid == otherUid) {
      return Stream.value(ConnectionStatus.none);
    }

    final docId = pairKey(currentUid, otherUid);
    return _collection.doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return ConnectionStatus.none;
      }

      final data = snapshot.data()!;
      final status = data['status']?.toString();
      final senderUid = data['senderUid']?.toString();

      if (status == 'accepted') {
        return ConnectionStatus.connected;
      }

      if (status == 'pending') {
        if (senderUid == currentUid) {
          return ConnectionStatus.pendingSent;
        } else {
          return ConnectionStatus.pendingReceived;
        }
      }

      if (status == 'rejected') {
        return ConnectionStatus.rejected;
      }

      return ConnectionStatus.none;
    }).handleError((error) {
      debugPrint('watchConnectionStatus error: $error');
      return ConnectionStatus.none;
    });
  }

  /// Listens to incoming pending connection requests for [receiverUid].
  static Stream<List<ConnectionRequest>> watchIncomingRequests(
    String receiverUid,
  ) {
    if (receiverUid.isEmpty) return Stream.value([]);

    return _collection
        .where('receiverUid', isEqualTo: receiverUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ConnectionRequest.fromFirestore(doc))
              .toList();
        })
        .handleError((error) {
          debugPrint('watchIncomingRequests error: $error');
          return <ConnectionRequest>[];
        });
  }

  /// Listens to all accepted connections involving [uid], strictly deduplicating by other user UID.
  static Stream<List<ConnectionRequest>> watchAcceptedConnections(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _collection
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .where((doc) {
                final d = doc.data();
                return d['senderUid'] == uid || d['receiverUid'] == uid;
              })
              .map((doc) => ConnectionRequest.fromFirestore(doc))
              .toList();

          // Strictly deduplicate by the other user's UID to ensure no user appears twice
          final seenOtherUids = <String>{};
          final deduplicated = <ConnectionRequest>[];
          for (final item in list) {
            final otherUid =
                item.senderUid == uid ? item.receiverUid : item.senderUid;
            if (otherUid.isNotEmpty && seenOtherUids.add(otherUid)) {
              deduplicated.add(item);
            }
          }
          return deduplicated;
        })
        .handleError((error) {
          debugPrint('watchAcceptedConnections error: $error');
          return <ConnectionRequest>[];
        });
  }

  /// Accepts an incoming request safely using transactions to prevent duplicates.
  static Future<void> acceptRequest({
    required String requestId,
    required String receiverUid,
  }) async {
    final docRef = _collection.doc(requestId);
    final connectionRef = _firestore.collection('connections').doc(requestId);

    String senderUid = '';
    String receiverName = '';
    String senderName = '';
    String receiverRole = '';
    String senderRole = '';
    String receiverPhoto = '';
    String senderPhoto = '';
    String receiverUsername = '';
    String senderUsername = '';

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Connection request not found.');
      }

      final data = snapshot.data();
      if (data?['receiverUid'] != receiverUid) {
        throw Exception('You are not authorized to accept this request.');
      }

      senderUid = data?['senderUid']?.toString() ?? '';
      senderName = data?['senderName']?.toString() ?? 'Creator';
      senderRole = data?['senderRole']?.toString() ?? 'Creator';
      senderPhoto = (data?['senderProfileImage'] ??
              data?['senderProfilePhoto'] ??
              '')
          .toString();
      senderUsername = data?['senderUsername']?.toString() ?? '';

      receiverName = data?['receiverName']?.toString() ?? 'Creator';
      receiverRole = data?['receiverRole']?.toString() ?? 'Creator';
      receiverPhoto = (data?['receiverProfileImage'] ??
              data?['receiverProfilePhoto'] ??
              '')
          .toString();
      receiverUsername = data?['receiverUsername']?.toString() ?? '';

      final userIds = [senderUid, receiverUid]..sort();

      transaction.update(docRef, {
        'status': 'accepted',
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        connectionRef,
        {
          'connectionId': requestId,
          'requestId': requestId,
          'userIds': userIds,
          'senderUid': senderUid,
          'receiverUid': receiverUid,
          'status': 'accepted',
          'isRead': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    // Atomically increment connection counts in Profile_Data for both users
    if (senderUid.isNotEmpty && receiverUid.isNotEmpty) {
      try {
        final senderRef =
            _firestore.collection('Profile_Data').doc(senderUid);
        final receiverRef =
            _firestore.collection('Profile_Data').doc(receiverUid);
        await senderRef.set({
          'connectionsCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
        await receiverRef.set({
          'connectionsCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating connectionsCount: $e');
      }

      // Ensure conversation document exists between both users
      try {
        await ChatService.ensureConversation(
          uid1: receiverUid,
          details1: {
            'name': receiverName,
            'role': receiverRole,
            'photo': receiverPhoto,
            'username': receiverUsername,
          },
          uid2: senderUid,
          details2: {
            'name': senderName,
            'role': senderRole,
            'photo': senderPhoto,
            'username': senderUsername,
          },
        );
      } catch (e) {
        debugPrint('Error initializing conversation: $e');
      }
    }
  }

  /// Rejects an incoming request.
  static Future<void> rejectRequest({
    required String requestId,
    required String receiverUid,
  }) async {
    final docRef = _collection.doc(requestId);
    final connectionRef = _firestore.collection('connections').doc(requestId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw Exception('Connection request not found.');
    }

    final data = snapshot.data();
    if (data?['receiverUid'] != receiverUid) {
      throw Exception('You are not authorized to reject this request.');
    }

    await docRef.update({
      'status': 'rejected',
      'isRead': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await connectionRef.set({
        'status': 'rejected',
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Real-time stream of the number of accepted connections for [uid].
  static Stream<int> watchConnectionCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);

    return _firestore
        .collection('connections')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          final connectedUserIds = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final userIds = (data['userIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            for (final id in userIds) {
              if (id.isNotEmpty && id != uid) {
                connectedUserIds.add(id);
              }
            }
          }
          return connectedUserIds.length;
        })
        .handleError((e) {
          debugPrint('watchConnectionCount error: $e');
          return 0;
        });
  }

  /// Combined real-time stream of unread messages + pending incoming connection requests.
  static Stream<int> watchCombinedMessagesBadgeCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);

    late StreamController<int> controller;
    StreamSubscription? chatSub;
    StreamSubscription? reqSub;
    int unreadChats = 0;
    int pendingReqs = 0;

    void emit() {
      if (!controller.isClosed) {
        controller.add(unreadChats + pendingReqs);
      }
    }

    controller = StreamController<int>.broadcast(
      onListen: () {
        chatSub = ChatService.watchTotalUnreadCount(uid).listen(
          (c) {
            unreadChats = c;
            emit();
          },
          onError: (e) {
            debugPrint('watchTotalUnreadCount error: $e');
          },
        );

        reqSub = watchIncomingRequests(uid).listen(
          (requests) {
            pendingReqs = requests.length;
            emit();
          },
          onError: (e) {
            debugPrint('watchIncomingRequests error: $e');
          },
        );
      },
      onCancel: () {
        chatSub?.cancel();
        reqSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Fetches the set of user UIDs that already have an existing connection request
  /// (sent or received) or are connected with [currentUid].
  static Future<Set<String>> getConnectedOrRequestedUserIds(
    String currentUid,
  ) async {
    if (currentUid.isEmpty) return <String>{};

    final userIds = <String>{};

    try {
      // 1. Fetch from connections collection
      final connSnap = await _firestore
          .collection('connections')
          .where('userIds', arrayContains: currentUid)
          .get();

      for (final doc in connSnap.docs) {
        final data = doc.data();
        final status = data['status']?.toString();
        // Ignore rejected connections so creators could potentially re-connect or view
        if (status == 'rejected') continue;

        final uList = (data['userIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        for (final u in uList) {
          if (u.isNotEmpty && u != currentUid) {
            userIds.add(u);
          }
        }
        final sUid = data['senderUid']?.toString();
        final rUid = data['receiverUid']?.toString();
        if (sUid != null && sUid.isNotEmpty && sUid != currentUid) {
          userIds.add(sUid);
        }
        if (rUid != null && rUid.isNotEmpty && rUid != currentUid) {
          userIds.add(rUid);
        }
      }
    } catch (e) {
      debugPrint('Error fetching from connections: $e');
    }

    try {
      // 2. Also check connection_requests collection
      final reqSentSnap = await _collection
          .where('senderUid', isEqualTo: currentUid)
          .get();
      for (final doc in reqSentSnap.docs) {
        final status = doc.data()['status']?.toString();
        if (status == 'rejected') continue;
        final rUid = doc.data()['receiverUid']?.toString();
        if (rUid != null && rUid.isNotEmpty && rUid != currentUid) {
          userIds.add(rUid);
        }
      }

      final reqRecvSnap = await _collection
          .where('receiverUid', isEqualTo: currentUid)
          .get();
      for (final doc in reqRecvSnap.docs) {
        final status = doc.data()['status']?.toString();
        if (status == 'rejected') continue;
        final sUid = doc.data()['senderUid']?.toString();
        if (sUid != null && sUid.isNotEmpty && sUid != currentUid) {
          userIds.add(sUid);
        }
      }
    } catch (e) {
      debugPrint('Error fetching from connection_requests: $e');
    }

    return userIds;
  }

  /// Listens in real-time to the set of connected or requested user UIDs for [currentUid].
  static Stream<Set<String>> watchConnectedOrRequestedUserIds(
    String currentUid,
  ) {
    if (currentUid.isEmpty) return Stream.value(<String>{});

    return _firestore
        .collection('connections')
        .where('userIds', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
          final set = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status']?.toString();
            if (status == 'rejected') continue;

            final uList = (data['userIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            for (final u in uList) {
              if (u.isNotEmpty && u != currentUid) {
                set.add(u);
              }
            }
            final sUid = data['senderUid']?.toString();
            final rUid = data['receiverUid']?.toString();
            if (sUid != null && sUid != currentUid && sUid.isNotEmpty) {
              set.add(sUid);
            }
            if (rUid != null && rUid != currentUid && rUid.isNotEmpty) {
              set.add(rUid);
            }
          }
          return set;
        })
        .handleError((e) {
          debugPrint('watchConnectedOrRequestedUserIds error: $e');
          return <String>{};
        });
  }
}
