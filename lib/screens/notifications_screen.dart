import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> markAllAsRead(String uid) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: uid)
            .where('isRead', isEqualTo: false)
            .get();

    for (var doc in snapshot.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Bildirimler")),
      body:
          uid == null
              ? const Center(child: Text("Kullanıcı bilgisi alınamadı."))
              : FutureBuilder(
                future: markAllAsRead(uid),
                builder: (context, _) {
                  return StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('notifications')
                            .where('toUserId', isEqualTo: uid)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(child: Text("Bir hata oluştu."));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("Henüz bildirim yok."));
                      }

                      final notifs = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: notifs.length,
                        itemBuilder: (context, index) {
                          final data =
                              notifs[index].data() as Map<String, dynamic>;
                          final createdAt =
                              data['createdAt'] is Timestamp
                                  ? (data['createdAt'] as Timestamp).toDate()
                                  : null;

                          return ListTile(
                            leading: const Icon(Icons.notifications),
                            title: Text(data['message'] ?? 'Mesaj yok'),
                            subtitle:
                                createdAt != null
                                    ? Text(
                                      "${createdAt.day}.${createdAt.month}.${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                                    )
                                    : null,
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
