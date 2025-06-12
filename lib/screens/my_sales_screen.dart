import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class MySalesScreen extends StatelessWidget {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  final statusOptions = {
    'payment_success': 'payment_success',
    'preparing': 'status_preparing',
    'shipped': 'status_shipped',
    'delivered': 'status_delivered',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('my_sales'.tr())),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders =
              snapshot.data!.docs.where((order) => order.exists).toList();

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(
              orders.map((order) async {
                final artworkDoc =
                    await FirebaseFirestore.instance
                        .collection('artworks')
                        .doc(order['artworkId'])
                        .get();
                if (artworkDoc.exists &&
                    (artworkDoc.data()?['userId'] == currentUserId)) {
                  return {'order': order, 'artwork': artworkDoc};
                }
                return {};
              }),
            ),
            builder: (context, futureSnapshot) {
              if (!futureSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final validSales =
                  futureSnapshot.data!
                      .where((entry) => entry.isNotEmpty)
                      .toList();

              if (validSales.isEmpty) {
                return Center(child: Text("no_sales_yet".tr()));
              }

              return ListView.builder(
                itemCount: validSales.length,
                itemBuilder: (context, index) {
                  final order = validSales[index]['order'] as DocumentSnapshot;
                  final artwork =
                      validSales[index]['artwork'] as DocumentSnapshot;

                  final data = artwork.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'untitled'.tr();
                  final status = order['status'];
                  final orderId = order.id;

                  return ListTile(
                    title: Text(title),
                    subtitle: Text(
                      '${'status'.tr()}: ${statusOptions[status]?.tr() ?? status}',
                    ),
                    trailing: DropdownButton<String>(
                      value: statusOptions.containsKey(status) ? status : null,
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .update({'status': newStatus});
                        }
                      },
                      items:
                          statusOptions.keys.map((key) {
                            return DropdownMenuItem(
                              value: key,
                              child: Text(statusOptions[key]!.tr()),
                            );
                          }).toList(),
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
