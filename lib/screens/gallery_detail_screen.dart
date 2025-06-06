import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'artwork_add_screen.dart';
import 'artwork_detail_screen.dart';
import 'artwork_public_view_screen.dart';

class GalleryDetailScreen extends StatefulWidget {
  final String galleryId;
  final Map<String, dynamic> initialData;

  const GalleryDetailScreen({
    super.key,
    required this.galleryId,
    required this.initialData,
  });

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  late TextEditingController nameController;
  late TextEditingController descController;
  bool isSaving = false;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  String? ownerName;
  String? ownerAvatarUrl;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialData['name']);
    descController = TextEditingController(
      text: widget.initialData['description'],
    );
    loadOwnerData();
  }

  Future<void> loadOwnerData() async {
    final ownerId = widget.initialData['ownerId'];
    final snapshot =
        await FirebaseFirestore.instance.collection('users').doc(ownerId).get();

    if (snapshot.exists) {
      final data = snapshot.data()!;
      setState(() {
        ownerName = data['username'];
        ownerAvatarUrl = data['avatarUrl'];
      });
    }
  }

  Future<void> updateGallery() async {
    setState(() => isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('galleries')
          .doc(widget.galleryId)
          .update({
            'name': nameController.text.trim(),
            'description': descController.text.trim(),
          });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("gallery_updated".tr())));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${"error".tr()}: $e")));
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteArtwork(String id) async {
    await FirebaseFirestore.instance.collection('artworks').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUserId == widget.initialData['ownerId'];

    return Scaffold(
      appBar: AppBar(title: Text("gallery_detail".tr())),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!isOwner)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          ownerAvatarUrl != null && ownerAvatarUrl!.isNotEmpty
                              ? NetworkImage(ownerAvatarUrl!)
                              : null,
                      child:
                          ownerAvatarUrl == null || ownerAvatarUrl!.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      ownerName ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            if (isOwner) ...[
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "gallery_name".tr()),
              ),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: "description".tr()),
              ),
              const SizedBox(height: 20),
              isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                    onPressed: updateGallery,
                    icon: const Icon(Icons.save),
                    label: Text("update".tr()),
                  ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ArtworkAddScreen(galleryId: widget.galleryId),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text("add_artwork".tr()),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            Text(
              "gallery_artworks".tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection("artworks")
                        .where("galleryId", isEqualTo: widget.galleryId)
                        .orderBy("likes", descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("no_artworks".tr()));
                  }

                  final artworks = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: artworks.length,
                    itemBuilder: (context, index) {
                      final doc = artworks[index];
                      final artwork = doc.data() as Map<String, dynamic>;
                      final price = (artwork['price'] ?? 0.0).toStringAsFixed(
                        2,
                      );

                      return ListTile(
                        title: Text(artwork['title'] ?? "untitled".tr()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(artwork['description'] ?? ""),
                            Text(
                              "${"price".tr()}: ₺$price",
                              style: const TextStyle(color: Colors.deepPurple),
                            ),
                            if (artwork['sold'] == true)
                              Text(
                                "sold_status".tr(),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        leading:
                            artwork['imageUrl'] != null &&
                                    artwork['imageUrl'] != ""
                                ? Image.network(
                                  artwork['imageUrl'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                )
                                : const Icon(Icons.image),
                        trailing:
                            isOwner
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: Text("delete_artwork".tr()),
                                            content: Text(
                                              "confirm_delete_artwork".tr(),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                child: Text("no".tr()),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                child: Text("yes".tr()),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (confirm == true) {
                                      await deleteArtwork(doc.id);
                                    }
                                  },
                                )
                                : null,
                        onTap: () {
                          if (artwork['userId'] == currentUserId) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ArtworkDetailScreen(
                                      artworkId: doc.id,
                                      initialData: artwork,
                                    ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ArtworkPublicViewScreen(
                                      artwork: artwork,
                                      artworkId: doc.id,
                                    ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
