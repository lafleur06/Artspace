import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'artwork_add_screen.dart';
import 'artwork_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialData['name']);
    descController = TextEditingController(
      text: widget.initialData['description'],
    );
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
      ).showSnackBar(const SnackBar(content: Text("Galeri güncellendi")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteArtwork(String artworkId) async {
    await FirebaseFirestore.instance
        .collection('artworks')
        .doc(artworkId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Galeri Detayı")),
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
            isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  onPressed: updateGallery,
                  icon: const Icon(Icons.save),
                  label: const Text("Güncelle"),
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
              label: const Text("Eser Ekle"),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              "Bu Galeriye Ait Eserler",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection("artworks")
                        .where("galleryId", isEqualTo: widget.galleryId)
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Hata oluştu: ${snapshot.error}"),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final artworks = snapshot.data!.docs;

                  if (artworks.isEmpty) {
                    return const Center(
                      child: Text("Bu galeriye ait eser yok."),
                    );
                  }

                  return ListView.builder(
                    itemCount: artworks.length,
                    itemBuilder: (context, index) {
                      final doc = artworks[index];
                      final artwork = doc.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(artwork['title'] ?? "Başlıksız"),
                        subtitle: Text(artwork['description'] ?? ""),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text("Eseri Sil"),
                                    content: const Text(
                                      "Bu eseri silmek istiyor musunuz?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text("Hayır"),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: const Text("Evet"),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true) {
                              await deleteArtwork(doc.id);
                            }
                          },
                        ),
                        onTap: () {
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
