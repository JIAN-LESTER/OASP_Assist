import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:capstone_project/colors.dart';

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

  Function(String notificationType, Map<String, dynamic> data)? _onNotificationTap;

  void setNavigationHandler(
    Function(String notificationType, Map<String, dynamic> data) handler,
  ) {
    _onNotificationTap = handler;
    print('✅ Navigation handler registered');
  }

  Future<void> initialize() async {
    if (_initialized) {
      print('⚠️ Notification service already initialized');
      return;
    }

    print('🔔 Initializing notification service...');
    print('📱 Platform: ${kIsWeb ? "Web" : Platform.operatingSystem}');

    try {
      if (isAndroidOrIOS) {
        await _initializeMobileNotifications();
      } else {
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

  Future<void> _initializeMobileNotifications() async {
    print('📱 Initializing mobile notifications (FCM)...');
    
    await _initializeLocalNotifications();
    
    final settings = await _requestPermissions();
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Notification permission denied');
      return;
    }

    print('✅ Notification permission granted: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('✅ iOS foreground notification presentation configured');
    }

    await _saveFCMToken();
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

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

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'announcements',
          'Announcements',
          description: 'General announcements and updates',
          importance: Importance.max,
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
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        ),
      );

      print('✅ Android notification channels created with MAX importance');
    }

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
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    print('✅ Local notifications initialized');
  }

  // ✅ FIXED: Save token as array in single user document
  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping token save');
        return;
      }

      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('⚠️ APNS token not available yet, waiting...');
          await Future.delayed(const Duration(seconds: 3));
          final retryApnsToken = await _firebaseMessaging.getAPNSToken();
          if (retryApnsToken == null) {
            print('⚠️ APNS token still not available after retry');
          }
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

      // ✅ FIXED: Store tokens as array in single document per user
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(user.uid) // Use userId as document ID
          .set({
        'userId': user.uid,
        'userRole': role,
        'tokens': FieldValue.arrayUnion([token]), // Add token to array
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved to user document with role: $role');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    print('🔄 FCM token refreshed: ${token.substring(0, 30)}...');
    await _saveFCMToken();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 ===== FOREGROUND MESSAGE =====');
    print('📬 Message ID: ${message.messageId}');
    print('📬 Title: ${message.notification?.title ?? message.data['title']}');
    print('📬 Body: ${message.notification?.body ?? message.data['body']}');
    print('📬 Data: ${message.data}');
    print('📬 ===============================');

    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    print('🔔 Showing local notification...');

    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final type = message.data['type'] ?? 'announcement';

    final channelId = _getChannelId(type);
    
    final importance = Importance.max;
    final priority = Priority.max;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      color: _getNotificationColor(message.data['category']),
      enableVibration: true,
      playSound: true,
      enableLights: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      autoCancel: true,
      ongoing: false,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
        summaryText: _getChannelName(channelId),
      ),
      ticker: title,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      groupKey: 'com.example.capstone_project.notifications',
      setAsGroupSummary: false,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final payload = _createPayload(message.data);
    
    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
      print('✅ Local notification shown with ID: $notificationId');
      print('✅ Payload: $payload');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  String _createPayload(Map<String, dynamic> data) {
    final type = data['type'] ?? 'announcement';
    final escalationId = data['escalationId'] ?? '';
    final announcementId = data['announcementId'] ?? '';
    final conversationId = data['conversationId'] ?? '';
    final category = data['category'] ?? '';
    
    // Format: type|escalationId|announcementId|conversationId|category
    return '$type|$escalationId|$announcementId|$conversationId|$category';
  }

  void _handleMessageTap(RemoteMessage message) {
    print('👆 ===== NOTIFICATION TAPPED (FCM) =====');
    print('👆 Message ID: ${message.messageId}');
    print('👆 Data: ${message.data}');
    print('👆 ====================================');
    
    final type = message.data['type'] ?? 'announcement';
    _navigateBasedOnNotification(type, message.data);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    print('👆 ===== LOCAL NOTIFICATION TAPPED =====');
    print('👆 Payload: ${response.payload}');
    print('👆 =======================================');
    
    if (response.payload == null || response.payload!.isEmpty) {
      print('⚠️ No payload in notification');
      return;
    }

    // Parse payload: type|escalationId|announcementId|conversationId|category
    final parts = response.payload!.split('|');
    if (parts.isEmpty) return;

    final type = parts[0];
    final escalationId = parts.length > 1 ? parts[1] : '';
    final announcementId = parts.length > 2 ? parts[2] : '';
    final conversationId = parts.length > 3 ? parts[3] : '';
    final category = parts.length > 4 ? parts[4] : '';

    final data = {
      'type': type,
      if (escalationId.isNotEmpty) 'escalationId': escalationId,
      if (announcementId.isNotEmpty) 'announcementId': announcementId,
      if (conversationId.isNotEmpty) 'conversationId': conversationId,
      if (category.isNotEmpty) 'category': category,
    };

    _navigateBasedOnNotification(type, data);
  }

 Future<void> _navigateBasedOnNotification(
  String type,
  Map<String, dynamic> data,
) async {
  print('🔍 ===== NAVIGATION DEBUG =====');
  print('Type: $type');
  print('Data: $data');
  print('Handler registered: ${_onNotificationTap != null}');
  print('=============================');
  
  if (_onNotificationTap == null) {
    print('⚠️ No navigation handler registered');
    return;
  }

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final role = userDoc.data()?['role'] ?? 'user';

    print('🔔 Navigation: Type=$type, Role=$role');

    // ✅ FIX: Pass the full data including announcementId
    if (type == 'new_escalation' && (role == 'staff' || role == 'admin')) {
      _onNotificationTap!('escalation_detail', data);
    } else if (type == 'escalation_reply' && role == 'user') {
      _onNotificationTap!('escalation_response', data);
    } else if (type == 'announcement' || type == 'deadline_reminder') {
      // ✅ Pass announcement data for navigation
      _onNotificationTap!('announcement', data);
    }
  } catch (e) {
    print('❌ Error handling notification navigation: $e');
  }
}

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

      // ✅ FIXED: Use same structure for web tokens
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'userRole': role,
        'tokens': FieldValue.arrayUnion([webToken]),
        'platform': 'web',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
            // ✅ FIXED: Remove token from array instead of deleting document
            await FirebaseFirestore.instance
                .collection('fcm_tokens')
                .doc(user.uid)
                .update({
              'tokens': FieldValue.arrayRemove([token]),
            });
          }
        }
      }

      _initialized = false;
      _onNotificationTap = null;
      print('✅ Notification service cleaned up');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }
}