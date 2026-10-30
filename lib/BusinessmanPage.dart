import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:creatorconnect/ProfileDetailsPage.dart';

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
  int _heroPageIndex = 0;

  List<Map<String, dynamic>> creators = [];

  final List<String> tabs = const [
    'Influencer',
    'Writer',
    'Editor',
    'Education',
  ];

  static const List<String> _heroImages = [
    'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1800&q=85',
    'https://images.unsplash.com/photo-1492724441997-5dc865305da7?auto=format&fit=crop&w=1800&q=85',
    'https://images.unsplash.com/photo-1524758631624-e2822e304c36?auto=format&fit=crop&w=1800&q=85',
    'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=1800&q=85',
  ];

  User? get currentUser => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _myUserDocument {
    final user = currentUser;
    if (user == null) return null;

    // Keep account settings and the profile summary tied to the signed-in user.
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  @override
  void initState() {
    super.initState();

    _loadNotificationPreference();
    _listenToCreators();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && selectedSidebarItem == 'Home') {
        _advanceHeroBackground();
      }
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _creatorsSubscription?.cancel();
    _heroPageController.dispose();
    _dashboardScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _listenToCreators() {
    // Subscribe to creator accounts so the dashboard stays current as profiles change.
    _creatorsSubscription = FirebaseFirestore.instance
        .collection('users')
        .where(
          'role',
          whereIn: const ['Influencer', 'Writer', 'Editor', 'Video Editor'],
        )
        .snapshots()
        .listen(
          (snapshot) {
            final uid = currentUser?.uid;
            final profiles = snapshot.docs
                .where((doc) {
                  if (doc.id == uid || doc.data()['uid'] == uid) return false;
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
    final ref = _myUserDocument;
    if (ref == null) return;

    try {
      // The preference is stored on the signed-in user's Firestore document.
      final snapshot = await ref.get();

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
    final ref = _myUserDocument;

    if (ref == null) {
      _showMessage('Please log in to change settings.');
      return;
    }

    setState(() {
      _savingNotification = true;
      _notificationError = null;
    });

    try {
      // Merge prevents this settings update from overwriting other profile fields.
      await ref.set({
        'notificationsEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
  }

  Future<void> _openCreatorProfile(String uid) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileDetailsPage()),
    );
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
    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/images/creatorconnect_background.png'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
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
                      final compact = constraints.maxWidth < 760;

                      if (compact) {
                        return Column(
                          children: [
                            _buildCompactSidebar(),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _dashboardScrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  28,
                                ),
                                child: _buildSelectedPage(),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSidebar(),

                          Expanded(
                            child: SingleChildScrollView(
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

  Widget _buildCompactSidebar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xDDF9F6F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _sidebarItems(compact: true)),
      ),
    );
  }

  List<Widget> _sidebarItems({bool compact = false}) {
    const items = <({String label, IconData icon})>[
      (label: 'Home', icon: Icons.home_rounded),
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
            leading: Icon(item.icon, size: 22),
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

  // ------------------------------------------------------------
  // PROFILE SUMMARY
  // ------------------------------------------------------------

  Widget _buildProfileSummary() {
    final ref = _myUserDocument;

    if (ref == null) {
      return _emptyPanel('Please log in to view your profile.');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyPanel('Unable to load your profile.');
        }

        if (!snapshot.hasData) {
          return _glassPanel(
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(color: purple, strokeWidth: 2),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};

        final name = (data['fullName'] ?? data['username'] ?? 'Your profile')
            .toString();

        final username = (data['username'] ?? '').toString();

        final role = (data['role'] ?? 'Businessman').toString();

        final bio = (data['bio'] ?? '').toString();

        final photo = (data['profilePhotoUrl'] ?? '').toString();

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

    final filteredCreators = creators.where((creator) {
      final role = (creator['role'] ?? '').toString().trim().toLowerCase();
      final name = (creator['name'] ?? '').toString().toLowerCase();

      final selectedRole = selectedTab?.toLowerCase();
      final roleMatches = selectedRole == null
          ? true
          : selectedRole == 'education'
          ? (creator['category'] ?? '').toString().trim().toLowerCase() ==
                selectedRole
          : role == selectedRole ||
                (selectedRole == 'editor' && role == 'video editor');

      final searchMatches = query.isEmpty || name.contains(query);

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
                const Expanded(
                  child: Text(
                    'Explore Profiles',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: purple,
                    ),
                  ),
                ),

                _pill(
                  '${filteredCreators.length} matches',
                  const Color(0xFFF0E5DE),
                  purple,
                ),
              ],
            ),

            const SizedBox(height: 6),

            const Text(
              'Discover creative people for your next project.',
              style: TextStyle(fontSize: 12, color: secondaryText),
            ),

            const SizedBox(height: 18),

            if (_loadingCreators)
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

                  final name = (item['name'] ?? 'Creator').toString();
                  final username = (item['username'] ?? '').toString();
                  final role = (item['role'] ?? 'Creator').toString();
                  final photo = (item['photo'] ?? '').toString();
                  final location = (item['location'] ?? '').toString();
                  final bio = (item['bio'] ?? '').toString();
                  final hasEducationVideo = (item['educationVideoUrl'] ?? '')
                      .toString()
                      .isNotEmpty;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => _openCreatorProfile(item['uid'].toString()),
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
                                          name,
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
                                    role,
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

                                  if (bio.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      bio,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: secondaryText,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  if (hasEducationVideo) ...[
                                    const SizedBox(height: 7),
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.play_circle_outline_rounded,
                                          size: 15,
                                          color: purple,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Education video',
                                          style: TextStyle(
                                            color: purple,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
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

                            final messageButton = OutlinedButton(
                              onPressed: () {
                                _showMessage(
                                  'Messaging for $name is not connected yet.',
                                );
                              },
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
                              child: const Text(
                                'Message',
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

  Widget _buildMyPosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading('My Posts', 'Create and manage your creative content.'),

        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              _showMessage('Post creation has not been connected yet.');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Post'),
            style: FilledButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          ),
        ),

        const SizedBox(height: 18),

        _emptyPanel('No posts yet. Your published content will appear here.'),
      ],
    );
  }

  // ------------------------------------------------------------
  // MESSAGES
  // ------------------------------------------------------------

  Widget _buildMessages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          'Messages',
          'Connect with creators, editors and collaborators.',
        ),

        _glassPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 45,
                    color: purple.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your conversations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your messages will appear here once chat is connected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
