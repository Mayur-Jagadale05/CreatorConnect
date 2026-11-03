import 'dart:async';
import 'package:flutter/material.dart';
import 'package:creatorconnect/services/chat_service.dart';
import 'package:creatorconnect/services/connection_request_service.dart';
import 'package:creatorconnect/ChatConversationPage.dart';

class MessageNotificationService {
  static final MessageNotificationService instance =
      MessageNotificationService._();

  MessageNotificationService._();

  StreamSubscription<List<ChatConversation>>? _subscription;
  StreamSubscription<List<ConnectionRequest>>? _connectionRequestsSub;
  final Set<String> _seenMessageSignatures = {};
  DateTime _sessionStartTime = DateTime.now();
  String? _currentListeningUid;
  OverlayEntry? _activeOverlay;

  /// Holds the chatId of the conversation the user currently has open,
  /// so we don't pop up notifications for messages in that chat.
  static String? activeChatId;

  /// Optional callback invoked when the user taps on a connection request notification
  /// to navigate directly to the Messages -> Connections section.
  static VoidCallback? onOpenMessages;

  void startListening(BuildContext context, String currentUid) {
    if (currentUid.isEmpty) return;
    if (_currentListeningUid == currentUid && _subscription != null) return;

    _subscription?.cancel();
    _connectionRequestsSub?.cancel();
    _currentListeningUid = currentUid;
    _sessionStartTime = DateTime.now();

    // 1. Listen for new chat messages
    _subscription = ChatService.watchUserConversations(currentUid).listen(
      (conversations) {
        for (final chat in conversations) {
          final senderUid = chat.lastMessageSenderUid;
          final lastTime = chat.lastMessageTime;

          if (senderUid.isEmpty || senderUid == currentUid) continue;
          if (lastTime == null || lastTime.isBefore(_sessionStartTime)) continue;
          if (activeChatId == chat.chatId) continue;

          final signature = '${chat.chatId}_${lastTime.millisecondsSinceEpoch}';
          if (_seenMessageSignatures.contains(signature)) continue;
          _seenMessageSignatures.add(signature);

          // Trigger in-app notification popup if context is still valid
          if (context.mounted) {
            _showInAppNotification(context, chat, currentUid);
          }
        }
      },
      onError: (err) {
        debugPrint('MessageNotificationService chat stream error: $err');
      },
    );

    // 2. Listen for incoming connection requests
    _connectionRequestsSub =
        ConnectionRequestService.watchIncomingRequests(currentUid).listen(
      (requests) {
        for (final req in requests) {
          if (req.senderUid.isEmpty || req.senderUid == currentUid) continue;
          if (req.status != 'pending') continue;

          final time = req.createdAt;
          if (time != null && time.isBefore(_sessionStartTime)) continue;

          final signature =
              'conn_${req.requestId}_${time?.millisecondsSinceEpoch ?? 0}';
          if (_seenMessageSignatures.contains(signature)) continue;
          _seenMessageSignatures.add(signature);

          if (context.mounted) {
            _showConnectionRequestNotification(context, req);
          }
        }
      },
      onError: (err) {
        debugPrint('MessageNotificationService connection request stream error: $err');
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _connectionRequestsSub?.cancel();
    _connectionRequestsSub = null;
    _currentListeningUid = null;
    _removeActiveOverlay();
  }

  void _removeActiveOverlay() {
    _activeOverlay?.remove();
    _activeOverlay = null;
  }

  void _showConnectionRequestNotification(
    BuildContext context,
    ConnectionRequest req,
  ) {
    _removeActiveOverlay();

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NotificationBannerWidget(
        senderName: req.senderName,
        senderPhoto: req.senderProfilePhoto,
        senderRole: req.senderRole,
        messagePreview: 'Sent you a connection request',
        onTap: () {
          _removeActiveOverlay();
          if (onOpenMessages != null) {
            onOpenMessages!();
          }
        },
        onDismiss: _removeActiveOverlay,
      ),
    );

    _activeOverlay = entry;
    overlayState.insert(entry);

    // Auto dismiss after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (_activeOverlay == entry) {
        _removeActiveOverlay();
      }
    });
  }

  void _showInAppNotification(
    BuildContext context,
    ChatConversation chat,
    String currentUid,
  ) {
    final other = chat.getOtherParticipant(currentUid);
    final otherUid = (other['uid'] ?? '').toString();
    final otherName = (other['name'] ?? 'Creator').toString();
    final otherPhoto = (other['photo'] ?? '').toString();
    final otherRole = (other['role'] ?? 'Creator').toString();
    final otherUsername = (other['username'] ?? '').toString();
    final preview = chat.lastMessage;

    _removeActiveOverlay();

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NotificationBannerWidget(
        senderName: otherName,
        senderPhoto: otherPhoto,
        senderRole: otherRole,
        messagePreview: preview,
        onTap: () {
          _removeActiveOverlay();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatConversationPage(
                chatId: chat.chatId,
                otherUserUid: otherUid,
                otherUserName: otherName,
                otherUserPhoto: otherPhoto,
                otherUserRole: otherRole,
                otherUserUsername: otherUsername,
              ),
            ),
          );
        },
        onDismiss: _removeActiveOverlay,
      ),
    );

    _activeOverlay = entry;
    overlayState.insert(entry);

    // Auto dismiss after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (_activeOverlay == entry) {
        _removeActiveOverlay();
      }
    });
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final String senderName;
  final String senderPhoto;
  final String senderRole;
  final String messagePreview;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBannerWidget({
    required this.senderName,
    required this.senderPhoto,
    required this.senderRole,
    required this.messagePreview,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  static const Color purple = Color(0xFF35132F);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: InkWell(
                  onTap: () {
                    widget.onTap();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: purple.withValues(alpha: 0.18),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withValues(alpha: 0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: lavender,
                          backgroundImage: widget.senderPhoto.isNotEmpty
                              ? NetworkImage(widget.senderPhoto)
                              : null,
                          child: widget.senderPhoto.isEmpty
                              ? const Icon(Icons.person, color: purple, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.senderName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: primaryText,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                                      widget.senderRole,
                                      style: const TextStyle(
                                        color: purple,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.messagePreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: secondaryText,
                          onPressed: _dismiss,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
