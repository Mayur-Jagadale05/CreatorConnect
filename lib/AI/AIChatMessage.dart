import 'package:cloud_firestore/cloud_firestore.dart';

/// Message sender role
enum MessageRole {
  user,
  assistant;

  String toValue() => name;

  static MessageRole fromValue(String? value) {
    if (value?.toLowerCase() == 'user') {
      return MessageRole.user;
    }
    return MessageRole.assistant;
  }
}

/// Represents an individual chat message in CreatorConnect AI
class AIChatMessage {
  final String id;
  final String chatId;
  final String userId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<Map<String, dynamic>> suggestedCreators;
  final bool isError;
  final bool isStreaming;
  final Map<String, dynamic>? metadata;

  const AIChatMessage({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedCreators = const [],
    this.isError = false,
    this.isStreaming = false,
    this.metadata,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  AIChatMessage copyWith({
    String? id,
    String? chatId,
    String? userId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<Map<String, dynamic>>? suggestedCreators,
    bool? isError,
    bool? isStreaming,
    Map<String, dynamic>? metadata,
  }) {
    return AIChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      suggestedCreators: suggestedCreators ?? this.suggestedCreators,
      isError: isError ?? this.isError,
      isStreaming: isStreaming ?? this.isStreaming,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts this message to a Firestore document map
  Map<String, dynamic> toFirestore() {
    return {
      'messageId': id,
      'chatId': chatId,
      'userId': userId,
      'role': role.toValue(),
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'clientTimestamp': timestamp.millisecondsSinceEpoch,
      if (suggestedCreators.isNotEmpty) 'suggestedCreators': suggestedCreators,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates a message from a Firestore document snapshot
  factory AIChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AIChatMessage.fromMap(data, doc.id);
  }

  /// Creates a message from a raw map
  factory AIChatMessage.fromMap(Map<String, dynamic> data, String fallbackId) {
    DateTime parsedDate = DateTime.now();

    final timestampField = data['timestamp'];
    final clientTimestamp = data['clientTimestamp'];

    if (timestampField is Timestamp) {
      parsedDate = timestampField.toDate();
    } else if (clientTimestamp is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(clientTimestamp);
    } else if (timestampField is String) {
      parsedDate = DateTime.tryParse(timestampField) ?? DateTime.now();
    }

    List<Map<String, dynamic>> creatorsList = [];
    if (data['suggestedCreators'] is List) {
      creatorsList = (data['suggestedCreators'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return AIChatMessage(
      id: data['messageId'] as String? ?? fallbackId,
      chatId: data['chatId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      role: MessageRole.fromValue(data['role'] as String?),
      content: data['content'] as String? ?? '',
      timestamp: parsedDate,
      suggestedCreators: creatorsList,
      isError: data['isError'] as bool? ?? false,
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
    );
  }
}
