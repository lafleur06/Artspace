import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArtworkPublicViewScreen extends StatefulWidget {
  final Map<String, dynamic> artwork;
  final String artworkId;

  const ArtworkPublicViewScreen({
    super.key,
    required this.artwork,
    required this.artworkId,
  });

  @override
  State<ArtworkPublicViewScreen> createState() =>
      _ArtworkPublicViewScreenState();
}

class _ArtworkPublicViewScreenState extends State<ArtworkPublicViewScreen> {
  double? offer;
  String? galleryName;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('galleries')
        .doc(widget.artwork['galleryId'])
        .get()
        .then((doc) {
          if (doc.exists) {
            setState(() => galleryName = doc['name']);
          }
        });
  }

  Future<void> submitOffer() async {
    final price = widget.artwork['price'] ?? 0.0;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (offer == null || offer! <= 0 || offer! > price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geçerli bir teklif girin.")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('offers').add({
      'artworkId': widget.artworkId,
      'artworkTitle': widget.artwork['title'],
      'toUserId': widget.artwork['userId'],
      'fromUserId': userId,
      'amount': offer,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': widget.artwork['userId'],
      'fromUserId': FirebaseAuth.instance.currentUser?.uid,
      'artworkTitle': widget.artwork['title'],
      'amount': offer,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Teklif gönderildi.")));
    Navigator.pop(context);
  }

  Future<void> confirmPurchase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Satın Al"),
            content: const Text("Bu eseri satın almak istiyor musunuz?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Satın Al"),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Ödeme sayfasına yönlendir (şimdilik basit sayfa)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MockPaymentScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.artwork;
    final price = artwork['price'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Eser Detayı")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (artwork['imageUrl'] != null && artwork['imageUrl'] != "")
              Image.network(
                artwork['imageUrl'],
                height: 200,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            Text(
              "Başlık: ${artwork['title']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text("Açıklama: ${artwork['description']}"),
            const SizedBox(height: 8),
            Text("Fiyat: ₺${price.toStringAsFixed(2)}"),
            const SizedBox(height: 8),
            Text("Galeri: ${galleryName ?? 'Yükleniyor...'}"),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: "Teklif (₺)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => offer = double.tryParse(val),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: submitOffer,
              icon: const Icon(Icons.attach_money),
              label: const Text("Teklif Ver"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: confirmPurchase,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text("Satın Al"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class MockPaymentScreen extends StatelessWidget {
  const MockPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ödeme Sayfası")),
      body: const Center(
        child: Text(
          "💳 Ödeme sistemine yönlendiriliyorsunuz...\n(Gerçek ödeme entegrasyonu henüz yapılmadı)",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
