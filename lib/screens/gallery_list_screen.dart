import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'gallery_detail_screen.dart';

class GalleryListScreen extends StatefulWidget {
  const GalleryListScreen({super.key});

  @override
  State<GalleryListScreen> createState() => _GalleryListScreenState();
}

class _GalleryListScreenState extends State<GalleryListScreen> {
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tüm Galeriler")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Galeri Ara",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                final galleries =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchText);
                    }).toList();

                if (galleries.isEmpty) {
                  return const Center(
                    child: Text("Aramaya uygun galeri bulunamadı."),
                  );
                }

                return ListView.builder(
                  itemCount: galleries.length,
                  itemBuilder: (context, index) {
                    final doc = galleries[index];
                    final gallery = doc.data() as Map<String, dynamic>;
                    final createdAt =
                        (gallery['createdAt'] as Timestamp?)?.toDate();
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => GalleryDetailScreen(
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
          ),
        ],
      ),
    );
  }
}
