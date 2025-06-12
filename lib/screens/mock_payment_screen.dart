import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class MockPaymentScreen extends StatefulWidget {
  final List<QueryDocumentSnapshot>? cartItems;
  final String userId;
  final String? artworkId;
  final Map<String, dynamic>? artworkData;

  const MockPaymentScreen({
    super.key,
    required this.userId,
    this.cartItems,
    this.artworkId,
    this.artworkData,
  });

  @override
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  double totalPrice = 0.0;
  List<Map<String, dynamic>> artworksToPurchase = [];

  @override
  void initState() {
    super.initState();
    if (widget.cartItems != null) {
      _loadCartArtworks();
    } else if (widget.artworkData != null) {
      final price = (widget.artworkData!['price'] ?? 0.0) as double;
      artworksToPurchase.add(widget.artworkData!);
      totalPrice = price;
    }

    Stripe.publishableKey =
        'pk_test_51RY61mH5lK8DjHeUp0U8aMSw9v90pWdvWLmpmY3NpsynGEhtA36zkgfFovzvhYbMObJxtz5mqjYyQV8TgiHaHiQx00FpEVWjaj';
  }

  Future<void> _loadCartArtworks() async {
    for (var item in widget.cartItems!) {
      final artworkId = item['artworkId'];
      final artDoc =
          await FirebaseFirestore.instance
              .collection('artworks')
              .doc(artworkId)
              .get();

      if (artDoc.exists) {
        final data = artDoc.data()!;
        artworksToPurchase.add({...data, 'artworkId': artworkId});
        totalPrice += (data['price'] ?? 0.0) as double;
      }
    }

    setState(() {});
  }

  Future<Map<String, dynamic>> fetchPaymentIntentClientSecret() async {
    final url = Uri.parse(
      'https://api-ceoctdjsaq-uc.a.run.app/create-payment-intent',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'amount': (totalPrice * 100).toInt(),
        'currency': 'try',
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('${'payment_intent_failed'.tr()}: ${response.body}');
    }
  }

  Future<void> startPayment() async {
    try {
      final paymentIntentData = await fetchPaymentIntentClientSecret();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          merchantDisplayName: 'Artspace',
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      completePurchase();
    } catch (e) {
      print("Ödeme sırasında hata: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('payment_failed'.tr())));
    }
  }

  Future<void> completePurchase() async {
    final batch = FirebaseFirestore.instance.batch();

    if (widget.cartItems != null) {
      for (var item in widget.cartItems!) {
        final artworkId = item['artworkId'];
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();

        batch.set(orderRef, {
          'userId': widget.userId,
          'artworkId': artworkId,
          'orderDate': Timestamp.now(),
          'status': 'payment_success',
        });

        batch.delete(item.reference);

        final artworkRef = FirebaseFirestore.instance
            .collection('artworks')
            .doc(artworkId);
        batch.update(artworkRef, {'sold': true});
      }
    } else if (widget.artworkId != null) {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();

      batch.set(orderRef, {
        'userId': widget.userId,
        'artworkId': widget.artworkId,
        'orderDate': Timestamp.now(),
        'status': 'payment_success',
      });

      final artworkRef = FirebaseFirestore.instance
          .collection('artworks')
          .doc(widget.artworkId);
      batch.update(artworkRef, {'sold': true});
    }

    await batch.commit();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('purchase_success'.tr())));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("payment".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            if (artworksToPurchase.isEmpty)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: artworksToPurchase.length,
                  itemBuilder: (context, index) {
                    final artwork = artworksToPurchase[index];
                    return ListTile(
                      title: Text(artwork['title'] ?? 'untitled'.tr()),
                      subtitle: Text(
                        "₺${(artwork['price'] ?? 0.0).toStringAsFixed(2)}",
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(
              "${'total'.tr()}: ₺${totalPrice.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: startPayment,
              icon: const Icon(Icons.check),
              label: Text("purchase_button".tr()),
            ),
          ],
        ),
      ),
    );
  }
}
