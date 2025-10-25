import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:capstone_project/notifications.dart';
import 'package:capstone_project/pages/user_pages/chat_page.dart';
import 'package:capstone_project/profile.dart' show ProfileModal;
import 'package:capstone_project/provider/chat_provider.dart';
import 'package:capstone_project/responsive/widgets/logout.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_group.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_item.dart';

import 'package:provider/provider.dart';

class UserConstant {
  static final TextEditingController _controller = TextEditingController();
  static final ScrollController _scrollController = ScrollController();

  static bool _isOASPAassistExpanded = false; // Changed to false by default

  static List<Map<String, dynamic>> _recentConversations = [];
  static String? _selectedConversationId;
  static StreamSubscription<QuerySnapshot>? _conversationsSubscription;

  // ADD: Flag to prevent multiple initializations
  static bool _isInitializing = false;
  static bool _isInitialized = false;

  static Map<String, List<Map<String, String>>>? _cachedFAQs;
  static DateTime? _faqCacheTime;
  static const Duration _faqCacheExpiry = Duration(hours: 1);

  static bool _isServicesExpanded = false;

  // Fixed logout method that handles both Firebase Auth and Google Sign In
  static Future<void> signUserOut() async {
    try {
      // Cancel any active subscriptions
      cancelConversationSubscription();

      final user = FirebaseAuth.instance.currentUser;
      String name = 'Unknown';

      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          name = userData['name'] ?? user.email ?? 'Unknown';

          // Create log before signing out
          final logRef = FirebaseFirestore.instance.collection('logs').doc();
          final logData = {
            'logId': logRef.id,
            'user': name,
            'action': 'Logged Out',
            'time': Timestamp.now(),
          };

          await logRef.set(logData);
        }
      }

      // Sign out from Google if not on Windows
      if (!Platform.isWindows) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } else {
        print("DEBUG: Skipping Google sign-out on Windows.");
      }

      // ✅ Always sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
      print('DEBUG: User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');

      // Optional: ensure Firebase signout even on error
      try {
        await FirebaseAuth.instance.signOut();
      } catch (inner) {
        print('Error forcing Firebase signout: $inner');
      }
    }
  }

  // Helper method to show the new improved logout dialog with loading
  static Future<void> showLogoutDialog(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout Confirmation',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return LogoutDialogContent(isMobile: isMobile);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  static Future<void> initializeChatSession(
    BuildContext context,
    Function setState,
  ) async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing) {
      print('DEBUG: Initialization already in progress, skipping...');
      return;
    }

    // If already initialized, just subscribe to updates
    if (_isInitialized) {
      print('DEBUG: Already initialized, just subscribing to conversations...');
      subscribeToRecentConversations(context, setState);
      return;
    }

    _isInitializing = true;
    print('DEBUG: Initializing chat session...');

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('DEBUG: No user logged in, cannot initialize chat');
      _isInitializing = false;
      return;
    }

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Check for active conversation
      final activeConversation = await findActiveConversation(userId);

      if (activeConversation != null) {
        // Check if conversation is older than 3 days
        final data = activeConversation.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final daysSinceCreation = DateTime.now().difference(createdAt).inDays;

          if (daysSinceCreation >= 3) {
            // End old conversation automatically
            print('DEBUG: Auto-ending conversation older than 3 days');
            await _endConversation(activeConversation.id);

            // Clear messages and reset state
            chatProvider.clearMessages();
            setState(() {
              _selectedConversationId = null;
            });
          } else {
            // Continue existing active conversation
            print(
              'DEBUG: Found active conversation: ${activeConversation.id} - CONTINUING IT',
            );
            await _continueExistingConversation(
              context,
              activeConversation.id,
              chatProvider,
              setState,
            );
          }
        }
      } else {
        // NO AUTO-CREATION: Just wait for user to start new chat
        print(
          'DEBUG: No active conversation found - waiting for user to start new chat',
        );
        chatProvider.clearMessages();
        setState(() {
          _selectedConversationId = null;
        });
      }

      // Subscribe to conversation updates
      subscribeToRecentConversations(context, setState);

      _isInitialized = true;
      print('DEBUG: Chat session initialization completed');
    } catch (e) {
      print('DEBUG: Error initializing chat session: $e');
      _showErrorSnackBar(context, 'Failed to initialize chat: ${e.toString()}');
    } finally {
      _isInitializing = false;
    }
  }

  // FIXED: Simplified continue existing conversation
  static Future<void> _continueExistingConversation(
    BuildContext context,
    String conversationId,
    ChatProvider chatProvider,
    Function setState,
  ) async {
    print('DEBUG: Continuing conversation: $conversationId');

    setState(() {
      _selectedConversationId = conversationId;
    });

    await chatProvider.setConversationId(conversationId);
    // Don't clear messages - let them load from the existing conversation

    print('DEBUG: Successfully continued existing conversation');
  }

  static Future<String> createNewConversation() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('No authenticated user');

    try {
      // End any existing active conversations
      final activeQuery =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .get();

      for (final doc in activeQuery.docs) {
        await doc.reference.update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create new conversation
      final firestore = FirebaseFirestore.instance;
      final conversationRef = await firestore.collection('conversations').add({
        'userId': userId,
        'title': 'New Conversation',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Created new conversation: ${conversationRef.id}');
      return conversationRef.id;
    } catch (e) {
      print('DEBUG: Error creating new conversation: $e');
      rethrow;
    }
  }

  // FIXED: Show all conversations instead of limiting to 5 active ones
  static void subscribeToRecentConversations(
    BuildContext context,
    Function setState,
  ) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    print('DEBUG: Starting subscription for user: $userId');

    if (userId == null) {
      print('DEBUG: No user logged in, cannot subscribe to conversations');
      return;
    }

    // Cancel existing subscription to prevent duplicates
    _conversationsSubscription?.cancel();
    print('DEBUG: Setting up Firestore listener...');

    _conversationsSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        // Removed status filter to show all conversations
        .orderBy('createdAt', descending: true)
        // Removed limit to show all conversations
        .snapshots()
        .listen(
          (querySnapshot) {
            print(
              'DEBUG: Listener triggered with ${querySnapshot.docs.length} docs',
            );

            if (querySnapshot.docs.isEmpty) {
              print('DEBUG: No conversations found for user $userId');
            }

            final conversations =
                querySnapshot.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  print(
                    'DEBUG: Found conversation - ID: ${doc.id}, Title: ${data['title']}, Status: ${data['status']}',
                  );

                  return {
                    'id': doc.id,
                    'title': data['title'] ?? 'Untitled',
                    'status': data['status'] ?? 'unknown',
                    'createdAt': data['createdAt'],
                  };
                }).toList();

            print('DEBUG: Processed ${conversations.length} conversations');

            try {
              setState(() {
                _recentConversations = conversations;

                // Auto-select the first active conversation if none selected
                if (_selectedConversationId == null &&
                    conversations.isNotEmpty) {
                  final activeConversations =
                      conversations
                          .where((c) => c['status'] == 'active')
                          .toList();
                  if (activeConversations.isNotEmpty) {
                    _selectedConversationId = activeConversations[0]['id'];
                  }
                }

                print(
                  'DEBUG: Updated UI with ${conversations.length} conversations',
                );
                print('DEBUG: Selected conversation: $_selectedConversationId');
              });
            } catch (e) {
              print('DEBUG: Error updating UI: $e');
            }
          },
          onError: (error) {
            print('DEBUG: Firestore listener error: $error');
          },
        );
  }

static Future<void> onConversationSelected(
  BuildContext context,
  String? conversationId,
) async {
  print('DEBUG: Selecting conversation: $conversationId');

  if (conversationId == null || !context.mounted) return;

  try {
    await setSelectedConversation(conversationId);
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.setConversationId(conversationId);
    
    print('DEBUG: Conversation selected successfully');
  } catch (e) {
    print('DEBUG: Error selecting conversation: $e');
  }
}


  // End a conversation
  static Future<void> _endConversation(String conversationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
      print('DEBUG: Ended conversation: $conversationId');
    } catch (e) {
      print('DEBUG: Error ending conversation: $e');
    }
  }

  static Future<void> deleteAllConversations() async {
    final firestore = FirebaseFirestore.instance;

    // Get all conversation documents
    final conversationsSnapshot =
        await firestore.collection('conversations').get();

    for (final convoDoc in conversationsSnapshot.docs) {
      final convoId = convoDoc.id;

      // Delete all messages in this conversation
      final messagesSnapshot =
          await firestore
              .collection('conversations')
              .doc(convoId)
              .collection('messages')
              .get();

      for (final messageDoc in messagesSnapshot.docs) {
        await firestore
            .collection('conversations')
            .doc(convoId)
            .collection('messages')
            .doc(messageDoc.id)
            .delete();
      }

      // Delete the conversation itself
      await firestore.collection('conversations').doc(convoId).delete();
      print('Deleted conversation $convoId with its messages.');
    }

    print('All conversations and messages deleted.');
  }

  static Future<void> deleteConversation(String conversationId) async {
    try {
      print('DEBUG: Deleting conversation: $conversationId');

      final firestore = FirebaseFirestore.instance;

      // Delete all messages in this conversation
      final messagesSnapshot =
          await firestore
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .get();

      // Use batch delete for efficiency
      final batch = firestore.batch();

      for (final messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }

      // Delete the conversation document itself
      batch.delete(firestore.collection('conversations').doc(conversationId));

      await batch.commit();

      print('DEBUG: Successfully deleted conversation and its messages');

      // If this was the selected conversation, clear the selection
      if (_selectedConversationId == conversationId) {
        _selectedConversationId = null;
      }

      // Remove from recent conversations list
      _recentConversations.removeWhere((conv) => conv['id'] == conversationId);
    } catch (e) {
      print('DEBUG: Error deleting conversation: $e');
      rethrow;
    }
  }

  static Future<String> findOrCreateConversation() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('No authenticated user');

    try {
      // Try to find existing active conversation
      final activeQuery =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();

      if (activeQuery.docs.isNotEmpty) {
        final conversationId = activeQuery.docs.first.id;
        print('DEBUG: Found existing conversation: $conversationId');
        return conversationId;
      }

      // Create new conversation if none exists
      print('DEBUG: Creating new conversation...');
      final firestore = FirebaseFirestore.instance;
      final conversationRef = await firestore.collection('conversations').add({
        'userId': userId,
        'title': 'New Conversation',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Created new conversation: ${conversationRef.id}');
      return conversationRef.id;
    } catch (e) {
      print('DEBUG: Error in findOrCreateConversation: $e');
      rethrow;
    }
  }

  // Enhanced find active conversation
  static Future<QueryDocumentSnapshot?> findActiveConversation(
    String userId,
  ) async {
    try {
      print('DEBUG: Looking for active conversations for user: $userId');

      final activeQuery =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .orderBy('createdAt', descending: true)
              .get();

      print('DEBUG: Found ${activeQuery.docs.length} active conversations');

      if (activeQuery.docs.isNotEmpty) {
        // Clean up old conversations (older than 3 days)
        final now = DateTime.now();

        for (var doc in activeQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          if (createdAt != null) {
            final daysSinceCreation = now.difference(createdAt).inDays;

            if (daysSinceCreation >= 3) {
              // Auto-end old conversations
              print(
                'DEBUG: Auto-ending old conversation: ${doc.id} (${daysSinceCreation} days old)',
              );
              await doc.reference.update({
                'status': 'ended',
                'endedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        // Return the most recent non-expired conversation
        for (var doc in activeQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          if (createdAt != null) {
            final daysSinceCreation = now.difference(createdAt).inDays;

            if (daysSinceCreation < 3) {
              print('DEBUG: Using existing active conversation: ${doc.id}');
              return doc;
            }
          }
        }
      }

      print('DEBUG: No valid active conversations found');
      return null;
    } catch (e) {
      print('DEBUG: Error finding active conversation: $e');
      return null;
    }
  }

  // UPDATED: New Chat will end active conversation and create a new one
  static Future<void> startNewChat(
    BuildContext context, [
    String? firstUserMessage,
    bool pushIfNeeded = true,
  ]) async {
    print('DEBUG: Starting new chat...');

    if (!context.mounted) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showErrorSnackBar(context, 'Please log in to start a chat');
      return;
    }

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // FIXED: End ALL active conversations before creating new one
      await _endAllActiveConversations(userId);

      // Clear messages first
      chatProvider.clearMessages();

      // Create new conversation
      final newConversationId = await _createNewConversation(userId);

      // Set up the new conversation
      await chatProvider.setConversationId(newConversationId);

      // Update the static variable directly (no setState needed in static context)
      _selectedConversationId = newConversationId;

      // REMOVED: Navigation logic - let parent handle tab switching
      // The parent (UserMainPage) should handle switching to chat tab

      // Clear any input field if present
      _controller.clear();

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.refresh, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('New chat started!'),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('DEBUG: Error starting new chat: $e');
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Failed to start new chat: ${e.toString()}',
        );
      }
    }
  }

  static Future<void> _endAllActiveConversations(String userId) async {
    try {
      print('DEBUG: Ending all active conversations for user: $userId');

      final activeQuery =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in activeQuery.docs) {
        batch.update(doc.reference, {
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
        print('DEBUG: Marking conversation ${doc.id} as ended');
      }

      if (activeQuery.docs.isNotEmpty) {
        await batch.commit();
        print(
          'DEBUG: Successfully ended ${activeQuery.docs.length} conversations',
        );
      }
    } catch (e) {
      print('DEBUG: Error ending active conversations: $e');
      rethrow;
    }
  }

  static Future<String> _createNewConversation(String userId) async {
    try {
      print('DEBUG: Creating new conversation for user: $userId');

      final firestore = FirebaseFirestore.instance;
      final conversationRef = await firestore.collection('conversations').add({
        'userId': userId,
        'title': 'New Conversation',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'messageCount': 0,
      });

      print('DEBUG: Created new conversation: ${conversationRef.id}');
      return conversationRef.id;
    } catch (e) {
      print('DEBUG: Error creating new conversation: $e');
      rethrow;
    }
  }

  // NEW: Navigate to chat page without creating conversation
  // FIXED: Navigate to chat without auto-creating
  static Future<void> navigateToChatPage(
    BuildContext context, {
    bool pushIfNeeded = true,
  }) async {
    print('DEBUG: Navigating to chat page...');

    if (!context.mounted) {
      print('DEBUG: Context not mounted at start');
      return;
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      _showErrorSnackBar(context, 'Please log in to access chat');
      return;
    }

    try {
      // Close drawer (if open)

      await Future.delayed(const Duration(milliseconds: 500));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // triggers Drawer's close animation
      }

      // Find active conversation (with auto-cleanup)
      final activeConversation = await findActiveConversation(userId);
      String? conversationId;

      if (activeConversation != null) {
        print('DEBUG: Found active conversation: ${activeConversation.id}');
        conversationId = activeConversation.id;

        // Update provider with existing conversation
        await chatProvider.setConversationId(conversationId);
      } else {
        print('DEBUG: No active conversation - clearing messages');
        // No active conversation - just clear messages, don't create new one
        chatProvider.clearMessages();
      }

      if (!context.mounted) return;

      // Navigate if needed
      if (pushIfNeeded && ModalRoute.of(context)?.settings.name != '/chat') {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/chat'),
            builder:
                (context) => ChatPage(conversationId: conversationId ?? ''),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error navigating to chat: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to access chat: ${e.toString()}');
      }
    }
  }

  static Future<void> cleanupOldConversations() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      print('DEBUG: Running cleanup of old conversations...');

      final now = DateTime.now();
      final threeDaysAgo = now.subtract(Duration(days: 3));

      final oldConversations =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .where('createdAt', isLessThan: Timestamp.fromDate(threeDaysAgo))
              .get();

      if (oldConversations.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();

        for (final doc in oldConversations.docs) {
          batch.update(doc.reference, {
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        print(
          'DEBUG: Auto-ended ${oldConversations.docs.length} old conversations',
        );
      }
    } catch (e) {
      print('DEBUG: Error during cleanup: $e');
    }
  }


  static Future<Map<String, List<Map<String, String>>>> getCachedFAQs() async {
    // Return cached FAQs if valid
    if (_cachedFAQs != null && 
        _faqCacheTime != null && 
        DateTime.now().difference(_faqCacheTime!) < _faqCacheExpiry) {
      print('Returning cached FAQs');
      return _cachedFAQs!;
    }
    
    // Fetch fresh FAQs
    print('Fetching fresh FAQs');
    final faqs = await _fetchFAQsFromFirestore();
    _cachedFAQs = faqs;
    _faqCacheTime = DateTime.now();
    return faqs;
  }
  
  // Clear FAQ cache (call this when FAQs are updated)
  static void clearFAQCache() {
    _cachedFAQs = null;
    _faqCacheTime = null;
  }
  
  static Future<Map<String, List<Map<String, String>>>> _fetchFAQsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('faqs')
          .get()
          .timeout(Duration(seconds: 10));
      
      final Map<String, List<Map<String, String>>> groupedFAQs = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'General';
        final question = data['question'];
        
        if (question != null && question.isNotEmpty) {
          groupedFAQs.putIfAbsent(category, () => []).add({
            'question': question,
          });
        }
      }
      
      return groupedFAQs;
    } catch (e) {
      print('Error fetching FAQs: $e');
      return {};
    }
  }

  // FIXED: Enhanced dispose method
  static void dispose() {
    print('DEBUG: Disposing conversation manager...');
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
    _controller.dispose();

    // Reset initialization flags
    _isInitializing = false;
    _isInitialized = false;
  }

  // FIXED: Reset method for when user logs out/changes
  static void reset() {
    print('DEBUG: Resetting conversation manager...');
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
    _recentConversations.clear();
    _selectedConversationId = null;
    _isInitializing = false;
    _isInitialized = false;
  }

  // Getters for accessing private variables
  static List<Map<String, dynamic>> get recentConversations =>
      _recentConversations;
  static String? get selectedConversationId => _selectedConversationId;
  static bool get isOASPAssistExpanded => _isOASPAassistExpanded;

  // Setters
  static set isOASPAssistExpanded(bool value) {
    _isOASPAassistExpanded = value;
  }

  // NEW METHOD Selected conversation set to: $conversationId :

  static Future<void> setSelectedConversation(String conversationId) async {
    _selectedConversationId = conversationId;
    print('DEBUG: Selected conversation set to: $conversationId');
  }

  // Helper method for showing error messages
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // NEW: Debug method to check conversations manually
  static Future<void> debugCheckConversations() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('DEBUG: No user logged in');
      return;
    }

    try {
      print('DEBUG: Manually checking conversations for user: $userId');

      final snapshot =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .get();

      print('DEBUG: Found ${snapshot.docs.length} total conversations');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('DEBUG: Conversation ${doc.id}:');
        print('  - Title: ${data['title']}');
        print('  - Status: ${data['status']}');
        print('  - Created: ${data['createdAt']}');
        print('  - User ID: ${data['userId']}');
      }
    } catch (e) {
      print('DEBUG: Error checking conversations: $e');
    }
  }

  // NEW: Cancel subscription method
  static void cancelConversationSubscription() {
    print('DEBUG: Cancelling conversation subscription');
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
  }

  static void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  static Future<void> cleanupDuplicateConversations() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      print('DEBUG: Cleaning up duplicate active conversations...');

      final activeConversations =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .orderBy('createdAt', descending: true)
              .get();

      if (activeConversations.docs.length > 1) {
        print(
          'DEBUG: Found ${activeConversations.docs.length} active conversations, keeping most recent',
        );

        // Keep the most recent one, end the rest
        for (int i = 1; i < activeConversations.docs.length; i++) {
          await activeConversations.docs[i].reference.update({
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
          });
          print(
            'DEBUG: Ended duplicate conversation: ${activeConversations.docs[i].id}',
          );
        }
      }
    } catch (e) {
      print('DEBUG: Error cleaning up conversations: $e');
    }
  }

  static var myDefaultBackground = Colors.grey[50];
}
