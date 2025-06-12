import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import 'gallery_list_screen.dart';
import 'gallery_add_screen.dart';
import 'artwork_detail_screen.dart';
import 'artwork_public_view_screen.dart';
import 'notifications_screen.dart';
import 'package:artspace/main.dart';

class LongPressZoomDialog extends StatelessWidget {
  final String imageUrl;
  const LongPressZoomDialog({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.7),
        body: Center(
          child: Hero(
            tag: imageUrl,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class LongPressZoomImage extends StatelessWidget {
  final String imageUrl;
  const LongPressZoomImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (_) => LongPressZoomDialog(imageUrl: imageUrl),
        );
      },
      child: Hero(
        tag: imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            height: 80,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

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
        .limit(5)
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
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ?? Colors.deepPurple,
        elevation: 4,
        actions: [
          _buildNotificationIcon(context, currentUserId),
          _buildMessageIcon(context, currentUserId),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/backgrounds/homebg.webp",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              const SizedBox(height: 20),
              _buildHeaderSection(),
              const SizedBox(height: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("most_liked".tr()),
                  const SizedBox(height: 8),
                  _buildTopArtworksSection(currentUserId),
                  const SizedBox(height: 30),
                  _buildNavigationButtons(context),
                ],
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/cart');
        },
        backgroundColor: Colors.greenAccent.shade400,
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Text(
          "home_title".tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.lobster(
            fontSize: 54,
            color: Colors.white,
            shadows: const [
              Shadow(
                offset: Offset(1, 2),
                blurRadius: 4,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "home_subtitle".tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.raleway(
            fontSize: 16,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationIcon(BuildContext context, String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMessageIcon(BuildContext context, String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collectionGroup('messages')
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: currentUserId)
              .where('receiverId', isEqualTo: currentUserId)
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
    );
  }

  Widget _buildTopArtworksSection(String currentUserId) {
    return SizedBox(
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
                  margin: EdgeInsets.only(left: index == 0 ? 12 : 0, right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (artwork['imageUrl'] != null &&
                          artwork['imageUrl'] != "")
                        LongPressZoomImage(imageUrl: artwork['imageUrl']),
                      const SizedBox(height: 6),
                      Text(
                        artwork['title'] ?? "Eser",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        artwork['description'] ?? "",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        "₺${artwork['price']?.toStringAsFixed(2) ?? '0.00'}",
                        style: const TextStyle(color: Colors.deepPurple),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
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
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
