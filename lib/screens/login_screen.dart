import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

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
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );
        final uid = userCredential.user!.uid;
        final randomId = Random().nextInt(9000) + 1000;

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'username': 'user-$randomId',
          'avatarUrl': '',
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? tr("error_occurred"))),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void openForgotPasswordDialog() {
    showDialog(context: context, builder: (_) => const ForgotPasswordDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? tr("login") : tr("register"))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: tr("email")),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: tr("password")),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: handleAuth,
                  child: Text(isLogin ? tr("login") : tr("register")),
                ),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(
                isLogin ? tr("no_account") : tr("already_have_account"),
              ),
            ),
            TextButton(
              onPressed: openForgotPasswordDialog,
              child: Text(tr("forgot_password")),
            ),
          ],
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
        ).showSnackBar(SnackBar(content: Text(tr("reset_email_sent"))));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? tr("error_occurred"))),
        );
      }
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr("reset_password")),
      content: TextField(
        controller: emailController,
        decoration: InputDecoration(labelText: tr("your_email")),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr("cancel")),
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
                  : Text(tr("send")),
        ),
      ],
    );
  }
}
