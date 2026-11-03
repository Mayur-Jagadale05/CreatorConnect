import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/models/educational_video_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EducationalVideoService {
  static const String educationBucket = 'Educationalvideo_picker';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _collection =
      _firestore.collection('educational_videos');

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

  static String _contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'video/mp4';
    }
  }

  /// Normalizes role string to canonical title case:
  /// 'Businessman', 'Influencer', 'Writer', 'Editor'
  static String getCanonicalRole(String rawRole) {
    final clean = rawRole.trim().toLowerCase();
    switch (clean) {
      case 'businessman':
        return 'Businessman';
      case 'influencer':
        return 'Influencer';
      case 'writer':
        return 'Writer';
      case 'editor':
      case 'video editor':
        return 'Editor';
      default:
        return rawRole.trim();
    }
  }

  /// Retrieves the authenticated user's actual registered role from Firestore.
  /// Single source of truth: Profile_Data, with fallback to users.
  static Future<String> getUserRegisteredRole(String uid) async {
    try {
      final doc = await _firestore.collection('Profile_Data').doc(uid).get();
      final data = doc.data();
      final role = data?['role']?.toString().trim();
      if (role != null && role.isNotEmpty) {
        return getCanonicalRole(role);
      }
    } catch (_) {}

    try {
      final legacy = await _firestore.collection('users').doc(uid).get();
      final data = legacy.data();
      final role = data?['role']?.toString().trim();
      if (role != null && role.isNotEmpty) {
        return getCanonicalRole(role);
      }
    } catch (_) {}

    return 'Creator';
  }

  /// Retrieves user profile details (fullName/name, role, etc.)
  static Future<Map<String, String>> getUserDetails(String uid) async {
    String name = 'Creator';
    String role = 'Creator';

    try {
      final doc = await _firestore.collection('Profile_Data').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        name =
            (data['fullName'] ?? data['name'] ?? data['username'] ?? 'Creator')
                .toString()
                .trim();
        role = (data['role'] ?? 'Creator').toString().trim();
      }
    } catch (_) {}

    if (name == 'Creator' || role == 'Creator') {
      try {
        final legacy = await _firestore.collection('users').doc(uid).get();
        final data = legacy.data();
        if (data != null) {
          if (name == 'Creator') {
            name =
                (data['fullName'] ??
                        data['name'] ??
                        data['username'] ??
                        'Creator')
                    .toString()
                    .trim();
          }
          if (role == 'Creator') {
            role = (data['role'] ?? 'Creator').toString().trim();
          }
        }
      } catch (_) {}
    }

    return {'name': name, 'role': getCanonicalRole(role)};
  }

  static bool _hasSyncedLegacyVideos = false;

  /// Uploads video bytes to Supabase Storage bucket 'Educationalvideo_picker'
  /// and saves metadata into Firestore 'educational_videos'.
  /// Validates authenticated user and database role.
  static Future<EducationalVideo> uploadAndRecordVideo({
    required String uid,
    required Uint8List bytes,
    required String fileName,
    String? title,
    String? description,
    String? fallbackRole,
  }) async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      throw Exception('Unauthorized: Logged-in user mismatch.');
    }

    final storage = _supabaseStorage;
    if (storage == null) {
      throw Exception('Supabase Storage is not initialized.');
    }

    // 1. Retrieve registered role and name directly from database
    final userDetails = await getUserDetails(uid);
    var registeredRole = userDetails['role'] ?? 'Creator';
    if ((registeredRole == 'Creator' || registeredRole.isEmpty) &&
        fallbackRole != null &&
        fallbackRole.isNotEmpty) {
      registeredRole = getCanonicalRole(fallbackRole);
    }

    final uploaderName =
        (userDetails['name']?.isNotEmpty == true &&
            userDetails['name'] != 'Creator')
        ? userDetails['name']!
        : (currentUser.displayName ?? 'Creator');

    // 2. Prepare file path & upload
    final originalExtension = fileName.split('.').last.toLowerCase();
    final extension = ['mp4', 'mov'].contains(originalExtension)
        ? originalExtension
        : 'mp4';
    final safeName = _safeFileName(fileName);
    final storagePath =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final bucket = storage.from(educationBucket);

    await bucket.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentTypeFor(extension),
        upsert: false,
      ),
    );

    final publicUrl = bucket.getPublicUrl(storagePath);

    final cleanTitle = (title ?? '').trim().isNotEmpty
        ? title!.trim()
        : ((description ?? '').trim().isNotEmpty
              ? (description!.trim().length > 40
                    ? '${description.trim().substring(0, 40)}...'
                    : description.trim())
              : 'Educational Video');

    final cleanDesc = (description ?? '').trim();

    // 3. Save to educational_videos collection
    final docRef = _collection.doc();
    final video = EducationalVideo(
      videoId: docRef.id,
      uploaderUid: uid,
      uploaderName: uploaderName,
      uploaderRole: registeredRole,
      title: cleanTitle,
      description: cleanDesc,
      videoUrl: publicUrl,
      thumbnailUrl: '',
      storagePath: storagePath,
      createdAt: DateTime.now(),
    );

    await docRef.set(video.toFirestore());

    // 4. Also sync latest video to Profile_Data
    try {
      await _firestore.collection('Profile_Data').doc(uid).set({
        'educationVideoUrl': publicUrl,
        'educationDescription': cleanDesc,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    return video;
  }

  /// Listens to educational videos for the currently logged-in user in real-time.
  /// Dynamically retrieves the actual registered role from Firestore profile data.
  ///
  /// CORE FILTERING CONDITIONS:
  /// 1. video.uploaderRole matches the logged-in user's actual registered role from Firestore.
  /// 2. video.uploaderUid is different from the logged-in user's UID (self-video exclusion).
  ///
  /// FINAL RULE:
  /// - Same Role + Different UID = Video Visible
  /// - Different Role = Video Hidden
  /// - Same UID = Own Video Hidden
  static Stream<List<EducationalVideo>> watchEducationalVideosForCurrentUser({
    required String currentUid,
    String? fallbackRole,
  }) async* {
    if (currentUid.isEmpty) {
      yield <EducationalVideo>[];
      return;
    }

    if (!_hasSyncedLegacyVideos) {
      _hasSyncedLegacyVideos = true;
      syncAllProfileVideos().catchError((e) {
        debugPrint('Background sync legacy videos error: $e');
      });
    }

    // 1. Retrieve the actual registered role from Firestore profile data (do not trust UI role)
    final registeredRole = await getUserRegisteredRole(currentUid);
    final targetRole = registeredRole != 'Creator' && registeredRole.isNotEmpty
        ? registeredRole
        : (fallbackRole != null ? getCanonicalRole(fallbackRole) : 'Creator');

    // 2. Stream and filter strictly matching the user's actual registered role
    yield* watchEducationalVideosForRole(
      role: targetRole,
      currentUid: currentUid,
    );
  }

  /// Listens to educational videos for a given role in real-time.
  /// MANDATORY QUERY LOGIC:
  /// 1. uploaderRole must exactly match the logged-in user's registered role.
  /// 2. uploaderUid must NOT match the logged-in user's Firebase Auth UID.
  /// 3. Latest videos first.
  ///
  /// conceptual filtering logic:
  /// video.uploaderRole == currentUserRole && video.uploaderUid != currentUserUid
  static Stream<List<EducationalVideo>> watchEducationalVideosForRole({
    required String role,
    required String currentUid,
  }) {
    if (!_hasSyncedLegacyVideos) {
      _hasSyncedLegacyVideos = true;
      syncAllProfileVideos().catchError((e) {
        debugPrint('Background sync legacy videos error: $e');
      });
    }

    final canonicalRole = getCanonicalRole(role);

    return _collection.snapshots().map((snapshot) {
      final videos = snapshot.docs
          .map((doc) => EducationalVideo.fromFirestore(doc))
          .where((video) {
            // Condition 1: Role exactly matches registered role
            final videoRole = getCanonicalRole(
              video.uploaderRole,
            ).toLowerCase();
            final expectedRole = canonicalRole.toLowerCase();
            final roleMatch =
                videoRole == expectedRole ||
                (expectedRole == 'editor' &&
                    (video.uploaderRole.toLowerCase() == 'video editor' ||
                        video.uploaderRole.toLowerCase() == 'editor'));

            // Condition 2: MUST NOT be uploaded by the current user (SELF-EXCLUSION)
            final notSelf =
                video.uploaderUid.isNotEmpty && video.uploaderUid != currentUid;

            // Condition 3: Has a valid video URL
            final hasUrl = video.videoUrl.trim().isNotEmpty;

            return roleMatch && notSelf && hasUrl;
          })
          .toList();

      // Latest videos first
      videos.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      return videos;
    });
  }

  /// Listens to the current user's own uploaded videos (for Profile management).
  static Stream<List<EducationalVideo>> watchMyUploadedVideos(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _collection.where('uploaderUid', isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final videos = snapshot.docs
          .map((doc) => EducationalVideo.fromFirestore(doc))
          .toList();

      videos.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      return videos;
    });
  }

  /// Deletes an educational video.
  /// Only the original uploader can delete their own video.
  static Future<void> deleteVideo({
    required String videoId,
    required String currentUid,
  }) async {
    final doc = await _collection.doc(videoId).get();
    if (!doc.exists) return;

    final data = doc.data();
    final uploaderUid = data?['uploaderUid']?.toString();

    // Security check: only original uploader can delete
    if (uploaderUid != currentUid) {
      throw Exception('You are not authorized to delete this video.');
    }

    final storagePath = data?['storagePath']?.toString();
    final videoUrl = data?['videoUrl']?.toString();

    // 1. Delete Firestore document
    await _collection.doc(videoId).delete();

    // 2. Remove file from Supabase Storage
    if (storagePath != null && storagePath.trim().isNotEmpty) {
      try {
        await _supabaseStorage?.from(educationBucket).remove([storagePath]);
      } catch (e) {
        debugPrint('Failed to remove video from Supabase Storage: $e');
      }
    }

    // 3. Clear Profile_Data if this video URL matches
    try {
      final profileDoc = await _firestore
          .collection('Profile_Data')
          .doc(currentUid)
          .get();
      if (profileDoc.exists) {
        final currentProfileUrl = profileDoc
            .data()?['educationVideoUrl']
            ?.toString();
        if (currentProfileUrl == videoUrl) {
          await _firestore.collection('Profile_Data').doc(currentUid).update({
            'educationVideoUrl': '',
            'educationDescription': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  /// Syncs an existing video from Profile_Data into educational_videos
  /// to ensure backward compatibility and prevent data loss.
  static Future<void> syncProfileVideoIfMissing(String uid) async {
    if (uid.isEmpty) return;

    try {
      final profileDoc = await _firestore
          .collection('Profile_Data')
          .doc(uid)
          .get();
      if (!profileDoc.exists) return;

      final data = profileDoc.data();
      final videoUrl = data?['educationVideoUrl']?.toString().trim() ?? '';
      if (videoUrl.isEmpty) return;

      // Check if already in educational_videos
      final existing = await _collection
          .where('uploaderUid', isEqualTo: uid)
          .where('videoUrl', isEqualTo: videoUrl)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        final name =
            (data?['fullName'] ??
                    data?['name'] ??
                    data?['username'] ??
                    'Creator')
                .toString()
                .trim();
        final rawRole = (data?['role'] ?? 'Creator').toString().trim();
        final role = getCanonicalRole(rawRole);
        final desc = (data?['educationDescription'] ?? '').toString().trim();

        final docRef = _collection.doc();
        await docRef.set({
          'videoId': docRef.id,
          'uploaderUid': uid,
          'uploaderName': name,
          'uploaderRole': role,
          'title': desc.isNotEmpty
              ? (desc.length > 40 ? '${desc.substring(0, 40)}...' : desc)
              : 'Educational Video',
          'description': desc,
          'videoUrl': videoUrl,
          'thumbnailUrl': '',
          'storagePath': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Sync video error: $e');
    }
  }

  /// Scans all Profile_Data records and syncs any existing education videos
  /// into educational_videos to guarantee no existing videos are lost.
  static Future<void> syncAllProfileVideos() async {
    try {
      final snapshot = await _firestore.collection('Profile_Data').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final videoUrl = data['educationVideoUrl']?.toString().trim() ?? '';
        if (videoUrl.isNotEmpty) {
          await syncProfileVideoIfMissing(doc.id);
        }
      }
    } catch (e) {
      debugPrint('Sync all videos error: $e');
    }
  }
}
