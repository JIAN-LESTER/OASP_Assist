import 'package:capstone_project/colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    print('🔔 Initializing notification service...');

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token and save to Firestore
    await _saveFCMToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Handle notification tap when app is terminated
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageTap(message);
      }
    });

    _initialized = true;
    print('✅ Notification service initialized');
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      print('📋 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('✅ User granted provisional notification permission');
      } else {
        print('❌ User declined notification permission');
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  // Initialize local notifications for showing notifications when app is in foreground
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('✅ Local notifications initialized');
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping token save');
        return;
      }

      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        print('⚠️ No FCM token available');
        return;
      }

      print('💾 Saving FCM token: ${token.substring(0, 20)}...');

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'userId': user.uid,
        'platform': _getPlatform(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    print('🔄 FCM token refreshed: ${token.substring(0, 20)}...');
    await _saveFCMToken();
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 Received foreground message: ${message.messageId}');
    print('📬 Title: ${message.notification?.title}');
    print('📬 Body: ${message.notification?.body}');

    // Show local notification
    await _showLocalNotification(message);

    // Save to Firestore notifications collection
    await _saveNotificationToFirestore(message);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Determine notification channel based on type
    final type = message.data['type'] ?? 'announcement';
    final channelId = type == 'deadline_reminder' ? 'deadline_reminders' : 'announcements';
    final channelName = type == 'deadline_reminder' ? 'Deadline Reminders' : 'Announcements';
    final importance = type == 'deadline_reminder' ? Importance.high : Importance.defaultImportance;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications for $channelName',
      importance: importance,
      priority: type == 'deadline_reminder' ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: getCategoryColor(message.data['category']),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['announcementId'],
    );

    print('✅ Local notification shown');
  }

  // Save notification to Firestore
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notification = message.notification;
      if (notification == null) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.uid,
        'title': notification.title ?? '',
        'body': notification.body ?? '',
        'type': message.data['type'] ?? 'announcement',
        'category': message.data['category'] ?? 'General',
        'announcementId': message.data['announcementId'],
        'data': message.data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Notification saved to Firestore');
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }

  // Handle notification tap
  void _handleMessageTap(RemoteMessage message) {
    print('👆 User tapped notification: ${message.messageId}');
    
    final announcementId = message.data['announcementId'];
    if (announcementId != null) {
      // Navigate to announcement details
      // You'll need to implement navigation based on your app structure
      print('🔗 Navigate to announcement: $announcementId');
      
      // Mark notification as read
      _markNotificationAsRead(announcementId);
    }
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 User tapped local notification');
    
    final announcementId = response.payload;
    if (announcementId != null && announcementId.isNotEmpty) {
      print('🔗 Navigate to announcement: $announcementId');
      _markNotificationAsRead(announcementId);
    }
  }

  // Mark notification as read
  Future<void> _markNotificationAsRead(String announcementId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('announcementId', isEqualTo: announcementId)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notificationsQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      print('✅ Notifications marked as read');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.size;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Get notification stream
  Stream<QuerySnapshot> getNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notificationsQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      print('✅ Notification deleted');
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  // Helper: Get platform name
  String _getPlatform() {
    // You'll need to import dart:io and use Platform.isAndroid, Platform.isIOS
    // For now, returning a placeholder
    return 'unknown';
  }

  // Helper: Get notification color based on category
  int? _getNotificationColor(String? category) {
    if (category == null) return null;
    
    switch (category.toLowerCase()) {
      case 'admission':
        return 0xFF2196F3; // Blue
      case 'scholarship':
        return 0xFF9C27B0; // Purple
      case 'placement':
        return 0xFFFF9800; // Orange
      case 'general':
        return 0xFF4CAF50; // Green
      default:
        return 0xFF4CAF50; // Green
    }
  }

  // Cleanup when user logs out
  Future<void> cleanup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        // Remove token from Firestore
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(token)
            .delete();

        print('✅ FCM token removed on logout');
      }

      _initialized = false;
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Handling background message: ${message.messageId}');
  print('📬 Title: ${message.notification?.title}');
  print('📬 Body: ${message.notification?.body}');
  // Background messages are automatically shown as system notifications
}