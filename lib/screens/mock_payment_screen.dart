import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';

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

  Future<void> completePurchase(BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();

    if (widget.cartItems != null) {
      for (var item in widget.cartItems!) {
        final artworkId = item['artworkId'];
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();

        // Sipariş kaydı
        batch.set(orderRef, {
          'userId': widget.userId,
          'artworkId': artworkId,
          'orderDate': Timestamp.now(),
          'status': 'Hazırlanıyor',
        });

        // Sepetten sil
        batch.delete(item.reference);
      }
    } else if (widget.artworkId != null) {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();

      batch.set(orderRef, {
        'userId': widget.userId,
        'artworkId': widget.artworkId,
        'orderDate': Timestamp.now(),
        'status': 'Hazırlanıyor',
      });
    }

    await batch.commit();

    // Ödeme sonrası artwork "sold" olarak işaretlenir
    if (widget.artworkId != null) {
      final artworkRef = FirebaseFirestore.instance
          .collection('artworks')
          .doc(widget.artworkId);
      await artworkRef.update({'sold': true});
    }

    // Başarı mesajı
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('added_to_orders'.tr())));

    // Ana sayfaya yönlendirme (HomeScreen)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(),
      ), // HomeScreen'e yönlendiriyoruz
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
            Text(
              "payment_redirect".tr(),
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
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
                      title: Text(artwork['title'] ?? ''),
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
              onPressed: () => completePurchase(context),
              icon: const Icon(Icons.check),
              label: Text("confirm_purchase".tr()),
            ),
          ],
        ),
      ),
    );
  }
}
