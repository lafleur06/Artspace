import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class AuctionDetailScreen extends StatefulWidget {
  final String auctionId;
  const AuctionDetailScreen({super.key, required this.auctionId});

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen> {
  late DocumentSnapshot auctionDoc;
  DocumentSnapshot? artworkDoc;
  Timer? countdownTimer;
  Duration? remaining;
  Duration? startCountdown;
  final TextEditingController _bidController = TextEditingController();
  bool loading = true;
  bool ended = false;
  bool notStartedYet = false;

  @override
  void initState() {
    super.initState();
    _loadAuction();
  }

  void _loadAuction() async {
    final now = DateTime.now();
    auctionDoc =
        await FirebaseFirestore.instance
            .collection('auctions')
            .doc(widget.auctionId)
            .get();
    final artworkId = auctionDoc['artworkId'];
    artworkDoc =
        await FirebaseFirestore.instance
            .collection('artworks')
            .doc(artworkId)
            .get();

    final status = auctionDoc['status'];
    final startTime = (auctionDoc['startTime'] as Timestamp).toDate();
    final bids = auctionDoc['bids'] as List<dynamic>? ?? [];

    if (now.isBefore(startTime)) {
      notStartedYet = true;
      startCountdown = startTime.difference(now);
      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (startCountdown!.inSeconds > 0) {
            startCountdown = startCountdown! - const Duration(seconds: 1);
          } else {
            countdownTimer?.cancel();
            notStartedYet = false;
            _loadAuction();
          }
        });
      });
      setState(() => loading = false);
      return;
    }

    if (status == 'pending' && now.isAfter(startTime)) {
      await FirebaseFirestore.instance
          .collection('auctions')
          .doc(widget.auctionId)
          .update({'status': 'active'});
      final ownerId = artworkDoc?['userId'];
      final artworkTitle = artworkDoc?['title'] ?? tr("an_artwork");
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': ownerId,
        'fromUserId': FirebaseAuth.instance.currentUser!.uid,
        'type': 'auction_started',
        'message': 'auction_started_message',
        'namedArgs': {'artwork': artworkTitle},
        'createdAt': Timestamp.now(),
        'isRead': false,
      });
      auctionDoc =
          await FirebaseFirestore.instance
              .collection('auctions')
              .doc(widget.auctionId)
              .get();
    }

    final updatedStatus = auctionDoc['status'];
    if (updatedStatus == 'ended') {
      await _notifyWinner();
      setState(() {
        loading = false;
        ended = true;
      });
      return;
    }

    if (bids.isEmpty) {
      setState(() {
        loading = false;
        ended = false;
      });
      return;
    }

    final countdown = auctionDoc['countdownSeconds'] ?? 60;
    final lastBidTime = (bids.last['timestamp'] as Timestamp).toDate();
    final expiryTime = lastBidTime.add(Duration(seconds: countdown));
    if (now.isAfter(expiryTime)) {
      await FirebaseFirestore.instance
          .collection('auctions')
          .doc(widget.auctionId)
          .update({'status': 'ended'});
      await _notifyWinner();
      setState(() {
        ended = true;
        loading = false;
      });
      return;
    }

    remaining = expiryTime.difference(now);
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (remaining!.inSeconds > 0) {
          remaining = remaining! - const Duration(seconds: 1);
        } else {
          countdownTimer?.cancel();
          ended = true;
        }
      });
    });

    setState(() => loading = false);
  }

  Future<void> _placeBid() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final newBid = double.tryParse(_bidController.text.trim());

    if (notStartedYet) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr("auction_not_started"))));
      return;
    }

    final ownerId = artworkDoc?['userId'];
    if (ownerId == userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr("cannot_bid_own_artwork"))));
      return;
    }

    final bids = auctionDoc['bids'] as List<dynamic>? ?? [];
    final lastBid = bids.isNotEmpty ? bids.last : null;
    if (lastBid != null && lastBid['userId'] == userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr("cannot_bid_twice"))));
      return;
    }

    if (newBid == null || newBid <= (auctionDoc['currentPrice'] ?? 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr("invalid_bid"))));
      return;
    }

    final artworkTitle = artworkDoc?['title'] ?? tr("an_artwork");

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final username = userDoc.data()?['username'] ?? tr("a_user");

    if (lastBid != null && lastBid['userId'] != userId) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': lastBid['userId'],
        'fromUserId': userId,
        'type': 'bid_outbid',
        'message': 'bid_outbid_message',
        'namedArgs': {'user': username, 'artwork': artworkTitle},
        'createdAt': Timestamp.now(),
        'isRead': false,
      });
    }

    if (ownerId != null) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': ownerId,
        'fromUserId': userId,
        'type': 'bid_placed',
        'message': 'bid_placed_message',
        'namedArgs': {
          'user': username,
          'artwork': artworkTitle,
          'amount': newBid.toStringAsFixed(2),
        },
        'createdAt': Timestamp.now(),
        'isRead': false,
      });
    }

    await FirebaseFirestore.instance
        .collection('auctions')
        .doc(widget.auctionId)
        .update({
          'currentPrice': newBid,
          'currentWinnerId': userId,
          'bids': FieldValue.arrayUnion([
            {'userId': userId, 'amount': newBid, 'timestamp': Timestamp.now()},
          ]),
        });

    countdownTimer?.cancel();
    _loadAuction();
    _bidController.clear();
  }

  Future<void> _notifyWinner() async {
    final winnerId = auctionDoc['currentWinnerId'];
    final ownerId = artworkDoc?['userId'];
    final artworkTitle = artworkDoc?['title'] ?? tr("an_artwork");
    final artworkId = artworkDoc?.id;
    final finalPrice = auctionDoc['currentPrice']?.toStringAsFixed(2) ?? "0.00";

    if (winnerId != null && winnerId.toString().isNotEmpty) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': winnerId,
        'fromUserId': FirebaseAuth.instance.currentUser!.uid,
        'type': 'auction_won',
        'message': 'auction_won_message',
        'namedArgs': {'artwork': artworkTitle, 'amount': finalPrice},
        'createdAt': Timestamp.now(),
        'isRead': false,
      });

      await FirebaseFirestore.instance.collection('offers').add({
        'artworkId': artworkId,
        'artworkTitle': artworkTitle,
        'toUserId': ownerId,
        'fromUserId': winnerId,
        'amount': finalPrice,
        'createdAt': Timestamp.now(),
        'isAuctionWinner': true,
      });

      if (ownerId != null && ownerId != winnerId) {
        final winnerDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(winnerId)
                .get();
        final winnerUsername = winnerDoc.get('username') ?? tr("a_user");

        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': ownerId,
          'fromUserId': winnerId,
          'type': 'auction_result',
          'message': 'auction_result_message',
          'namedArgs': {
            'user': winnerUsername,
            'artwork': artworkTitle,
            'amount': finalPrice,
          },
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
      }
    }
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title = artworkDoc?['title'] ?? '';
    final imageUrl = artworkDoc?['imageUrl'];
    final price = auctionDoc['currentPrice'];
    final winner = auctionDoc['currentWinnerId'];
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final bids = auctionDoc['bids'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text("auction_detail".tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child:
                  imageUrl != null && imageUrl.toString().isNotEmpty
                      ? Image.network(imageUrl, height: 200)
                      : const Icon(Icons.image_not_supported, size: 100),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("${"current_price".tr()}: ₺${price.toStringAsFixed(2)}"),
            if (notStartedYet)
              Text(
                "${"starts_in".tr()}: ${startCountdown!.inSeconds}s",
                style: const TextStyle(color: Colors.blue),
              ),
            if (remaining != null && !ended)
              Text(
                "${"time_left".tr()}: ${remaining!.inSeconds}s",
                style: const TextStyle(color: Colors.red),
              ),
            if (ended)
              FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(winner)
                        .get(),
                builder: (context, snapshot) {
                  final username =
                      snapshot.data?.get('username') ?? tr('a_user');
                  final isYou = winner == userId;
                  return Text(
                    isYou
                        ? "you_won".tr()
                        : "$username ${"won_the_auction".tr()}",
                    style: TextStyle(
                      color: isYou ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            if (!ended && !notStartedYet)
              Column(
                children: [
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bidController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "your_bid".tr()),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _placeBid,
                    child: Text("place_bid".tr()),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (bids.isNotEmpty) ...[
              Text(
                "bid_history".tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...bids.reversed.map((bid) {
                final bidUserId = bid['userId'];
                final amount = (bid['amount'] ?? 0).toDouble();
                final timestamp = (bid['timestamp'] as Timestamp).toDate();
                return FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(bidUserId)
                          .get(),
                  builder: (context, snapshot) {
                    final username = snapshot.data?.get('username') ?? 'Anon';
                    final avatarUrl = snapshot.data?.get('avatarUrl');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child:
                            avatarUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(username),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(timestamp),
                      ),
                      trailing: Text("₺${amount.toStringAsFixed(2)}"),
                    );
                  },
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
