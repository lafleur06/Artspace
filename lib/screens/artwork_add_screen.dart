import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class ArtworkAddScreen extends StatefulWidget {
  final String galleryId;

  const ArtworkAddScreen({super.key, required this.galleryId});

  @override
  State<ArtworkAddScreen> createState() => _ArtworkAddScreenState();
}

class _ArtworkAddScreenState extends State<ArtworkAddScreen> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final imageUrlController = TextEditingController();
  bool isLoading = false;

  Future<void> sendArtwork() async {
    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
      await FirebaseFirestore.instance.collection("artworks").add({
        "title": titleController.text.trim(),
        "description": descController.text.trim(),
        "imageUrl": imageUrlController.text.trim(),
        "userId": uid,
        "galleryId": widget.galleryId,
        "createdAt": FieldValue.serverTimestamp(),
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
        child: Column(
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
              controller: imageUrlController,
              decoration: const InputDecoration(labelText: "Görsel URL"),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
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
