import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'artwork_detail_screen.dart';
import 'gallery_detail_screen.dart';

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
    ).showSnackBar(const SnackBar(content: Text("Kullanıcı adı güncellendi")));
  }

  Future<void> confirmAndDelete(String type, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("$type Sil"),
            content: Text("Bu $type silinsin mi?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("İptal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Sil"),
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

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Oturum açılmamış")));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text("Profilim")),
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
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: "Kullanıcı adı",
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
                    label: const Text("Kaydet"),
                  ),
            const Divider(),
            Expanded(
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: "Galerilerim", icon: Icon(Icons.collections)),
                      Tab(text: "Eserlerim", icon: Icon(Icons.image)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // GALERİLER
                        StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection("galleries")
                                  .where("ownerId", isEqualTo: uid)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty)
                              return const Center(
                                child: Text("Galeriniz yok."),
                              );

                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return ListTile(
                                  title: Text(data['name'] ?? ""),
                                  subtitle: Text(data['description'] ?? ""),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () =>
                                            confirmAndDelete("Galeri", doc.id),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => GalleryDetailScreen(
                                              galleryId: doc.id,
                                              initialData: data,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        // ESERLER
                        StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection("artworks")
                                  .where("userId", isEqualTo: uid)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty)
                              return const Center(child: Text("Eseriniz yok."));

                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;

                                return ListTile(
                                  leading:
                                      data['imageUrl'] != null &&
                                              data['imageUrl'] != ""
                                          ? Image.network(
                                            data['imageUrl'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          )
                                          : const Icon(Icons.image),
                                  title: Text(data['title'] ?? ""),
                                  subtitle: Text(data['description'] ?? ""),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => confirmAndDelete("Eser", doc.id),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => ArtworkDetailScreen(
                                              artworkId: doc.id,
                                              initialData: data,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
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
}
