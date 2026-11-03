import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/models/post_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _posts = _firestore
      .collection('posts');

  static const String _profileBucket = 'img_picker';
  static const String _portfolioBucket = 'portfolios_picker';
  static const String _videoBucket = 'Educationalvideo_picker';

  static SupabaseStorageClient? get _supabaseStorage {
    try {
      return Supabase.instance.client.storage;
    } catch (e) {
      debugPrint('Supabase storage unavailable: $e');
      return null;
    }
  }

  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static String _contentTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads post media to Supabase Storage and returns the public URL.
  static Future<String?> uploadPostMedia({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String mediaType, // 'image' | 'video' | 'pdf' | 'document'
  }) async {
    final storage = _supabaseStorage;
    if (storage == null) {
      throw Exception('Supabase Storage is not initialized.');
    }

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : (mediaType == 'image'
              ? 'jpg'
              : mediaType == 'video'
              ? 'mp4'
              : 'pdf');

    final safeName = _safeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Follow the single-folder format '$userId/<timestamp>_<filename>' matching ProfileDetailsPage
    final path = '$userId/${timestamp}_post_$safeName';

    // Candidate buckets ordered by appropriateness
    final candidateBuckets = <String>{
      if (mediaType == 'image') _profileBucket,
      if (mediaType == 'video') _videoBucket,
      _portfolioBucket,
      _profileBucket,
      _videoBucket,
    }.toList();

    StorageException? lastStorageError;

    for (final bucketName in candidateBuckets) {
      try {
        final bucket = storage.from(bucketName);
        await bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(ext),
            upsert: false, // Must be false to avoid requiring UPDATE RLS permission
          ),
        );

        return bucket.getPublicUrl(path);
      } on StorageException catch (e) {
        lastStorageError = e;
        debugPrint(
          'Supabase upload to "$bucketName" encountered ${e.statusCode}: ${e.message}. Trying next bucket...',
        );
      } catch (e) {
        debugPrint('Supabase upload error to "$bucketName": $e');
      }
    }

    if (lastStorageError != null) {
      throw lastStorageError;
    }

    throw Exception('Failed to upload media to Supabase Storage.');
  }

  /// Creates a new post document in `posts/{postId}`.
  static Future<String> createPost({
    required String userId,
    required String userName,
    required String username,
    required String userRole,
    required String userProfilePhoto,
    required String title,
    required String description,
    String mediaUrl = '',
    String mediaType = 'none',
  }) async {
    final docRef = _posts.doc();
    final cleanRole = userRole.trim().isEmpty ? 'Creator' : userRole.trim();
    final cleanTitle = title.trim();
    final cleanDesc = description.trim();
    final cleanMediaUrl = mediaUrl.trim();

    await docRef.set({
      'postId': docRef.id,
      // Store both creator* and user* schemas for 100% interoperability
      'userId': userId,
      'creatorUid': userId,
      'userName': userName,
      'creatorName': userName,
      'username': username,
      'creatorUsername': username,
      'userRole': cleanRole,
      'creatorRole': cleanRole,
      'userProfilePhoto': userProfilePhoto,
      'creatorProfileImage': userProfilePhoto,
      'title': cleanTitle,
      'description': cleanDesc,
      'postContent': cleanDesc,
      'mediaUrl': cleanMediaUrl,
      'postImage': cleanMediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Updates an existing post. Only the post author can update.
  static Future<void> editPost({
    required String postId,
    required String userId,
    required String title,
    required String description,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final docRef = _posts.doc(postId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw Exception('Post not found.');
    }

    final data = snapshot.data();
    final authorId = data?['userId'] ?? data?['creatorUid'];
    if (authorId != userId) {
      throw Exception('You are not authorized to edit this post.');
    }

    final Map<String, dynamic> updates = {
      'title': title.trim(),
      'description': description.trim(),
      'postContent': description.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (mediaUrl != null) {
      updates['mediaUrl'] = mediaUrl.trim();
      updates['postImage'] = mediaUrl.trim();
    }
    if (mediaType != null) {
      updates['mediaType'] = mediaType;
    }

    await docRef.update(updates);
  }

  /// Deletes an existing post. Only the post author can delete.
  static Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    final docRef = _posts.doc(postId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data();
    final authorId = data?['userId'] ?? data?['creatorUid'];
    if (authorId != userId) {
      throw Exception('You are not authorized to delete this post.');
    }

    await docRef.delete();
  }

  /// Streams all posts created by [userId], sorted newest first.
  static Stream<List<PostModel>> watchUserPosts(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _posts
        .where(
          Filter.or(
            Filter('userId', isEqualTo: userId),
            Filter('creatorUid', isEqualTo: userId),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            final tA = a.createdAt ?? DateTime(1970);
            final tB = b.createdAt ?? DateTime(1970);
            return tB.compareTo(tA);
          });
          return list;
        })
        .handleError((e) {
          debugPrint('watchUserPosts error: $e');
          return <PostModel>[];
        });
  }

  /// Streams posts filtered by [role], sorted newest first.
  static Stream<List<PostModel>> watchRolePosts(String role) {
    if (role.isEmpty) return Stream.value([]);

    return _posts
        .where('userRole', isEqualTo: role)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            final tA = a.createdAt ?? DateTime(1970);
            final tB = b.createdAt ?? DateTime(1970);
            return tB.compareTo(tA);
          });
          return list;
        })
        .handleError((e) {
          debugPrint('watchRolePosts error: $e');
          return <PostModel>[];
        });
  }

  /// Deletes all posts created by Businessmen from Firestore.
  static Future<int> deleteBusinessmanPosts() async {
    int deletedCount = 0;
    try {
      final snap1 = await _posts
          .where('userRole', isEqualTo: 'Businessman')
          .get();
      for (final doc in snap1.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      final snap2 = await _posts
          .where('creatorRole', isEqualTo: 'Businessman')
          .get();
      for (final doc in snap2.docs) {
        try {
          await doc.reference.delete();
          deletedCount++;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting Businessman posts: $e');
    }
    return deletedCount;
  }
}
