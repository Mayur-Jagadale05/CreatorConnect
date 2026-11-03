import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:creatorconnect/AI/AIChatPage.dart';
import 'package:creatorconnect/ChatConversationPage.dart';
import 'package:creatorconnect/ProfileDetailsPage.dart';
import 'package:creatorconnect/ProfileViewPage.dart';
import 'package:creatorconnect/models/educational_video_model.dart';
import 'package:creatorconnect/models/post_model.dart';
import 'package:creatorconnect/services/chat_service.dart';
import 'package:creatorconnect/services/connection_request_service.dart';
import 'package:creatorconnect/services/educational_video_service.dart';
import 'package:creatorconnect/services/message_notification_service.dart';
import 'package:creatorconnect/services/post_service.dart';
import 'package:creatorconnect/widgets/create_post_dialog.dart';
import 'package:creatorconnect/widgets/education_video_card.dart';
import 'package:creatorconnect/widgets/post_card.dart';
import 'package:creatorconnect/widgets/upload_education_video_dialog.dart';

class Businessmanpage extends StatefulWidget {
  const Businessmanpage({super.key});

  @override
  State<Businessmanpage> createState() => _BusinessmanpageState();
}

class _BusinessmanpageState extends State<Businessmanpage>
    with SingleTickerProviderStateMixin {
  // ------------------------------------------------------------
  // CREATORCONNECT DESIGN SYSTEM
  // ------------------------------------------------------------

  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color iceSilver = Color(0xFFF0EDF0);
  static const Color marigold = Color(0xFFF2D39A);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);
  static const Color borderColor = Color(0xCCFFFFFF);
  static const Color lavender = Color(0xFFECE7F4);

  String? selectedTab;
  String selectedSidebarItem = 'Home';

  bool notificationsEnabled = true;
  bool _savingNotification = false;
  String? _notificationError;
  String? _creatorLoadError;
  bool _loadingCreators = true;

  final TextEditingController searchController = TextEditingController();
  final PageController _heroPageController = PageController();
  final ScrollController _dashboardScrollController = ScrollController();
  final GlobalKey _searchSectionKey = GlobalKey();

  Timer? _heroTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _creatorsSubscription;
  StreamSubscription<Set<String>>? _connectedUsersSubscription;
  int _heroPageIndex = 0;

  List<Map<String, dynamic>> creators = [];
  final Set<String> _connectingUids = {};
  Set<String> _connectedOrRequestedUids = {};

  final List<String> tabs = const [
    'Businessman',
    'Influencer',
    'Editor',
    'Writer',
    'Education',
  ];

  static const List<String> _heroImages = [
    'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1800&q=85',
    'https://images.unsplash.com/photo-1492724441997-5dc865305da7?auto=format&fit=crop&w=1800&q=85',
    'https://images.unsplash.com/photo-1524758631624-e2822e304c36?auto=format&fit=crop&w=1800&q=85',
    'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=1800&q=85',
  ];

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    MessageNotificationService.onOpenMessages = () {
      if (mounted) {
        setState(() {
          selectedSidebarItem = 'Messages';
        });
      }
    };

    _loadNotificationPreference();
    _loadCreators();
    _listenToCreators();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = currentUser?.uid;
      if (uid != null && mounted) {
        MessageNotificationService.instance.startListening(context, uid);
      }
    });
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && selectedSidebarItem == 'Home') {
        _advanceHeroBackground();
      }
    });
  }

  @override
  void dispose() {
    MessageNotificationService.onOpenMessages = null;
    MessageNotificationService.instance.stopListening();
    _heroTimer?.cancel();
    _creatorsSubscription?.cancel();
    _connectedUsersSubscription?.cancel();
    _heroPageController.dispose();
    _dashboardScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreators() async {
    try {
      final uid = currentUser?.uid;

      if (uid != null) {
        try {
          final existing =
              await ConnectionRequestService.getConnectedOrRequestedUserIds(uid);
          _connectedOrRequestedUids = existing;
        } catch (_) {}
      }

      var profileDataSnapshot = await FirebaseFirestore.instance
          .collection('Profile_Data')
          .get();

      // Legacy fallback if Profile_Data is empty
      if (profileDataSnapshot.docs.isEmpty) {
        final legacyUsersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();
        if (legacyUsersSnapshot.docs.isNotEmpty) {
          profileDataSnapshot = legacyUsersSnapshot;
        }
      }

      final profiles = profileDataSnapshot.docs
          .where((doc) {
            final docUid = doc.id;
            if (docUid == uid || doc.data()['uid'] == uid) return false;
            if (_connectedOrRequestedUids.contains(docUid) ||
                _connectedOrRequestedUids.contains(doc.data()['uid'])) {
              return false;
            }
            final role = doc.data()['role']?.toString().trim().toLowerCase();
            return const {
              'businessman',
              'influencer',
              'writer',
              'editor',
              'video editor',
            }.contains(role);
          })
          .map((doc) {
            final id = doc.id;
            final data = doc.data();

            return <String, dynamic>{
              'uid': id,
              'name':
                  data['fullName'] ??
                  data['name'] ??
                  data['username'] ??
                  'Creator',
              'username': data['username'] ?? '',
              'email': data['email'] ?? '',
              'role': data['role'] ?? 'Creator',
              'category': data['category'] ?? '',
              'location': data['location'] ?? '',
              'photo':
                  data['profilePhotoUrl'] ??
                  data['photo'] ??
                  data['profileImage'] ??
                  '',
              'bio': data['bio'] ?? '',
              'educationVideoUrl': data['educationVideoUrl'] ?? '',
              'educationDescription': data['educationDescription'] ?? '',
            };
          })
          .toList();

      if (!mounted) return;
      setState(() {
        creators = profiles;
        _loadingCreators = false;
        _creatorLoadError = null;
      });
    } catch (error) {
      debugPrint('Unable to load creators: $error');
      if (!mounted) return;
      setState(() {
        _loadingCreators = false;
        _creatorLoadError = 'Unable to load creators: $error';
      });
    }
  }

  void _listenToCreators() {
    final uid = currentUser?.uid;
    if (uid != null) {
      _connectedUsersSubscription?.cancel();
      _connectedUsersSubscription = ConnectionRequestService
          .watchConnectedOrRequestedUserIds(uid)
          .listen((uids) {
        if (!mounted) return;
        setState(() {
          _connectedOrRequestedUids.addAll(uids);
          creators.removeWhere(
            (c) => _connectedOrRequestedUids.contains(c['uid']),
          );
        });
      });
    }

    // Subscribe to creator accounts so the dashboard stays current as profiles change.
    _creatorsSubscription = FirebaseFirestore.instance
        .collection('Profile_Data')
        .where(
          'role',
          whereIn: const [
            'Influencer',
            'Writer',
            'Editor',
            'Video Editor',
            'Businessman',
          ],
        )
        .snapshots()
        .listen(
          (snapshot) {
            final uid = currentUser?.uid;
            final profiles = snapshot.docs
                .where((doc) {
                  final docUid = doc.id;
                  if (docUid == uid || doc.data()['uid'] == uid) return false;
                  if (_connectedOrRequestedUids.contains(docUid) ||
                      _connectedOrRequestedUids.contains(doc.data()['uid'])) {
                    return false;
                  }
                  final role = doc
                      .data()['role']
                      ?.toString()
                      .trim()
                      .toLowerCase();
                  return const {
                    'influencer',
                    'writer',
                    'editor',
                    'video editor',
                    'businessman',
                  }.contains(role);
                })
                .map((doc) {
                  final data = doc.data();
                  return <String, dynamic>{
                    'uid': doc.id,
                    'name':
                        data['fullName'] ??
                        data['name'] ??
                        data['username'] ??
                        'Creator',
                    'username': data['username'] ?? '',
                    'email': data['email'] ?? '',
                    'role': data['role'] ?? 'Creator',
                    'category': data['category'] ?? '',
                    'location': data['location'] ?? '',
                    'photo':
                        data['profilePhotoUrl'] ?? data['profileImage'] ?? '',
                    'bio': data['bio'] ?? '',
                    'educationVideoUrl': data['educationVideoUrl'] ?? '',
                    'educationDescription': data['educationDescription'] ?? '',
                  };
                })
                .toList();

            if (!mounted) return;
            setState(() {
              creators = profiles;
              _loadingCreators = false;
              _creatorLoadError = null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Unable to listen for creators: $error');
            if (!mounted) return;
            setState(() {
              _loadingCreators = false;
              _creatorLoadError =
                  'Unable to load profiles from Firestore: $error';
            });
          },
        );
  }

  // ------------------------------------------------------------
  // NOTIFICATION SETTINGS
  // ------------------------------------------------------------

  Future<void> _loadNotificationPreference() async {
    final user = currentUser;
    if (user == null) return;

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(user.uid)
          .get();

      if (!snapshot.exists ||
          snapshot.data()?['notificationsEnabled'] == null) {
        final legacySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (legacySnapshot.exists) {
          snapshot = legacySnapshot;
        }
      }

      if (!mounted) return;

      setState(() {
        notificationsEnabled =
            snapshot.data()?['notificationsEnabled'] as bool? ?? true;
      });
    } catch (error) {
      debugPrint('Notification preference error: $error');
    }
  }

  Future<void> _saveNotificationPreference(bool value) async {
    final user = currentUser;

    if (user == null) {
      _showMessage('Please log in to change settings.');
      return;
    }

    setState(() {
      _savingNotification = true;
      _notificationError = null;
    });

    try {
      final updateData = {
        'notificationsEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => notificationsEnabled = value);
      _showMessage('Notification preference saved.');
    } catch (error) {
      debugPrint('Save notification error: $error');

      if (!mounted) return;

      setState(() {
        _notificationError = 'Could not save notification preference.';
      });
    } finally {
      if (mounted) {
        setState(() => _savingNotification = false);
      }
    }
  }

  // ------------------------------------------------------------
  // COMMON HELPERS
  // ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
    );
    if (mounted) {
      _loadCreators();
    }
  }

  Future<void> _openCreatorProfile(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileViewPage(selectedUserUid: cleanUid),
      ),
    );
    final user = currentUser;
    if (user != null && mounted) {
      final updated =
          await ConnectionRequestService.getConnectedOrRequestedUserIds(
        user.uid,
      );
      setState(() {
        _connectedOrRequestedUids.addAll(updated);
        creators.removeWhere(
          (c) => _connectedOrRequestedUids.contains(c['uid']),
        );
      });
    }
  }

  Future<void> _sendConnectionRequest(Map<String, dynamic> targetCreator) async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Please log in to connect.');
      return;
    }

    final targetUid = (targetCreator['uid'] ?? '').toString().trim();
    if (targetUid.isEmpty || targetUid == user.uid) return;

    if (_connectingUids.contains(targetUid) ||
        _connectedOrRequestedUids.contains(targetUid)) {
      return;
    }

    setState(() {
      _connectingUids.add(targetUid);
    });

    try {
      final senderProfile = await ChatService.getUserProfile(user.uid);
      final myName = senderProfile['name'] ?? user.displayName ?? 'Creator';
      final myUsername = senderProfile['username'] ?? '';
      final myRole = senderProfile['role'] ?? 'Businessman';
      final myPhoto = senderProfile['photo'] ?? user.photoURL ?? '';
      final myEmail = user.email ?? '';

      final targetName = (targetCreator['name'] ?? 'Creator').toString();
      final targetUsername = (targetCreator['username'] ?? '').toString();
      final targetRole = (targetCreator['role'] ?? 'Creator').toString();
      final targetPhoto = (targetCreator['photo'] ?? '').toString();

      await ConnectionRequestService.sendRequest(
        senderUid: user.uid,
        senderName: myName,
        senderUsername: myUsername,
        senderEmail: myEmail,
        senderRole: myRole,
        senderProfilePhoto: myPhoto,
        receiverUid: targetUid,
        receiverName: targetName,
        receiverUsername: targetUsername,
        receiverRole: targetRole,
        receiverProfilePhoto: targetPhoto,
      );

      if (!mounted) return;
      setState(() {
        _connectedOrRequestedUids.add(targetUid);
        creators.removeWhere((c) => c['uid'] == targetUid);
        _connectingUids.remove(targetUid);
      });

      _showMessage('Connection request sent to $targetName!');
    } catch (e) {
      debugPrint('Error sending connection request: $e');
      if (!mounted) return;
      setState(() {
        _connectingUids.remove(targetUid);
      });
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _openUploadEducationVideoDialog() async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Please log in first.');
      return;
    }

    final uploaded = await showDialog<bool>(
      context: context,
      builder: (ctx) => const UploadEducationVideoDialog(
        defaultRole: 'Businessman',
      ),
    );

    if (uploaded == true) {
      _showMessage(
        'Educational video uploaded successfully! It is now visible to other Businessmen.',
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: pageBg,
          title: const Text('Log out?'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Signing out clears the Firebase Authentication session for this device.
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Logout error: $error');
      _showMessage('Logout failed. Please try again.');
    }
  }

  Future<void> _resetPassword() async {
    final email = currentUser?.email;

    if (email == null || email.isEmpty) {
      _showMessage('No email address is available.');
      return;
    }

    try {
      // Firebase sends the reset link to the address on the authenticated account.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showMessage('Password reset email sent to $email');
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Unable to send reset email.');
    }
  }

  void _selectSidebarItem(String item) {
    setState(() => selectedSidebarItem = item);

    if (item == 'Home') {
      _dashboardScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _advanceHeroBackground() {
    if (!_heroPageController.hasClients) return;

    final nextIndex = (_heroPageIndex + 1) % _heroImages.length;

    _heroPageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _scrollToSearch() async {
    final searchContext = _searchSectionKey.currentContext;
    if (searchContext == null) return;

    await Scrollable.ensureVisible(
      searchContext,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  // ------------------------------------------------------------
  // ROOT LAYOUT
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobile = screenWidth < 760;

    return Scaffold(
      backgroundColor: pageBg,
      bottomNavigationBar: mobile ? _buildMobileBottomNavigation() : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/creatorconnect_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),

          // Soft neutral overlay keeps the background subtle.
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: pageBg.withValues(alpha: 0.48)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 760;

                      if (isMobile) {
                        return selectedSidebarItem == 'AI Assistant'
                            ? const AIChatPage()
                            : SingleChildScrollView(
                                controller: _dashboardScrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  8,
                                  14,
                                  28,
                                ),
                                child: _buildSelectedPage(),
                              );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSidebar(),

                          Expanded(
                            child: selectedSidebarItem == 'AI Assistant'
                                ? const AIChatPage()
                                : SingleChildScrollView(
                                    controller: _dashboardScrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      28,
                                      28,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1400,
                                        ),
                                        child: _buildSelectedPage(),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // GLASS PANEL
  // ------------------------------------------------------------

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry? margin,
    double radius = 22,
    Color color = const Color(0xDDF9F6F5),
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: color, child: child),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP BAR
  // ------------------------------------------------------------

  Widget _buildTopBar() {
    return _glassPanel(
      margin: const EdgeInsets.fromLTRB(22, 8, 22, 8),
      radius: 24,
      color: const Color(0xDDF9F6F5),
      child: SizedBox(
        height: 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: purple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'CreatorConnect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: purple,
                  ),
                ),
              ),

              if (MediaQuery.sizeOf(context).width > 580)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Text(
                    'A COMMUNITY FOR CREATIVE WORK',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

              IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  _showMessage(
                    notificationsEnabled
                        ? 'Notifications are enabled.'
                        : 'Notifications are disabled.',
                  );
                },
                style: IconButton.styleFrom(
                  foregroundColor: purple,
                  backgroundColor: Colors.white.withValues(alpha: 0.65),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SIDEBAR
  // ------------------------------------------------------------

  Widget _buildSidebar() {
    return Container(
      width: 246,
      margin: const EdgeInsets.fromLTRB(22, 8, 12, 18),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xDDF9F6F5),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 5, 12, 18),
            child: Text(
              'YOUR STUDIO',
              style: TextStyle(
                color: secondaryText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
              ),
            ),
          ),

          ..._sidebarItems(),

          const Spacer(),

          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lavender.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.eco_outlined, color: purple, size: 20),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Make something\nmeaningful.',
                    style: TextStyle(
                      color: purple,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNavigation() {
    const items = <({String label, IconData icon, IconData activeIcon})>[
      (
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      (
        label: 'AI Assistant',
        icon: Icons.auto_awesome,
        activeIcon: Icons.auto_awesome,
      ),
      (
        label: 'My Post',
        icon: Icons.article_outlined,
        activeIcon: Icons.article_rounded,
      ),
      (
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
      ),
      (
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE8FDFBF9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: items.map((item) {
                  final selected = selectedSidebarItem == item.label;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _selectSidebarItem(item.label),
                      splashColor: lavender,
                      highlightColor: Colors.transparent,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? lavender : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreamBuilder<int>(
                                stream: item.label == 'Messages' &&
                                        currentUser != null
                                    ? ConnectionRequestService
                                        .watchCombinedMessagesBadgeCount(
                                        currentUser!.uid,
                                      )
                                    : Stream.value(0),
                                builder: (context, unreadSnap) {
                                  final count = unreadSnap.data ?? 0;
                                  final iconWidget = Icon(
                                    selected ? item.activeIcon : item.icon,
                                    size: 21,
                                    color: selected ? purple : secondaryText,
                                  );
                                  if (count > 0 && item.label == 'Messages') {
                                    return Badge.count(
                                      count: count,
                                      backgroundColor: purple,
                                      child: iconWidget,
                                    );
                                  }
                                  return iconWidget;
                                },
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected ? purple : secondaryText,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sidebarItems({bool compact = false}) {
    const items = <({String label, IconData icon})>[
      (label: 'Home', icon: Icons.home_rounded),
      (label: 'AI Assistant', icon: Icons.auto_awesome),
      (label: 'My Post', icon: Icons.article_outlined),
      (label: 'Messages', icon: Icons.chat_bubble_outline_rounded),
      (label: 'Settings', icon: Icons.settings_outlined),
    ];

    return items.map((item) {
      final selected = selectedSidebarItem == item.label;

      if (compact) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectSidebarItem(item.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? lavender : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 18, color: purple),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            selected: selected,
            selectedTileColor: lavender,
            selectedColor: purple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: StreamBuilder<int>(
              stream: item.label == 'Messages' && currentUser != null
                  ? ConnectionRequestService.watchCombinedMessagesBadgeCount(
                      currentUser!.uid,
                    )
                  : Stream.value(0),
              builder: (context, unreadSnap) {
                final count = unreadSnap.data ?? 0;
                final iconWidget = Icon(item.icon, size: 22);
                if (count > 0 && item.label == 'Messages') {
                  return Badge.count(
                    count: count,
                    backgroundColor: purple,
                    child: iconWidget,
                  );
                }
                return iconWidget;
              },
            ),
            title: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            onTap: () => _selectSidebarItem(item.label),
          ),
        ),
      );
    }).toList();
  }

  // ------------------------------------------------------------
  // PAGE ROUTING
  // ------------------------------------------------------------

  Widget _buildSelectedPage() {
    switch (selectedSidebarItem) {
      case 'AI Assistant':
        return const AIChatPage();

      case 'My Post':
        return _buildMyPosts();

      case 'Messages':
        return _buildMessages();

      case 'Settings':
        return _buildSettings();

      default:
        return _buildHome();
    }
  }

  Widget _pageHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 29,
              fontWeight: FontWeight.w700,
              color: purple,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // HOME PAGE
  // ------------------------------------------------------------

  Widget _buildHome() {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('homePage'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroBanner(),
          const SizedBox(height: 18),
          _buildProfileSummary(),
          const SizedBox(height: 18),
          _buildRoleTabs(),
          const SizedBox(height: 14),
          _buildSearch(),
          const SizedBox(height: 18),
          _buildExploreProfiles(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // HERO CAROUSEL
  // ------------------------------------------------------------

  Widget _buildHeroBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        return Container(
          height: compact ? 205 : 286,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFE8DFD9),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: purple.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _heroPageController,
                itemCount: _heroImages.length,
                onPageChanged: (index) {
                  setState(() => _heroPageIndex = index);
                },
                itemBuilder: (context, index) {
                  return Image.network(
                    _heroImages[index],
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: const Color(0xFFE8DFD9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.photo_outlined,
                          size: 70,
                          color: purple,
                        ),
                      );
                    },
                  );
                },
              ),

              // Light overlay: preserves the original image colors.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x08000000),
                      Color(0x18000000),
                      Color(0x99000000),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(compact ? 14 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            setState(() {
                              selectedTab = 'Influencer';
                              selectedSidebarItem = 'Home';
                            });

                            await Future.delayed(
                              const Duration(milliseconds: 80),
                            );

                            if (mounted) {
                              _scrollToSearch();
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                          ),
                          label: const Text('Explore creators'),
                          style: FilledButton.styleFrom(
                            backgroundColor: marigold,
                            foregroundColor: purple,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_heroImages.length, (index) {
                            return GestureDetector(
                              onTap: () {
                                _heroPageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: _heroPageIndex == index ? 19 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: _heroPageIndex == index ? 1 : 0.65,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            );
                          }),
                        ),

                        IconButton(
                          onPressed: _advanceHeroBackground,
                          tooltip: 'Next image',
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.20,
                            ),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<Map<String, dynamic>> _watchUserProfile(String uid) {
    late StreamController<Map<String, dynamic>> controller;
    StreamSubscription? subProfileData;

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        // Immediate fetch from Profile_Data
        FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(uid)
            .get()
            .then((doc) {
              if (doc.exists && doc.data() != null) {
                if (!controller.isClosed) controller.add(doc.data()!);
              } else {
                // Legacy fallback: check users and migrate to Profile_Data
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get()
                    .then((legacyDoc) {
                      if (legacyDoc.exists && legacyDoc.data() != null) {
                        FirebaseFirestore.instance
                            .collection('Profile_Data')
                            .doc(uid)
                            .set(legacyDoc.data()!, SetOptions(merge: true))
                            .catchError((_) {});
                        if (!controller.isClosed) {
                          controller.add(legacyDoc.data()!);
                        }
                      }
                    })
                    .catchError((_) {});
              }
            })
            .catchError((_) {});

        // Real-time updates from Profile_Data
        subProfileData = FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(uid)
            .snapshots()
            .listen(
              (doc) {
                if (doc.exists && doc.data() != null) {
                  if (!controller.isClosed) controller.add(doc.data()!);
                }
              },
              onError: (err) {
                debugPrint('Profile_Data stream warning: $err');
              },
            );
      },
      onCancel: () {
        subProfileData?.cancel();
      },
    );

    return controller.stream;
  }

  // ------------------------------------------------------------
  // PROFILE SUMMARY
  // ------------------------------------------------------------

  Widget _buildProfileSummary() {
    final user = currentUser;

    if (user == null) {
      return _emptyPanel('Please log in to view your profile.');
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: _watchUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyPanel('Unable to load your profile.');
        }

        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _glassPanel(
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(color: purple, strokeWidth: 2),
              ),
            ),
          );
        }

        final data = snapshot.data ?? <String, dynamic>{};

        final name =
            (data['fullName'] ??
                    data['name'] ??
                    data['username'] ??
                    user.displayName ??
                    'Your profile')
                .toString();

        final username = (data['username'] ?? '').toString();

        final role = (data['role'] ?? 'Businessman').toString();

        final bio = (data['bio'] ?? '').toString();

        final photo =
            (data['profilePhotoUrl'] ??
                    data['photo'] ??
                    data['profileImage'] ??
                    user.photoURL ??
                    '')
                .toString();

        return _glassPanel(
          radius: 24,
          color: const Color(0xDDF9F6F5),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;

                final profileInfo = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: purple.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: compact ? 35 : 47,
                        backgroundColor: iceSilver,
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        child: photo.isEmpty
                            ? const Icon(
                                Icons.person_outline_rounded,
                                color: purple,
                                size: 40,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            username.isEmpty
                                ? 'Username not added'
                                : '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: secondaryText,
                            ),
                          ),

                          const SizedBox(height: 9),

                          _pill(role, const Color(0xFFF0E5DE), purple),

                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              bio,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );

                final editButton = OutlinedButton.icon(
                  onPressed: _openProfile,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: purple,
                    backgroundColor: lavender.withValues(alpha: 0.65),
                    side: BorderSide(color: purple.withValues(alpha: 0.08)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      profileInfo,
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: editButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: profileInfo),
                    const SizedBox(width: 16),
                    editButton,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _pill(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyPanel(String message) {
    return _glassPanel(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: secondaryText, fontSize: 13),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ROLE TABS
  // ------------------------------------------------------------

  Widget _buildRoleTabs() {
    const icons = <String, IconData>{
      'Businessman': Icons.business_center_outlined,
      'Influencer': Icons.auto_awesome_rounded,
      'Editor': Icons.movie_creation_outlined,
      'Writer': Icons.edit_note_rounded,
      'Education': Icons.school_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xCFF9F6F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: tabs.map((tab) {
              final selected = selectedTab == tab;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () {
                      setState(() => selectedTab = selected ? null : tab);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF7F2FA)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: purple.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[tab],
                            size: 17,
                            color: selected ? purple : secondaryText,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              tab,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? purple : primaryText,
                                fontSize: constraints.maxWidth < 420 ? 10 : 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Widget _buildSearch() {
    return Container(
      key: _searchSectionKey,
      decoration: BoxDecoration(
        color: const Color(0xDDF9F6F5),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          hintStyle: const TextStyle(color: secondaryText, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: secondaryText),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, color: secondaryText),
                ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.22),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide(
              color: purple.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EXPLORE PROFILES
  // ------------------------------------------------------------

  Widget _buildExploreProfiles() {
    final query = searchController.text.trim().toLowerCase();
    final cleanSelectedTab = selectedTab?.trim().toLowerCase();
    final isEducationTab = cleanSelectedTab == 'education';

    final filteredCreators = selectedTab == null || isEducationTab
        ? <Map<String, dynamic>>[]
        : creators.where((creator) {
            final creatorUid = (creator['uid'] ?? '').toString();
            if (_connectedOrRequestedUids.contains(creatorUid)) {
              return false;
            }

            final role = (creator['role'] ?? '').toString().trim().toLowerCase();
            final category = (creator['category'] ?? '').toString().trim().toLowerCase();
            final name = (creator['name'] ?? '').toString().toLowerCase();

            final roleMatches = role == cleanSelectedTab ||
                (cleanSelectedTab == 'editor' && role == 'video editor');

            final searchMatches = query.isEmpty ||
                name.contains(query) ||
                category.contains(query) ||
                role.contains(query);

            return roleMatches && searchMatches;
          }).toList();

    return _glassPanel(
      radius: 22,
      color: const Color(0xDDF9F6F5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEducationTab ? 'Educational Videos' : 'Explore Profiles',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: purple,
                    ),
                  ),
                ),

                if (isEducationTab)
                  FilledButton.icon(
                    onPressed: _openUploadEducationVideoDialog,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Upload Video'),
                    style: FilledButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else if (selectedTab == null)
                  _pill('Select a role', const Color(0xFFF0E5DE), purple)
                else if (!isEducationTab)
                  _pill(
                    '${filteredCreators.length} matches',
                    const Color(0xFFF0E5DE),
                    purple,
                  ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              isEducationTab
                  ? 'Educational videos shared by other Businessmen.'
                  : 'Discover creative people for your next project.',
              style: const TextStyle(fontSize: 12, color: secondaryText),
            ),

            const SizedBox(height: 18),

            if (selectedTab == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 46,
                        color: purple.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select a role to view profiles',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Click on Businessman, Influencer, Editor, Writer, or Education above to explore profiles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else if (isEducationTab)
              StreamBuilder<List<EducationalVideo>>(
                stream:
                    EducationalVideoService.watchEducationalVideosForCurrentUser(
                  currentUid: currentUser?.uid ?? '',
                  fallbackRole: 'Businessman',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: purple,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'Error loading educational videos: ${snapshot.error}',
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }

                  var videos = snapshot.data ?? [];
                  if (query.isNotEmpty) {
                    videos = videos.where((v) {
                      return v.title.toLowerCase().contains(query) ||
                          v.description.toLowerCase().contains(query) ||
                          v.uploaderName.toLowerCase().contains(query);
                    }).toList();
                  }

                  if (videos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 46,
                              color: purple.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No educational videos available yet.',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Videos uploaded by other Businessmen will appear here.\nShare your knowledge to help fellow Businessmen!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _openUploadEducationVideoDialog,
                              icon: const Icon(Icons.upload_rounded, size: 16),
                              label: const Text('Upload Educational Video'),
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: videos.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return EducationVideoCard(video: videos[index]);
                    },
                  );
                },
              )
            else if (_loadingCreators)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: CircularProgressIndicator(
                    color: purple,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_creatorLoadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 42,
                        color: secondaryText,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _creatorLoadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: secondaryText),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _loadingCreators = true;
                            _creatorLoadError = null;
                          });
                          _creatorsSubscription?.cancel();
                          _listenToCreators();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredCreators.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 46,
                        color: purple.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No creators found',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Try another role or search keyword.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                itemCount: filteredCreators.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = filteredCreators[index];

                  final creatorUid = (item['uid'] ?? '').toString();

                  final name = (item['name'] ?? 'Creator').toString().trim();
                  final rawUsername =
                      (item['username'] ?? '').toString().trim();
                  final username = rawUsername.startsWith('@')
                      ? rawUsername.substring(1).trim()
                      : rawUsername;
                  final role = (item['role'] ?? 'Creator').toString().trim();
                  final photo = (item['photo'] ?? '').toString().trim();
                  final location = (item['location'] ?? '').toString().trim();

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => _openCreatorProfile(creatorUid),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 440;

                            final details = Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name.isNotEmpty ? name : 'Creator',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: primaryText,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (item['verified'] == true)
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: purple,
                                          size: 17,
                                        ),
                                    ],
                                  ),

                                  if (username.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$username',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: secondaryText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 6),

                                  Text(
                                    role.isNotEmpty ? role : 'Creator',
                                    style: const TextStyle(
                                      color: purple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  if (location.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: secondaryText,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            location,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: secondaryText,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );

                            final avatar = ClipOval(
                              child: photo.isEmpty
                                  ? Container(
                                      width: 54,
                                      height: 54,
                                      color: lavender,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.person_outline_rounded,
                                        color: purple,
                                        size: 28,
                                      ),
                                    )
                                  : Image.network(
                                      photo,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 54,
                                        height: 54,
                                        color: lavender,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          color: purple,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                            );

                            final isConnecting = _connectingUids
                                .contains(item['uid'].toString());

                            final messageButton = OutlinedButton(
                              onPressed: isConnecting
                                  ? null
                                  : () => _sendConnectionRequest(item),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: purple,
                                side: BorderSide(
                                  color: purple.withValues(alpha: 0.25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isConnecting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: purple,
                                      ),
                                    )
                                  : const Text(
                                      'Connect',
                                      style: TextStyle(fontSize: 12),
                                    ),
                            );

                            if (compact) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      avatar,
                                      const SizedBox(width: 12),
                                      details,
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: messageButton,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                avatar,
                                const SizedBox(width: 12),
                                details,
                                const SizedBox(width: 10),
                                messageButton,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MY POSTS
  // ------------------------------------------------------------

  void _openCreatePostModal([PostModel? existingPost]) async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Please log in to create a post.');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('Profile_Data')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    final name = (data['fullName'] ??
            data['name'] ??
            user.displayName ??
            'Businessman')
        .toString();
    final username = (data['username'] ?? '').toString();
    final role = (data['role'] ?? 'Businessman').toString();
    final photo = (data['profilePhotoUrl'] ??
            data['photo'] ??
            user.photoURL ??
            '')
        .toString();

    if (!mounted) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreatePostDialog(
        userId: user.uid,
        userName: name,
        username: username,
        userRole: role,
        userProfilePhoto: photo,
        existingPost: existingPost,
      ),
    );

    if (created == true && mounted) {
      _showMessage(existingPost != null
          ? 'Post updated successfully!'
          : 'Post published successfully!');
    }
  }

  void _confirmDeletePost(PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to permanently delete this post?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await PostService.deletePost(
                  postId: post.postId,
                  userId: post.userId,
                );
                _showMessage('Post deleted.');
              } catch (e) {
                _showMessage('Failed to delete post: $e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPosts() {
    final user = currentUser;
    if (user == null) {
      return _emptyPanel('Please log in to manage your posts.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _pageHeading(
                'My Posts',
                'Create and manage your creative content. Posts are visible to other verified members of your role.',
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openCreatePostModal(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Post'),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        StreamBuilder<List<PostModel>>(
          stream: PostService.watchUserPosts(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: purple, strokeWidth: 2),
                ),
              );
            }

            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return _emptyPanel(
                'You have not published any posts yet. Click "Create Post" above to share your work with other Businessmen!',
              );
            }

            return ListView.builder(
              itemCount: posts.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  isOwner: true,
                  onEdit: () => _openCreatePostModal(post),
                  onDelete: () => _confirmDeletePost(post),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // MESSAGES
  // ------------------------------------------------------------

  String _timeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatChatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && time.day == now.day) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }

  Widget _buildMessages() {
    final user = currentUser;
    if (user == null) {
      return _emptyPanel('Please log in to view your messages.');
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  final connectionsBadge = StreamBuilder<int>(
                    stream:
                        ConnectionRequestService.watchConnectionCount(user.uid),
                    builder: (context, countSnap) {
                      final count = countSnap.data ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECE7F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: purple.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_alt_outlined,
                              size: 16,
                              color: purple,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '$count Connections',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: purple,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                'Messages & Connections',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: purple,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            connectionsBadge,
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Chat directly with connected creators, collaborators, and partners.',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages & Connections',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: purple,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Chat directly with connected creators, collaborators, and partners.',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      connectionsBadge,
                    ],
                  );
                },
              ),
            ),

            // 1. INCOMING CONNECTION REQUESTS
            StreamBuilder<List<ConnectionRequest>>(
              stream: ConnectionRequestService.watchIncomingRequests(user.uid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: purple.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: lavender,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: purple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Connection Requests',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: purple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${requests.length} New',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final senderPhoto = req.senderProfilePhoto.isNotEmpty
                              ? req.senderProfilePhoto
                              : req.senderProfileImage;
                          final username = req.senderUsername.trim();
                          final timeStr = _timeAgo(req.createdAt);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF8F6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFECE7F4)),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      _openCreatorProfile(req.senderUid),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: lavender,
                                    backgroundImage: senderPhoto.isNotEmpty
                                        ? NetworkImage(senderPhoto)
                                        : null,
                                    child: senderPhoto.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: purple,
                                            size: 22,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _openCreatorProfile(
                                                req.senderUid),
                                            child: Text(
                                              req.senderName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: primaryText,
                                              ),
                                            ),
                                          ),
                                          if (username.isNotEmpty)
                                            Text(
                                              '@$username',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: secondaryText,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          _pill(
                                            req.senderRole,
                                            lavender,
                                            purple,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.link_rounded,
                                            size: 14,
                                            color: secondaryText,
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Sent you a connection request',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryText,
                                            ),
                                          ),
                                          if (timeStr.isNotEmpty) ...[
                                            const Text(
                                              ' • ',
                                              style: TextStyle(
                                                color: secondaryText,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              timeStr,
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
                                const SizedBox(width: 12),
                                FilledButton(
                                  onPressed: () async {
                                    try {
                                      await ConnectionRequestService.acceptRequest(
                                        requestId: req.requestId,
                                        receiverUid: user.uid,
                                      );
                                      _showMessage('Connection accepted!');
                                    } catch (e) {
                                      _showMessage(
                                          'Error accepting request: $e');
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await ConnectionRequestService.rejectRequest(
                                        requestId: req.requestId,
                                        receiverUid: user.uid,
                                      );
                                      _showMessage('Request declined.');
                                    } catch (e) {
                                      _showMessage(
                                          'Error declining request: $e');
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: secondaryText,
                                    side: BorderSide(
                                      color:
                                          secondaryText.withValues(alpha: 0.3),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // 2. CONVERSATIONS LIST
            StreamBuilder<List<ChatConversation>>(
              stream: ChatService.watchUserConversations(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: purple,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 48,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: Color(0xFFECE7F4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              size: 38,
                              color: purple,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No conversations yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Connect with other creators in Explore Profiles to start chatting here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: secondaryText, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                selectedSidebarItem = 'Home';
                              });
                            },
                            icon: const Icon(Icons.explore_outlined, size: 16),
                            label: const Text('Explore Creators'),
                            style: FilledButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: purple.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: lavender,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: purple,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Conversations',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: primaryText,
                                ),
                              ),
                            ],
                          ),
                          _pill('${chats.length} Active', lavender, purple),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: chats.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final other = chat.getOtherParticipant(user.uid);
                          final otherName = other['name'] ?? 'Creator';
                          final otherPhoto = other['photo'] ?? '';
                          final otherRole = other['role'] ?? 'Creator';
                          final otherUsername = other['username'] ?? '';
                          final otherUid = (other['uid'] ?? '').toString();
                          final timeStr = _formatChatTime(chat.lastMessageTime);

                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: otherUid.isNotEmpty
                                ? FirebaseFirestore.instance
                                    .collection('Profile_Data')
                                    .doc(otherUid)
                                    .snapshots()
                                : null,
                            builder: (context, profileSnap) {
                              final profile = profileSnap.data?.data();
                              final realName = (profile?['fullName'] ??
                                      profile?['name'] ??
                                      '')
                                  .toString()
                                  .trim();
                              final realPhoto = (profile?['photo'] ??
                                      profile?['profilePhotoUrl'] ??
                                      '')
                                  .toString()
                                  .trim();
                              final realRole =
                                  (profile?['role'] ?? '').toString().trim();
                              final realUsername =
                                  (profile?['username'] ?? '').toString().trim();

                              final resolvedName = realName.isNotEmpty
                                  ? realName
                                  : (otherName != 'Creator'
                                      ? otherName
                                      : 'Creator');
                              final resolvedPhoto = realPhoto.isNotEmpty
                                  ? realPhoto
                                  : otherPhoto;
                              final resolvedRole = realRole.isNotEmpty
                                  ? realRole
                                  : otherRole;
                              final resolvedUsername = realUsername.isNotEmpty
                                  ? realUsername
                                  : otherUsername;

                              final hasMessage = chat.lastMessage.isNotEmpty;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatConversationPage(
                                          chatId: chat.chatId,
                                          otherUserUid: otherUid,
                                          otherUserName: resolvedName,
                                          otherUserPhoto: resolvedPhoto,
                                          otherUserRole: resolvedRole,
                                          otherUserUsername: resolvedUsername,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF9F8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFECE7F4),
                                        width: 1.1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: lavender,
                                          backgroundImage:
                                              resolvedPhoto.isNotEmpty
                                                  ? NetworkImage(resolvedPhoto)
                                                  : null,
                                          child: resolvedPhoto.isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  color: purple,
                                                  size: 24,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      resolvedName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: primaryText,
                                                      ),
                                                    ),
                                                  ),
                                                  if (resolvedUsername
                                                      .isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '@$resolvedUsername',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: secondaryText,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(width: 8),
                                                  _pill(
                                                    resolvedRole,
                                                    const Color(0xFFF0E5DE),
                                                    purple,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  Icon(
                                                    hasMessage
                                                        ? Icons
                                                            .chat_bubble_outline_rounded
                                                        : Icons
                                                            .waving_hand_outlined,
                                                    size: 13,
                                                    color: hasMessage
                                                        ? secondaryText
                                                        : purple,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      hasMessage
                                                          ? chat.lastMessage
                                                          : 'Connected! Say hello.',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: hasMessage
                                                            ? secondaryText
                                                            : purple,
                                                        fontWeight: hasMessage
                                                            ? FontWeight.w500
                                                            : FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (timeStr.isNotEmpty)
                                              Text(
                                                timeStr,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: secondaryText,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: lavender.withValues(
                                                    alpha: 0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                color: purple,
                                                size: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SETTINGS
  // ------------------------------------------------------------

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading('Settings', 'Manage your account and preferences.'),

        _settingsCard(
          title: 'Account',
          icon: Icons.manage_accounts_outlined,
          children: [
            _settingTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit profile',
              subtitle: 'Update your personal and professional details',
              onTap: _openProfile,
            ),

            _settingTile(
              icon: Icons.email_outlined,
              title: 'Email address',
              subtitle: currentUser?.email ?? 'No email available',
              onTap: () {
                _showMessage(currentUser?.email ?? 'No email available.');
              },
            ),

            _settingTile(
              icon: Icons.lock_reset_outlined,
              title: 'Reset password',
              subtitle: 'Receive a password reset email',
              onTap: _resetPassword,
            ),
          ],
        ),

        _settingsCard(
          title: 'Preferences',
          icon: Icons.tune_rounded,
          children: [
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 5),
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: purple,
              ),
              title: const Text(
                'Notifications',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                _notificationError ??
                    (_savingNotification
                        ? 'Saving preference...'
                        : 'Manage your notification preference'),
                style: TextStyle(
                  color: _notificationError == null
                      ? secondaryText
                      : Colors.red,
                  fontSize: 12,
                ),
              ),
              value: notificationsEnabled,
              activeThumbColor: purple,
              onChanged: _savingNotification
                  ? null
                  : _saveNotificationPreference,
            ),

            _settingTile(
              icon: Icons.info_outline_rounded,
              title: 'App information',
              subtitle: 'CreatorConnect · Version 1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'CreatorConnect',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'A community for creative work.',
                );
              },
            ),
          ],
        ),

        _settingsCard(
          title: 'Security',
          icon: Icons.shield_outlined,
          children: [
            _settingTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              subtitle: 'Sign out from this device',
              color: Colors.redAccent,
              onTap: _logout,
            ),
          ],
        ),
      ],
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return _glassPanel(
      margin: const EdgeInsets.only(bottom: 16),
      radius: 21,
      color: const Color(0xEAF9F6F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: lavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: purple),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE9E3E9)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = purple,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color == purple ? primaryText : color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: secondaryText, fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: secondaryText),
      onTap: onTap,
    );
  }
}
