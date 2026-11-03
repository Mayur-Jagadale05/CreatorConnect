import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/ChatConversationPage.dart';
import 'package:creatorconnect/ProfileDetailsPage.dart';
import 'package:creatorconnect/models/post_model.dart';
import 'package:creatorconnect/services/chat_service.dart';
import 'package:creatorconnect/services/connection_request_service.dart';
import 'package:creatorconnect/services/post_service.dart';
import 'package:creatorconnect/widgets/post_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileViewPage extends StatefulWidget {
  final String selectedUserUid;

  const ProfileViewPage({super.key, required this.selectedUserUid});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color lavender = Color(0xFFECE7F4);
  static const Color marigold = Color(0xFFF4C95D);
  static const Color primaryText = Color(0xFF302A33);
  static const Color secondaryText = Color(0xFF827985);
  static const Color iceSilver = Color(0xFFF0EDF0);

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _currentUserProfile;
  bool _isProcessingAction = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isOwnProfile => currentUser?.uid == widget.selectedUserUid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = widget.selectedUserUid.trim();
      if (uid.isEmpty) {
        throw Exception('Invalid user identifier.');
      }

      // Fetch target user's document from 'Profile_Data'
      var targetProfileDataDoc = await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(uid)
          .get();

      // Legacy fallback if not in Profile_Data
      if (!targetProfileDataDoc.exists || targetProfileDataDoc.data() == null) {
        final legacyUsersDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (legacyUsersDoc.exists && legacyUsersDoc.data() != null) {
          targetProfileDataDoc = legacyUsersDoc;
        }
      }

      if (!targetProfileDataDoc.exists) {
        throw Exception('User profile not found in CreatorConnect.');
      }

      final merged = <String, dynamic>{
        ...targetProfileDataDoc.data()!,
      };

      // Also fetch current user's profile info if not own profile
      final myUser = currentUser;
      if (myUser != null && myUser.uid != uid) {
        var myProfileDataDoc = await FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(myUser.uid)
            .get();

        if (!myProfileDataDoc.exists || myProfileDataDoc.data() == null) {
          final legacyMyDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(myUser.uid)
              .get();
          if (legacyMyDoc.exists && legacyMyDoc.data() != null) {
            myProfileDataDoc = legacyMyDoc;
          }
        }

        _currentUserProfile = <String, dynamic>{
          if (myProfileDataDoc.exists && myProfileDataDoc.data() != null)
            ...myProfileDataDoc.data()!,
        };
      }

      if (!mounted) return;
      setState(() {
        _userData = merged;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    String url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch URL: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
        }
      }
    }
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double radius = 22,
    Color color = const Color(0xDDF9F6F5),
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
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
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONNECT ACTION HANDLING
  // ------------------------------------------------------------

  Future<void> _sendConnectRequest() async {
    final user = currentUser;
    final target = _userData;
    if (user == null || target == null || _isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      var myProfile = _currentUserProfile ?? {};
      if (myProfile.isEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          myProfile = doc.data()!;
        }
      }

      var targetData = target;
      if (targetData.isEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(widget.selectedUserUid)
            .get();
        if (doc.exists && doc.data() != null) {
          targetData = doc.data()!;
        }
      }

      final myName =
          myProfile['fullName'] ??
          myProfile['name'] ??
          user.displayName ??
          'Creator';
      final myUsername = myProfile['username'] ?? '';
      final myEmail = user.email ?? myProfile['email'] ?? '';
      final myRole = myProfile['role'] ?? 'Creator';
      final myPhoto =
          myProfile['profilePhotoUrl'] ??
          myProfile['photo'] ??
          user.photoURL ??
          '';

      final targetName =
          targetData['fullName'] ?? targetData['name'] ?? 'Creator';
      final targetUsername = targetData['username'] ?? '';
      final targetRole = targetData['role'] ?? 'Creator';
      final targetPhoto =
          targetData['profilePhotoUrl'] ?? targetData['photo'] ?? '';

      await ConnectionRequestService.sendRequest(
        senderUid: user.uid,
        senderName: myName.toString(),
        senderUsername: myUsername.toString(),
        senderEmail: myEmail.toString(),
        senderRole: myRole.toString(),
        senderProfilePhoto: myPhoto.toString(),
        receiverUid: widget.selectedUserUid,
        receiverName: targetName.toString(),
        receiverUsername: targetUsername.toString(),
        receiverRole: targetRole.toString(),
        receiverProfilePhoto: targetPhoto.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _acceptConnectRequest() async {
    final user = currentUser;
    if (user == null || _isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      final docId = ConnectionRequestService.pairKey(
        user.uid,
        widget.selectedUserUid,
      );
      await ConnectionRequestService.acceptRequest(
        requestId: docId,
        receiverUid: user.uid,
      );

      // Also ensure chat conversation exists with real profiles
      var myProfile = _currentUserProfile ?? {};
      if (myProfile.isEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          myProfile = doc.data()!;
        }
      }
      var targetData = _userData ?? {};
      if (targetData.isEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Profile_Data')
            .doc(widget.selectedUserUid)
            .get();
        if (doc.exists && doc.data() != null) {
          targetData = doc.data()!;
        }
      }

      await ChatService.ensureConversation(
        uid1: user.uid,
        details1: myProfile,
        uid2: widget.selectedUserUid,
        details2: targetData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection request accepted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _openChat() {
    final user = currentUser;
    final target = _userData;
    if (user == null || target == null) return;

    final chatId = ChatService.getChatId(user.uid, widget.selectedUserUid);
    final targetName = (target['fullName'] ?? target['name'] ?? 'Creator')
        .toString();
    final targetPhoto = (target['profilePhotoUrl'] ?? target['photo'] ?? '')
        .toString();
    final targetRole = (target['role'] ?? 'Creator').toString();
    final targetUsername = (target['username'] ?? '').toString();

    // Ensure conversation exists in Firestore right away with both participants
    final myProfile = _currentUserProfile ?? {};
    ChatService.ensureConversation(
      uid1: user.uid,
      details1: myProfile,
      uid2: widget.selectedUserUid,
      details2: target,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          chatId: chatId,
          otherUserUid: widget.selectedUserUid,
          otherUserName: targetName,
          otherUserPhoto: targetPhoto,
          otherUserRole: targetRole,
          otherUserUsername: targetUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _buildTopBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: purple,
                            strokeWidth: 2,
                          ),
                        )
                      : _errorMessage != null
                      ? _buildErrorView()
                      : _buildProfileContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return _glassPanel(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: 20,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: purple),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Creator Profile',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: purple,
              ),
            ),
          ),
          if (isOwnProfile)
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
                );
                _loadProfile();
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile'),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Unable to load profile.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    final data = _userData ?? {};
    final name = (data['fullName'] ?? data['name'] ?? 'Creator').toString();
    final username = (data['username'] ?? '').toString();
    final role = (data['role'] ?? 'Creator').toString();
    final bio = (data['bio'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final experience = (data['experience'] ?? '').toString();
    final skills = (data['skills'] ?? '').toString();
    final photo = (data['profilePhotoUrl'] ?? data['photo'] ?? '').toString();
    final instagram = (data['instagramUrl'] ?? data['instagram'] ?? '')
        .toString();
    final youtube = (data['youtubeUrl'] ?? data['youtube'] ?? '').toString();
    final website = (data['websiteUrl'] ?? data['website'] ?? '').toString();
    final projects = (data['previousProjects'] ?? data['projects'] ?? '')
        .toString();
    final portfolioUrl = (data['portfolioUrl'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO HEADER CARD
              _buildHeroCard(
                name: name,
                username: username,
                role: role,
                photo: photo,
                location: location,
              ),
              const SizedBox(height: 16),

              // 2. BIO & INTRODUCTION
              if (bio.isNotEmpty) ...[
                _buildSectionCard(
                  title: _bioSectionTitleForRole(role),
                  icon: Icons.person_outline_rounded,
                  child: Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 14,
                      color: primaryText,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. EXPERTISE & SKILLS
              if (category.isNotEmpty ||
                  experience.isNotEmpty ||
                  skills.isNotEmpty) ...[
                _buildSectionCard(
                  title: 'Specialization & Skills',
                  icon: Icons.auto_awesome_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (category.isNotEmpty)
                            _pill(category, lavender, purple),
                          if (experience.isNotEmpty)
                            _pill(
                              experience,
                              const Color(0xFFF0E5DE),
                              primaryText,
                            ),
                        ],
                      ),
                      if (skills.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Skills',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: skills
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .map((skill) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: purple.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Text(
                                    skill,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: purple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. PORTFOLIO & WORK SAMPLES
              if (portfolioUrl.isNotEmpty) ...[
                _buildSectionCard(
                  title: _portfolioSectionTitleForRole(role),
                  icon: Icons.work_outline_rounded,
                  child: _buildPortfolioItemCard(portfolioUrl, role),
                ),
                const SizedBox(height: 16),
              ],

              // 5. PREVIOUS PROJECTS & COLLABORATIONS
              if (projects.isNotEmpty) ...[
                _buildSectionCard(
                  title: role.toLowerCase() == 'influencer'
                      ? 'Previous Collaborations'
                      : 'Previous Projects & Experience',
                  icon: Icons.assignment_outlined,
                  child: Text(
                    projects,
                    style: const TextStyle(
                      fontSize: 14,
                      color: primaryText,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6. SOCIAL & WEB CHANNELS
              if (instagram.isNotEmpty ||
                  youtube.isNotEmpty ||
                  website.isNotEmpty) ...[
                _buildSectionCard(
                  title: 'Social & Web Profiles',
                  icon: Icons.link_rounded,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (instagram.isNotEmpty)
                        _buildSocialButton(
                          label: 'Instagram',
                          icon: Icons.camera_alt_outlined,
                          url: instagram,
                        ),
                      if (youtube.isNotEmpty)
                        _buildSocialButton(
                          label: 'YouTube',
                          icon: Icons.play_arrow_rounded,
                          url: youtube,
                        ),
                      if (website.isNotEmpty)
                        _buildSocialButton(
                          label: 'Website / Link',
                          icon: Icons.language_rounded,
                          url: website,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 7. POSTS & ROLE-BASED CREATIVE WORK
              _buildPostsSection(role, name),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUB-SECTIONS
  // ------------------------------------------------------------

  Widget _buildHeroCard({
    required String name,
    required String username,
    required String role,
    required String photo,
    required String location,
  }) {
    return _glassPanel(
      radius: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 580;

          final avatarAndInfo = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: purple.withValues(alpha: 0.65),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: compact ? 38 : 48,
                  backgroundColor: iceSilver,
                  backgroundImage: photo.isNotEmpty
                      ? NetworkImage(photo)
                      : null,
                  child: photo.isEmpty
                      ? const Icon(
                          Icons.person_outline_rounded,
                          color: purple,
                          size: 42,
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
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _pill(role, const Color(0xFFF0E5DE), purple),
                        StreamBuilder<int>(
                          stream: ConnectionRequestService.watchConnectionCount(
                            widget.selectedUserUid,
                          ),
                          builder: (context, countSnap) {
                            final count = countSnap.data ?? 0;
                            return _pill(
                              '$count Connections',
                              lavender,
                              purple,
                            );
                          },
                        ),
                        if (location.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final connectActionButton = _buildConnectActionButton();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                avatarAndInfo,
                const SizedBox(height: 18),
                connectActionButton,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: avatarAndInfo),
              const SizedBox(width: 16),
              connectActionButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectActionButton() {
    final user = currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (isOwnProfile) {
      return OutlinedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
          );
          _loadProfile();
        },
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Edit Profile'),
        style: OutlinedButton.styleFrom(
          foregroundColor: purple,
          side: const BorderSide(color: purple),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    return StreamBuilder<ConnectionStatus>(
      stream: ConnectionRequestService.watchConnectionStatus(
        user.uid,
        widget.selectedUserUid,
      ),
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectionStatus.none;

        if (_isProcessingAction) {
          return const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(color: purple, strokeWidth: 2),
          );
        }

        switch (status) {
          case ConnectionStatus.connected:
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: lavender,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: purple.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: purple, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Connected',
                        style: TextStyle(
                          color: purple,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message'),
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
            );

          case ConnectionStatus.pendingSent:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: secondaryText,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Request Sent',
                    style: TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );

          case ConnectionStatus.pendingReceived:
            return FilledButton.icon(
              onPressed: _acceptConnectRequest,
              icon: const Icon(Icons.how_to_reg_rounded, size: 17),
              label: const Text('Accept Request'),
              style: FilledButton.styleFrom(
                backgroundColor: marigold,
                foregroundColor: purple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );

          case ConnectionStatus.rejected:
          case ConnectionStatus.none:
            return FilledButton.icon(
              onPressed: _sendConnectRequest,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
              label: const Text('Connect'),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            );
        }
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _glassPanel(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: purple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPortfolioItemCard(String url, String role) {
    final lower = url.toLowerCase();
    final isPdf = lower.contains('.pdf');
    final isVideo = lower.contains('.mp4') || lower.contains('.mov');
    final isImage =
        lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.webp');

    IconData fileIcon = Icons.insert_drive_file_outlined;
    String fileTypeLabel = 'Document';

    if (isPdf) {
      fileIcon = Icons.picture_as_pdf_outlined;
      fileTypeLabel = 'PDF Portfolio';
    } else if (isVideo) {
      fileIcon = Icons.video_file_outlined;
      fileTypeLabel = 'Video Sample';
    } else if (isImage) {
      fileIcon = Icons.image_outlined;
      fileTypeLabel = 'Image Sample';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(fileIcon, color: purple, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileTypeLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to view / download work sample',
                      style: TextStyle(fontSize: 11, color: secondaryText),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openUrl(url),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open'),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (isImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostsSection(String targetRole, String targetName) {
    final user = currentUser;
    final myProfile = _currentUserProfile ?? {};
    final myRole = (myProfile['role'] ?? '').toString().trim();
    final bool isOwnProfile = user?.uid == widget.selectedUserUid;

    return StreamBuilder<List<PostModel>>(
      stream: PostService.watchUserPosts(widget.selectedUserUid),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: purple, strokeWidth: 2),
              ),
            );
          }
          return _buildSectionCard(
            title: 'Posts & Work',
            icon: Icons.article_outlined,
            child: Text(
              isOwnProfile
                  ? 'You have not published any posts yet.'
                  : '$targetName has not published any posts yet.',
              style: const TextStyle(color: secondaryText, fontSize: 13),
            ),
          );
        }

        return _buildSectionCard(
          title: 'Posts & Work (${posts.length})',
          icon: Icons.article_outlined,
          child: Column(
            children: posts
                .map((post) => PostCard(
                      post: post,
                      isOwner: isOwnProfile,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required String url,
  }) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: purple.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: purple),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: purple,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_outward_rounded,
              size: 14,
              color: secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  String _bioSectionTitleForRole(String role) {
    switch (role.toLowerCase()) {
      case 'influencer':
        return 'Creator Introduction';
      case 'editor':
        return 'About the Editor';
      case 'writer':
        return 'About the Writer';
      case 'businessman':
        return 'Business Introduction';
      default:
        return 'About Me';
    }
  }

  String _portfolioSectionTitleForRole(String role) {
    switch (role.toLowerCase()) {
      case 'influencer':
        return 'Content Portfolio & Media';
      case 'editor':
        return 'Video Editing Portfolio & Samples';
      case 'writer':
        return 'Writing Samples & Documents';
      case 'businessman':
        return 'Work Samples & Project Documents';
      default:
        return 'Portfolio & Work Samples';
    }
  }
}
