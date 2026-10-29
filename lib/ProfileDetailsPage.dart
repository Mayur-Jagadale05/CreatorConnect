import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color secondaryText = Color(0xFF827985);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _photoUrlController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Please log in to edit your profile.';
      });
      return;
    }

    try {
      // Load the profile owned by the currently authenticated Firebase user.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};

      if (!mounted) return;

      _nameController.text = (data['fullName'] ?? data['name'] ?? '')
          .toString();
      _usernameController.text = (data['username'] ?? '').toString();
      _categoryController.text = (data['category'] ?? '').toString();
      _locationController.text = (data['location'] ?? '').toString();
      _photoUrlController.text =
          (data['profilePhotoUrl'] ?? data['profileImage'] ?? '').toString();
      _bioController.text = (data['bio'] ?? '').toString();
      setState(() => _loading = false);
    } catch (error) {
      debugPrint('Unable to load profile: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your profile. Please try again.';
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (user == null) {
      setState(() => _error = 'Please log in to save your profile.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Merge profile fields so role, email, and other account data are preserved.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'category': _categoryController.text.trim(),
        'location': _locationController.text.trim(),
        'profilePhotoUrl': _photoUrlController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
      Navigator.pop(context);
    } catch (error) {
      debugPrint('Unable to save profile: $error');
      if (!mounted) return;
      setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: pageBg,
        foregroundColor: purple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Your profile',
                              style: TextStyle(
                                color: purple,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _textField(
                              controller: _nameController,
                              label: 'Full name',
                              required: true,
                            ),
                            _textField(
                              controller: _usernameController,
                              label: 'Username',
                            ),
                            _textField(
                              controller: _categoryController,
                              label: 'Category',
                            ),
                            _textField(
                              controller: _locationController,
                              label: 'Location',
                            ),
                            _textField(
                              controller: _photoUrlController,
                              label: 'Profile photo URL',
                              keyboardType: TextInputType.url,
                            ),
                            _textField(
                              controller: _bioController,
                              label: 'Bio',
                              maxLines: 4,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _saving ? null : _saveProfile,
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                _saving ? 'Saving...' : 'Save profile',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: secondaryText),
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? '$label is required.'
                  : null
            : null,
      ),
    );
  }
}

class CreatorProfileDetailsPage extends StatelessWidget {
  const CreatorProfileDetailsPage({super.key, required this.uid});

  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color secondaryText = Color(0xFF827985);

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Creator profile'),
        backgroundColor: pageBg,
        foregroundColor: purple,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        // Subscribe to the selected creator's profile for live updates.
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this profile.'));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: purple),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(
              child: Text('This profile is no longer available.'),
            );
          }

          final name = (data['fullName'] ?? data['name'] ?? 'Creator')
              .toString();
          final username = (data['username'] ?? '').toString();
          final role = (data['role'] ?? 'Creator').toString();
          final photo = (data['profilePhotoUrl'] ?? data['profileImage'] ?? '')
              .toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFFF0EDF0),
                            backgroundImage: photo.isEmpty
                                ? null
                                : NetworkImage(photo),
                            child: photo.isEmpty
                                ? const Icon(
                                    Icons.person_outline_rounded,
                                    size: 44,
                                    color: purple,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: purple,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              '@$username',
                              style: const TextStyle(color: secondaryText),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _detail('Role', role),
                        _detail('Category', data['category']),
                        _detail('Location', data['location']),
                        _detail('Bio', data['bio']),
                        _detail('Education video', data['educationVideoUrl']),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detail(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            text,
            style: const TextStyle(color: purple, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
