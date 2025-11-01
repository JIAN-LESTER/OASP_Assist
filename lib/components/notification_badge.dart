import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Add this widget to your AppBar
class NotificationBadgeButton extends StatelessWidget {
  final String role; // 'user', 'staff', or 'admin'
  final VoidCallback onTap;

  const NotificationBadgeButton({
    Key? key,
    required this.role,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return IconButton(
        icon: Icon(Icons.notifications_outlined),
        onPressed: onTap,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetRole', isEqualTo: role)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        // Count unread notifications
        int unreadCount = 0;
        
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final readBy = data['readBy'] as List<dynamic>? ?? [];
            
            if (!readBy.contains(currentUserId)) {
              unreadCount++;
            }
          }
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 
                    ? Icons.notifications_active 
                    : Icons.notifications_outlined,
                color: unreadCount > 0 ? Color(0xFF2E7D32) : null,
              ),
              onPressed: onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

// ✅ Example usage in your AppBar:
// AppBar(
//   title: Text('Dashboard'),
//   actions: [
//     NotificationBadgeButton(
//       role: 'user', // or 'staff', 'admin'
//       onTap: () {
//         showModalBottomSheet(
//           context: context,
//           isScrollControlled: true,
//           backgroundColor: Colors.transparent,
//           builder: (context) => NotificationModal(role: 'user'),
//         );
//       },
//     ),
//   ],
// )