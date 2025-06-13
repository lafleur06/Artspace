import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class AuctionListScreen extends StatelessWidget {
  const AuctionListScreen({super.key});

  Stream<QuerySnapshot> _auctionStream() {
    return FirebaseFirestore.instance
        .collection('auctions')
        .orderBy('startTime', descending: false)
        .snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.orange;
      case 'ended':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.local_fire_department;
      case 'ended':
        return Icons.check_circle;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("auction_list_title".tr())),
      body: StreamBuilder<QuerySnapshot>(
        stream: _auctionStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final auctions = snapshot.data?.docs ?? [];
          if (auctions.isEmpty) {
            return Center(child: Text("no_auctions".tr()));
          }

          return ListView.builder(
            itemCount: auctions.length,
            itemBuilder: (context, index) {
              final auction = auctions[index];
              final artworkId = auction['artworkId'];
              final status = auction['status']?.toString() ?? 'pending';
              final startTime = (auction['startTime'] as Timestamp).toDate();
              final currentPrice =
                  auction['currentPrice'] ?? auction['initialPrice'];

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('artworks')
                        .doc(artworkId)
                        .get(),
                builder: (context, artSnapshot) {
                  if (!artSnapshot.hasData) return const SizedBox.shrink();
                  final artwork = artSnapshot.data!;
                  final imageUrl = artwork['imageUrl'];
                  final title = artwork['title'];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading:
                          (imageUrl != null && imageUrl.toString().isNotEmpty)
                              ? Image.network(
                                imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                              : const Icon(
                                Icons.image_not_supported,
                                size: 60,
                                color: Colors.grey,
                              ),
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${'current_price'.tr()}: ₺${currentPrice.toStringAsFixed(2)}",
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("${'status'.tr()}: "),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(status),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getStatusIcon(status),
                                      size: 16,
                                      color: _getStatusColor(status),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      status.tr(),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${'starts_at'.tr()}: ${DateFormat('yyyy-MM-dd HH:mm').format(startTime)}",
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/auctionDetail',
                          arguments: auction.id,
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
