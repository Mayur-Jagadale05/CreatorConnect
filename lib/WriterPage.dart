// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Writerpage extends StatefulWidget {
  const Writerpage({super.key});

  @override
  State<Writerpage> createState() => _WriterpageState();
}

class _WriterpageState extends State<Writerpage> {
  static const Color purple = Color(0xFF35132F);
  static const Color marigold = Color(0xFFF4C95D);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);
  static const Color borderColor = Color(0xCCFFFFFF);

  String selectedTab = 'Influencer';
  String selectedSidebarItem = 'Home';
  bool notificationsEnabled = true;

  final TextEditingController searchController = TextEditingController();
  final GlobalKey _searchKey = GlobalKey();
  final PageController _heroPageController = PageController();
  int _heroPageIndex = 0;
  final List<String> _heroImages = const [
    'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=1400',
    'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1400',
    'https://images.unsplash.com/photo-1497215842964-222b430dc094?w=1400',
  ];
  final List<String> tabs = const [
    'Influencer',
    'Editor',
    'Writer',
    'Education',
  ];

  final List<Map<String, dynamic>> creators = const [
    {
      'name': 'Maya Carter',
      'username': 'mayacarter',
      'role': 'Influencer',
      'category': 'Influencer',
      'bio': 'Lifestyle and travel storyteller.',
      'location': 'New York',
      'verified': true,
    },
    {
      'name': 'Noah Williams',
      'username': 'noahwrites',
      'role': 'Writer',
      'category': 'Writer',
      'bio': 'Writer focused on culture and technology.',
      'location': 'London',
      'verified': false,
    },
    {
      'name': 'Ava Thompson',
      'username': 'avacreates',
      'role': 'Editor',
      'category': 'Editor',
      'bio': 'Video editor and visual storyteller.',
      'location': 'Los Angeles',
      'verified': true,
    },
    {
      'name': 'Liam Patel',
      'username': 'learnwithliam',
      'role': 'Education',
      'category': 'Education',
      'bio': 'Educator creating accessible learning content.',
      'location': 'Toronto',
      'verified': false,
    },
  ];

  /*
  User? get currentUser => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _myUserDocument {
    final user = currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }
  */

  @override
  void initState() {
    super.initState();
    // Firebase-backed settings are disabled.
  }

  @override
  void dispose() {
    searchController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  void _advanceHeroBackground() {
    if (!_heroPageController.hasClients || _heroImages.isEmpty) return;
    final nextIndex = (_heroPageIndex + 1) % _heroImages.length;
    _heroPageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSearch() {
    final searchContext = _searchKey.currentContext;
    if (searchContext == null) return;
    Scrollable.ensureVisible(
      searchContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /*
  Future<void> _loadNotificationPreference() async {
    final ref = _myUserDocument;
    if (ref == null) return;
    try {
      final snapshot = await ref.get();
      if (!mounted) return;
      setState(() {
        notificationsEnabled =
            snapshot.data()?['notificationsEnabled'] as bool? ?? true;
      });
    } catch (e) {
      debugPrint('Could not load notification preference: $e');
    }
  }
  */

  void _saveNotificationPreference(bool value) {
    setState(() => notificationsEnabled = value);
    _showMessage('Preference updated for this session only.');
  }

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

  void _selectSidebarItem(String item) {
    setState(() => selectedSidebarItem = item);
  }

  void _openProfile() {
    _showMessage('Profile editing is unavailable while Firebase is disabled.');
  }

  void _resetPassword() {
    _showMessage('Password reset is unavailable while Firebase is disabled.');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: pageBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to sign out of CreatorConnect?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _showMessage('Sign-out is unavailable while Firebase is disabled.');
  }

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
          Positioned.fill(
            child: ColoredBox(color: pageBg.withValues(alpha: 0.48)),
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
                                padding: const EdgeInsets.all(12),
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
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _buildSelectedPage(),
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

  Widget _buildTopBar() {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E0E6)),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'CreatorConnect',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: purple,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 650)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Text(
                'A COMMUNITY FOR CREATIVE WORK',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: secondaryText,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEDE5EB)),
            ),
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () => _showMessage(
                notificationsEnabled
                    ? 'In-app notification preference is enabled.'
                    : 'In-app notification preference is disabled.',
              ),
              icon: const Icon(Icons.notifications_none_rounded, color: purple),
            ),
          ),
        ],
      ),
    );
  }

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
    return _emptyPanel(
      'Profile details are unavailable while Firebase is disabled.',
    );

    /*
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
    */
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

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double radius = 18,
    Color color = const Color(0xDDF9F6F5),
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
                      setState(() => selectedTab = tab);
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
      key: _searchKey,
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
          hintText: 'Search creators...',
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
      final role = (creator['role'] ?? '').toString().toLowerCase();
      final category = (creator['category'] ?? '').toString().toLowerCase();
      final name = (creator['name'] ?? '').toString().toLowerCase();
      final username = (creator['username'] ?? '').toString().toLowerCase();
      final bio = (creator['bio'] ?? '').toString().toLowerCase();
      final location = (creator['location'] ?? '').toString().toLowerCase();

      final roleMatches =
          role == selectedTab.toLowerCase() ||
          category == selectedTab.toLowerCase();

      final searchMatches =
          query.isEmpty ||
          name.contains(query) ||
          username.contains(query) ||
          role.contains(query) ||
          category.contains(query) ||
          bio.contains(query) ||
          location.contains(query);

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

            if (filteredCreators.isEmpty)
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

                  return Container(
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
                            ],
                          ),
                        );

                        final avatar = CircleAvatar(
                          radius: 27,
                          backgroundColor: lavender,
                          backgroundImage: photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: purple,
                                  size: 28,
                                )
                              : null,
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
              subtitle: 'Unavailable while Firebase is disabled',
              onTap: () {
                _showMessage(
                  'Email is unavailable while Firebase is disabled.',
                );
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
              subtitle: const Text(
                'Manage your notification preference for this session',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
              value: notificationsEnabled,
              activeThumbColor: purple,
              onChanged: _saveNotificationPreference,
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