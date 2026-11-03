import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatMessage {
  final String messageId;
  final String senderUid;
  final String receiverUid;
  final String text;
  final DateTime? timestamp;
  final bool read;

  ChatMessage({
    required this.messageId,
    required this.senderUid,
    required this.receiverUid,
    required this.text,
    this.timestamp,
    this.read = false,
  });

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ChatMessage(
      messageId: doc.id,
      senderUid: data['senderUid']?.toString() ?? '',
      receiverUid: data['receiverUid']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      read: data['read'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'text': text,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
      'read': read,
    };
  }
}

class ChatConversation {
  final String chatId;
  final List<String> participants;
  final Map<String, dynamic> participantDetails;
  final String lastMessage;
  final String lastMessageSenderUid;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;

  ChatConversation({
    required this.chatId,
    required this.participants,
    required this.participantDetails,
    required this.lastMessage,
    required this.lastMessageSenderUid,
    this.lastMessageTime,
    this.createdAt,
  });

  factory ChatConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final parts = (data['participants'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    return ChatConversation(
      chatId: doc.id,
      participants: parts,
      participantDetails:
          (data['participantDetails'] as Map<String, dynamic>?) ?? {},
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageSenderUid: data['lastMessageSenderUid']?.toString() ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> getOtherParticipant(String currentUid) {
    for (final entry in participantDetails.entries) {
      if (entry.key != currentUid) {
        final d = entry.value as Map<String, dynamic>? ?? {};
        final name = (d['name'] ?? d['fullName'] ?? '').toString().trim();
        return {
          'uid': entry.key,
          'name': name.isNotEmpty ? name : 'Creator',
          'username': (d['username'] ?? '').toString().trim(),
          'role': (d['role'] ?? 'Creator').toString().trim(),
          'photo': (d['photo'] ?? d['profilePhotoUrl'] ?? '').toString().trim(),
        };
      }
    }
    // If not found in participantDetails, check participants list
    for (final uid in participants) {
      if (uid != currentUid) {
        return {
          'uid': uid,
          'name': 'Creator',
          'username': '',
          'role': 'Creator',
          'photo': '',
        };
      }
    }
    return {
      'uid': '',
      'name': 'Creator',
      'username': '',
      'role': 'Creator',
      'photo': '',
    };
  }
}

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _chats =
      _firestore.collection('chats');

  /// Fetches the profile data for [uid] from the Profile_Data collection.
  static Future<Map<String, dynamic>> getUserProfile(String uid) async {
    if (uid.isEmpty) {
      return {
        'uid': '',
        'name': 'Creator',
        'username': '',
        'role': 'Creator',
        'photo': '',
      };
    }

    try {
      final doc = await _firestore.collection('Profile_Data').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        final name = (d['fullName'] ?? d['name'] ?? '').toString().trim();
        final username = (d['username'] ?? '').toString().trim();
        final role = (d['role'] ?? 'Creator').toString().trim();
        final photo =
            (d['photo'] ?? d['profilePhotoUrl'] ?? '').toString().trim();

        return {
          'uid': uid,
          'name': name.isNotEmpty ? name : 'Creator',
          'username': username,
          'role': role.isNotEmpty ? role : 'Creator',
          'photo': photo,
        };
      }
    } catch (e) {
      debugPrint('getUserProfile error for $uid: $e');
    }

    return {
      'uid': uid,
      'name': 'Creator',
      'username': '',
      'role': 'Creator',
      'photo': '',
    };
  }

  /// Returns a deterministic chat ID for any two users.
  static String getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  /// Ensures a conversation document exists between [uid1] and [uid2].
  static Future<String> ensureConversation({
    required String uid1,
    required Map<String, dynamic> details1,
    required String uid2,
    required Map<String, dynamic> details2,
  }) async {
    final chatId = getChatId(uid1, uid2);
    final docRef = _chats.doc(chatId);

    var d1 = Map<String, dynamic>.from(details1);
    var d2 = Map<String, dynamic>.from(details2);

    final name1 = (d1['name'] ?? d1['fullName'] ?? '').toString().trim();
    if (name1.isEmpty || name1 == 'Creator') {
      final p1 = await getUserProfile(uid1);
      if (p1['name'] != 'Creator') {
        d1 = p1;
      }
    }

    final name2 = (d2['name'] ?? d2['fullName'] ?? '').toString().trim();
    if (name2.isEmpty || name2 == 'Creator') {
      final p2 = await getUserProfile(uid2);
      if (p2['name'] != 'Creator') {
        d2 = p2;
      }
    }

    await docRef.set({
      'chatId': chatId,
      'participants': [uid1, uid2],
      'participantDetails': {
        uid1: {
          'name': d1['name'] ?? d1['fullName'] ?? 'Creator',
          'username': d1['username'] ?? '',
          'role': d1['role'] ?? 'Creator',
          'photo': d1['photo'] ?? d1['profilePhotoUrl'] ?? '',
        },
        uid2: {
          'name': d2['name'] ?? d2['fullName'] ?? 'Creator',
          'username': d2['username'] ?? '',
          'role': d2['role'] ?? 'Creator',
          'photo': d2['photo'] ?? d2['profilePhotoUrl'] ?? '',
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return chatId;
  }

  /// Sends a text message in [chatId].
  static Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String receiverUid,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final chatDocRef = _chats.doc(chatId);
    final chatDocSnap = await chatDocRef.get();

    // Ensure conversation exists and both participant details are populated
    if (!chatDocSnap.exists ||
        chatDocSnap.data() == null ||
        chatDocSnap.data()?['participantDetails'] == null) {
      final senderProfile = await getUserProfile(senderUid);
      final receiverProfile = await getUserProfile(receiverUid);

      await chatDocRef.set({
        'chatId': chatId,
        'participants': [senderUid, receiverUid],
        'participantDetails': {
          senderUid: senderProfile,
          receiverUid: receiverProfile,
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // Patch any missing participant names or participants array
      final existingData = chatDocSnap.data()!;
      final details =
          existingData['participantDetails'] as Map<String, dynamic>? ?? {};
      final sDetails =
          details[senderUid] as Map<String, dynamic>? ?? {};
      final rDetails =
          details[receiverUid] as Map<String, dynamic>? ?? {};

      final sName =
          (sDetails['name'] ?? sDetails['fullName'] ?? '').toString().trim();
      final rName =
          (rDetails['name'] ?? rDetails['fullName'] ?? '').toString().trim();

      final Map<String, dynamic> patch = {
        'participants': [senderUid, receiverUid],
      };

      if (sName.isEmpty || sName == 'Creator') {
        final p = await getUserProfile(senderUid);
        if (p['name'] != 'Creator') {
          patch['participantDetails.$senderUid'] = p;
        }
      }

      if (rName.isEmpty || rName == 'Creator') {
        final p = await getUserProfile(receiverUid);
        if (p['name'] != 'Creator') {
          patch['participantDetails.$receiverUid'] = p;
        }
      }

      await chatDocRef.set(patch, SetOptions(merge: true));
    }

    final batch = _firestore.batch();
    final messageDoc = chatDocRef.collection('messages').doc();

    batch.set(messageDoc, {
      'messageId': messageDoc.id,
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'text': cleanText,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    batch.set(chatDocRef, {
      'lastMessage': cleanText,
      'lastMessageSenderUid': senderUid,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Marks all unread messages received by [currentUid] in [chatId] as read.
  static Future<void> markMessagesAsRead({
    required String chatId,
    required String currentUid,
  }) async {
    try {
      final unread = await _chats
          .doc(chatId)
          .collection('messages')
          .where('receiverUid', isEqualTo: currentUid)
          .where('read', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markMessagesAsRead error: $e');
    }
  }

  /// Listens to real-time messages in [chatId].
  static Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        })
        .handleError((e) {
          debugPrint('watchMessages error: $e');
          return <ChatMessage>[];
        });
  }

  /// Listens to all active conversations for [uid].
  static Stream<List<ChatConversation>> watchUserConversations(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ChatConversation.fromFirestore(doc))
              .toList();
          // Sort by lastMessageTime descending (most recent first)
          list.sort((a, b) {
            final tA = a.lastMessageTime ?? a.createdAt ?? DateTime(1970);
            final tB = b.lastMessageTime ?? b.createdAt ?? DateTime(1970);
            return tB.compareTo(tA);
          });
          return list;
        })
        .handleError((e) {
          debugPrint('watchUserConversations error: $e');
          return <ChatConversation>[];
        });
  }

  /// Listens to total unread messages count for [uid] across all conversations.
  static Stream<int> watchTotalUnreadCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);

    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((chatsSnapshot) {
          int count = 0;
          for (final chatDoc in chatsSnapshot.docs) {
            final data = chatDoc.data();
            // If the last message was sent by someone else and isn't read
            final lastSender = data['lastMessageSenderUid']?.toString() ?? '';
            if (lastSender.isNotEmpty && lastSender != uid) {
              // Note: could also check lastMessageRead if denormalized
              count += 1;
            }
          }
          return count;
        })
        .handleError((e) {
          debugPrint('watchTotalUnreadCount error: $e');
          return 0;
        });
  }
}
