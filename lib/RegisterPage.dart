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
  // Password visibility toggles
  bool _obscureConfirmPassword = true;

  // Form validation key
  final _formkey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController fullnamecontroller = TextEditingController();
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  final TextEditingController confirmpasswordcontroller =
      TextEditingController();

  // Selected user role
  String? selectedRole;

  // CreatorConnect theme colors
  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color borderColor = Color(0xCCFFFFFF);
  static const Color subtitleColor = Color(0xFF827985);

  // Create account using Firebase Authentication
  Future<void> createaccount() async {
    // Validate all form fields
    final formState = _formkey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final role = selectedRole;
    if (role == null) {
      return;
    }

    try {
      // Create a new Firebase Authentication account
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailcontroller.text.trim(),
            password: passwordcontroller.text.trim(),
          );

      // Get the unique Firebase user ID
      final user = userCredential.user;
      if (user == null) {
        throw StateError('Firebase did not return a user after registration.');
      }
      final uid = user.uid;

      // Save user details and selected role in Firestore
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "email": emailcontroller.text.trim(),
        "fullName": fullnamecontroller.text.trim(),
        "role": role,
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully"),
          backgroundColor: purple,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to Login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Loginpage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Handle Firebase authentication errors
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
        default:
          errorMessage = e.message ?? 'Registration failed.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Show a general error if registration fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Common decoration for all input fields
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

  // Release controllers when the page is removed
  @override
  void dispose() {
    fullnamecontroller.dispose();
    emailcontroller.dispose();
    passwordcontroller.dispose();
    confirmpasswordcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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

  Widget _buildRegistrationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // CreatorConnect logo
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
          "CreatorConnect",
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: purple,
          ),
        ),

        const SizedBox(height: 8),

        // Welcome message
        const Text(
          "Create your account and connect!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: subtitleColor),
        ),

        const SizedBox(height: 25),

        // First name field
        TextFormField(
          controller: fullnamecontroller,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Please enter your full name";
            }
            return null;
          },
          decoration: fieldDecoration(
            label: "Full Name",
            hint: "Enter your Full name",
            icon: Icons.person_outline,
          ),
        ),

        const SizedBox(height: 18),

        // Email field
        TextFormField(
          controller: emailcontroller,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Please enter your email";
            }

            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
              return "Enter a valid email";
            }

            return null;
          },
          decoration: fieldDecoration(
            label: "Email",
            hint: "Enter your email",
            icon: Icons.email_outlined,
          ),
        ),

        const SizedBox(height: 18),

        // Password field
        TextFormField(
          controller: passwordcontroller,
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your password";
            }

            if (value.length < 6) {
              return "Password must be at least 6 characters";
            }

            return null;
          },
          decoration: fieldDecoration(
            label: "Password",
            hint: "Enter your password",
            icon: Icons.lock_outline,
          ),
        ),

        const SizedBox(height: 18),

        // Confirm password field
        TextFormField(
          controller: confirmpasswordcontroller,
          obscureText: _obscureConfirmPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please confirm your password";
            }

            if (value != passwordcontroller.text) {
              return "Passwords do not match";
            }

            return null;
          },
          decoration:
              fieldDecoration(
                label: "Confirm Password",
                hint: "Re-enter your password",
                icon: Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmPassword
                      ? "Show password"
                      : "Hide password",
                  onPressed: () {
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
          onChanged: (value) {
            setState(() {
              selectedRole = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please select your role";
            }
            return null;
          },
          decoration: fieldDecoration(
            label: "Enter your role",
            hint: "Select your role",
            icon: Icons.work_outline,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          iconEnabledColor: purple,
        ),

        const SizedBox(height: 18),

        // Create account button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: createaccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: purple.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              "Create Account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Navigate to Login page
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Already have an account?",
              style: TextStyle(color: subtitleColor),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Loginpage()),
                );
              },
              child: const Text(
                "Login",
                style: TextStyle(color: purple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const GlassPanel({
    super.key,
    this.padding,
    required this.child,
  });

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
              border: Border.all(
                color: const Color(0xCCFFFFFF),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
