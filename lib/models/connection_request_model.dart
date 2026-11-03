import 'package:cloud_firestore/cloud_firestore.dart';

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
    final senderPhoto =
        (data['senderProfileImage'] ?? data['senderProfilePhoto'] ?? '')
            .toString();
    final receiverPhoto =
        (data['receiverProfileImage'] ?? data['receiverProfilePhoto'] ?? '')
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
