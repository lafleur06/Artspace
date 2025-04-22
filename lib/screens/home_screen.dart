import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'gallery_list_screen.dart';
import 'gallery_add_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GalleryListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.collections),
              label: const Text("Galerileri Gör"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GalleryAddScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_business),
              label: const Text("Yeni Galeri Oluştur"),
            ),
          ],
        ),
      ),
    );
  }
}
