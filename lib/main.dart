import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/auth_pages/auth_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/auth_pages/email_verification_page.dart';
import 'package:capstone_project/onboarding/onboarding.dart';

import 'package:capstone_project/onboarding/useronboarding.dart';
import 'package:capstone_project/pages/admin_pages/information_bank_page.dart';
import 'package:capstone_project/pages/user_pages/admission_info.dart';
import 'package:capstone_project/pages/user_pages/chat_page.dart';
import 'package:capstone_project/pages/user_pages/home.dart';
import 'package:capstone_project/pages/user_pages/placement_info.dart';
import 'package:capstone_project/pages/user_pages/scholarship_list.dart';
import 'package:capstone_project/pages/user_pages/user_announcement.dart';
import 'package:capstone_project/pages/user_pages/user_main_page.dart';
import 'package:capstone_project/provider/chat_provider.dart';
import 'package:capstone_project/services/admin_functions.dart';
import 'package:capstone_project/services/answer_retrieval.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:capstone_project/services/pinecone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Global initialization flag
bool _servicesInitialized = false;

Future<void> initializeServices() async {
  if (_servicesInitialized) {
    print('⚠️ Services already initialized');
    return;
  }

  try {
    print('🚀 Starting service initialization...');
    
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Initialize Cloud Functions IMMEDIATELY after Firebase
    // This ensures it's ready before any widget tries to use it
    FirebaseFunctionsService().initialize(
      region: 'us-central1',
      useEmulator: false,
    );
    print('✅ Cloud Functions service initialized');
    
    _servicesInitialized = true;
    print('✅ All services initialized successfully');
    
  } catch (e, stackTrace) {
    print('❌ Service initialization error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize all services BEFORE running the app
    await initializeServices();

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
          // FirebaseFunctionsService uses singleton pattern, so this returns the already-initialized instance
          Provider<FirebaseFunctionsService>.value(value: FirebaseFunctionsService()),
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
        '/onboarding': (context) => const OnboardingScreen(),
        '/userOnboarding': (context) => const UserOnboardingScreen(userId: '', userName: '',),
        '/auth': (context) => AuthPage(),
     
        '/home': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final initialTab = args?['initialTab'] as int?;
          return UserMainPage(initialTabIndex: initialTab);
        },
        '/chat': (context) => ChatPage(conversationId: ''),
        '/informationBank': (context) => InformationBankPage(),
        '/announcements': (context) => const UserAnnouncementPage(),
        '/admission': (context) => AdmissionInfo(),
        '/scholarships': (context) => ScholarshipList(),
        '/placements': (context) => PlacementInfo(),
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