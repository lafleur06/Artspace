import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

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
      appBar: AppBar(title: Text("all_galleries".tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "search_gallery".tr(),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
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
                  return Center(child: Text("no_gallery".tr()));
                }

                final galleries =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchText);
                    }).toList();

                if (galleries.isEmpty) {
                  return Center(child: Text("no_gallery_match".tr()));
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
                            ? DateFormat.yMMMMd(
                              context.locale.languageCode,
                            ).format(createdAt)
                            : "no_date".tr();

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(gallery['name'] ?? 'unnamed_gallery'.tr()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(gallery['description'] ?? ''),
                            const SizedBox(height: 4),
                            Text("${"created_at".tr()}: $formattedDate"),
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
