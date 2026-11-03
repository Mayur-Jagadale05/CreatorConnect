import 'package:flutter/material.dart';
import 'package:creatorconnect/models/post_model.dart';
import 'package:url_launcher/url_launcher.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.isOwner = false,
    this.onEdit,
    this.onDelete,
  });

  static const Color purple = Color(0xFF35132F);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);
  static const Color marigold = Color(0xFFF2D39A);

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    if (urlString.isEmpty) return;
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open media: $e')),
        );
      }
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: const Text('Failed to load image preview'),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaWidget(BuildContext context) {
    if (post.mediaUrl.isEmpty || post.mediaType == 'none') {
      return const SizedBox.shrink();
    }

    final type = post.mediaType.toLowerCase();

    if (type == 'image') {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: () => _showImageDialog(context, post.mediaUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    post.mediaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: lavender,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_rounded, color: purple),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (type == 'video') {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InkWell(
          onTap: () => _launchUrl(context, post.mediaUrl),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to Play Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Video',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // PDF or Document
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => _launchUrl(context, post.mediaUrl),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: lavender,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: purple.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attached Document / Sample',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: primaryText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap to open or download',
                      style: TextStyle(fontSize: 11, color: secondaryText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18, color: purple),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: lavender,
                backgroundImage: post.userProfilePhoto.isNotEmpty
                    ? NetworkImage(post.userProfilePhoto)
                    : null,
                child: post.userProfilePhoto.isEmpty
                    ? const Icon(Icons.person, color: purple, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lavender,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.userRole,
                            style: const TextStyle(
                              color: purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (post.username.isNotEmpty) ...[
                          Text(
                            post.username.startsWith('@')
                                ? post.username
                                : '@${post.username}',
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(color: secondaryText, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _formatDate(post.createdAt),
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: secondaryText),
                  onSelected: (val) {
                    if (val == 'edit' && onEdit != null) onEdit!();
                    if (val == 'delete' && onDelete != null) onDelete!();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: purple),
                          SizedBox(width: 8),
                          Text('Edit Post'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ],

          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.description,
              style: const TextStyle(
                color: primaryText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],

          // Media Attachment
          _buildMediaWidget(context),
        ],
      ),
    );
  }
}

