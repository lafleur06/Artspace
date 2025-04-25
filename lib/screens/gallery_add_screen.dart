import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class GalleryAddScreen extends StatefulWidget {
  const GalleryAddScreen({super.key});

  @override
  State<GalleryAddScreen> createState() => _GalleryAddScreenState();
}

class _GalleryAddScreenState extends State<GalleryAddScreen> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  bool isLoading = false;

  Future<void> addGallery() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("auth_error".tr());

      await FirebaseFirestore.instance.collection("galleries").add({
        "name": nameController.text.trim(),
        "description": descController.text.trim(),
        "ownerId": user.uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("gallery_added".tr())));

      nameController.clear();
      descController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${"error".tr()}: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("add_gallery".tr())),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "gallery_name".tr()),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: "description".tr()),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  onPressed: addGallery,
                  icon: const Icon(Icons.add),
                  label: Text("create_gallery".tr()),
                ),
          ],
        ),
      ),
    );
  }
}
