import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;

  Future<void> handleAuth() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        final userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        final user = userCredential.user;

        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text("Email not verified"),
                  content: const Text(
                    "Please verify your email and try again.",
                  ),
                  actions: [
                    TextButton(
                      child: const Text("OK"),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
          );
          return;
        }

        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .get();

        if (!userDoc.exists) {
          final randomId = Random().nextInt(9000) + 1000;
          final fcmToken = await FirebaseMessaging.instance.getToken();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'username': 'user-$randomId',
                'avatarUrl': '',
                'fcmToken': fcmToken ?? '',
              });
        }
      } else {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        final user = userCredential.user;

        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Verification email sent. Please check your inbox.",
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = "An error occurred";

      if (isLogin) {
        errorMsg = "Invalid email or password.";
      } else {
        if (e.code == 'email-already-in-use') {
          errorMsg = "This email is already in use.";
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void openForgotPasswordDialog() {
    showDialog(context: context, builder: (_) => const ForgotPasswordDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ArtSpace',
                  style: GoogleFonts.lobster(
                    fontSize: 54,
                    fontWeight: FontWeight.w400,
                    color: Colors.deepPurple,
                    shadows: [
                      Shadow(
                        offset: Offset(1.5, 1.5),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  isLogin ? "Login" : "Register",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin ? "Login to continue" : "Register to get started",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child:
                              isLoading
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : ElevatedButton(
                                    onPressed: handleAuth,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      isLogin ? "Login" : "Register",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? "Don't have an account? Register"
                        : "Already have an account? Login",
                  ),
                ),
                TextButton(
                  onPressed: openForgotPasswordDialog,
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final emailController = TextEditingController();
  bool isSending = false;

  Future<void> sendResetEmail() async {
    setState(() => isSending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Reset email sent.")));
      }
    } on FirebaseAuthException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("An error occurred")));
      }
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reset Password"),
      content: TextField(
        controller: emailController,
        decoration: const InputDecoration(labelText: "Your Email"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: isSending ? null : sendResetEmail,
          child:
              isSending
                  ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text("Send"),
        ),
      ],
    );
  }
}
