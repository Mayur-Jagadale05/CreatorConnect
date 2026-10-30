import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

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
  static const String educationBucket = 'Educationalvideo_picker';

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
      if (!opened)
        showMessage('Could not open the $fileType. Please try again.');
    } catch (e) {
      debugPrint('Unable to open $fileType: $e');
      showMessage('Unable to open the $fileType. Check the uploaded file URL.');
    }
  }

  Future<void> pickImage() async {
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
    final originalExtension = selectedImage!.name.split('.').last.toLowerCase();
    final extension =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(originalExtension)
        ? originalExtension
        : 'jpg';
    final path =
        '${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storage = Supabase.instance.client.storage.from(profileBucket);
    await storage.uploadBinary(
      path,
      imageBytes!,
      fileOptions: FileOptions(
        contentType: _contentTypeFor(extension),
        upsert: false,
      ),
    );
    return storage.getPublicUrl(path);
  }

  Future<String?> _uploadPortfolio(firebase_auth.User user) async {
    final file = selectedPortfolio;
    if (file == null || file.bytes == null) return null;
    final extension = (file.extension ?? '').toLowerCase();
    if (!['pdf', 'mp4', 'mov', 'png', 'jpg', 'jpeg'].contains(extension)) {
      throw Exception('Unsupported portfolio file type.');
    }
    final path =
        '${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(file.name)}';
    final storage = Supabase.instance.client.storage.from(portfolioBucket);
    await storage.uploadBinary(
      path,
      file.bytes!,
      fileOptions: FileOptions(
        contentType: _contentTypeFor(extension),
        upsert: false,
      ),
    );
    return storage.getPublicUrl(path);
  }

  Future<String?> _uploadEducationVideo(firebase_auth.User user) async {
    final file = selectedEducationVideo;
    if (file == null || file.bytes == null) return null;
    final extension = (file.extension ?? '').toLowerCase();
    if (!['mp4', 'mov'].contains(extension)) {
      throw Exception('Only MP4 and MOV videos are supported.');
    }
    final path =
        '${user.uid}/${DateTime.now().millisecondsSinceEpoch}_education.$extension';
    final storage = Supabase.instance.client.storage.from(educationBucket);
    await storage.uploadBinary(
      path,
      file.bytes!,
      fileOptions: FileOptions(
        contentType: _contentTypeFor(extension),
        upsert: false,
      ),
    );
    return storage.getPublicUrl(path);
  }

  Future<void> loadProfile() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      setState(() {
        registeredEmail = data['email'] as String? ?? user.email;
        nameController.text =
            data['fullName'] as String? ?? user.displayName ?? '';
        usernameController.text = data['username'] as String? ?? '';
        bioController.text = data['bio'] as String? ?? '';
        locationController.text = data['location'] as String? ?? '';
        instagramController.text = data['instagramUrl'] as String? ?? '';
        youtubeController.text = data['youtubeUrl'] as String? ?? '';
        websiteController.text = data['websiteUrl'] as String? ?? '';
        skillsController.text = data['skills'] as String? ?? '';
        projectsController.text = data['previousProjects'] as String? ?? '';
        educationDescriptionController.text =
            data['educationDescription'] as String? ?? '';
        profilePhotoUrl = data['profilePhotoUrl'] as String?;
        portfolioUrl = data['portfolioUrl'] as String?;
        educationVideoUrl = data['educationVideoUrl'] as String?;
        final role = data['role'] as String?;
        if (role != null && allowedRoles.contains(role)) {
          registeredRole = role;
          selectedRole = role;
        }
        final category = data['category'] as String?;
        if (category != null && categories.contains(category))
          selectedCategory = category;
        final experience = data['experience'] as String?;
        if (experience != null && experiences.contains(experience))
          selectedExperience = experience;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Unable to load profile: $e');
      if (mounted) setState(() => isLoading = false);
      showMessage('Unable to load profile. Please try again.');
    }
  }

  void startEditing() {
    if (isSaving || isLoading) return;
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
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      showMessage('Please log in before saving your profile.');
      return;
    }
    setState(() => isSaving = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final storedRole = userDoc.data()?['role'] as String?;
      if (storedRole == null || !allowedRoles.contains(storedRole)) {
        throw Exception(
          'A valid registered role was not found in Firestore. Check the role saved during registration.',
        );
      }
      final newPhotoUrl = await _uploadProfilePhoto(user);
      final newPortfolioUrl = await _uploadPortfolio(user);
      final newEducationVideoUrl = await _uploadEducationVideo(user);
      final data = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? registeredEmail ?? '',
        'fullName': nameController.text.trim().isNotEmpty
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
      if (newPhotoUrl != null) data['profilePhotoUrl'] = newPhotoUrl;
      if (newPortfolioUrl != null) data['portfolioUrl'] = newPortfolioUrl;
      if (newEducationVideoUrl != null)
        data['educationVideoUrl'] = newEducationVideoUrl;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        registeredRole = storedRole;
        selectedRole = storedRole;
        if (newPhotoUrl != null) profilePhotoUrl = newPhotoUrl;
        if (newPortfolioUrl != null) portfolioUrl = newPortfolioUrl;
        if (newEducationVideoUrl != null)
          educationVideoUrl = newEducationVideoUrl;
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
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/images/creatorconnect_background.png'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profile Details',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'Keep your creator profile current and polished.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF827985),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (!isEditing)
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
                                            profilePhotoUrl == null)
                                          return;
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
                                            onPressed: isEditing
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
                                  ),
                                  field(
                                    'YouTube Channel URL',
                                    youtubeController,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                field(
                                  'Other Social Media / Website',
                                  websiteController,
                                  hint: 'Optional',
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.business_center,
                              title: 'PROFESSIONAL INFORMATION',
                              children: [
                                responsiveFields(
                                  dropdownField('Role', selectedRole, [
                                    selectedRole,
                                  ], (value) {}),
                                  dropdownField(
                                    'Content / Service Category',
                                    selectedCategory,
                                    categories,
                                    (value) {
                                      if (value != null)
                                        setState(
                                          () => selectedCategory = value,
                                        );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                                responsiveFields(
                                  field('Skills / Expertise', skillsController),
                                  dropdownField(
                                    'Experience Level',
                                    selectedExperience,
                                    experiences,
                                    (value) {
                                      if (value != null)
                                        setState(
                                          () => selectedExperience = value,
                                        );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            sectionCard(
                              icon: Icons.folder,
                              title: 'PORTFOLIO / WORK',
                              children: [
                                const Text('Portfolio File', style: labelStyle),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: isEditing ? pickPortfolio : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 34,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCFCFE),
                                      border: Border.all(
                                        color: const Color(0xFFDCE5F0),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload,
                                          size: 32,
                                          color: Color(0xFFEC8CA9),
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
                                  onTap: isEditing ? pickEducationVideo : null,
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
                              ],
                            ),
                            const SizedBox(height: 28),
                            if (isEditing)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: isSaving
                                          ? null
                                          : cancelEditing,
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
          readOnly: !isEditing || isSaving,
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
          value: selectedValue,
          onChanged: isEditing && !isSaving && label != 'Role'
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
        if (constraints.maxWidth < 600)
          return Column(children: [first, const SizedBox(height: 22), second]);
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
