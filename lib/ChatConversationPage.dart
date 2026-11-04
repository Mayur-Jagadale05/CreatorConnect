import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/ProfileViewPage.dart';
import 'package:creatorconnect/services/chat_service.dart';
import 'package:creatorconnect/services/message_notification_service.dart';
import 'package:creatorconnect/widgets/remove_connection_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatConversationPage extends StatefulWidget {
  final String chatId;
  final String otherUserUid;
  final String otherUserName;
  final String otherUserPhoto;
  final String otherUserRole;
  final String otherUserUsername;

  const ChatConversationPage({
    super.key,
    required this.chatId,
    required this.otherUserUid,
    required this.otherUserName,
    required this.otherUserPhoto,
    required this.otherUserRole,
    this.otherUserUsername = '',
  });

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);
  static const Color borderColor = Color(0xCCFFFFFF);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    MessageNotificationService.activeChatId = widget.chatId;
    _markAsRead();
  }

  void _markAsRead() {
    final user = currentUser;
    if (user != null) {
      ChatService.markMessagesAsRead(
        chatId: widget.chatId,
        currentUid: user.uid,
      );
    }
  }

  @override
  void dispose() {
    if (MessageNotificationService.activeChatId == widget.chatId) {
      MessageNotificationService.activeChatId = null;
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuad,
      );
    }
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    final user = currentUser;
    if (text.isEmpty || user == null || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        senderUid: user.uid,
        receiverUid: widget.otherUserUid,
        text: text,
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/creatorconnect_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: pageBg.withValues(alpha: 0.50)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: user == null
                      ? const Center(child: Text('Please log in.'))
                      : StreamBuilder<List<ChatMessage>>(
                          stream: ChatService.watchMessages(widget.chatId),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading messages: ${snapshot.error}',
                                  style: const TextStyle(color: secondaryText),
                                ),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: purple,
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final messages = snapshot.data!;
                            if (messages.isEmpty) {
                              return _buildEmptyState();
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToBottom();
                            });

                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe = msg.senderUid == user.uid;
                                return _buildMessageBubble(msg, isMe);
                              },
                            );
                          },
                        ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDDF9F6F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: purple),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileViewPage(selectedUserUid: widget.otherUserUid),
                    ),
                  );
                },
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: widget.otherUserUid.isNotEmpty
                      ? FirebaseFirestore.instance
                            .collection('Profile_Data')
                            .doc(widget.otherUserUid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    final pData = snapshot.data?.data();
                    final realName =
                        (pData?['fullName'] ?? pData?['name'] ?? '')
                            .toString()
                            .trim();
                    final realPhoto =
                        (pData?['photo'] ?? pData?['profilePhotoUrl'] ?? '')
                            .toString()
                            .trim();
                    final realRole = (pData?['role'] ?? '').toString().trim();

                    final headerName = realName.isNotEmpty
                        ? realName
                        : (widget.otherUserName.isNotEmpty &&
                                  widget.otherUserName != 'Creator'
                              ? widget.otherUserName
                              : 'Creator');
                    final headerPhoto = realPhoto.isNotEmpty
                        ? realPhoto
                        : widget.otherUserPhoto;
                    final headerRole = realRole.isNotEmpty
                        ? realRole
                        : widget.otherUserRole;

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: lavender,
                          backgroundImage: headerPhoto.isNotEmpty
                              ? NetworkImage(headerPhoto)
                              : null,
                          child: headerPhoto.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: purple,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                            Text(
                              headerRole,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Spacer(),
              if (currentUser != null)
                RemoveConnectionButton(
                  currentUid: currentUser!.uid,
                  otherUid: widget.otherUserUid,
                  onRemoved: () {
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileViewPage(selectedUserUid: widget.otherUserUid),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Profile'),
                style: TextButton.styleFrom(
                  foregroundColor: purple,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lavender,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: purple,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Connected with ${widget.otherUserName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Say hello and start collaborating!',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final timeStr = msg.timestamp != null
        ? '${msg.timestamp!.hour.toString().padLeft(2, '0')}:${msg.timestamp!.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? purple : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : primaryText,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: TextStyle(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.65)
                      : secondaryText,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xE8FDFBF9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: purple,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _handleSend,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
