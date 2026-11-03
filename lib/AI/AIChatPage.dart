import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'AIChatBubble.dart';
import 'AIChatHistoryPage.dart';
import 'AIChatMessage.dart';
import 'AIPrompt.dart';
import 'AIService.dart';

/// The central AI Assistant interface for CreatorConnect.
/// Accessible from all four role dashboards (Businessman, Editor, Writer, Influencer).
class AIChatPage extends StatefulWidget {
  final String? initialChatId;

  const AIChatPage({super.key, this.initialChatId});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  static const Color primaryBurgundy = Color(0xFF35132F);
  static const Color goldAccent = Color(0xFFF2D39A);
  static const Color darkInk = Color(0xFF302A33);
  static const Color mutedText = Color(0xFF827985);
  static const Color creamBg = Color(0xFFF7F5F3);
  static const Color lavender = Color(0xFFECE7F4);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _activeChatId;
  String _userRole = 'Influencer';
  String? _userName;
  bool _isLoadingRole = true;
  bool _isSending = false;
  String? _errorMessage;

  // Local message cache for immediate rendering before Firestore echo
  final List<AIChatMessage> _localMessages = [];

  StreamSubscription<List<AIChatMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _activeChatId = widget.initialChatId;
    _initializeUserContext();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeUserContext() async {
    try {
      final role = await AIService().getCurrentUserRole();
      final name = await AIService().getCurrentUserName();

      if (!mounted) return;
      setState(() {
        _userRole = role;
        _userName = name;
        _isLoadingRole = false;
      });

      if (_activeChatId != null) {
        _subscribeToMessages(_activeChatId!);
      }
    } catch (e) {
      debugPrint('Error initializing user context: $e');
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  void _subscribeToMessages(String chatId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = AIService()
        .getChatMessagesStream(chatId)
        .listen(
          (remoteMessages) {
            if (!mounted) return;
            setState(() {
              _localMessages.clear();
              _localMessages.addAll(remoteMessages);
            });
            _scrollToBottom();
          },
          onError: (err) {
            debugPrint('Error listening to chat messages: $err');
          },
        );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  void _startNewChat() {
    _messagesSubscription?.cancel();
    setState(() {
      _activeChatId = null;
      _localMessages.clear();
      _errorMessage = null;
    });
  }

  Future<void> _openHistory() async {
    final selectedChatId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AIChatHistoryPage(
          onSelectChat: (chatId) {
            _switchChat(chatId);
          },
        ),
      ),
    );

    if (selectedChatId != null && mounted) {
      _switchChat(selectedChatId);
    }
  }

  void _switchChat(String chatId) {
    setState(() {
      _activeChatId = chatId;
      _errorMessage = null;
    });
    _subscribeToMessages(chatId);
  }

  Future<void> _handleSendMessage({String? promptOverride}) async {
    final text = promptOverride ?? _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final tempUserMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final userMessage = AIChatMessage(
      id: tempUserMessageId,
      chatId: _activeChatId ?? 'pending',
      userId: '',
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    // Add optimistically to local UI
    setState(() {
      _localMessages.add(userMessage);
    });
    _scrollToBottom();

    try {
      // 1. Create a new chat session if none is active
      String chatId = _activeChatId ?? '';
      if (chatId.isEmpty) {
        chatId = await AIService().createNewChat(
          initialMessage: text,
          role: _userRole,
        );
        _activeChatId = chatId;
        _subscribeToMessages(chatId);
      }

      // 2. Save user message to Firestore
      final persistedUserMessage = userMessage.copyWith(chatId: chatId);
      await AIService().saveMessage(persistedUserMessage);

      // 3. Send to AIService (handles Gemini, creator matching, context)
      await AIService().sendMessage(
        chatId: chatId,
        userText: text,
        history: _localMessages.where((m) => !m.isError).toList(),
      );
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _localMessages.add(
            AIChatMessage(
              id: 'err_${DateTime.now().millisecondsSinceEpoch}',
              chatId: _activeChatId ?? '',
              userId: '',
              role: MessageRole.assistant,
              content:
                  'Unable to complete request: $_errorMessage\n\nPlease check your internet connection or API settings and try again.',
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Center(
        child: CircularProgressIndicator(color: primaryBurgundy),
      );
    }

    final suggestedPrompts = AIPrompt.getSuggestedPrompts(_userRole);

    return Scaffold(
      backgroundColor: creamBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                // Premium AI Header
                _buildHeader(),

                // Message List or Empty State with Suggested Prompts
                Expanded(
                  child: _localMessages.isEmpty
                      ? _buildEmptyState(suggestedPrompts)
                      : _buildMessageList(),
                ),

                // Typing Indicator
                if (_isSending) const AITypingIndicator(),

                // Suggested Prompts Quick Strip (when chatting)
                if (_localMessages.isNotEmpty && !_isSending)
                  _buildPromptChips(suggestedPrompts),

                // Input Bar
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: primaryBurgundy.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF35132F), Color(0xFF6C3C68)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: goldAccent, size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'CreatorConnect AI',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: darkInk,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: goldAccent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_userRole.toUpperCase()} AI',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primaryBurgundy,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _userName != null
                      ? 'Role-tailored assistance for $_userName'
                      : 'Role-based intelligence for ${_userRole}s',
                  style: const TextStyle(fontSize: 11.5, color: mutedText),
                ),
              ],
            ),
          ),

          // Header Actions: History and New Chat
          IconButton(
            tooltip: 'Chat History',
            icon: const Icon(Icons.history_rounded, color: primaryBurgundy),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'New Conversation',
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: primaryBurgundy,
            ),
            onPressed: _startNewChat,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(List<AIPromptSuggestion> prompts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // AI Glowing Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF35132F), Color(0xFF6C3C68)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBurgundy.withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: goldAccent, size: 40),
          ),
          const SizedBox(height: 20),

          Text(
            'How can I help you today?',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkInk,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            'Specialized for ${_userRole}s. Ask for content concepts, workflow help, or to search verified creators from CreatorConnect database.',
            style: const TextStyle(fontSize: 14, color: mutedText, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Role Prompt Cards Grid
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'SUGGESTED FOR ${_userRole.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primaryBurgundy,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: prompts.map((prompt) {
                  return SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: _buildPromptCard(prompt),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getSuggestionIcon(String code) {
    switch (code) {
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'mail':
        return Icons.mail_outline_rounded;
      case 'tag':
        return Icons.tag_rounded;
      case 'calendar_month':
        return Icons.calendar_month_outlined;
      case 'person_search':
        return Icons.person_search_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'file_download':
        return Icons.file_download_outlined;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_outlined;
      case 'movie_filter':
        return Icons.movie_filter_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outline_rounded;
      case 'campaign':
        return Icons.campaign_outlined;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'stars':
        return Icons.stars_rounded;
      case 'assignment':
        return Icons.assignment_outlined;
      case 'handshake':
        return Icons.handshake_outlined;
      default:
        return Icons.bolt_rounded;
    }
  }

  Widget _buildPromptCard(AIPromptSuggestion suggestion) {
    return InkWell(
      onTap: () => _handleSendMessage(promptOverride: suggestion.prompt),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryBurgundy.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: lavender,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getSuggestionIcon(suggestion.iconCode),
                    color: primaryBurgundy,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: darkInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.prompt,
              style: const TextStyle(fontSize: 12.5, color: mutedText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChips(List<AIPromptSuggestion> prompts) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = prompts[index];
          return ActionChip(
            backgroundColor: Colors.white,
            side: BorderSide(color: primaryBurgundy.withValues(alpha: 0.15)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            avatar: Icon(
              _getSuggestionIcon(p.iconCode),
              size: 14,
              color: primaryBurgundy,
            ),
            label: Text(
              p.title,
              style: const TextStyle(
                fontSize: 12,
                color: darkInk,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => _handleSendMessage(promptOverride: p.prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _localMessages.length,
      itemBuilder: (context, index) {
        final message = _localMessages[index];
        return AIChatBubble(
          message: message,
          onRetry: message.isError
              ? () {
                  // Retry the previous user query
                  final prevUserMsg = _localMessages
                      .sublist(0, index)
                      .lastWhere((m) => m.isUser, orElse: () => message);
                  _handleSendMessage(promptOverride: prevUserMsg.content);
                }
              : null,
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: primaryBurgundy.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: creamBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryBurgundy.withValues(alpha: 0.12),
                ),
              ),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    _handleSendMessage();
                  },
                },
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                  style: const TextStyle(fontSize: 14.5, color: darkInk),
                  decoration: InputDecoration(
                    hintText: 'Ask CreatorConnect AI anything...',
                    hintStyle: const TextStyle(color: mutedText, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send Button
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            child: FilledButton(
              onPressed: _isSending ? null : () => _handleSendMessage(),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBurgundy,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
                minimumSize: const Size(48, 48),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: goldAccent,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 22,
                      color: goldAccent,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
