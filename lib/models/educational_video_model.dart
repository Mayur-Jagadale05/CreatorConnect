import 'package:cloud_firestore/cloud_firestore.dart';

class EducationalVideo {
  final String videoId;
  final String uploaderUid;
  final String uploaderName;
  final String uploaderRole;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final DateTime? createdAt;
  final String? storagePath;

  EducationalVideo({
    required this.videoId,
    required this.uploaderUid,
    required this.uploaderName,
    required this.uploaderRole,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.createdAt,
    this.storagePath,
  });

  factory EducationalVideo.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EducationalVideo(
      videoId: doc.id,
      uploaderUid: (data['uploaderUid'] ?? '').toString().trim(),
      uploaderName: (data['uploaderName'] ?? 'Creator').toString().trim(),
      uploaderRole: (data['uploaderRole'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
      videoUrl: (data['videoUrl'] ?? '').toString().trim(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString().trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      storagePath: data['storagePath']?.toString().trim(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'videoId': videoId,
      'uploaderUid': uploaderUid,
      'uploaderName': uploaderName,
      'uploaderRole': uploaderRole,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'storagePath': storagePath ?? '',
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

