import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'chat_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'mock_payment_screen.dart';

class ArtworkPublicViewScreen extends StatefulWidget {
  final Map<String, dynamic> artwork;
  final String artworkId;

  const ArtworkPublicViewScreen({
    super.key,
    required this.artwork,
    required this.artworkId,
  });

  @override
  State<ArtworkPublicViewScreen> createState() =>
      _ArtworkPublicViewScreenState();
}

class _ArtworkPublicViewScreenState extends State<ArtworkPublicViewScreen> {
  double? offer;
  String? galleryName;
  bool isLiked = false;
  bool isFavorite = false;
  double userRating = 0;
  final commentController = TextEditingController();
  late bool isSold;

  @override
  void initState() {
    super.initState();
    checkIfLiked();
    checkIfFavorite();
    isSold = widget.artwork['sold'] == true;

    FirebaseFirestore.instance
        .collection('galleries')
        .doc(widget.artwork['galleryId'])
        .get()
        .then((doc) {
          if (doc.exists) {
            setState(() => galleryName = doc['name']);
          }
        });
  }

  Future<void> checkIfFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: uid)
            .where('artworkId', isEqualTo: widget.artworkId)
            .get();

    setState(() {
      isFavorite = snapshot.docs.isNotEmpty;
    });
  }

  Future<void> toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .where('artworkId', isEqualTo: widget.artworkId);

    final snapshot = await ref.get();
    if (snapshot.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('favorites').add({
        'userId': uid,
        'artworkId': widget.artworkId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    checkIfFavorite();
  }

  Future<void> checkIfLiked() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('artworks')
            .doc(widget.artworkId)
            .get();
    final data = doc.data();
    if (data == null) return;

    final likedBy = List<String>.from(data['likedBy'] ?? []);
    setState(() {
      isLiked = likedBy.contains(uid);
    });
  }

  Future<void> toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('artworks')
        .doc(widget.artworkId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final data = doc.data()!;
    List likedBy = List<String>.from(data['likedBy'] ?? []);
    int likes = data['likes'] ?? 0;

    if (likedBy.contains(uid)) {
      likedBy.remove(uid);
      likes = (likes - 1).clamp(0, double.infinity).toInt();
      setState(() => isLiked = false);
    } else {
      likedBy.add(uid);
      likes += 1;
      setState(() => isLiked = true);
    }

    await docRef.update({'likedBy': likedBy, 'likes': likes});
  }

  Future<void> submitOffer() async {
    if (isSold) return;

    final price = widget.artwork['price'] ?? 0.0;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (offer == null || offer! <= 0 || offer! > price || userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("enter_valid_offer".tr())));
      return;
    }

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final username = userDoc.data()?['username'] ?? tr("a_user");

    await FirebaseFirestore.instance.collection('offers').add({
      'artworkId': widget.artworkId,
      'artworkTitle': widget.artwork['title'],
      'toUserId': widget.artwork['userId'],
      'fromUserId': userId,
      'amount': offer,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': widget.artwork['userId'],
      'fromUserId': userId,
      'type': 'normal_offer',
      'message': 'normal_offer_message',
      'namedArgs': {
        'user': username,
        'artwork': widget.artwork['title'],
        'amount': offer!.toStringAsFixed(2),
      },
      'createdAt': Timestamp.now(),
      'isRead': false,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("offer_sent".tr())));
    Navigator.pop(context);
  }

  Future<void> confirmPurchase() async {
    if (isSold) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("purchase".tr()),
            content: Text("confirm_purchase".tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text("cancel".tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text("purchase".tr()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => MockPaymentScreen(
                userId: FirebaseAuth.instance.currentUser!.uid,
                artworkId: widget.artworkId,
                artworkData: widget.artwork,
              ),
        ),
      );
    }
  }

  Future<void> addToCart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final artDoc =
        await FirebaseFirestore.instance
            .collection('artworks')
            .doc(widget.artworkId)
            .get();

    if (artDoc.exists && (artDoc['sold'] == true)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("already_sold".tr())));
      return;
    }

    final existing =
        await FirebaseFirestore.instance
            .collection('carts')
            .where('userId', isEqualTo: uid)
            .where('artworkId', isEqualTo: widget.artworkId)
            .get();

    if (existing.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('carts').add({
        'userId': uid,
        'artworkId': widget.artworkId,
        'addedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('added_to_cart'.tr())));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('already_in_cart'.tr())));
    }
  }

  Future<void> submitComment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || userRating == 0 || commentController.text.trim().isEmpty)
      return;

    await FirebaseFirestore.instance.collection('comments').add({
      'artworkId': widget.artworkId,
      'userId': uid,
      'rating': userRating,
      'comment': commentController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      userRating = 0;
      commentController.clear();
    });
  }

  void openChatWithArtist() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final artistId = widget.artwork['userId'];
    if (currentUserId == null || artistId == null) return;

    final participants = [currentUserId, artistId]..sort();
    final chatId = participants.join('_');

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final chatSnapshot = await chatRef.get();

    if (!chatSnapshot.exists) {
      await chatRef.set({
        'participants': participants,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              chatId: chatId,
              otherUserId: artistId,
              otherUsername: widget.artwork['artistName'] ?? 'Artist',
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.artwork;
    final price = artwork['price'] ?? 0.0;
    final createdAt = (artwork['createdAt'] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(title: Text("artwork_detail".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (artwork['imageUrl'] != null && artwork['imageUrl'] != "")
              Image.network(
                artwork['imageUrl'],
                height: 200,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${"title".tr()}: ${artwork['title']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: toggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.grey,
                  ),
                  tooltip:
                      isFavorite ? tr("remove_favorite") : tr("add_favorite"),
                ),
                IconButton(
                  onPressed: toggleLike,
                  icon: Icon(
                    Icons.favorite,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  tooltip: isLiked ? tr("unlike") : tr("like"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("${"description".tr()}: ${artwork['description']}"),
            const SizedBox(height: 8),
            Text("${"price".tr()}: ₺${price.toStringAsFixed(2)}"),
            const SizedBox(height: 8),
            Text("${"gallery".tr()}: ${galleryName ?? 'loading'.tr()}"),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "${"uploaded_on".tr()}: ${DateFormat.yMMMMd().format(createdAt)}",
                ),
              ),
            const SizedBox(height: 20),
            Column(
              children: [
                if (isSold)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text("sold_status".tr()),
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                else ...[
                  TextField(
                    decoration: InputDecoration(
                      labelText: "offer".tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => offer = double.tryParse(val),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    {
                      'onPressed': submitOffer,
                      'icon': Icons.attach_money,
                      'label': "submit_offer".tr(),
                      'color': Colors.purple,
                    },
                    {
                      'onPressed': confirmPurchase,
                      'icon': Icons.shopping_cart_checkout,
                      'label': "purchase".tr(),
                      'color': Colors.green,
                    },
                    {
                      'onPressed': addToCart,
                      'icon': Icons.shopping_cart,
                      'label': "add_to_cart".tr(),
                      'color': Colors.orange,
                    },
                    {
                      'onPressed': openChatWithArtist,
                      'icon': Icons.message,
                      'label': "send_message".tr(),
                      'color': Colors.indigo,
                    },
                  ].map(
                    (btn) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: btn['onPressed'] as VoidCallback,
                          icon: Icon(btn['icon'] as IconData),
                          label: Text(btn['label'] as String),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btn['color'] as Color,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 40),
            Text(
              "${"rate_and_comment".tr()}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RatingBar.builder(
                  initialRating: 0,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 30,
                  itemBuilder:
                      (context, _) =>
                          const Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (rating) => userRating = rating,
                ),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('comments')
                          .where('artworkId', isEqualTo: widget.artworkId)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      return const Text("⭐ 0.0");
                    final ratings =
                        snapshot.data!.docs
                            .map((doc) => doc['rating'] as num)
                            .toList();
                    final average =
                        ratings.reduce((a, b) => a + b) / ratings.length;
                    return Text("⭐ ${average.toStringAsFixed(1)}");
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: "your_comment".tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: submitComment,
              icon: const Icon(Icons.send),
              label: Text("submit".tr()),
            ),
            const Divider(height: 40),
            Text(
              "${"comments".tr()}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('comments')
                      .where('artworkId', isEqualTo: widget.artworkId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text("no_comments_yet".tr());
                }
                return Column(
                  children:
                      snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final userId = data['userId'] ?? '';
                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || !userSnap.data!.exists) {
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(data['comment'] ?? ''),
                                subtitle: Text("⭐ ${data['rating'] ?? ''}"),
                              );
                            }
                            final user =
                                userSnap.data!.data() as Map<String, dynamic>;
                            final username = user['username'] ?? 'Unknown';
                            final avatarUrl = user['avatarUrl'] ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                child:
                                    avatarUrl.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                              ),
                              title: Text(username),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['comment'] ?? ''),
                                  Text("⭐ ${data['rating'] ?? ''}"),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
