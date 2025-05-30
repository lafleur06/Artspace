import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArtworkGridTile extends StatelessWidget {
  final DocumentSnapshot doc;

  const ArtworkGridTile({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isLiked =
        (data['likedBy'] as List<dynamic>?)?.contains(
          FirebaseAuth.instance.currentUser?.uid,
        ) ??
        false;

    return Card(
      elevation: 2,
      child: Column(
        children: [
          Expanded(
            child:
                data['imageUrl'] != null && data['imageUrl'] != ""
                    ? Image.network(
                      data['imageUrl'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                    : const Icon(Icons.image_not_supported),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  data['title'] ?? "",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  data['description'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    final ref = FirebaseFirestore.instance
                        .collection("artworks")
                        .doc(doc.id);
                    await ref.update({
                      "likedBy":
                          isLiked
                              ? FieldValue.arrayRemove([uid])
                              : FieldValue.arrayUnion([uid]),
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
