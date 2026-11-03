import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:creatorconnect/Loginpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Registerpage extends StatefulWidget {
  const Registerpage({super.key});

  @override
  State<Registerpage> createState() => _RegisteraccountState();
}

class _RegisteraccountState extends State<Registerpage> {
  // Password visibility
  bool _obscureConfirmPassword = true;

  // Loading state
  bool isLoading = false;

  // Form validation key
  final _formkey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController fullnamecontroller = TextEditingController();

  final TextEditingController emailcontroller = TextEditingController();

  final TextEditingController passwordcontroller = TextEditingController();

  final TextEditingController confirmpasswordcontroller =
      TextEditingController();

  // Selected role
  String? selectedRole;

  // CreatorConnect theme colors
  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color borderColor = Color(0xCCFFFFFF);
  static const Color subtitleColor = Color(0xFF827985);

  // --------------------------------------------------
  // CREATE ACCOUNT
  // --------------------------------------------------

  Future<void> createaccount() async {
    if (isLoading) return;

    final formState = _formkey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final role = selectedRole;

    if (role == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // STEP 1: Create Firebase Authentication account

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailcontroller.text.trim(),
            password: passwordcontroller.text.trim(),
          );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Firebase user not found.');
      }

      final String uid = user.uid;

      // STEP 2: Save user information in Firestore Profile_Data collection
      final userData = {
        'uid': uid,
        'email': emailcontroller.text.trim(),
        'fullName': fullnamecontroller.text.trim(),
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final DocumentReference profileDocument = FirebaseFirestore.instance
          .collection('Profile_Data')
          .doc(uid);

      await profileDocument.set(userData, SetOptions(merge: true));

      // STEP 3: Verify Firestore document in Profile_Data collection
      final DocumentSnapshot savedDocument = await profileDocument.get();

      if (!savedDocument.exists) {
        throw Exception('User data was not saved in Firestore.');
      }

      // Explicitly sign out so user returns to clean Login state
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // STEP 4: Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please log in.'),
          backgroundColor: purple,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // STEP 5: Navigate to Login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Loginpage()),
      );
    }
    // Firebase Authentication errors
    on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;

        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          errorMessage = 'Password is too weak.';
          break;

        case 'operation-not-allowed':
          errorMessage = 'Email/password authentication is not enabled.';
          break;

        case 'network-request-failed':
          errorMessage = 'Please check your internet connection.';
          break;

        default:
          errorMessage = e.message ?? 'Registration failed: ${e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // Firestore errors
    on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestore Error: ${e.code}\n${e.message ?? ''}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }
    // Other errors
    catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // FIELD DECORATION
  // --------------------------------------------------

  InputDecoration fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: purple),
      filled: true,
      fillColor: pageBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: purple, width: 1.5),
      ),
    );
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    fullnamecontroller.dispose();
    emailcontroller.dispose();
    passwordcontroller.dispose();
    confirmpasswordcontroller.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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

          Positioned.fill(
            child: ColoredBox(color: pageBg.withValues(alpha: 0.48)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(32),
                    child: Form(key: _formkey, child: _buildRegistrationForm()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // REGISTRATION FORM
  // --------------------------------------------------

  Widget _buildRegistrationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          height: 65,
          width: 65,
          decoration: BoxDecoration(
            color: purple,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),

        const SizedBox(height: 15),

        // App name
        const Text(
          'CreatorConnect',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: purple,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Create your account and connect!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: subtitleColor),
        ),

        const SizedBox(height: 25),

        // Full Name
        TextFormField(
          controller: fullnamecontroller,
          textCapitalization: TextCapitalization.words,
          enabled: !isLoading,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
          decoration: fieldDecoration(
            label: 'Full Name',
            hint: 'Enter your Full name',
            icon: Icons.person_outline,
          ),
        ),

        const SizedBox(height: 18),

        // Email
        TextFormField(
          controller: emailcontroller,
          keyboardType: TextInputType.emailAddress,
          enabled: !isLoading,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }

            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
              return 'Enter a valid email';
            }

            return null;
          },
          decoration: fieldDecoration(
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
          ),
        ),

        const SizedBox(height: 18),

        // Password
        TextFormField(
          controller: passwordcontroller,
          obscureText: true,
          enabled: !isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }

            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }

            return null;
          },
          decoration: fieldDecoration(
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline,
          ),
        ),

        const SizedBox(height: 18),

        // Confirm Password
        TextFormField(
          controller: confirmpasswordcontroller,
          obscureText: _obscureConfirmPassword,
          enabled: !isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }

            if (value != passwordcontroller.text) {
              return 'Passwords do not match';
            }

            return null;
          },
          decoration:
              fieldDecoration(
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                icon: Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmPassword
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: subtitleColor,
                  ),
                ),
              ),
        ),

        const SizedBox(height: 25),

        // Role dropdown
        DropdownButtonFormField<String>(
          initialValue: selectedRole,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'Businessman', child: Text('Businessman')),
            DropdownMenuItem(value: 'Influencer', child: Text('Influencer')),
            DropdownMenuItem(value: 'Editor', child: Text('Editor')),
            DropdownMenuItem(value: 'Writer', child: Text('Writer')),
          ],
          onChanged: isLoading
              ? null
              : (value) {
                  setState(() {
                    selectedRole = value;
                  });
                },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your role';
            }
            return null;
          },
          decoration: fieldDecoration(
            label: 'Enter your role',
            hint: 'Select your role',
            icon: Icons.work_outline,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          iconEnabledColor: purple,
        ),

        const SizedBox(height: 18),

        // Create Account Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : createaccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: purple.withValues(alpha: 0.6),
              elevation: 0,
              shadowColor: purple.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 23,
                    width: 23,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Login Navigation
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(color: subtitleColor),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Loginpage(),
                        ),
                      );
                    },
              child: const Text(
                'Login',
                style: TextStyle(color: purple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------
// GLASS PANEL
// --------------------------------------------------

class GlassPanel extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const GlassPanel({super.key, this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF35132F).withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xCCFFFFFF), width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
