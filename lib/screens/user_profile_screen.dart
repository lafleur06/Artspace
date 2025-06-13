import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';

import 'artwork_detail_screen.dart';
import 'gallery_detail_screen.dart';
import 'artwork_public_view_screen.dart';
import 'offers_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  TextEditingController usernameController = TextEditingController();
  String? avatarUrl;
  bool isEditing = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      usernameController.text = data['username'] ?? "";
      avatarUrl = data['avatarUrl'];
      setState(() {});
    }
  }

  Future<void> pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final ref = FirebaseStorage.instance
        .ref()
        .child('avatars')
        .child('$uid.jpg');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'avatarUrl': url,
    });

    setState(() => avatarUrl = url);
  }

  Future<void> saveUsername() async {
    final newName = usernameController.text.trim();
    if (newName.isEmpty || uid == null) return;

    setState(() => isSaving = true);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'username': newName,
    });
    setState(() {
      isSaving = false;
      isEditing = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr("username_updated"))));
  }

  Future<void> confirmAndDelete(String type, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("${tr("delete")} ${tr(type.toLowerCase())}"),
            content: Text("${tr("delete_confirm")} ${tr(type.toLowerCase())}?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr("cancel")),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr("delete")),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection(type == "Galeri" ? "galleries" : "artworks")
          .doc(id)
          .delete();
    }
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('favorites')
              .where('userId', isEqualTo: uid)
              .snapshots(),
      builder: (context, favSnapshot) {
        if (!favSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final favDocs = favSnapshot.data!.docs;
        final artworkIds = favDocs.map((e) => e['artworkId']).toList();

        if (artworkIds.isEmpty) return Center(child: Text(tr("no_favorites")));

        return FutureBuilder<QuerySnapshot>(
          future:
              FirebaseFirestore.instance
                  .collection('artworks')
                  .where(FieldPath.documentId, whereIn: artworkIds)
                  .get(),
          builder: (context, artSnapshot) {
            if (!artSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final artworks = artSnapshot.data!.docs;

            return ListView.builder(
              itemCount: artworks.length,
              itemBuilder: (context, index) {
                final doc = artworks[index];
                final data = doc.data() as Map<String, dynamic>;

                return ListTile(
                  leading:
                      data['imageUrl'] != null && data['imageUrl'] != ""
                          ? Image.network(
                            data['imageUrl'],
                            width: 50,
                            height: 50,
                          )
                          : const Icon(Icons.image),
                  title: Text(data['title'] ?? ""),
                  subtitle: Text(data['description'] ?? ""),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: Text(tr("remove_favorite")),
                              content: Text(tr("confirm_remove_favorite")),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(tr("no")),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(tr("yes")),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true) {
                        toggleFavorite(doc.id);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ArtworkPublicViewScreen(
                              artwork: data,
                              artworkId: doc.id,
                            ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> toggleFavorite(String artworkId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .where('artworkId', isEqualTo: artworkId);

    final snapshot = await ref.get();
    if (snapshot.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('favorites').add({
        'userId': uid,
        'artworkId': artworkId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(body: Center(child: Text(tr("not_logged_in"))));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: Text(tr("my_profile"))),
        body: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: pickAndUploadAvatar,
              child: CircleAvatar(
                radius: 45,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child:
                    avatarUrl == null
                        ? const Icon(Icons.person, size: 45)
                        : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isEditing)
                  Text(
                    usernameController.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (isEditing)
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: tr("username"),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(isEditing ? Icons.close : Icons.edit, size: 20),
                  onPressed: () => setState(() => isEditing = !isEditing),
                ),
              ],
            ),
            if (isEditing)
              isSaving
                  ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  )
                  : ElevatedButton.icon(
                    onPressed: saveUsername,
                    icon: const Icon(Icons.save),
                    label: Text(tr("save")),
                  ),
            const Divider(),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        _buildProfileButton(
                          context,
                          icon: Icons.receipt_long,
                          label: tr("my_orders"),
                          color: Colors.indigo,
                          onPressed:
                              () => Navigator.pushNamed(context, '/orders'),
                        ),
                        const SizedBox(height: 10),
                        _buildProfileButton(
                          context,
                          icon: Icons.local_offer,
                          label: tr("my_offers"),
                          color: Colors.deepPurple,
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyOffersScreen(),
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        _buildProfileButton(
                          context,
                          icon: Icons.sell,
                          label: tr("my_sales"),
                          color: Colors.green,
                          onPressed:
                              () => Navigator.pushNamed(context, '/sales'),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    tabs: [
                      Tab(
                        text: tr("my_galleries"),
                        icon: const Icon(Icons.collections),
                      ),
                      Tab(
                        text: tr("my_artworks"),
                        icon: const Icon(Icons.image),
                      ),
                      Tab(
                        text: tr("my_favorites"),
                        icon: const Icon(Icons.favorite),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildUserCollection(
                          "galleries",
                          (doc, data) => GalleryDetailScreen(
                            galleryId: doc.id,
                            initialData: data,
                          ),
                          type: "Galeri",
                        ),
                        _buildUserCollection(
                          "artworks",
                          (doc, data) => ArtworkDetailScreen(
                            artworkId: doc.id,
                            initialData: data,
                          ),
                          type: "Eser",
                        ),
                        _buildFavoritesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCollection(
    String collection,
    Widget Function(DocumentSnapshot, Map<String, dynamic>) onTapBuilder, {
    required String type,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection(collection)
              .where(type == "Galeri" ? "ownerId" : "userId", isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(tr(type == "Galeri" ? "no_galleries" : "no_artworks")),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isSold = data['sold'] == true;

            return ListTile(
              leading:
                  data['imageUrl'] != null && data['imageUrl'] != ""
                      ? Image.network(
                        data['imageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                      : const Icon(Icons.image),
              title: Row(
                children: [
                  Expanded(child: Text(data['title'] ?? data['name'] ?? "")),
                  if (type == "Eser" && isSold)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tr("sold_status"),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(data['description'] ?? ""),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => confirmAndDelete(type, doc.id),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => onTapBuilder(doc, data)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 220,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
