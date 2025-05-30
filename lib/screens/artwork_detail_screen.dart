import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  late String currentUserId;

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
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
    final createdAt = (widget.initialData['createdAt'] as Timestamp?)?.toDate();
    final sold = widget.initialData['sold'] == true;

    return Scaffold(
      appBar: AppBar(title: Text("artwork_detail".tr())),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            if (createdAt != null)
              Text(
                "${"uploaded_on".tr()}: ${DateFormat("dd.MM.yyyy").format(createdAt)}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (sold)
              Text(
                "sold_status".tr(),
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
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
            const Divider(height: 40),
            Text(
              "${"comments".tr()}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('comments')
                      .where('artworkId', isEqualTo: widget.artworkId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text("no_comments_yet".tr());
                }
                final docs = snapshot.data!.docs;
                final ratings = docs.map((e) => e['rating'] as num).toList();
                final average =
                    ratings.reduce((a, b) => a + b) / ratings.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "⭐ ${average.toStringAsFixed(1)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = data['userId'] ?? '';
                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists) {
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(data['comment'] ?? ''),
                              subtitle: Text("⭐ ${data['rating'] ?? ''}"),
                            );
                          }
                          final user =
                              userSnap.data!.data() as Map<String, dynamic>;
                          final username = user['username'] ?? 'Unknown';
                          final avatarUrl = user['avatarUrl'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child:
                                  avatarUrl.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                            ),
                            title: Text(username),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['comment'] ?? ''),
                                Text("⭐ ${data['rating'] ?? ''}"),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
