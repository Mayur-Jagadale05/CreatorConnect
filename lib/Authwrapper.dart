import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:creatorconnect/BusinessmanPage.dart';
import 'package:creatorconnect/EditorPage.dart';
import 'package:creatorconnect/InfluencerPage.dart';
import 'package:creatorconnect/Loginpage.dart';
import 'package:creatorconnect/WriterPage.dart';
import 'package:creatorconnect/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Authwrapper extends StatelessWidget {
  const Authwrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        return ValueListenableBuilder<bool>(
          valueListenable: LoginStatus.isCheckingRole,
          builder: (context, checkingRole, child) {
            // Keep the login screen visible during role verification.
            if (checkingRole) {
              return const Loginpage();
            }

            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingView();
            }

            final user = authSnapshot.data;

            if (user == null) {
              return const Loginpage();
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              key: ValueKey(user.uid),
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const _AuthLoadingView();
                }

                if (userSnapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text('Unable to load your profile.')),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Scaffold(
                    body: Center(
                      child: Text('User profile not found. Please register.'),
                    ),
                  );
                }

                final data = userSnapshot.data!.data();
                final role = data?['role']?.toString().trim().toLowerCase();

                switch (role) {
                  case 'businessman':
                    return Businessmanpage();

                  case 'influencer':
                    return InfluencerPage();

                  case 'editor':
                    return EditorPage();

                  case 'writer':
                    return Writerpage();

                  default:
                    return const Scaffold(
                      body: Center(
                        child: Text(
                          'Invalid role in Firebase. Please contact support.',
                        ),
                      ),
                    );
                }
              },
            );
          },
        );
      },
    );
  }
}

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
