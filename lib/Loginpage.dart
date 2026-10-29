import 'package:creatorconnect/RegisterPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginStatus {
  static final ValueNotifier<bool> isCheckingRole = ValueNotifier<bool>(false);
}

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  String? selectedRole;

  final _formkey = GlobalKey<FormState>();
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? errorMessage;

  static const Color purple = Color(0xFF35132F);
  static const Color pageBg = Color(0xFFF7F5F3);
  static const Color iceSilver = Color(0xFFF0EDF0);
  static const Color borderColor = Color(0xCCFFFFFF);
  static const Color secondaryText = Color(0xFF827985);

  Future<void> login() async {
    if (!_formkey.currentState!.validate()) return;

    if (selectedRole == null) {
      setState(() {
        errorMessage = 'Please select your role.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    LoginStatus.isCheckingRole.value = true;

    bool signedIn = false;
    bool roleVerified = false;

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailcontroller.text.trim(),
        password: passwordcontroller.text.trim(),
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Unable to log in. Please try again.');
      }

      signedIn = true;

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists) {
        throw Exception(
          'Your user profile was not found in Firebase Firestore.',
        );
      }

      final data = document.data();
      final savedRole = data?['role']?.toString().trim();

      if (savedRole == null || savedRole.isEmpty) {
        throw Exception('Role is missing from your Firebase profile.');
      }

      if (savedRole.toLowerCase() != selectedRole!.trim().toLowerCase()) {
        throw Exception(
          'Role mismatch! You selected "$selectedRole", '
          'but your Firebase role is "$savedRole".',
        );
      }

      roleVerified = true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        if (mounted) {
          setState(() {
            errorMessage = 'Invalid email or password.';
          });
        }
      } else if (e.code == 'wrong-password') {
        if (mounted) {
          setState(() {
            errorMessage = 'Incorrect password.';
          });
        }
      } else if (e.code == 'invalid-email') {
        if (mounted) {
          setState(() {
            errorMessage = 'Please enter a valid email address.';
          });
        }
      } else if (mounted) {
        setState(() {
          errorMessage = e.message ?? 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }

      if (mounted) {
        setState(() {
          errorMessage = message;
        });
      }
    } finally {
      if (signedIn && !roleVerified) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }

      LoginStatus.isCheckingRole.value = false;

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: purple),
      filled: true,
      fillColor: Colors.white.withOpacity(0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: iceSilver),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: purple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
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
            child: ColoredBox(color: pageBg.withOpacity(0.48)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.82),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formkey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              height: 82,
                              width: 82,
                              decoration: BoxDecoration(
                                color: purple,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(
                                Icons.people_alt_rounded,
                                color: Colors.white,
                                size: 43,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'CreatorConnect',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: purple,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Welcome back to your creative network.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: emailcontroller,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              'Email',
                              Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: passwordcontroller,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              'Password',
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: secondaryText,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Businessman',
                                child: Text('Businessman'),
                              ),
                              DropdownMenuItem(
                                value: 'Influencer',
                                child: Text('Influencer'),
                              ),
                              DropdownMenuItem(
                                value: 'Editor',
                                child: Text('Editor'),
                              ),
                              DropdownMenuItem(
                                value: 'Writer',
                                child: Text('Writer'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedRole = value;
                                errorMessage = null;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your role.';
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              'Select your role',
                              Icons.work_outline_rounded,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            iconEnabledColor: purple,
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                border: Border.all(
                                  color: const Color(0xFFE6A8A8),
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFF9B3B3B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFF873333),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 62,
                            child: FilledButton(
                              onPressed: isLoading ? null : login,
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 23,
                                      width: 23,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Registerpage(),
                                          ),
                                        );
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: purple,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
