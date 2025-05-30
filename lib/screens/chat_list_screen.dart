import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('chats'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _openNewChatDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUserId)
                .orderBy('updatedAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final chats = snapshot.data!.docs;
          if (chats.isEmpty) return Center(child: Text('no_chats'.tr()));

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final otherUserId = (data['participants'] as List).firstWhere(
                (id) => id != currentUserId,
              );

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(otherUserId)
                        .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>?;
                  final username = userData?['username'] ?? 'Unknown';
                  final avatarUrl = userData?['avatarUrl'];
                  final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
                  final formattedTime =
                      updatedAt != null
                          ? DateFormat('HH:mm').format(updatedAt)
                          : '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                      child:
                          avatarUrl == null || avatarUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(username)),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      data['lastMessage'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatScreen(
                                chatId: chat.id,
                                otherUserId: otherUserId,
                                otherUsername: username,
                              ),
                        ),
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

  void _openNewChatDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('new_chat'.tr()),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: 'enter_username'.tr()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () async {
                  final username = controller.text.trim();
                  if (username.isEmpty) return;

                  final userQuery =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .where('username', isEqualTo: username)
                          .limit(1)
                          .get();

                  if (userQuery.docs.isEmpty) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('user_not_found'.tr())),
                    );
                    return;
                  }

                  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                  final otherUserDoc = userQuery.docs.first;
                  final otherUserId = otherUserDoc.id;

                  final participants = [currentUserId, otherUserId]..sort();
                  final chatId = participants.join('_');

                  final chatRef = FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId);
                  final chatSnapshot = await chatRef.get();

                  if (!chatSnapshot.exists) {
                    await chatRef.set({
                      'participants': participants,
                      'lastMessage': '',
                      'updatedAt': FieldValue.serverTimestamp(),
                      'isRead': false,
                    });
                  }

                  Navigator.pop(ctx);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ChatScreen(
                            chatId: chatId,
                            otherUserId: otherUserId,
                            otherUsername: username,
                          ),
                    ),
                  );
                },
                child: Text('start'.tr()),
              ),
            ],
          ),
    );
  }
}
