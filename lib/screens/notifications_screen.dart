import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

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

  Future<String> getUsername(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['username'] ?? tr('a_user');
    } catch (_) {
      return tr('a_user');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(tr("notifications"))),
      body:
          uid == null
              ? Center(child: Text(tr("user_not_found")))
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
                        return Center(child: Text(tr("error_occurred")));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text(tr("no_notifications")));
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
                          final fromUserId = data['fromUserId'];
                          final message =
                              data['message'] ?? tr("default_message");

                          return FutureBuilder<String>(
                            future:
                                fromUserId != null
                                    ? getUsername(fromUserId)
                                    : Future.value(tr("a_user")),
                            builder: (context, userSnapshot) {
                              final username =
                                  userSnapshot.data ?? tr("a_user");
                              final fullMessage = message.replaceAll(
                                "{user}",
                                username,
                              );

                              return ListTile(
                                leading: const Icon(Icons.notifications),
                                title: Text(fullMessage),
                                subtitle:
                                    createdAt != null
                                        ? Text(
                                          DateFormat(
                                            "dd.MM.yyyy HH:mm",
                                          ).format(createdAt),
                                        )
                                        : null,
                              );
                            },
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
