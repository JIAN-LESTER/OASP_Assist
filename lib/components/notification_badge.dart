import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBadgeButton extends StatelessWidget {
  final String role;
  final VoidCallback onTap;

  const NotificationBadgeButton({
    Key? key,
    required this.role,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: onTap);
    }

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetRole', isEqualTo: role)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int unread = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final readBy = (doc['readBy'] ?? []) as List<dynamic>;
            if (!readBy.contains(uid)) unread++;
          }
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                unread > 0 ? Icons.notifications_active : Icons.notifications_outlined,
                color: unread > 0 ? const Color(0xFF2E7D32) : null,
              ),
              onPressed: onTap,
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 13,
                    minHeight: 13,
                  ),
                  child: Center(
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
