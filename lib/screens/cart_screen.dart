import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:artspace/screens/artwork_public_view_screen.dart';

class CartScreen extends StatelessWidget {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  void removeFromCart(String docId) {
    FirebaseFirestore.instance.collection('carts').doc(docId).delete();
  }

  void purchaseAll(
    List<QueryDocumentSnapshot> cartItems,
    BuildContext context,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    for (var item in cartItems) {
      final artworkId = item['artworkId'];
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();

      batch.set(orderRef, {
        'userId': userId,
        'artworkId': artworkId,
        'orderDate': Timestamp.now(),
        'status': 'Hazırlanıyor', // default
      });

      batch.delete(item.reference);
    }

    await batch.commit();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('added_to_orders'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('cart_title'.tr())),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('carts')
                .where('userId', isEqualTo: userId)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final cartItems = snapshot.data!.docs;

          if (cartItems.isEmpty) {
            return Center(child: Text('empty_cart'.tr()));
          }

          return FutureBuilder<List<DocumentSnapshot>>(
            future: Future.wait(
              cartItems.map((item) {
                return FirebaseFirestore.instance
                    .collection('artworks')
                    .doc(item['artworkId'])
                    .get();
              }),
            ),
            builder: (context, asyncSnapshot) {
              if (!asyncSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final artworks = asyncSnapshot.data!;
              double totalPrice = 0.0;

              for (var doc in artworks) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalPrice += (data['price'] ?? 0.0) as double;
                }
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 12),
                      itemCount: artworks.length,
                      itemBuilder: (context, index) {
                        final doc = artworks[index];
                        final item = cartItems[index];

                        if (!doc.exists) return const SizedBox();

                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Untitled';
                        final price = (data['price'] ?? 0.0) as double;
                        final imageUrl = data['imageUrl'] ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading:
                              imageUrl.isNotEmpty
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 60,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                  ),
                          title: Text(title),
                          subtitle: Text("₺${price.toStringAsFixed(2)}"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ArtworkPublicViewScreen(
                                      artwork: data,
                                      artworkId: item['artworkId'],
                                    ),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle),
                            tooltip: 'remove_from_cart'.tr(),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: Text("remove_from_cart".tr()),
                                      content: Text(
                                        "confirm_remove_from_cart".tr(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: Text("confirm_no".tr()),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          child: Text("confirm_yes".tr()),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirmed == true) {
                                removeFromCart(item.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "${'total'.tr()}: ₺${totalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => purchaseAll(cartItems, context),
                      icon: const Icon(Icons.shopping_bag),
                      label: Text('buy_all'.tr()),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
