import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      debugPrint('Resim yükleme hatası: $e');
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
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("🎨 Eser eklendi")));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yeni Eser Ekle")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Başlık"),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Açıklama"),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Fiyat (₺)"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Resim Seç"),
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
                  label: const Text("Kaydet"),
                ),
          ],
        ),
      ),
    );
  }
}
