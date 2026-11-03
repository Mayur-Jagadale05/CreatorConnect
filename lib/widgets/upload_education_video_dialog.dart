import 'package:creatorconnect/services/educational_video_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UploadEducationVideoDialog extends StatefulWidget {
  final String? defaultRole;

  const UploadEducationVideoDialog({
    super.key,
    this.defaultRole,
  });

  @override
  State<UploadEducationVideoDialog> createState() =>
      _UploadEducationVideoDialogState();
}

class _UploadEducationVideoDialogState
    extends State<UploadEducationVideoDialog> {
  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);
  static const Color lavender = Color(0xFFECE7F4);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _errorMessage;
  String _targetRole = 'Businessman';

  @override
  void initState() {
    super.initState();
    final role = widget.defaultRole ?? 'Businessman';
    _targetRole = EducationalVideoService.getCanonicalRole(role);
    _loadRegisteredRole();
  }

  Future<void> _loadRegisteredRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role =
          await EducationalVideoService.getUserRegisteredRole(user.uid);
      if (mounted && role != 'Creator' && role.isNotEmpty) {
        setState(() {
          _targetRole = role;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > 50 * 1024 * 1024) {
        setState(() {
          _errorMessage = 'Video file size must be 50MB or less.';
        });
        return;
      }

      if (file.bytes == null) {
        setState(() {
          _errorMessage = 'Could not read the selected video file.';
        });
        return;
      }

      setState(() {
        _selectedFile = file;
        if (_titleController.text.trim().isEmpty) {
          final rawName = file.name.split('.').first;
          _titleController.text = rawName.replaceAll('_', ' ');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting video: $e';
      });
    }
  }

  Future<void> _startUpload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to upload.');
      return;
    }

    if (_selectedFile == null || _selectedFile!.bytes == null) {
      setState(() => _errorMessage = 'Please select a video file first.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a video title.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await EducationalVideoService.uploadAndRecordVideo(
        uid: user.uid,
        bytes: _selectedFile!.bytes!,
        fileName: _selectedFile!.name,
        title: title,
        description: _descController.text.trim(),
        fallbackRole: _targetRole,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: pageBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Educational Video',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Visible to other ${_targetRole}s in Education',
                            style: const TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: secondaryText),
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Video Picker Container
                InkWell(
                  onTap: _isUploading ? null : _pickVideo,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedFile != null
                            ? purple
                            : purple.withValues(alpha: 0.2),
                        width: _selectedFile != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.cloud_upload_outlined,
                          size: 38,
                          color: _selectedFile != null ? Colors.green : purple,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFile != null
                              ? _selectedFile!.name
                              : 'Select Video File (MP4 or MOV)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedFile != null
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedFile != null
                              ? '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                              : 'Maximum file size: 50MB',
                          style: const TextStyle(
                            fontSize: 11,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Video Title Field
                const Text(
                  'Video Title *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  enabled: !_isUploading,
                  decoration: InputDecoration(
                    hintText: 'e.g. Strategic Business Growth 101',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: secondaryText),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: purple.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: purple, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Description Field
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descController,
                  enabled: !_isUploading,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Briefly explain what fellow creators will learn...',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: secondaryText),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: purple.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: purple, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Informational Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lavender.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: purple.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: purple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Once uploaded, this video will be visible to other ${_targetRole}s in their Education tab. You can manage or delete your uploaded videos anytime from your Profile.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: primaryText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isUploading ? null : _startUpload,
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Upload Video',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

