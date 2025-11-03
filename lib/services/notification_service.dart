import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:capstone_project/colors.dart';

// ✅ CRITICAL: Background handler MUST be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 ===== BACKGROUND MESSAGE =====');
  print('📬 Message ID: ${message.messageId}');
  print('📬 Title: ${message.notification?.title ?? message.data['title']}');
  print('📬 Body: ${message.notification?.body ?? message.data['body']}');
  print('📬 Data: ${message.data}');
  print('📬 ===============================');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
        // ✅ Web/Windows: Save web token only
        await _saveWebToken();
        print('✅ Web notifications initialized (in-app only)');
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
    
    // Request permissions FIRST
    final settings = await _requestPermissions();
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Notification permission denied');
      return;
    }

    print('✅ Notification permission granted: ${settings.authorizationStatus}');

    // Initialize local notifications BEFORE setting up listeners
    await _initializeLocalNotifications();

    // Get and save FCM token
    await _saveFCMToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

    // ✅ CRITICAL: Set up message handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check for notification that opened the app from terminated state
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('📬 App opened from notification (terminated state)');
      _handleMessageTap(initialMessage);
    }

    print('✅ Mobile FCM listeners active');
  }

  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
      criticalAlert: false,
    );
    
    print('📋 Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  Future<void> _initializeLocalNotifications() async {
    print('🔧 Setting up local notifications...');

    // ✅ ANDROID: Create notification channels
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
          enableLights: true,
          showBadge: true,
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
          enableLights: true,
          showBadge: true,
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
          enableLights: true,
          showBadge: true,
        ),
      );

      print('✅ Android notification channels created');
    }

    // ✅ iOS: Request permissions
    final iosImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('✅ iOS notification permissions requested');
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

    print('✅ Local notifications initialized');
  }

  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping token save');
        return;
      }

      // ✅ CRITICAL: Get APNS token first on iOS
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('⚠️ APNS token not available yet, waiting...');
          // Wait a bit for APNS token
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        print('⚠️ No FCM token available');
        return;
      }

      print('💾 Saving FCM token for user ${user.uid}');
      print('💾 Token: ${token.substring(0, 30)}...');

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

      print('✅ FCM token saved with role: $role');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    print('🔄 FCM token refreshed: ${token.substring(0, 30)}...');
    await _saveFCMToken();
  }

  // ✅ CRITICAL: Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 ===== FOREGROUND MESSAGE =====');
    print('📬 Message ID: ${message.messageId}');
    print('📬 Title: ${message.notification?.title ?? message.data['title']}');
    print('📬 Body: ${message.notification?.body ?? message.data['body']}');
    print('📬 Data: ${message.data}');
    print('📬 ===============================');

    // ✅ Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    print('🔔 Showing local notification...');

    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final type = message.data['type'] ?? 'announcement';

    final channelId = _getChannelId(type);
    final importance = type == 'deadline_reminder' ? Importance.max : Importance.high;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: type == 'deadline_reminder' ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      color: _getNotificationColor(message.data['category']),
      enableVibration: true,
      playSound: true,
      enableLights: true,
      styleInformation: BigTextStyleInformation(body),
      ticker: title,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: message.data['announcementId'] ?? message.data['escalationId'] ?? '',
      );
      print('✅ Local notification shown with ID: $notificationId');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    print('👆 ===== NOTIFICATION TAPPED =====');
    print('👆 Message ID: ${message.messageId}');
    print('👆 Data: ${message.data}');
    print('👆 ================================');
    
    // TODO: Implement navigation based on type
    // You can use a global navigator key or a callback to handle navigation
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Local notification tapped');
    print('👆 Payload: ${response.payload}');
    
    // TODO: Implement navigation
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