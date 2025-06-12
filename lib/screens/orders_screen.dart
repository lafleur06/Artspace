import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class OrdersScreen extends StatelessWidget {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  String getTranslatedStatus(String status) {
    final localizedKeys = {
      'payment_success': 'payment_success',
      'preparing': 'status_preparing',
      'shipped': 'status_shipped',
      'delivered': 'status_delivered',
    };

    return localizedKeys.containsKey(status)
        ? localizedKeys[status]!.tr()
        : status.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('orders_title'.tr())),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('orders')
                .where('userId', isEqualTo: userId)
                .orderBy('orderDate', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return Center(child: Text('no_orders_yet'.tr()));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final artworkId = order['artworkId'];
              final timestamp = order['orderDate'] as Timestamp;
              final dateStr = DateFormat.yMMMd(
                context.locale.languageCode,
              ).format(timestamp.toDate());
              final status = getTranslatedStatus(order['status']);

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('artworks')
                        .doc(artworkId)
                        .get(),
                builder: (context, artworkSnap) {
                  if (!artworkSnap.hasData || !artworkSnap.data!.exists) {
                    return ListTile(
                      leading: const Icon(Icons.image),
                      title: Text("loading_artwork".tr()),
                      subtitle: Text("loading".tr()),
                    );
                  }

                  final artworkData =
                      artworkSnap.data!.data() as Map<String, dynamic>;
                  final title = artworkData['title'] ?? 'untitled'.tr();
                  final price = (artworkData['price'] ?? 0.0) as double;

                  return ListTile(
                    leading: const Icon(Icons.shopping_bag),
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${'price'.tr()}: ₺${price.toStringAsFixed(2)}'),
                        Text('${'order_date'.tr()}: $dateStr'),
                        Text('${'status'.tr()}: $status'),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
