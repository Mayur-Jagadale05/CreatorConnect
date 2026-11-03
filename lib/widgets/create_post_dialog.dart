import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:creatorconnect/models/post_model.dart';
import 'package:creatorconnect/services/post_service.dart';

class CreatePostDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String username;
  final String userRole;
  final String userProfilePhoto;
  final PostModel? existingPost; // Non-null when editing

  const CreatePostDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.username,
    required this.userRole,
    required this.userProfilePhoto,
    this.existingPost,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  static const Color purple = Color(0xFF35132F);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _selectedMediaType =
      'none'; // 'image' | 'video' | 'pdf' | 'document' | 'none'
  String? _existingMediaUrl;

  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingPost?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingPost?.description ?? '',
    );
    if (widget.existingPost != null) {
      _existingMediaUrl = widget.existingPost!.mediaUrl;
      _selectedMediaType = widget.existingPost!.mediaType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedFileBytes = bytes;
        _selectedFileName = picked.name;
        _selectedMediaType = 'image';
        _existingMediaUrl = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickFile(FileType type, String mediaType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() {
        _selectedFileBytes = file.bytes;
        _selectedFileName = file.name;
        _selectedMediaType = mediaType;
        _existingMediaUrl = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  void _clearMedia() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedMediaType = 'none';
      _existingMediaUrl = null;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty &&
        description.isEmpty &&
        _selectedFileBytes == null &&
        _existingMediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add a title, description, or media to publish.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Uploading media...';
    });

    try {
      String finalMediaUrl = _existingMediaUrl ?? '';
      String finalMediaType = _selectedMediaType;

      if (_selectedFileBytes != null && _selectedFileName != null) {
        final uploaded = await PostService.uploadPostMedia(
          userId: widget.userId,
          bytes: _selectedFileBytes!,
          fileName: _selectedFileName!,
          mediaType: _selectedMediaType,
        );
        finalMediaUrl = uploaded ?? '';
      }

      setState(() => _statusMessage = 'Saving post...');

      if (widget.existingPost != null) {
        await PostService.editPost(
          postId: widget.existingPost!.postId,
          userId: widget.userId,
          title: title,
          description: description,
          mediaUrl: finalMediaUrl,
          mediaType: finalMediaType,
        );
      } else {
        await PostService.createPost(
          userId: widget.userId,
          userName: widget.userName,
          username: widget.username,
          userRole: widget.userRole,
          userProfilePhoto: widget.userProfilePhoto,
          title: title,
          description: description,
          mediaUrl: finalMediaUrl,
          mediaType: finalMediaType,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = null;
        });
        final cleanMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish post: $cleanMsg')),
        );
      }
    }
  }

  Widget _buildMediaAttachmentPreview() {
    if (_selectedFileName == null &&
        (_existingMediaUrl == null || _existingMediaUrl!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final name =
        _selectedFileName ?? 'Attached ${_selectedMediaType.toUpperCase()}';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: lavender,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            _selectedMediaType == 'image'
                ? Icons.image_rounded
                : _selectedMediaType == 'video'
                ? Icons.videocam_rounded
                : Icons.picture_as_pdf_rounded,
            color: purple,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: secondaryText,
            ),
            onPressed: _isSubmitting ? null : _clearMedia,
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove media',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPost != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: lavender,
                      backgroundImage: widget.userProfilePhoto.isNotEmpty
                          ? NetworkImage(widget.userProfilePhoto)
                          : null,
                      child: widget.userProfilePhoto.isEmpty
                          ? const Icon(Icons.person, color: purple, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Post' : 'Create New Post',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),
                          Text(
                            'Visible to all creators on your profile',
                            style: const TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: secondaryText,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSubmitting,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Post Title (Optional)',
                    hintStyle: const TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFBF9F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFECE7F4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFECE7F4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: purple, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Description Input
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  maxLines: 5,
                  minLines: 3,
                  style: const TextStyle(
                    fontSize: 14,
                    color: primaryText,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What would you like to share?',
                    hintStyle: const TextStyle(color: secondaryText),
                    filled: true,
                    fillColor: const Color(0xFFFBF9F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFECE7F4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFECE7F4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: purple, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),

                // Media Attachment Preview
                _buildMediaAttachmentPreview(),

                const SizedBox(height: 18),

                // Media Picker Action Buttons
                Text(
                  'Add Media (Supabase Storage)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: purple.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: purple,
                        side: BorderSide(color: purple.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickFile(FileType.video, 'video'),
                      icon: const Icon(Icons.video_library_outlined, size: 16),
                      label: const Text('Video'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: purple,
                        side: BorderSide(color: purple.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (_isSubmitting) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: purple,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _statusMessage ?? 'Publishing...',
                        style: const TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Save Changes' : 'Publish Post',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
