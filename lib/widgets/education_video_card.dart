import 'package:creatorconnect/models/educational_video_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EducationVideoCard extends StatelessWidget {
  static const Color purple = Color(0xFF35132F);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);

  final EducationalVideo video;
  final VoidCallback? onDelete; // Used when displayed in uploader's Profile

  const EducationVideoCard({super.key, required this.video, this.onDelete});

  Future<void> _watchVideo(BuildContext context, String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No video link available.')));
      return;
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid video link.')));
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video player.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to play video: $e')));
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    return '$m ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = video.title.isNotEmpty ? video.title : 'Educational Video';
    final hasThumbnail = video.thumbnailUrl.trim().isNotEmpty;
    final dateStr = _formatDate(video.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Uploader Header (Uploader name, role, date)
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: lavender,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.uploaderName.isNotEmpty
                          ? video.uploaderName
                          : 'Creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: lavender,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            video.uploaderRole,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: purple,
                            ),
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Delete Video',
                  color: Colors.red.withValues(alpha: 0.75),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Video Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryText,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 10),

          // 3. Video Thumbnail / Player Container
          InkWell(
            onTap: () => _watchVideo(context, video.videoUrl),
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2E1029),
                      Color(0xFF4A1840),
                      Color(0xFF22091E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: purple.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (hasThumbnail)
                      Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),

                    // Translucent dark overlay if thumbnail is present
                    if (hasThumbnail)
                      Container(color: Colors.black.withValues(alpha: 0.35)),

                    // Centered Play Button & Label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to Watch Educational Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),

                    // Top-right badge
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Educational',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Description
          if (video.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lavender.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: purple.withValues(alpha: 0.08)),
              ),
              child: Text(
                video.description,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: primaryText,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 5. Watch Video Button
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _watchVideo(context, video.videoUrl),
              icon: const Icon(Icons.play_circle_outline, size: 16),
              label: const Text('Watch Video'),
              style: OutlinedButton.styleFrom(
                foregroundColor: purple,
                side: BorderSide(color: purple.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
