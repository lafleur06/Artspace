import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class AuctionAddScreen extends StatefulWidget {
  const AuctionAddScreen({super.key});

  @override
  State<AuctionAddScreen> createState() => _AuctionAddScreenState();
}

class _AuctionAddScreenState extends State<AuctionAddScreen> {
  String? selectedArtworkId;
  double initialPrice = 0.0;
  DateTime? selectedDateTime;
  int countdownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();

  Future<List<QueryDocumentSnapshot>> _getUserArtworks() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final query =
        await FirebaseFirestore.instance
            .collection('artworks')
            .where('userId', isEqualTo: userId)
            .get();

    return query.docs;
  }

  Future<void> _submitAuction() async {
    if (_formKey.currentState!.validate() &&
        selectedArtworkId != null &&
        selectedDateTime != null) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final auctionRef =
          FirebaseFirestore.instance.collection('auctions').doc();

      await auctionRef.set({
        'artworkId': selectedArtworkId,
        'userId': userId,
        'startTime': Timestamp.fromDate(selectedDateTime!),
        'initialPrice': initialPrice,
        'currentPrice': initialPrice,
        'currentWinnerId': '',
        'countdownSeconds': countdownSeconds,
        'status': 'pending',
        'bids': [],
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("auction_created".tr())));
      Navigator.pop(context);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("new_auction".tr())),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _getUserArtworks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final artworks = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedArtworkId,
                    items:
                        artworks
                            .map(
                              (art) => DropdownMenuItem(
                                value: art.id,
                                child: Text(art['title'] ?? 'Untitled'),
                              ),
                            )
                            .toList(),
                    hint: Text("select_artwork".tr()),
                    onChanged: (value) {
                      setState(() {
                        selectedArtworkId = value;
                      });
                    },
                    validator:
                        (value) =>
                            value == null ? 'select_artwork_error'.tr() : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "starting_price".tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'price_required'.tr();
                      }
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed <= 0) {
                        return 'price_invalid'.tr();
                      }
                      return null;
                    },
                    onChanged: (val) {
                      setState(() {
                        initialPrice = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      selectedDateTime == null
                          ? "select_date_time".tr()
                          : DateFormat(
                            'yyyy-MM-dd – HH:mm',
                          ).format(selectedDateTime!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDateTime,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: countdownSeconds,
                    items: [
                      DropdownMenuItem(value: 60, child: Text("1_minute".tr())),
                      DropdownMenuItem(
                        value: 300,
                        child: Text("5_minutes".tr()),
                      ),
                    ],
                    onChanged:
                        (val) => setState(() => countdownSeconds = val ?? 60),
                    decoration: InputDecoration(
                      labelText: "countdown_duration".tr(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitAuction,
                    child: Text("create_auction".tr()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
