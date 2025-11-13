import 'dart:async';
import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/pages/admin_pages/admin_main_page.dart';
import 'package:capstone_project/pages/staff_pages/human_escalation.dart';
import 'package:capstone_project/pages/staff_pages/staff_main_page.dart';

import 'package:flutter/services.dart';
import 'package:capstone_project/auth_pages/auth_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:capstone_project/onboarding/onboarding.dart';
import 'package:capstone_project/onboarding/useronboarding.dart';
import 'package:capstone_project/pages/admin_pages/information_bank_page.dart';
import 'package:capstone_project/pages/user_pages/admission_info.dart';
import 'package:capstone_project/pages/user_pages/chat_page.dart';

import 'package:capstone_project/pages/user_pages/placement_info.dart';
import 'package:capstone_project/pages/user_pages/scholarship_list.dart';
import 'package:capstone_project/pages/user_pages/user_announcement.dart';
import 'package:capstone_project/pages/user_pages/user_main_page.dart';
import 'package:capstone_project/provider/chat_provider.dart';
import 'package:capstone_project/services/admin_functions.dart';
import 'package:capstone_project/services/answer_retrieval.dart';
import 'package:capstone_project/services/cohere_service.dart';

import 'package:capstone_project/services/pinecone_service.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


bool _servicesInitialized = false;

class NotificationNavigationHandler {
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationNavigationHandler(this.navigatorKey);

  void setup() {
    NotificationService().setNavigationHandler(_handleNavigation);
    print('✅ Navigation handler registered');
  }

  void _handleNavigation(String type, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ No navigator context available');
      return;
    }

    print('📍 Navigating to: $type with data: $data');

    switch (type) {
      case 'escalation_detail':
        _navigateToEscalationDetail(context, data);
        break;
      case 'escalation_response':
        _showEscalationResponse(context, data);
        break;
      case 'announcement':
        _navigateToAnnouncement(context, data);
        break;
      case 'announcements_list':
        _navigateToAnnouncementsList(context);
        break;
    }
  }

  void _navigateToEscalationDetail(BuildContext context, Map<String, dynamic> data) async {
    final escalationId = data['escalationId'];
    if (escalationId == null || escalationId.isEmpty) {
      print('⚠️ No escalation ID provided');
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
      
      final route = role == 'admin' ? '/admin/home' : '/staff/home';
      final tabIndex = role == 'admin' ? 5 : 2;
      
      print('📍 Navigating $role to escalations (route: $route, tab: $tabIndex)');
      
      Navigator.of(context).pushReplacementNamed(
        route,
        arguments: {
          'initialTab': tabIndex,
          'escalationId': escalationId,
          'autoOpen': true,
        },
      );
    } catch (e) {
      print('❌ Error determining user role: $e');
      Navigator.of(context).pushReplacementNamed(
        '/staff/escalations',
        arguments: {
          'escalationId': escalationId,
          'autoOpen': true,
        },
      );
    }
  }

  Future<void> _showEscalationResponse(BuildContext context, Map<String, dynamic> data) async {
    final escalationId = data['escalationId'] ?? data['relatedId'];
    
    print('🔍 DEBUG: escalationId = $escalationId');
    print('🔍 DEBUG: data keys = ${data.keys}');
    
    if (escalationId == null || escalationId.isEmpty) {
      _showErrorDialog(context, 'No escalation ID provided');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );

      final escalationDoc = await FirebaseFirestore.instance
          .collection('escalations')
          .doc(escalationId)
          .get();

      if (context.mounted) Navigator.of(context).pop();

      if (!escalationDoc.exists) {
        _showErrorDialog(context, 'Escalation not found');
        return;
      }

      final escalation = escalationDoc.data()!;
      final staffResponse = escalation['staffResponse'] ?? 'No response yet';
      final respondedBy = escalation['respondedBy'] ?? 'Staff';
      final respondedAt = escalation['respondedAt'] as Timestamp?;
      final userQuestion = escalation['question'] ?? 'No question available';
      final conversationId = escalation['conversationId'] as String?;

      if (!context.mounted) return;

      final shouldNavigate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.support_agent, color: Color(0xFF2E7D32), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Staff Response', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    if (respondedAt != null)
                      Text(
                        formatTime(respondedAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.question_answer, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text('Your Question', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(userQuestion, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFF2E7D32).withOpacity(0.1), const Color(0xFF388E3C).withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.support_agent, size: 16, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 6),
                          Text('Response from $respondedBy', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(staffResponse, style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Close', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ),
            if (conversationId != null && conversationId.isNotEmpty)
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Chat', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      );

      if (shouldNavigate == true && conversationId != null && conversationId.isNotEmpty) {
        print('✅ Navigating to chat with conversation: $conversationId');
        
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/home',
            arguments: {
              'initialTab': 1,
              'conversationId': conversationId,
              'loadExisting': true,
            },
          );
        }
      }
    } catch (e) {
      print('❌ Error fetching escalation: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(context, 'Failed to load response');
      }
    }
  }

  // ✅ FIXED: Navigate directly to the announcements tab based on role
  Future<void> _navigateToAnnouncement(BuildContext context, Map<String, dynamic> data) async {
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
      final announcementId = data['announcementId'];

      print('📢 Navigating to announcements for role: $role');
      print('📢 Announcement ID: $announcementId');

      // ✅ FIXED: Navigate with proper route and tab index for each role
      if (role == 'user') {
        Navigator.of(context).pushReplacementNamed(
          '/home',
          arguments: {
            'initialTab': 2, // Announcements tab for users
            'announcementId': announcementId,
          },
        );
      } else if (role == 'staff') {
        Navigator.of(context).pushReplacementNamed(
          '/staff/home',
          arguments: {
            'initialTab': 3, // Announcements tab for staff
            'announcementId': announcementId,
          },
        );
      } else if (role == 'admin') {
        Navigator.of(context).pushReplacementNamed(
          '/admin/home',
          arguments: {
            'initialTab': 4, // Announcements tab for admin (adjust based on your structure)
            'announcementId': announcementId,
          },
        );
      }
    } catch (e) {
      print('❌ Error navigating to announcement: $e');
      _showErrorDialog(context, 'Failed to navigate to announcement');
    }
  }

  void _navigateToAnnouncementsList(BuildContext context) {
    Navigator.of(context).pushNamed('/announcements');
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


}

Future<void> initializeServices() async {
  if (_servicesInitialized) {
    print('⚠️ Services already initialized');
    return;
  }

  try {
    print('🚀 Starting service initialization...');
    
    // Step 1: Initialize Firebase FIRST
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
    
    // ✅ CRITICAL: Wait for Firebase to be fully ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Step 2: Test Firebase Auth (ensures platform channels are ready)
    try {
      final _ = FirebaseAuth.instance.currentUser;
      print('✅ Firebase Auth ready');
    } catch (e) {
      print('⚠️ Firebase Auth not ready: $e');
    }
    
    // Step 4: Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Background message handler registered');
    
    // Step 5: Initialize notification service
    print('🔔 Initializing notification service...');
    await NotificationService().initialize();
    print('✅ Notification service initialized');
    
    // Step 6: Setup navigation handler
    NotificationNavigationHandler(navigatorKey).setup();
    print('✅ Navigation handler setup complete');
    
    _servicesInitialized = true;
    print('✅ All services initialized successfully');
  } catch (e, stackTrace) {
    print('❌ Service initialization error: $e');
    print('Stack trace: $stackTrace');
    // Don't rethrow - allow app to continue with degraded functionality
  }
}
// 

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
    
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );

    // ✅ Initialize all services and WAIT for completion
    await initializeServices();
    
    // ✅ Additional delay to ensure platform channels are fully connected
    await Future.delayed(const Duration(milliseconds: 300));

    runApp(
      MultiProvider(
        providers: [
          Provider<CohereService>(create: (_) => CohereService()),
          ProxyProvider<CohereService, AnswerRetrievalService>(
            update: (_, cohere, __) => AnswerRetrievalService(),
          ),
          ChangeNotifierProxyProvider<AnswerRetrievalService, ChatProvider>(
            create: (_) => ChatProvider(AnswerRetrievalService()),
            update: (_, retriever, __) => ChatProvider(retriever),
          ),
          Provider<PineconeCloudService>(create: (_) => PineconeCloudService()),
          
          // ✅ CRITICAL FIX: Create service lazily and only when needed
          Provider<FirebaseFunctionsService>(
            create: (_) {
              print('🔧 Creating FirebaseFunctionsService instance');
              return FirebaseFunctionsService();
            },
            // ✅ Don't dispose the static instance
            dispose: (_, __) => print('📌 FirebaseFunctionsService provider disposed'),
          ),
          
          Provider<NotificationService>.value(
            value: NotificationService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stackTrace) {
    print('🔴 Zone Error: $error');
    print('🧩 StackTrace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Use global navigator key
      debugShowCheckedModeBanner: false,
      title: 'OASP Assist',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.3),
          ),
        ),
      ),
      home: const AppInitializer(),
      routes: {
         '/admin/home': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    print('📍 /admin/home route called');
    print('📍 Arguments: $args');
    
    return AdminMainPage(
      initialTabIndex: args?['initialTab'] as int?,
      escalationId: args?['escalationId'] as String?,
      conversationId: args?['conversationId'] as String?,
      autoOpen: args?['autoOpen'] as bool? ?? false,
    );
  },

  '/admin/escalations': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final escalationId = args?['escalationId'] as String?;
    final autoOpen = args?['autoOpen'] as bool? ?? false;
    return HumanEscalation(
      initialEscalationId: escalationId,
      autoOpen: autoOpen,
    );
  },
  
        '/onboarding': (context) => const OnboardingScreen(),
        '/userOnboarding': (context) => const UserOnboardingScreen(userId: '', userName: '',),
        '/auth': (context) => AuthPage(),
    '/home': (context) {
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  
  print('🏠 /home route called with args: $args');
  
  final initialTab = args?['initialTab'] as int?;
  final conversationId = args?['conversationId'] as String?;
  final loadExisting = args?['loadExisting'] as bool?;
  
  return UserMainPage(
    initialTabIndex: initialTab,
    conversationId: conversationId,
    loadExisting: loadExisting,
    fromNotification: loadExisting ?? false,
  );
},
        '/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final conversationId = args?['conversationId'] as String? ?? '';
          return ChatPage(conversationId: conversationId);
        },
        '/informationBank': (context) => InformationBankPage(),
        '/announcements': (context) => const UserAnnouncementPage(),
        '/announcements/detail': (context) {
          return const UserAnnouncementPage();
        },
        '/admission': (context) => AdmissionInfo(),
        '/scholarships': (context) => ScholarshipList(),
        '/placements': (context) => PlacementInfo(),
        '/staff/home': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    print('📍 /staff/home route called');
    print('📍 Arguments: $args');
    
    return StaffMainPage(
      initialTabIndex: args?['initialTab'] as int?,
      escalationId: args?['escalationId'] as String?,
      conversationId: args?['conversationId'] as String?,
      autoOpen: args?['autoOpen'] as bool? ?? false,
    );
  },
        '/staff/escalations': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final escalationId = args?['escalationId'] as String?;
          final autoOpen = args?['autoOpen'] as bool? ?? false;
          return HumanEscalation(
            initialEscalationId: escalationId,
            autoOpen: autoOpen,
          );
        },
      },
    );
  }
}

class OnboardingManager {
  static const String _appOnboardingKey = 'app_onboarding_completed';
  static const String _userOnboardingPrefix = 'user_onboarding_completed';

  static Future<bool> hasSeenAppOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appOnboardingKey) ?? false;
  }

  static Future<bool> hasSeenUserOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_userOnboardingPrefix}_$userId') ?? false;
  }

  static Future<void> setAppOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appOnboardingKey, true);
  }

  static Future<void> setUserOnboardingCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_userOnboardingPrefix}_$userId', true);
  }

  static Future<void> handleFirstTimeLogin(BuildContext context, String userId, String userName) async {
    try {
      final hasSeenUserOnboarding = await OnboardingManager.hasSeenUserOnboarding(userId);
      
      if (!hasSeenUserOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => UserOnboardingScreen(
              userId: userId,
              userName: userName,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      print('Error handling first time login: $e');
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}

class AppInitializer extends StatelessWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingManager.hasSeenAppOnboarding(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasError) {
          return const ErrorScreen();
        }

        final hasSeenAppOnboarding = snapshot.data ?? false;

        if (!hasSeenAppOnboarding) {
          return const OnboardingScreen();
        } else {
          return AuthPage();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'OASP Assist',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please try again later',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/auth');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF667EEA),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Continue to App',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}