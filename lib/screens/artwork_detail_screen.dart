import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';

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
  late TextEditingController priceController;
  File? newImageFile;
  bool isSaving = false;
  String? galleryName;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialData['title']);
    descController = TextEditingController(
      text: widget.initialData['description'],
    );
    priceController = TextEditingController(
      text: widget.initialData['price']?.toString() ?? '0',
    );

    FirebaseFirestore.instance
        .collection('galleries')
        .doc(widget.initialData['galleryId'])
        .get()
        .then((doc) {
          if (doc.exists) {
            setState(() => galleryName = doc['name']);
          }
        });
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => newImageFile = File(picked.path));
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('artworks')
          .child(
            '${widget.artworkId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("⚠️ Upload error: $e");
      return null;
    }
  }

  Future<void> updateArtwork() async {
    setState(() => isSaving = true);
    try {
      final updateData = {
        'title': titleController.text.trim(),
        'description': descController.text.trim(),
        'price': double.tryParse(priceController.text.trim()) ?? 0.0,
      };

      if (newImageFile != null) {
        final imageUrl = await uploadImage(newImageFile!);
        if (imageUrl != null) {
          updateData['imageUrl'] = imageUrl;
        }
      }

      await FirebaseFirestore.instance
          .collection('artworks')
          .doc(widget.artworkId)
          .update(updateData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("artwork_updated".tr())));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${"error".tr()}: $e")));
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.initialData['imageUrl'] ?? "";

    return Scaffold(
      appBar: AppBar(title: Text("artwork_detail".tr())),
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
              maxLines: 4,
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "price".tr()),
            ),
            const SizedBox(height: 20),
            Text(
              "image".tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            newImageFile != null
                ? Image.file(newImageFile!, height: 150)
                : (imageUrl != ""
                    ? Image.network(imageUrl, height: 150)
                    : Text("no_image".tr())),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: Text(
                imageUrl == "" && newImageFile == null
                    ? "add_image".tr()
                    : "change_image".tr(),
              ),
            ),
            const SizedBox(height: 20),
            isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                  onPressed: updateArtwork,
                  icon: const Icon(Icons.save),
                  label: Text("update".tr()),
                ),
          ],
        ),
      ),
    );
  }
}
