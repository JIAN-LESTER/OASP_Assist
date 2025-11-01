import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:capstone_project/colors.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // ✅ NEW: Firestore listener for real-time notifications
  StreamSubscription<QuerySnapshot>? _notificationListener;
  Set<String> _processedNotificationIds = {};

  bool _initialized = false;
  bool get isAndroidOrIOS => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized) {
      print('⚠️ Notification service already initialized');
      return;
    }

    print('🔔 Initializing notification service...');
    print('📱 Platform: ${kIsWeb ? "Web" : Platform.operatingSystem}');

    try {
      if (isAndroidOrIOS) {
        // ✅ Android/iOS: Use FCM + Local Notifications
        await _initializeMobileNotifications();
      } else {
        // ✅ Web/Windows: Use Firestore listeners only
        await _initializeWebNotifications();
      }

      _initialized = true;
      print('✅ Notification service initialized successfully');
      
    } catch (e, stackTrace) {
      print('❌ Error initializing notification service: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // ✅ Initialize for Android/iOS (FCM + Local Notifications)
  Future<void> _initializeMobileNotifications() async {
    print('📱 Initializing mobile notifications (FCM)...');
    
    // Request permissions
    final settings = await _requestPermissions();
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Notification permission denied');
      // Still set up Firestore listener as fallback
      await _setupFirestoreListener();
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get and save FCM token
    await _saveFCMToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Handle terminated tap
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // ✅ ALSO set up Firestore listener as backup
    await _setupFirestoreListener();
  }

  // ✅ Initialize for Web/Windows (Firestore only)
  Future<void> _initializeWebNotifications() async {
    print('🌐 Initializing web/desktop notifications (Firestore listener)...');
    
    // ✅ Save a "web token" for tracking purposes
    await _saveWebToken();
    
    // ✅ Set up Firestore listener for real-time notifications
    await _setupFirestoreListener();
    
    print('✅ Web notification listener active');
  }

  // ✅ NEW: Set up Firestore listener for ALL platforms
  Future<void> _setupFirestoreListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in, skipping Firestore listener');
      return;
    }

    // Get user role
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final role = userDoc.data()?['role'] ?? 'user';
    print('👤 Setting up notification listener for role: $role');

    // ✅ Listen to notifications for this user's role
    _notificationListener = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetRole', isEqualTo: role)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _handleFirestoreNotifications(snapshot);
    }, onError: (error) {
      print('❌ Firestore listener error: $error');
    });

    print('✅ Firestore notification listener active');
  }

  // ✅ NEW: Handle Firestore notifications (for ALL platforms)
  void _handleFirestoreNotifications(QuerySnapshot snapshot) {
    print('📬 Firestore notification update: ${snapshot.docs.length} total notifications');
    
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final doc = change.doc;
        final data = doc.data() as Map<String, dynamic>;
        final notificationId = doc.id;

        // Skip if already processed
        if (_processedNotificationIds.contains(notificationId)) {
          continue;
        }

        // Mark as processed
        _processedNotificationIds.add(notificationId);

        // Check if notification is unread
        final readBy = data['readBy'] as List<dynamic>? ?? [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        
        if (currentUserId != null && !readBy.contains(currentUserId)) {
          print('🔔 New unread notification: $notificationId');
          _showNotificationFromFirestore(data, notificationId);
        }
      }
    }

    // Clean up old processed IDs (keep only last 100)
    if (_processedNotificationIds.length > 100) {
      final excess = _processedNotificationIds.length - 100;
      _processedNotificationIds = _processedNotificationIds.skip(excess).toSet();
    }
  }

  // ✅ NEW: Show notification from Firestore data
  Future<void> _showNotificationFromFirestore(
    Map<String, dynamic> data,
    String notificationId,
  ) async {
    final title = data['title'] ?? 'New Notification';
    final body = data['body'] ?? 'You have a new notification';
    final type = data['type'] ?? 'announcement';

    print('📬 Showing notification: $title');

    if (isAndroidOrIOS) {
      // Show local notification on mobile
      await _showLocalNotificationFromData(title, body, type, data);
    } else {
      // Show web notification (browser notification API or in-app banner)
      _showWebNotification(title, body, type, data);
    }
  }

  // ✅ Show local notification on Android/iOS
  Future<void> _showLocalNotificationFromData(
    String title,
    String body,
    String type,
    Map<String, dynamic> data,
  ) async {
    final channelId = _getChannelId(type);
    final importance = type == 'deadline_reminder' ? Importance.max : Importance.high;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: type == 'deadline_reminder' ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      color: _getNotificationColor(data['category']),
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
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

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: data['announcementId'] ?? data['escalationId'],
    );
  }

  // ✅ NEW: Show web notification (in-app banner)
  void _showWebNotification(
    String title,
    String body,
    String type,
    Map<String, dynamic> data,
  ) {
    print('🌐 Web notification: $title - $body');
    
    // ✅ For web, we rely on the NotificationModal to show updates
    // The StreamBuilder in NotificationModal will automatically show new notifications
    
    // Optionally, you could use browser notifications API here
    // but that requires additional permissions and setup
  }

  // ✅ Save web token (for tracking)
  Future<void> _saveWebToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final role = userDoc.data()?['role'] ?? 'user';

      // Create a unique "token" for web sessions
      final webToken = 'web_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(webToken)
          .set({
        'token': webToken,
        'userId': user.uid,
        'userRole': role,
        'platform': 'web',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Web session token saved');
    } catch (e) {
      print('❌ Error saving web token: $e');
    }
  }

  // Mobile-specific methods (unchanged)
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings;
  }

  Future<void> _initializeLocalNotifications() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'announcements',
          'Announcements',
          description: 'General announcements and updates',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'deadline_reminders',
          'Deadline Reminders',
          description: 'Important deadline reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'escalations',
          'Escalations',
          description: 'Question escalations and responses',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

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
  }

  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final role = userDoc.data()?['role'] ?? 'user';

      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'userId': user.uid,
        'userRole': role,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    await _saveFCMToken();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 Foreground message received');
    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final type = message.data['type'] ?? 'announcement';

    await _showLocalNotificationFromData(title, body, type, message.data);
  }

  void _handleMessageTap(RemoteMessage message) {
    print('👆 Notification tapped');
    // TODO: Implement navigation
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Local notification tapped');
    // TODO: Implement navigation
  }

  String _getChannelId(String type) {
    switch (type) {
      case 'deadline_reminder':
        return 'deadline_reminders';
      case 'escalation_reply':
      case 'new_escalation':
        return 'escalations';
      default:
        return 'announcements';
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'deadline_reminders':
        return 'Deadline Reminders';
      case 'escalations':
        return 'Escalations';
      default:
        return 'Announcements';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'deadline_reminders':
        return 'Important deadline reminders';
      case 'escalations':
        return 'Question escalations and responses';
      default:
        return 'General announcements and updates';
    }
  }

  Color _getNotificationColor(String? category) {
    if (category == null) return getCategoryColor('general');
    return getCategoryColor(category);
  }

  Future<void> cleanup() async {
    try {
      // Cancel Firestore listener
      await _notificationListener?.cancel();
      _notificationListener = null;
      _processedNotificationIds.clear();

      // Clean up FCM token
      if (isAndroidOrIOS) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await _firebaseMessaging.getToken();
          if (token != null) {
            await FirebaseFirestore.instance
                .collection('fcm_tokens')
                .doc(token)
                .delete();
          }
        }
      }

      _initialized = false;
      print('✅ Notification service cleaned up');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Background message received');
}