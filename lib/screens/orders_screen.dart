import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatelessWidget {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  String getTranslatedStatus(String status) {
    switch (status) {
      case 'Hazırlanıyor':
        return 'status_preparing'.tr();
      case 'Kargoda':
        return 'status_shipped'.tr();
      case 'Teslim Edildi':
        return 'status_delivered'.tr();
      default:
        return status;
    }
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
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return Center(child: Text('no_orders_yet'.tr()));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final timestamp = order['orderDate'] as Timestamp;
              final dateStr = DateFormat.yMMMd().format(timestamp.toDate());
              final status = getTranslatedStatus(order['status']);

              return ListTile(
                leading: Icon(Icons.shopping_bag),
                title: Text('Artwork ID: ${order['artworkId']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'order_date'.tr()}: $dateStr'),
                    Text('${'status_preparing'.tr()}: $status'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
