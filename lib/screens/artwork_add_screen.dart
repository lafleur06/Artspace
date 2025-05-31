// importların başında sadece easy_localization ve diğerler sabit
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';

class ArtworkAddScreen extends StatefulWidget {
  final String galleryId;

  const ArtworkAddScreen({super.key, required this.galleryId});

  @override
  State<ArtworkAddScreen> createState() => _ArtworkAddScreenState();
}

class _ArtworkAddScreenState extends State<ArtworkAddScreen> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  File? imageFile;
  bool isLoading = false;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => imageFile = File(picked.path));
    }
  }

  Future<String?> uploadImageToStorage(File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('artworks')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  Future<void> sendArtwork() async {
    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
      String? imageUrl;

      if (imageFile != null) {
        imageUrl = await uploadImageToStorage(imageFile!);
      }

      await FirebaseFirestore.instance.collection("artworks").add({
        "title": titleController.text.trim(),
        "description": descController.text.trim(),
        "price": double.tryParse(priceController.text.trim()) ?? 0.0,
        "imageUrl": imageUrl ?? "",
        "userId": uid,
        "galleryId": widget.galleryId,
        "createdAt": FieldValue.serverTimestamp(),
        "likes": 0,
        "likedBy": [],
        'sold': false,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("artwork_added".tr())));

      Navigator.pop(context);
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
      appBar: AppBar(title: Text("add_artwork".tr())),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: "title".tr()),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: "description".tr()),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "price".tr()),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: Text("select_image".tr()),
            ),
            if (imageFile != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Image.file(imageFile!, width: 100, height: 100),
              ),
            const SizedBox(height: 20),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                  onPressed: sendArtwork,
                  icon: const Icon(Icons.add),
                  label: Text("save".tr()),
                ),
          ],
        ),
      ),
    );
  }
}
