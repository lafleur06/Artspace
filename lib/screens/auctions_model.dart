import 'package:cloud_firestore/cloud_firestore.dart';

class Bid {
  final String userId;
  final double amount;
  final DateTime timestamp;

  Bid({required this.userId, required this.amount, required this.timestamp});

  factory Bid.fromMap(Map<String, dynamic> map) {
    return Bid(
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class Auction {
  final String id;
  final String artworkId;
  final String userId;
  final DateTime startTime;
  final double initialPrice;
  final double currentPrice;
  final String currentWinnerId;
  final int countdownSeconds;
  final String status;
  final List<Bid> bids;

  Auction({
    required this.id,
    required this.artworkId,
    required this.userId,
    required this.startTime,
    required this.initialPrice,
    required this.currentPrice,
    required this.currentWinnerId,
    required this.countdownSeconds,
    required this.status,
    required this.bids,
  });

  factory Auction.fromMap(String id, Map<String, dynamic> data) {
    return Auction(
      id: id,
      artworkId: data['artworkId'],
      userId: data['userId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      initialPrice: (data['initialPrice'] ?? 0).toDouble(),
      currentPrice: (data['currentPrice'] ?? 0).toDouble(),
      currentWinnerId: data['currentWinnerId'] ?? '',
      countdownSeconds: data['countdownSeconds'] ?? 60,
      status: data['status'] ?? 'pending',
      bids:
          (data['bids'] as List<dynamic>?)
              ?.map((b) => Bid.fromMap(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'artworkId': artworkId,
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'initialPrice': initialPrice,
      'currentPrice': currentPrice,
      'currentWinnerId': currentWinnerId,
      'countdownSeconds': countdownSeconds,
      'status': status,
      'bids': bids.map((b) => b.toMap()).toList(),
    };
  }
}
