import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'AIChatMessage.dart';
import 'CreatorMatchingPage.dart';

/// Renders individual chat message bubbles with CreatorConnect branding,
/// copy support, timestamps, typing indicators, and grounded creator recommendation cards.
class AIChatBubble extends StatelessWidget {
  final AIChatMessage message;
  final VoidCallback? onRetry;

  const AIChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  static const Color primaryBurgundy = Color(0xFF35132F);
  static const Color darkInk = Color(0xFF302A33);
  static const Color goldAccent = Color(0xFFF2D39A);
  static const Color creamBg = Color(0xFFF7F5F3);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color mutedText = Color(0xFF827985);

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildAssistantBubble(context);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Timestamp & actions
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(fontSize: 11, color: mutedText),
            ),
          ),

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: primaryBurgundy,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBurgundy.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectableText(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    final hasCreators = message.suggestedCreators.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assistant Avatar Icon
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF35132F), Color(0xFF6C3C68)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryBurgundy.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: goldAccent,
              size: 20,
            ),
          ),

          // Bubble & Content
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: primaryBurgundy.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Assistant label and copy action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'CreatorConnect AI',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: primaryBurgundy,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.verified,
                                color: goldAccent,
                                size: 14,
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () =>
                                _copyToClipboard(context, message.content),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Text message content
                      SelectableText(
                        message.content,
                        style: const TextStyle(
                          color: darkInk,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),

                      // Error state retry
                      if (message.isError && onRetry != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry Response'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBurgundy,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Grounded Creator Recommendation Cards
                if (hasCreators) ...[
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'VERIFIED MATCHING CREATORS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryBurgundy,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...message.suggestedCreators.map(
                    (creator) => _buildCreatorCard(context, creator),
                  ),
                ],

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(fontSize: 11, color: mutedText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Creator Card embedded directly in chat
  Widget _buildCreatorCard(BuildContext context, Map<String, dynamic> creator) {
    final name = creator['name'] ?? 'Creator';
    final role = creator['role'] ?? 'Creator';
    final location = creator['location'] ?? '';
    final category = creator['category'] ?? '';
    final experience = creator['experience'] ?? '';
    final photo = creator['photo'] ?? '';
    final skills = creator['skills'] ?? '';

    final skillsList = skills
        .toString()
        .split(RegExp(r'[,|/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBurgundy.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: primaryBurgundy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Creator Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: lavender,
                backgroundImage:
                    (photo.isNotEmpty && photo.toString().startsWith('http'))
                        ? NetworkImage(photo)
                        : null,
                child: (photo.isEmpty || !photo.toString().startsWith('http'))
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: primaryBurgundy,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Creator Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: darkInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lavender,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primaryBurgundy,
                            ),
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: mutedText,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 11,
                                color: mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // View Profile Button
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreatorMatchingPage(creator: creator),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBurgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'View Profile',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          // Extra details: Category, Experience and Skills
          if (category.isNotEmpty || experience.isNotEmpty || skillsList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: creamBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(fontSize: 11, color: darkInk),
                    ),
                  ),
                if (experience.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: creamBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      experience,
                      style: const TextStyle(fontSize: 11, color: darkInk),
                    ),
                  ),
                ...skillsList.map(
                  (sk) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: creamBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sk,
                      style: const TextStyle(fontSize: 11, color: mutedText),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Typing / Thinking animation widget for CreatorConnect AI
class AITypingIndicator extends StatefulWidget {
  const AITypingIndicator({super.key});

  @override
  State<AITypingIndicator> createState() => _AITypingIndicatorState();
}

class _AITypingIndicatorState extends State<AITypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF35132F), Color(0xFF6C3C68)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFFF2D39A),
              size: 20,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF35132F).withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CreatorConnect AI is thinking',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF827985),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final delay = index * 0.25;
                        final value = (_controller.value - delay) % 1.0;
                        final opacity = (value < 0.5 ? value * 2 : (1.0 - value) * 2).clamp(0.2, 1.0);
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35132F).withValues(alpha: opacity),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
