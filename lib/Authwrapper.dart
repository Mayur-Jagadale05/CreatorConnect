import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/BusinessmanPage.dart';
import 'package:creatorconnect/EditorPage.dart';
import 'package:creatorconnect/InfluencerPage.dart';
import 'package:creatorconnect/Loginpage.dart';
import 'package:creatorconnect/WriterPage.dart';
import 'package:creatorconnect/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Master Authentication Wrapper for CreatorConnect
/// Listens to FirebaseAuth authStateChanges and uses the Firestore user document
/// as the SINGLE SOURCE OF TRUTH for role-based dashboard navigation.
class Authwrapper extends StatefulWidget {
  const Authwrapper({super.key});

  @override
  State<Authwrapper> createState() => _AuthwrapperState();
}

class _AuthwrapperState extends State<Authwrapper> {
  int _retryNonce = 0;

  void _retry() {
    setState(() {
      _retryNonce++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        return ValueListenableBuilder<bool>(
          valueListenable: LoginStatus.isCheckingRole,
          builder: (context, checkingRole, child) {
            // Keep Loginpage active while Loginpage.login() verifies Firestore credentials
            if (checkingRole) {
              return const Loginpage();
            }

            // Waiting for initial auth state
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingView();
            }

            final user = authSnapshot.data;

            // User is signed out -> Present Loginpage
            if (user == null) {
              return const Loginpage();
            }

            // User is signed in -> Query Firestore Profile_Data/{uid} for the true stored role
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              key: ValueKey('${user.uid}_$_retryNonce'),
              future: _fetchUserDocument(user.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const _AuthLoadingView();
                }

                if (userSnapshot.hasError) {
                  return _AuthErrorView(
                    title: 'Connection Error',
                    message:
                        'Unable to load your profile: ${userSnapshot.error}',
                    onRetry: _retry,
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const _AuthErrorView(
                    title: 'Profile Not Found',
                    message:
                        'Your user profile was not found in Firestore. Please register or contact support.',
                  );
                }

                final data = userSnapshot.data!.data();
                final rawRole = data?['role']?.toString().trim();

                if (rawRole == null || rawRole.isEmpty) {
                  return const _AuthErrorView(
                    title: 'Role Missing',
                    message:
                        'No role is assigned to your account in Firestore. Please contact support.',
                  );
                }

                // Strictly compare and match against the 4 official roles:
                // 1. Influencer -> InfluencerPage()
                // 2. Editor -> EditorPage()
                // 3. Writer -> Writerpage()
                // 4. Businessman -> Businessmanpage()
                // Note: 'Business' is strictly rejected and NOT treated as 'Businessman'.
                final normalizedRole = rawRole.toLowerCase();

                switch (normalizedRole) {
                  case 'influencer':
                    return const InfluencerPage();

                  case 'editor':
                    return const EditorPage();

                  case 'writer':
                    return const Writerpage();

                  case 'businessman':
                    return const Businessmanpage();

                  default:
                    return _AuthErrorView(
                      title: 'Invalid Role in Firestore',
                      message:
                          'Your account has role "$rawRole", which is not a valid CreatorConnect role.\n\n'
                          'Allowed roles: Influencer, Editor, Writer, Businessman.',
                    );
                }
              },
            );
          },
        );
      },
    );
  }

  /// Fetches the user document from 'Profile_Data' with fallback to legacy 'users'
  static Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserDocument(
    String uid,
  ) async {
    // Ensure auth token is valid and fresh
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      try {
        await currentUser.getIdToken(true);
      } catch (_) {}
    }

    DocumentSnapshot<Map<String, dynamic>>? profileDoc;
    Object? profileError;

    // 1. Check primary 'Profile_Data' collection first
    try {
      profileDoc = await FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(uid)
          .get();

      if (profileDoc.exists &&
          profileDoc.data() != null &&
          profileDoc.data()?['role'] != null) {
        return profileDoc;
      }
    } catch (e) {
      profileError = e;
      debugPrint('Error reading Profile_Data collection: $e');
    }

    // 2. Fallback check for legacy accounts previously in 'users'
    try {
      final legacyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (legacyDoc.exists && legacyDoc.data() != null) {
        // Auto-migrate to 'Profile_Data' collection
        try {
          await FirebaseFirestore.instance
              .collection('Profile_Data')
              .doc(uid)
              .set(legacyDoc.data()!, SetOptions(merge: true));
        } catch (_) {}

        return legacyDoc;
      }
    } catch (e) {
      debugPrint('Error reading legacy users collection: $e');
    }

    if (profileDoc != null) {
      return profileDoc;
    }

    if (profileError != null) {
      throw profileError;
    }

    return await FirebaseFirestore.instance
        .collection('Profile_Data')
        .doc(uid)
        .get();
  }
}

/// Loading view during auth verification
class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}

/// Dedicated error screen when role or profile is missing/invalid.
/// Provides a clear explanation and an explicit "Log Out" button
/// so the user is never trapped in an unrecoverable state.
class _AuthErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _AuthErrorView({
    required this.title,
    required this.message,
    this.onRetry,
  });

  static const Color primaryBurgundy = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color darkInk = Color(0xFF302A33);
  static const Color mutedText = Color(0xFF827985);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: primaryBurgundy.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 44,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: darkInk,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: mutedText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (onRetry != null) ...[
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBurgundy,
                        side: const BorderSide(color: primaryBurgundy),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Log Out & Return to Login'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBurgundy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
