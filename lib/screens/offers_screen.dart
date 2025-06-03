import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';

class MyOffersScreen extends StatelessWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('my_offers'.tr())),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('offers')
                .where('toUserId', isEqualTo: currentUserId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final offers = snapshot.data!.docs;
          if (offers.isEmpty) {
            return Center(child: Text('no_offers_received'.tr()));
          }

          return ListView.builder(
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final data = offers[index].data() as Map<String, dynamic>;
              final fromUserId = data['fromUserId'];
              final artworkTitle = data['artworkTitle'] ?? "Artwork";
              final amount = data['amount'];
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(fromUserId)
                        .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox();
                  }

                  final user = userSnap.data!.data() as Map<String, dynamic>;
                  final username = user['username'] ?? 'User';

                  final formattedTime =
                      createdAt != null
                          ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt)
                          : tr('unknown_time');

                  return ListTile(
                    leading: const Icon(Icons.local_offer),
                    title: Text(
                      tr(
                        'offer_for_artwork',
                        namedArgs: {
                          'amount': '₺$amount',
                          'title': artworkTitle,
                        },
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tr('from')}: $username'),
                        Text(formattedTime),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.message),
                      onPressed: () {
                        final participants = [currentUserId, fromUserId]
                          ..sort();
                        final chatId = participants.join('_');

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChatScreen(
                                  chatId: chatId,
                                  otherUserId: fromUserId,
                                  otherUsername: username,
                                ),
                          ),
                        );
                      },
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
