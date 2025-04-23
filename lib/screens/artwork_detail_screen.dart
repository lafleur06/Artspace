import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArtworkDetailScreen extends StatefulWidget {
  final String artworkId;
  final Map<String, dynamic> initialData;

  const ArtworkDetailScreen({
    super.key,
    required this.artworkId,
    required this.initialData,
  });

  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  late TextEditingController titleController;
  late TextEditingController descController;
  late TextEditingController imageUrlController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialData['title']);
    descController = TextEditingController(
      text: widget.initialData['description'],
    );
    imageUrlController = TextEditingController(
      text: widget.initialData['imageUrl'],
    );
  }

  Future<void> updateArtwork() async {
    setState(() => isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection("artworks")
          .doc(widget.artworkId)
          .update({
            "title": titleController.text.trim(),
            "description": descController.text.trim(),
            "imageUrl": imageUrlController.text.trim(),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Eser güncellendi")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Eser Detayı")),
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
            isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  onPressed: updateArtwork,
                  icon: const Icon(Icons.save),
                  label: const Text("Güncelle"),
                ),
          ],
        ),
      ),
    );
  }
}
