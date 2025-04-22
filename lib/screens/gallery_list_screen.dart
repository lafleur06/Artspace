import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'gallery_detail_screen.dart';

class GalleryListScreen extends StatelessWidget {
  const GalleryListScreen({super.key});

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Galeriyi Sil"),
            content: const Text(
              "Bu galeriyi silmek istediğinizden emin misiniz?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Hayır"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await FirebaseFirestore.instance
                      .collection("galleries")
                      .doc(docId)
                      .delete();
                },
                child: const Text("Evet"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tüm Galeriler")),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('galleries')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henüz galeri yok."));
          }

          final galleries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: galleries.length,
            itemBuilder: (context, index) {
              final doc = galleries[index];
              final gallery = doc.data() as Map<String, dynamic>;
              final createdAt = (gallery['createdAt'] as Timestamp?)?.toDate();
              final formattedDate =
                  createdAt != null
                      ? DateFormat.yMMMMd().format(createdAt)
                      : "Tarih yok";

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(gallery['name'] ?? 'İsimsiz Galeri'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gallery['description'] ?? ''),
                      const SizedBox(height: 4),
                      Text("Oluşturulma: $formattedDate"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(context, doc.id),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => GalleryDetailScreen(
                              galleryId: doc.id,
                              initialData: gallery,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
