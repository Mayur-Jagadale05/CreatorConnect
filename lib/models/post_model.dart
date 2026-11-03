import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String userName;
  final String username;
  final String userRole;
  final String userProfilePhoto;
  final String title;
  final String description;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video' | 'pdf' | 'document' | 'none'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Getters aligning with creator* naming conventions
  String get creatorUid => userId;
  String get creatorName => userName;
  String get creatorUsername => username;
  String get creatorRole => userRole;
  String get creatorProfileImage => userProfilePhoto;
  String get postContent => description;
  String get postImage => mediaUrl;

  PostModel({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.username,
    required this.userRole,
    required this.userProfilePhoto,
    required this.title,
    required this.description,
    required this.mediaUrl,
    required this.mediaType,
    this.createdAt,
    this.updatedAt,
  });

  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PostModel(
      postId: doc.id,
      userId: (data['creatorUid'] ?? data['userId'] ?? '').toString().trim(),
      userName: (data['creatorName'] ?? data['userName'] ?? 'Creator')
          .toString()
          .trim(),
      username: (data['creatorUsername'] ?? data['username'] ?? '')
          .toString()
          .trim(),
      userRole: (data['creatorRole'] ?? data['userRole'] ?? 'Creator')
          .toString()
          .trim(),
      userProfilePhoto:
          (data['creatorProfileImage'] ?? data['userProfilePhoto'] ?? '')
              .toString()
              .trim(),
      title: (data['title'] ?? '').toString().trim(),
      description: (data['postContent'] ?? data['description'] ?? '')
          .toString()
          .trim(),
      mediaUrl: (data['postImage'] ?? data['mediaUrl'] ?? '').toString().trim(),
      mediaType: (data['mediaType'] ?? 'none').toString().trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      // Both naming conventions populated for 100% interoperability
      'userId': userId,
      'creatorUid': userId,
      'userName': userName,
      'creatorName': userName,
      'username': username,
      'creatorUsername': username,
      'userRole': userRole,
      'creatorRole': userRole,
      'userProfilePhoto': userProfilePhoto,
      'creatorProfileImage': userProfilePhoto,
      'title': title,
      'description': description,
      'postContent': description,
      'mediaUrl': mediaUrl,
      'postImage': mediaUrl,
      'mediaType': mediaType,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
