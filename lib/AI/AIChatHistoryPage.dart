import 'package:flutter/material.dart';
import 'package:creatorconnect/design_system.dart';
import 'AIService.dart';

/// Screen listing previous AI chat sessions for the logged-in user.
/// Supports reopening conversations or deleting old sessions.
class AIChatHistoryPage extends StatelessWidget {
  final Function(String chatId)? onSelectChat;

  const AIChatHistoryPage({super.key, this.onSelectChat});

  static const Color primaryBurgundy = Color(0xFF35132F);
  static const Color darkInk = Color(0xFF302A33);
  static const Color mutedText = Color(0xFF827985);
  static const Color creamBg = Color(0xFFF7F5F3);
  static const Color goldAccent = Color(0xFFF2D39A);

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return 'Today, $hour:$minute $ampm';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String chatId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: creamBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Conversation?',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.bold,
              color: darkInk,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$title"? This action cannot be undone.',
            style: const TextStyle(color: darkInk),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: mutedText)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await AIService().deleteChat(chatId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation deleted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete chat: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: primaryBurgundy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Chat History',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkInk,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AIService().getUserChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryBurgundy),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load chat history: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CreatorTheme.lavender,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        size: 48,
                        color: primaryBurgundy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No AI Conversations Yet',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ask CreatorConnect AI for ideas, hooks, scripts, or to match you with top creators!',
                      style: TextStyle(fontSize: 14, color: mutedText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Start New Conversation'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBurgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatId = chat['chatId'] as String;
              final title = chat['title'] as String;
              final lastMsg = chat['lastMessage'] as String;
              final updatedAt = chat['updatedAt'] as DateTime;
              final role = chat['userRole'] as String;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryBurgundy.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: () {
                    if (onSelectChat != null) {
                      onSelectChat!(chatId);
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pop(chatId);
                    }
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CreatorTheme.lavender,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: primaryBurgundy,
                      size: 22,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: darkInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (role.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: creamBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: mutedText,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (lastMsg.isNotEmpty)
                        Text(
                          lastMsg,
                          style: const TextStyle(
                            fontSize: 13,
                            color: mutedText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(updatedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: mutedText.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: mutedText,
                      size: 20,
                    ),
                    onPressed: () => _confirmDelete(context, chatId, title),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

