import 'package:creatorconnect/design_system.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dedicated Creator Profile view specifically rendered for CreatorConnect AI matching.
/// Allows businesses and collaborators to inspect candidate details, portfolio, and credentials.
class CreatorMatchingPage extends StatelessWidget {
  final Map<String, dynamic> creator;

  const CreatorMatchingPage({super.key, required this.creator});

  static const Color primaryBurgundy = Color(0xFF35132F);
  static const Color goldAccent = Color(0xFFF2D39A);
  static const Color darkInk = Color(0xFF302A33);
  static const Color mutedText = Color(0xFF827985);
  static const Color creamBg = Color(0xFFF7F5F3);
  static const Color cardBg = Colors.white;

  Future<void> _launchExternalUrl(
    BuildContext context,
    String? urlString,
  ) async {
    if (urlString == null || urlString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link provided by creator.')),
      );
      return;
    }

    final uri = Uri.tryParse(urlString.trim());
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid URL format.')));
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = creator['name'] ?? 'Creator';
    final role = creator['role'] ?? 'Creator';
    final location = creator['location'] ?? 'Not specified';
    final skills = creator['skills'] ?? '';
    final category = creator['category'] ?? '';
    final experience = creator['experience'] ?? '';
    final photo = creator['photo'] ?? '';
    final portfolioUrl = creator['portfolioUrl'] ?? '';
    final educationVideoUrl = creator['educationVideoUrl'] ?? '';
    final bio = creator['bio'] ?? '';

    final skillsList = skills
        .toString()
        .split(RegExp(r'[,|/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryBurgundy,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Creator Recommendation',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkInk,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBurgundy.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: CreatorTheme.lavender,
                            backgroundImage:
                                (photo.isNotEmpty && photo.startsWith('http'))
                                ? NetworkImage(photo)
                                : null,
                            child: (photo.isEmpty || !photo.startsWith('http'))
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primaryBurgundy,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: primaryBurgundy,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: goldAccent,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkInk,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBurgundy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Quick info row
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (location.isNotEmpty &&
                              location != 'Not specified')
                            _buildInfoPill(
                              Icons.location_on_outlined,
                              location,
                            ),
                          if (experience.isNotEmpty)
                            _buildInfoPill(
                              Icons.work_outline_rounded,
                              experience,
                            ),
                          if (category.isNotEmpty)
                            _buildInfoPill(Icons.category_outlined, category),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bio Card
                if (bio.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBurgundy.withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: primaryBurgundy,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'About Creator',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: darkInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          bio,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: darkInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (bio.isNotEmpty) const SizedBox(height: 18),

                // Skills Card
                if (skillsList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBurgundy.withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: primaryBurgundy,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Verified Skills & Tools',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: darkInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skillsList.map((skill) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: CreatorTheme.lavender,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                skill,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryBurgundy,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (skillsList.isNotEmpty) const SizedBox(height: 18),

                // Portfolio & Media Links Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBurgundy.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.folder_shared_outlined,
                            color: primaryBurgundy,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Portfolio & Work Samples',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (portfolioUrl.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: CreatorTheme.lavender,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.attachment_rounded,
                              color: primaryBurgundy,
                            ),
                          ),
                          title: const Text(
                            'Creator Portfolio File',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Tap to inspect uploaded portfolio work',
                            style: TextStyle(fontSize: 12, color: mutedText),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () =>
                                _launchExternalUrl(context, portfolioUrl),
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryBurgundy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Open'),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No portfolio document uploaded yet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      if (educationVideoUrl.isNotEmpty) ...[
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: goldAccent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: primaryBurgundy,
                            ),
                          ),
                          title: const Text(
                            'Educational / Showreel Video',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Watch showcase video',
                            style: TextStyle(fontSize: 12, color: mutedText),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () =>
                                _launchExternalUrl(context, educationVideoUrl),
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryBurgundy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Watch'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Collaboration Action Button
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You can connect with $name directly via Messages or Project Posts.',
                        ),
                        backgroundColor: primaryBurgundy,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.handshake_rounded, color: goldAccent),
                  label: Text('Initiate Collaboration with $name'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBurgundy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: creamBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryBurgundy),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: darkInk,
            ),
          ),
        ],
      ),
    );
  }
}
