import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      if (user == null) throw Exception("Kullanıcı oturum açmamış.");

      await FirebaseFirestore.instance.collection("galleries").add({
        "name": nameController.text.trim(),
        "description": descController.text.trim(),
        "ownerId": user.uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Galeri başarıyla eklendi")));

      nameController.clear();
      descController.clear();
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
      appBar: AppBar(title: const Text("Yeni Galeri Ekle")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Galeri Adı"),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Açıklama"),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  onPressed: addGallery,
                  icon: const Icon(Icons.add),
                  label: const Text("Galeri Oluştur"),
                ),
          ],
        ),
      ),
    );
  }
}
