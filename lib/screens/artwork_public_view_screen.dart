import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'chat_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

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
  bool isFavorite = false;
  double userRating = 0;
  final commentController = TextEditingController();
  late bool isSold;

  @override
  void initState() {
    super.initState();
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

  Future<void> submitOffer() async {
    if (isSold) return;

    final price = widget.artwork['price'] ?? 0.0;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (offer == null || offer! <= 0 || offer! > price) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("enter_valid_offer".tr())));
      return;
    }

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
      'artworkTitle': widget.artwork['title'],
      'amount': offer,
      'createdAt': FieldValue.serverTimestamp(),
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
      await FirebaseFirestore.instance
          .collection('artworks')
          .doc(widget.artworkId)
          .update({'sold': true});

      setState(() {
        isSold = true;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MockPaymentScreen()),
      );
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
            if (isSold)
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text("sold_status".tr()),
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.grey,
                ),
              )
            else
              Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: "offer".tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => offer = double.tryParse(val),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: submitOffer,
                    icon: const Icon(Icons.attach_money),
                    label: Text("submit_offer".tr()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: confirmPurchase,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: Text("purchase".tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: openChatWithArtist,
              icon: const Icon(Icons.message),
              label: Text("send_message".tr()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
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

class MockPaymentScreen extends StatelessWidget {
  const MockPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("payment".tr())),
      body: Center(
        child: Text(
          "payment_redirect".tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
