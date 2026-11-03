import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/models/educational_video_model.dart';
import 'package:creatorconnect/services/educational_video_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileDetailsPage extends StatefulWidget {
  final String? targetUserId;
  final String? uid;
  const ProfileDetailsPage({super.key, this.targetUserId, this.uid});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final ImagePicker imagePicker = ImagePicker();
  XFile? selectedImage;
  Uint8List? imageBytes;
  PlatformFile? selectedPortfolio;
  PlatformFile? selectedEducationVideo;

  bool isSaving = false;
  bool isEditing = false;
  bool isLoading = true;

  String? profilePhotoUrl;
  String? portfolioUrl;
  String? educationVideoUrl;
  String? registeredRole;
  String? registeredEmail;

  Map<String, dynamic>? _profileBackup;

  final Color primaryColor = const Color(0xFF35132F);
  final Color backgroundColor = const Color(0xFFF7F5F3);
  final Color fieldColor = const Color(0xFFF0EDF0);

  String selectedRole = 'Influencer';
  String selectedCategory = 'Lifestyle & Vlogging';
  String selectedExperience = 'Intermediate (1-3 years)';

  final nameController = TextEditingController(text: '');
  final usernameController = TextEditingController(text: '');
  final bioController = TextEditingController(text: '');
  final locationController = TextEditingController(text: '');
  final instagramController = TextEditingController(text: '');
  final youtubeController = TextEditingController(text: '');
  final websiteController = TextEditingController(text: '');
  final skillsController = TextEditingController(text: '');
  final projectsController = TextEditingController(text: '');
  final educationDescriptionController = TextEditingController(text: '');

  static const String profileBucket = 'img_picker';
  static const String portfolioBucket = 'portfolios_picker';

  static const List<String> allowedRoles = [
    'Influencer',
    'Editor',
    'Writer',
    'Businessman',
  ];
  static const List<String> categories = [
    'Lifestyle & Vlogging',
    'Technology',
    'Education',
    'Fashion & Beauty',
    'Gaming',
    'Travel',
    'Video Editing',
    'Content Writing',
    'Business Marketing',
  ];
  static const List<String> experiences = [
    'Beginner (0-1 year)',
    'Intermediate (1-3 years)',
    'Experienced (3-5 years)',
    'Expert (5+ years)',
  ];

  String? get targetUid => widget.uid ?? widget.targetUserId;

  bool get isOwnProfile {
    final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return false;
    return targetUid == null || targetUid == currentUid;
  }

  String? get effectiveUid =>
      targetUid ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid;

  SupabaseStorageClient? get _supabaseStorage {
    try {
      return Supabase.instance.client.storage;
    } catch (e) {
      debugPrint('Supabase storage unavailable: $e');
      return null;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openUploadedFile(String? url, String fileType) async {
    if (url == null || url.trim().isEmpty) {
      showMessage(
        'No uploaded $fileType found. Save the profile after uploading.',
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      showMessage('The $fileType URL is invalid. Please upload it again.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        showMessage('Could not open the $fileType. Please try again.');
      }
    } catch (e) {
      debugPrint('Unable to open $fileType: $e');
      showMessage('Unable to open the $fileType. Check the uploaded file URL.');
    }
  }

  Future<void> pickImage() async {
    if (!isOwnProfile) return;
    try {
      final image = await imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      if (await image.length() > 5 * 1024 * 1024) {
        showMessage('Image size must be 5MB or less.');
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        selectedImage = image;
        imageBytes = bytes;
      });
    } catch (e) {
      showMessage('Unable to select image: $e');
    }
  }

  Future<void> pickPortfolio() async {
    if (!isOwnProfile) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'mp4', 'mov', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      if (file.size > 50 * 1024 * 1024) {
        showMessage('Portfolio file size must be 50MB or less.');
        return;
      }
      if (file.bytes == null) {
        showMessage('Could not read the selected file.');
        return;
      }
      setState(() => selectedPortfolio = file);
    } catch (e) {
      showMessage('Unable to select portfolio: $e');
    }
  }

  Future<void> pickEducationVideo() async {
    if (!isOwnProfile) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      if (file.size > 50 * 1024 * 1024) {
        showMessage('Education video must be 50MB or less.');
        return;
      }
      if (file.bytes == null) {
        showMessage('Could not read the selected video.');
        return;
      }
      setState(() => selectedEducationVideo = file);
    } catch (e) {
      showMessage('Unable to select education video: $e');
    }
  }

  Future<void> _confirmDeleteVideo(EducationalVideo video) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != video.uploaderUid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Video?'),
        content: Text(
          'Are you sure you want to delete "${video.title}"? This video will be permanently removed for all other users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await EducationalVideoService.deleteVideo(
          videoId: video.videoId,
          currentUid: user.uid,
        );
        showMessage('Educational video deleted.');
        setState(() {
          if (educationVideoUrl == video.videoUrl) {
            educationVideoUrl = null;
          }
        });
      } catch (e) {
        showMessage('Failed to delete video: $e');
      }
    }
  }

  Widget _buildMyUploadedVideosList(String uid) {
    return StreamBuilder<List<EducationalVideo>>(
      stream: EducationalVideoService.watchMyUploadedVideos(uid),
      builder: (context, snapshot) {
        final myVideos = snapshot.data ?? [];
        if (myVideos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Your Uploaded Educational Videos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF35132F),
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myVideos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final vid = myVideos[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCE5F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFF35132F),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vid.title.isNotEmpty
                                  ? vid.title
                                  : 'Educational Video',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF302A33),
                              ),
                            ),
                            if (vid.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                vid.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF827985),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            openUploadedFile(vid.videoUrl, 'education video'),
                        icon: const Icon(
                          Icons.play_circle_outline,
                          size: 20,
                          color: Color(0xFF35132F),
                        ),
                        tooltip: 'Watch Video',
                      ),
                      if (isEditing && isOwnProfile)
                        IconButton(
                          onPressed: () => _confirmDeleteVideo(vid),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: Colors.red,
                          ),
                          tooltip: 'Delete Video',
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
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

  String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Future<String?> _uploadProfilePhoto(firebase_auth.User user) async {
    if (imageBytes == null || selectedImage == null) return null;
    final storage = _supabaseStorage;
    if (storage == null) {
      throw Exception('Supabase Storage is not initialized.');
    }
    final originalExtension = selectedImage!.name.split('.').last.toLowerCase();
    final extension =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(originalExtension)
            ? originalExtension
            : 'jpg';
    final path =
        '${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final bucket = storage.from(profileBucket);
    await bucket.uploadBinary(
      path,
      imageBytes!,
      fileOptions: FileOptions(
        contentType: _contentTypeFor(extension),
        upsert: false,
      ),
    );
    return bucket.getPublicUrl(path);
  }

  Future<String?> _uploadPortfolio(firebase_auth.User user) async {
    final file = selectedPortfolio;
    if (file == null || file.bytes == null) return null;
    final storage = _supabaseStorage;
    if (storage == null) {
      throw Exception('Supabase Storage is not initialized.');
    }
    final extension = (file.extension ?? '').toLowerCase();
    if (!['pdf', 'mp4', 'mov', 'png', 'jpg', 'jpeg'].contains(extension)) {
      throw Exception('Unsupported portfolio file type.');
    }
    final path =
        '${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(file.name)}';
    final bucket = storage.from(portfolioBucket);
    await bucket.uploadBinary(
      path,
      file.bytes!,
      fileOptions: FileOptions(
        contentType: _contentTypeFor(extension),
        upsert: false,
      ),
    );
    return bucket.getPublicUrl(path);
  }



  Future<void> loadProfile() async {
    final uid = effectiveUid;
    if (uid == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      // Fetch from 'Profile_Data' collection
      var profileDataDoc = await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(uid)
          .get();

      // Legacy fallback: check 'users' if missing in 'Profile_Data'
      if (!profileDataDoc.exists || profileDataDoc.data() == null) {
        try {
          final usersDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (usersDoc.exists && usersDoc.data() != null) {
            await FirebaseFirestore.instance
                .collection('Profile_Data')
                .doc(uid)
                .set(usersDoc.data()!, SetOptions(merge: true));
            profileDataDoc = usersDoc;
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final data = profileDataDoc.data() ?? <String, dynamic>{};
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final fallbackEmail = isOwnProfile ? currentUser?.email : null;
      final fallbackName = isOwnProfile ? currentUser?.displayName : null;

      setState(() {
        registeredEmail = data['email'] as String? ?? fallbackEmail;
        nameController.text =
            data['fullName'] as String? ?? data['name'] as String? ?? fallbackName ?? '';
        usernameController.text = data['username'] as String? ?? '';
        bioController.text = data['bio'] as String? ?? '';
        locationController.text = data['location'] as String? ?? '';
        instagramController.text =
            data['instagramUrl'] as String? ?? data['instagram'] as String? ?? '';
        youtubeController.text =
            data['youtubeUrl'] as String? ?? data['youtube'] as String? ?? '';
        websiteController.text =
            data['websiteUrl'] as String? ?? data['website'] as String? ?? '';
        skillsController.text = data['skills'] as String? ?? '';
        projectsController.text =
            data['previousProjects'] as String? ?? data['projects'] as String? ?? '';
        educationDescriptionController.text =
            data['educationDescription'] as String? ?? '';
        profilePhotoUrl =
            data['profilePhotoUrl'] as String? ?? data['photo'] as String?;
        portfolioUrl = data['portfolioUrl'] as String?;
        educationVideoUrl = data['educationVideoUrl'] as String?;
        final role = data['role'] as String?;
        if (role != null && allowedRoles.contains(role)) {
          registeredRole = role;
          selectedRole = role;
        }
        final category = data['category'] as String?;
        if (category != null && categories.contains(category)) {
          selectedCategory = category;
        }
        final experience = data['experience'] as String?;
        if (experience != null && experiences.contains(experience)) {
          selectedExperience = experience;
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Unable to load profile: $e');
      if (mounted) setState(() => isLoading = false);
      showMessage('Unable to load profile. Please try again.');
    }
  }

  void startEditing() {
    if (isSaving || isLoading || !isOwnProfile) return;
    setState(() {
      _profileBackup = {
        'fullName': nameController.text,
        'username': usernameController.text,
        'bio': bioController.text,
        'location': locationController.text,
        'instagram': instagramController.text,
        'youtube': youtubeController.text,
        'website': websiteController.text,
        'skills': skillsController.text,
        'projects': projectsController.text,
        'educationDescription': educationDescriptionController.text,
        'role': selectedRole,
        'category': selectedCategory,
        'experience': selectedExperience,
        'profilePhotoUrl': profilePhotoUrl,
        'portfolioUrl': portfolioUrl,
        'educationVideoUrl': educationVideoUrl,
      };
      isEditing = true;
    });
  }

  void cancelEditing() {
    if (isSaving || _profileBackup == null) return;
    final backup = _profileBackup!;
    setState(() {
      nameController.text = backup['fullName'] as String;
      usernameController.text = backup['username'] as String;
      bioController.text = backup['bio'] as String;
      locationController.text = backup['location'] as String;
      instagramController.text = backup['instagram'] as String;
      youtubeController.text = backup['youtube'] as String;
      websiteController.text = backup['website'] as String;
      skillsController.text = backup['skills'] as String;
      projectsController.text = backup['projects'] as String;
      educationDescriptionController.text =
          backup['educationDescription'] as String;
      selectedRole = backup['role'] as String;
      selectedCategory = backup['category'] as String;
      selectedExperience = backup['experience'] as String;
      profilePhotoUrl = backup['profilePhotoUrl'] as String?;
      portfolioUrl = backup['portfolioUrl'] as String?;
      educationVideoUrl = backup['educationVideoUrl'] as String?;
      selectedImage = null;
      imageBytes = null;
      selectedPortfolio = null;
      selectedEducationVideo = null;
      isEditing = false;
      _profileBackup = null;
    });
  }

  Future<void> saveProfile() async {
    if (isSaving || !isEditing) return;
    if (!isOwnProfile) {
      showMessage('You cannot edit another user\'s profile.');
      return;
    }
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      showMessage('Please log in before saving your profile.');
      return;
    }
    setState(() => isSaving = true);
    try {
      // 1. Verify role from Profile_Data collection first, fallback to legacy users
      var profileDoc = await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(user.uid)
          .get();
      String? storedRole = profileDoc.data()?['role'] as String?;
      if (storedRole == null || !allowedRoles.contains(storedRole)) {
        final legacyUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        storedRole = legacyUserDoc.data()?['role'] as String?;
      }

      if (storedRole == null || !allowedRoles.contains(storedRole)) {
        throw Exception(
          'A valid registered role was not found in Firestore. Check the role saved during registration.',
        );
      }

      final newPhotoUrl = await _uploadProfilePhoto(user);
      final newPortfolioUrl = await _uploadPortfolio(user);
      String? newEducationVideoUrl;

      if (selectedEducationVideo != null &&
          selectedEducationVideo!.bytes != null) {
        final uploaded = await EducationalVideoService.uploadAndRecordVideo(
          uid: user.uid,
          bytes: selectedEducationVideo!.bytes!,
          fileName: selectedEducationVideo!.name,
          title: educationDescriptionController.text.trim().isNotEmpty
              ? educationDescriptionController.text.trim()
              : 'Educational Video',
          description: educationDescriptionController.text.trim(),
          fallbackRole: storedRole,
        );
        newEducationVideoUrl = uploaded.videoUrl;
      } else if (educationVideoUrl != null && educationVideoUrl!.isNotEmpty) {
        await EducationalVideoService.syncProfileVideoIfMissing(user.uid);
      }

      final data = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? registeredEmail ?? '',
        'fullName': nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : (user.displayName ?? ''),
        'name': nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : (user.displayName ?? ''),
        'username': usernameController.text.trim(),
        'bio': bioController.text.trim(),
        'location': locationController.text.trim(),
        'instagramUrl': instagramController.text.trim(),
        'youtubeUrl': youtubeController.text.trim(),
        'websiteUrl': websiteController.text.trim(),
        'role': storedRole,
        'category': selectedCategory,
        'skills': skillsController.text.trim(),
        'experience': selectedExperience,
        'previousProjects': projectsController.text.trim(),
        'educationDescription': educationDescriptionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newPhotoUrl != null) {
        data['profilePhotoUrl'] = newPhotoUrl;
        data['photo'] = newPhotoUrl;
      }
      if (newPortfolioUrl != null) data['portfolioUrl'] = newPortfolioUrl;
      if (newEducationVideoUrl != null) {
        data['educationVideoUrl'] = newEducationVideoUrl;
      }

      // Write to 'Profile_Data' collection (Single Source of Truth)
      await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        registeredRole = storedRole;
        selectedRole = storedRole!;
        if (newPhotoUrl != null) profilePhotoUrl = newPhotoUrl;
        if (newPortfolioUrl != null) portfolioUrl = newPortfolioUrl;
        if (newEducationVideoUrl != null) {
          educationVideoUrl = newEducationVideoUrl;
        }
        selectedImage = null;
        imageBytes = null;
        selectedPortfolio = null;
        selectedEducationVideo = null;
        isEditing = false;
        _profileBackup = null;
      });
      showMessage('Profile saved successfully!');
    } catch (e) {
      debugPrint('Error saving profile: $e');
      showMessage('Error saving profile: $e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    locationController.dispose();
    instagramController.dispose();
    youtubeController.dispose();
    websiteController.dispose();
    skillsController.dispose();
    projectsController.dispose();
    educationDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/creatorconnect_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: backgroundColor.withValues(alpha: 0.52)),
          ),
          SafeArea(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (Navigator.canPop(context)) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                      ),
                                      color: primaryColor,
                                      tooltip: 'Back',
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isOwnProfile
                                            ? 'Profile Details'
                                            : 'Creator Profile',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        isOwnProfile
                                            ? 'Keep your creator profile current and polished.'
                                            : 'View creator details, skills, and portfolio.',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF827985),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (isOwnProfile && !isEditing)
                                  ElevatedButton.icon(
                                    onPressed: isSaving ? null : startEditing,
                                    icon: const Icon(Icons.edit, size: 17),
                                    label: const Text('Edit Profile'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.person,
                              title: 'BASIC INFORMATION',
                              children: [
                                const Text('Profile Photo', style: labelStyle),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (imageBytes == null &&
                                            profilePhotoUrl == null) {
                                          return;
                                        }
                                        showDialog<void>(
                                          context: context,
                                          builder: (dialogContext) => Dialog(
                                            child: InteractiveViewer(
                                              child: imageBytes != null
                                                  ? Image.memory(
                                                      imageBytes!,
                                                      fit: BoxFit.contain,
                                                    )
                                                  : Image.network(
                                                      profilePhotoUrl!,
                                                      fit: BoxFit.contain,
                                                    ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 48,
                                        backgroundColor: const Color(
                                          0xFFECE7F4,
                                        ),
                                        backgroundImage: imageBytes != null
                                            ? MemoryImage(imageBytes!)
                                            : profilePhotoUrl != null
                                            ? NetworkImage(profilePhotoUrl!)
                                            : null,
                                        child:
                                            imageBytes == null &&
                                                profilePhotoUrl == null
                                            ? Icon(
                                                Icons.person,
                                                size: 55,
                                                color: primaryColor,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          OutlinedButton(
                                            onPressed: isEditing && isOwnProfile
                                                ? pickImage
                                                : null,
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFECE7F4,
                                              ),
                                              foregroundColor: primaryColor,
                                              side: BorderSide.none,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text('Upload Image'),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'JPG, PNG or GIF. Max size 5MB.',
                                            style: helperStyle,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                responsiveFields(
                                  field(
                                    'Full Name / Business Name',
                                    nameController,
                                  ),
                                  field(
                                    'Username',
                                    usernameController,
                                    prefix: const Icon(
                                      Icons.alternate_email,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                field(
                                  'Bio / About',
                                  bioController,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 22),
                                field('Location', locationController),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.language,
                              title: 'SOCIAL MEDIA',
                              children: [
                                responsiveFields(
                                  field(
                                    'Instagram Profile URL',
                                    instagramController,
                                    hint: 'https://instagram.com/...',
                                    prefix: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 18,
                                    ),
                                  ),
                                  field(
                                    'YouTube Channel URL',
                                    youtubeController,
                                    hint: 'https://youtube.com/@...',
                                    prefix: const Icon(
                                      Icons.video_collection_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                field(
                                  'Website or Linktree',
                                  websiteController,
                                  hint: 'https://yourwebsite.com',
                                  prefix: const Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.work_outline,
                              title: 'PROFESSIONAL DETAILS',
                              children: [
                                responsiveFields(
                                  dropdownField(
                                    'Role',
                                    selectedRole,
                                    allowedRoles,
                                    (value) {},
                                  ),
                                  dropdownField(
                                    'Category',
                                    selectedCategory,
                                    categories,
                                    (val) {
                                      if (val != null) {
                                        setState(() => selectedCategory = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                                responsiveFields(
                                  field(
                                    'Skills (Comma-separated)',
                                    skillsController,
                                    hint: 'e.g. Video Editing, Scriptwriting',
                                    prefix: const Icon(Icons.bolt, size: 18),
                                  ),
                                  dropdownField(
                                    'Experience Level',
                                    selectedExperience,
                                    experiences,
                                    (val) {
                                      if (val != null) {
                                        setState(() => selectedExperience = val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.folder_open,
                              title: 'PORTFOLIO & PROJECTS',
                              children: [
                                const Text('Portfolio File / Video', style: labelStyle),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: isEditing && isOwnProfile ? pickPortfolio : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 28,
                                      horizontal: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFBFBFE),
                                      border: Border.all(
                                        color: const Color(0xFFDCE5F0),
                                        width: 1.2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 34,
                                          color: Color(0xFF4C3AE3),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          selectedPortfolio?.name ??
                                              (portfolioUrl != null
                                                  ? 'Portfolio uploaded — click to replace'
                                                  : 'Drop video/file here or click to browse'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Supports MP4, MOV, PDF, PNG, JPG (Max 50MB)',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFFB4C0D1),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (portfolioUrl != null &&
                                    portfolioUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: isSaving
                                          ? null
                                          : () => openUploadedFile(
                                              portfolioUrl,
                                              'portfolio',
                                            ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text(
                                        'View Uploaded Portfolio',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                field(
                                  'Previous Projects / Clients',
                                  projectsController,
                                  hint:
                                      'Mention top brands, channels or clients...',
                                  maxLines: 3,
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.school,
                              title: 'EDUCATION (OPTIONAL)',
                              children: [
                                const Text(
                                  'Educational Video (Optional)',
                                  style: labelStyle,
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: isEditing && isOwnProfile ? pickEducationVideo : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCFCFE),
                                      border: Border.all(
                                        color: const Color(0xFFDCE5F0),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 32,
                                          color: Color(0xFF5146F5),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          selectedEducationVideo?.name ??
                                              (educationVideoUrl != null
                                                  ? 'Education video uploaded — click to replace'
                                                  : 'Upload Video'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        const Text(
                                          'MP4 or MOV · Max 50MB · Optional',
                                          style: helperStyle,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (educationVideoUrl != null &&
                                    educationVideoUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: isSaving
                                          ? null
                                          : () => openUploadedFile(
                                              educationVideoUrl,
                                              'education video',
                                            ),
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                      ),
                                      label: const Text('Watch Uploaded Video'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                field(
                                  'Description (Optional)',
                                  educationDescriptionController,
                                  hint: 'Describe your educational video...',
                                  maxLines: 3,
                                ),
                                if (effectiveUid != null)
                                  _buildMyUploadedVideosList(effectiveUid!),
                              ],
                            ),
                            const SizedBox(height: 28),
                            if (isEditing && isOwnProfile)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: isSaving ? null : cancelEditing,
                                      icon: const Icon(Icons.close),
                                      label: const Text('Cancel'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: isSaving ? null : saveProfile,
                                      icon: isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save),
                                      label: Text(
                                        isSaving ? 'Saving...' : 'Save Profile',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 17,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5DDE6), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFEFE8EF), height: 1),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }

  Widget field(
    String label,
    TextEditingController controller, {
    String? hint,
    Widget? prefix,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          readOnly: !isEditing || isSaving || !isOwnProfile,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: Color(0xFF302A33)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF827985), fontSize: 14),
            prefixIcon: prefix,
            prefixIconColor: const Color(0xFF827985),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5DDE6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5DDE6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF35132F),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget dropdownField(
    String label,
    String selectedValue,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: selectedValue,
          onChanged: isEditing && !isSaving && isOwnProfile && label != 'Role'
              ? onChanged
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5DDE6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5DDE6)),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF302A33),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget responsiveFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(children: [first, const SizedBox(height: 22), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 20),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  static const TextStyle labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF35132F),
  );
  static const TextStyle helperStyle = TextStyle(
    fontSize: 13,
    color: Color(0xFF827985),
  );
}
