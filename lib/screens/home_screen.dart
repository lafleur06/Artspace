import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import 'gallery_list_screen.dart';
import 'gallery_add_screen.dart';
import 'artwork_detail_screen.dart';
import 'artwork_public_view_screen.dart';
import 'notifications_screen.dart';
import 'package:artspace/main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("logout_confirm_title".tr()),
            content: Text("logout_confirm_message".tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text("confirm_no".tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text("confirm_yes".tr()),
              ),
            ],
          ),
    );
    if (shouldLogout == true) {
      FirebaseAuth.instance.signOut();
    }
  }

  Stream<QuerySnapshot> getTopArtworks() {
    return FirebaseFirestore.instance
        .collection("artworks")
        .orderBy("likes", descending: true)
        .limit(10)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final currentUserId = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("ArtSpace"),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('notifications')
                    .where('toUserId', isEqualTo: currentUserId)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collectionGroup('messages')
                    .where('isRead', isEqualTo: false)
                    .where('senderId', isNotEqualTo: currentUserId)
                    .snapshots(),
            builder: (context, snapshot) {
              final unreadMsgCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () {
                      Navigator.pushNamed(context, '/chats');
                    },
                  ),
                  if (unreadMsgCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '$unreadMsgCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.palette, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    "menu".tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.collections),
              title: Text("gallery_list".tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business),
              title: Text("gallery_add".tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryAddScreen()),
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Text(
                "language".tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.setLocale(const Locale('tr')),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/flags/tr.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => context.setLocale(const Locale('en')),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/flags/en.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text("dark_mode".tr()),
              trailing: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) {
                  return Switch(
                    value: mode == ThemeMode.dark,
                    onChanged: (val) {
                      themeNotifier.value =
                          val ? ThemeMode.dark : ThemeMode.light;
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text("logout".tr()),
              onTap: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.auto_awesome, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            Text(
              "home_title".tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "home_subtitle".tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            _sectionTitle("most_liked".tr()),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: StreamBuilder<QuerySnapshot>(
                stream: getTopArtworks(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final artworks = snapshot.data!.docs;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: artworks.length,
                    itemBuilder: (context, index) {
                      final doc = artworks[index];
                      final artwork = doc.data() as Map<String, dynamic>;

                      return GestureDetector(
                        onTap: () {
                          final ownerId = artwork['userId'];
                          if (ownerId == currentUserId) {
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
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (artwork['imageUrl'] != null &&
                                  artwork['imageUrl'] != "")
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    artwork['imageUrl'],
                                    height: 80,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                artwork['title'] ?? "Eser",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                artwork['description'] ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                "₺${artwork['price']?.toStringAsFixed(2) ?? '0.00'}",
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryListScreen()),
                );
              },
              icon: const Icon(Icons.collections, color: Colors.white),
              label: Text(
                "gallery_list".tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryAddScreen()),
                );
              },
              icon: const Icon(Icons.add_business, color: Colors.white),
              label: Text(
                "gallery_add".tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/cart');
        },
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.shopping_cart, color: Colors.white),
        label: Text(
          "cart_title".tr(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
