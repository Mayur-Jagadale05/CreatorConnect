import 'package:cloud_firestore/cloud_firestore.dart';

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
    final parts =
        (data['participants'] as List<dynamic>?)
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
    return {
      'uid': '',
      'name': 'Creator',
      'username': '',
      'role': 'Creator',
      'photo': '',
    };
  }
}
