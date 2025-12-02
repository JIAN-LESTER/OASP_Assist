import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:capstone_project/responsive/user_constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:capstone_project/models/conversations.dart';
import 'package:capstone_project/models/message.dart';

import 'package:capstone_project/services/answer_retrieval.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

// Cache classes for better performance
class FAQCache {
  static Map<String, Map<String, dynamic>> cache = {};
  static DateTime lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration cacheExpiry = Duration(
    hours: 2,
  ); // ⚡ Increased from 1 hour

  static bool get isExpired =>
      DateTime.now().difference(lastCacheUpdate) > cacheExpiry;

  static void updateCache(List<QueryDocumentSnapshot> docs) {
    cache.clear();
    for (var doc in docs) {
      cache[doc.id] = doc.data() as Map<String, dynamic>;
    }
    lastCacheUpdate = DateTime.now();
  }
}

class EmbeddingCache {
  static final Map<String, List<double>> _cache = {};
  static const int maxSize = 1000; // ⚡ Increased from 500

  static List<double>? get(String key) => _cache[key];

  static void put(String key, List<double> value) {
    if (_cache.length >= maxSize) {
      final oldestKeys = _cache.keys.take(_cache.length - maxSize + 1);
      for (final oldKey in oldestKeys) {
        _cache.remove(oldKey);
      }
    }
    _cache[key] = value;
  }
}

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnswerRetrievalService _retriever;
  CohereService? _cohere;
  bool isNowAddedToFAQ = false;
  int count = 1;

  final String _geminiApiKey = "AIzaSyBEsKofC_0dTYRNwFhjnnY8jzuhmQqbHQI";
  VoidCallback? _onMessageAdded;

  ChatProvider(this._retriever);

  //  ADDED TWO METHODS:
  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_welcome') ?? false;
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
  }

  final Map<String, String> _pendingRatingsCache = {};
  String? getCachedRating(String messageId) => _pendingRatingsCache[messageId];

  final List<Message> _messages = [];
  List<Message> get messages => _messages;

  String? conversationId;
  Conversation? currentConversation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  static const int MAX_DAILY_MESSAGES = 5;

  StreamSubscription<DocumentSnapshot>? _userMessageCountSubscription;

  int _userDailyMessageCount = 0;
  DateTime? _userLastResetDate;

  int get userDailyMessageCount => _userDailyMessageCount;

  final escalationResponseKeywords = [
    "i'm not sure",
    "i'm sorry",
    "i don't have",
    "i cannot help with that",
    "i don't understand",
    "i don't know",
    "sorry, i don't have an answer",
    "beyond my capabilities",
    "unable to assist",
    "contact support",
    "speak with staff",
    "reach out to the registrar",
    "recommend speaking with",
  ];

  void listenToUserMessageCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _userMessageCountSubscription?.cancel();

    _userMessageCountSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data()!;
              final newCount = data['dailyMessageCount'] ?? 0;
              final newResetDate =
                  (data['lastMessageResetDate'] as Timestamp?)?.toDate();

              // ✅ Only update if values actually changed
              if (newCount != _userDailyMessageCount ||
                  newResetDate != _userLastResetDate) {
                _userDailyMessageCount = newCount;
                _userLastResetDate = newResetDate;

                print(
                  '📊 Real-time update: User message count = $_userDailyMessageCount',
                );
                notifyListeners();
              }
            } else {
              // Document doesn't exist yet - initialize
              print(
                '⚠️ User document not found - will be created on first message',
              );
              _userDailyMessageCount = 0;
              _userLastResetDate = null;
              notifyListeners();
            }
          },
          onError: (error) {
            print('❌ Error in message count listener: $error');
          },
        );
  }

  void setScrollCallback(VoidCallback callback) {
    _onMessageAdded = callback;
  }

  void clearScrollCallback() {
    _onMessageAdded = null;
  }

  bool get canSendMessage {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final now = DateTime.now();

    // ✅ NEW USER CHECK: If count is 0 and no reset date, they can send
    // (This is a brand new user who hasn't been initialized yet)
    if (_userDailyMessageCount == 0 && _userLastResetDate == null) {
      print('ℹ️ New user detected - allowing first message');
      return true;
    }

    // ✅ RESET CHECK: If we need to reset, allow sending
    if (_userLastResetDate != null) {
      final resetTime = DateTime(now.year, now.month, now.day, 6, 0, 0);

      final shouldReset =
          now.isAfter(resetTime) &&
          (_userLastResetDate!.isBefore(resetTime) ||
              _userLastResetDate!.day != now.day);

      if (shouldReset) {
        print('ℹ️ Reset time reached - allowing message');
        return true;
      }
    }

    // ✅ LIMIT CHECK: Can send if count is LESS than limit
    // With MAX = 5: counts 0,1,2,3,4 can send → total 5 messages allowed
    final canSend = _userDailyMessageCount < MAX_DAILY_MESSAGES;

    print('🔍 Message limit check:');
    print('   Current count: $_userDailyMessageCount');
    print('   Max allowed: $MAX_DAILY_MESSAGES');
    print('   Can send: $canSend');

    return canSend;
  }

  // Keep the old getter for backward compatibility but use the new logic
  bool get isMessageLimitReached => !canSendMessage;

  // // Replace the isMessageLimitReached getter in chat_provider.dart with this:

  // bool get isMessageLimitReached {
  //   final userId = FirebaseAuth.instance.currentUser?.uid;
  //   if (userId == null) return false;

  //   final now = DateTime.now();

  //   // ✅ CRITICAL FIX: If values haven't been loaded yet (both are initial values),
  //   // assume user can send messages (don't block new users)
  //   if (_userDailyMessageCount == 0 && _userLastResetDate == null) {
  //     return false; // Brand new user or data not loaded yet
  //   }

  //   // If we have a reset date, check if we need to reset
  //   if (_userLastResetDate != null) {
  //     final resetTime = DateTime(now.year, now.month, now.day, 6, 0, 0);

  //     // Check if it's past 6 AM and the last reset was before today's 6 AM
  //     final shouldReset =
  //         now.isAfter(resetTime) &&
  //         (_userLastResetDate!.isBefore(resetTime) ||
  //             _userLastResetDate!.day != now.day);

  //     if (shouldReset) {
  //       return false; // Time to reset, allow messages
  //     }
  //   }

  //   // If we have a non-zero count but no reset date (edge case from old data),
  //   // allow reset
  //   if (_userDailyMessageCount > 0 && _userLastResetDate == null) {
  //     return false; // Reset needed
  //   }

  //   // Check if limit reached
  //   return _userDailyMessageCount >= MAX_DAILY_MESSAGES;
  // }

  Duration getTimeUntilReset() {
    final now = DateTime.now();
    DateTime nextReset;

    if (now.hour < 6) {
      // Reset is today at 6 AM
      nextReset = DateTime(now.year, now.month, now.day, 6, 0, 0);
    } else {
      // Reset is tomorrow at 6 AM
      nextReset = DateTime(now.year, now.month, now.day + 1, 6, 0, 0);
    }

    return nextReset.difference(now);
  }

  Future<void> loadUserMessageCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userDailyMessageCount = data['dailyMessageCount'] ?? 0;
        _userLastResetDate =
            (data['lastMessageResetDate'] as Timestamp?)?.toDate();

        print(
          '✅ Loaded user message count: $_userDailyMessageCount/$MAX_DAILY_MESSAGES',
        );
      } else {
        // ✅ NEW: Initialize brand new users properly
        _userDailyMessageCount = 0;
        _userLastResetDate = null;

        // Create the document with initial values
        await _firestore.collection('users').doc(userId).set({
          'dailyMessageCount': 0,
          'lastMessageResetDate': Timestamp.now(),
        }, SetOptions(merge: true));

        print(
          '✅ Initialized new user with message count: 0/$MAX_DAILY_MESSAGES',
        );
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error loading user message count: $e');
    }
  }

  Future<void> _updateUserMessageCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final userRef = _firestore.collection('users').doc(userId);

      // Get current data
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        // ✅ Brand new user - create document and set count to 1
        await userRef.set({
          'dailyMessageCount': 1,
          'lastMessageResetDate': Timestamp.now(),
        }, SetOptions(merge: true));

        _userDailyMessageCount = 1;
        _userLastResetDate = now;

        print('✅ New user first message - count set to 1');
        notifyListeners();
        return;
      }

      // Existing user - check if reset needed
      final data = userDoc.data()!;
      final currentCount = data['dailyMessageCount'] ?? 0;
      final lastReset = (data['lastMessageResetDate'] as Timestamp?)?.toDate();

      final resetTime = DateTime(now.year, now.month, now.day, 6, 0, 0);
      final shouldReset =
          lastReset == null ||
          (now.isAfter(resetTime) &&
              (lastReset.isBefore(resetTime) || lastReset.day != now.day));

      if (shouldReset) {
        // ✅ Reset and set to 1 (current message)
        await userRef.update({
          'dailyMessageCount': 1,
          'lastMessageResetDate': Timestamp.now(),
        });

        _userDailyMessageCount = 1;
        _userLastResetDate = now;

        print('✅ Message count reset to 1');
      } else {
        // ✅ Increment using transaction to avoid race conditions
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          final currentCount = snapshot.data()?['dailyMessageCount'] ?? 0;
          final newCount = currentCount + 1;

          transaction.update(userRef, {'dailyMessageCount': newCount});
        });

        _userDailyMessageCount = currentCount + 1;

        print('✅ User message count incremented to $_userDailyMessageCount');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error updating user message count: $e');
    }
  }

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _isSettingConversation = false;

  Future<void> setConversationId(String id) async {
    print('🔧 ChatProvider.setConversationId: $id');

    if (_isSettingConversation) {
      print('⚠️ Already setting conversation, ignoring duplicate call');
      return;
    }

    if (conversationId == id && _messagesSubscription != null) {
      print('ℹ️ Already set to conversation $id with active subscription');
      return;
    }

    _isSettingConversation = true;

    try {
      // Cancel old subscriptions
      _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _escalationSubscription
          ?.cancel(); // ✅ NEW: Cancel old escalation listener
      _escalationSubscription = null;

      // Clear all state
      _messages.clear();
      _processedMessages.clear();
      _streamingContent.clear();
      _pendingRatingsCache.clear();

      // Reset loading flags
      _isLoading = false;

      // Set new conversation ID
      conversationId = id;
      currentConversation = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      await Future.delayed(Duration(milliseconds: 100));

      // Load conversation info
      await loadConversationInfo();

      // Load messages
      await loadExistingMessages();

      // Start message subscription
      listenToMessages();

      // ✅ NEW: Start escalation response listener
      listenToEscalationResponses();

      await Future.delayed(Duration(milliseconds: 100));

      print('✅ ChatProvider setup complete (with escalation listener)');
      print('   - Conversation ID: $conversationId');
      print('   - Messages: ${_messages.length}');
      print('   - Message subscription: ${_messagesSubscription != null}');
      print('   - Escalation subscription: ${_escalationSubscription != null}');
    } finally {
      _isSettingConversation = false;
    }
  }

  Future<void> loadConversationInfo() async {
    if (conversationId == null) return;

    try {
      final doc =
          await _firestore
              .collection('conversations')
              .doc(conversationId!)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        currentConversation = Conversation(
          id: doc.id,
          userId: data['userId'] ?? '',
          title: data['title'] ?? 'Untitled',
          status: data['status'] ?? 'active',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
        print('✅ Loaded conversation: ${currentConversation!.title}');
      } else {
        currentConversation = null;
        print('⚠️ Conversation document does not exist');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print('❌ Error loading conversation info: $e');
    }
  }

  Map<String, dynamic> _messageToMap(Message message) {
    return {
      'messageID': message.id,
      'conversationID': message.conversationId,
      'content': message.content,
      'sender': message.sender,
      'userID': message.userID,
      'message_status': message.status,
      'message_type': message.type,
      'category': message.category,
      'sent_at': Timestamp.fromDate(message.sentAt),
      'responded_at':
          message.respondedAt != null
              ? Timestamp.fromDate(message.respondedAt!)
              : null,
      'isAnswered': message.isAnswered ?? false,
      'rating': message.rating,
    };
  }

  Future<void> saveMessageToFirebase(
    String conversationId,
    Message message,
  ) async {
    try {
      final messagesRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

      await messagesRef.doc(message.id).set(_messageToMap(message));
    } catch (e) {
      print('Error saving message to Firebase: $e');
      rethrow;
    }
  }

  Future<void> loadExistingMessages() async {
    if (conversationId == null) return;

    try {
      final snapshot =
          await _firestore
              .collection('conversations')
              .doc(conversationId!)
              .collection('messages')
              .orderBy('sent_at', descending: false)
              .get();

      _messages.clear();
      _processedMessages.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final message = Message.fromJson(data);
        _messages.add(message);
        _processedMessages.add(message.id);

        // Pre-populate local ratings cache
        if (message.rating != null && message.rating!.isNotEmpty) {
          _pendingRatingsCache[message.id] = message.rating!;
        }
      }

      // ✅ CRITICAL FIX: Schedule notification after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print('Error loading existing messages: $e');
    }
  }

  StreamSubscription<QuerySnapshot>? _escalationSubscription;

  // ✅ NEW: Add real-time listener for escalation responses
  void listenToEscalationResponses() {
    if (conversationId == null) return;

    print('👂 Starting escalation response listener for: $conversationId');

    _escalationSubscription?.cancel();

    _escalationSubscription = _firestore
        .collection('escalations')
        .where('conversationId', isEqualTo: conversationId)
        .where('status', isEqualTo: 'resolved')
        .snapshots()
        .listen(
          (snapshot) async {
            print(
              '📩 Escalation snapshot received: ${snapshot.docs.length} resolved',
            );

            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                final escalation = change.doc.data();
                if (escalation == null) continue;

                final staffResponse = escalation['staffResponse'] as String?;
                final respondedBy =
                    escalation['respondedBy'] as String? ?? 'Staff';

                if (staffResponse == null || staffResponse.isEmpty) continue;

                // ✅ Check if we already have this staff response
                final staffMessageContent =
                    '**Staff Response from $respondedBy:**\n\n$staffResponse';

                final alreadyExists = _messages.any(
                  (msg) =>
                      msg.content == staffMessageContent &&
                      msg.sender == 'staff',
                );

                if (alreadyExists) {
                  print('ℹ️ Staff response already exists in memory');
                  continue;
                }

                // ✅ Also check Firestore to avoid duplicates
                final existingInFirestore =
                    await _firestore
                        .collection('conversations')
                        .doc(conversationId!)
                        .collection('messages')
                        .where('sender', isEqualTo: 'staff')
                        .where('content', isEqualTo: staffMessageContent)
                        .limit(1)
                        .get();

                if (existingInFirestore.docs.isNotEmpty) {
                  print('ℹ️ Staff response already exists in Firestore');
                  continue;
                }

                print('✨ Adding new staff response to chat');

                // ✅ Create and save staff message
                final staffMessageRef =
                    _firestore
                        .collection('conversations')
                        .doc(conversationId!)
                        .collection('messages')
                        .doc();

                final staffMessage = Message(
                  id: staffMessageRef.id,
                  conversationId: conversationId!,
                  content: staffMessageContent,
                  sender: 'staff',
                  status: 'sent',
                  type: 'text',
                  sentAt: DateTime.now(),
                );

                // Save to Firestore (will be picked up by message listener)
                await saveMessageToFirebase(conversationId!, staffMessage);

                print('✅ Staff response added successfully');
              }
            }
          },
          onError: (error) {
            print('❌ Error in escalation listener: $error');
          },
        );
  }

  void listenToMessages() {
    if (conversationId == null) return;

    print('👂 Starting message listener for conversation: $conversationId');

    _messagesSubscription = _firestore
        .collection('conversations')
        .doc(conversationId!)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
            // ✅ Skip if we're actively creating messages
            if (_isLoading) {
              print(
                '⏭️ Skipping listener update - message creation in progress',
              );
              return;
            }

            bool changed = false;

            print(
              '📩 Message snapshot received: ${snapshot.docs.length} total messages',
            );
            print('   Changes: ${snapshot.docChanges.length}');

            for (var change in snapshot.docChanges) {
              final data = change.doc.data();
              if (data == null) continue;

              final message = Message.fromJson(data);
              final index = _messages.indexWhere((m) => m.id == message.id);

              if (change.type == DocumentChangeType.added) {
                // ✅ FIX: Only add if not already in local state
                final isAlreadyLocal = _messages.any((m) => m.id == message.id);
                final isCurrentlyStreaming = _streamingContent.containsKey(
                  message.id,
                );

                if (!isAlreadyLocal && !isCurrentlyStreaming) {
                  print('➕ Adding message from Firestore: ${message.id}');
                  print('   Sender: ${message.sender}');
                  print(
                    '   Content: ${message.content.substring(0, min(50, message.content.length))}...',
                  );

                  _messages.add(message);
                  _processedMessages.add(message.id);
                  changed = true;
                } else {
                  print('⏭️ Skipping duplicate/local message: ${message.id}');
                }
              } else if (change.type == DocumentChangeType.modified) {
                if (index != -1 && !_streamingContent.containsKey(message.id)) {
                  print('✏️ Updating message: ${message.id}');
                  _messages[index] = message;
                  changed = true;
                }
              } else if (change.type == DocumentChangeType.removed) {
                if (index != -1) {
                  print('🗑️ Removing message: ${message.id}');
                  _messages.removeAt(index);
                  _processedMessages.remove(message.id);
                  changed = true;
                }
              }
            }

            if (changed) {
              _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
              print('✅ Messages updated. Total count: ${_messages.length}');

              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifyListeners();
              });
            }
          },
          onError: (error) {
            print('❌ Error listening to messages: $error');
          },
        );
  }

  void debugPrintMessageState(String context) {
    print('=== DEBUG $context ===');
    print('Messages in list: ${_messages.map((m) => m.id).join(", ")}');
    print('Processed messages: ${_processedMessages.toList()}');
    print('Streaming messages: ${_streamingContent.keys.toList()}');
    print('Is loading: $_isLoading');
    print('========================');
  }

  // Add this method to your ChatProvider class

  final Map<String, String> _streamingContent = {};
  final Set<String> _processedMessages = {}; // NEW: Track processed messages

  String? getStreamingContent(String messageId) => _streamingContent[messageId];

  Future<void> askQuestionWithStreaming(
    BuildContext context,
    String question,
  ) async {
    if (_isLoading) return;

    // Check message limit
    if (isMessageLimitReached) {
      print('❌ User daily message limit reached');
      return;
    }

    // Create conversation if needed
    if (conversationId == null || conversationId!.isEmpty) {
      print('⚠️ No conversation ID - creating new conversation');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      try {
        final newConversationId = await UserConstant.createNewConversation(
          userId,
        );
        await setConversationId(newConversationId);
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        print('❌ Error creating conversation: $e');
        return;
      }
    }

    if (conversationId == null || conversationId!.isEmpty) {
      print('❌ Still no conversation ID after creation attempt');
      return;
    }

    _isLoading = true;
    notifyListeners();

    final startTime = DateTime.now();

    try {
      _cohere ??= CohereService();
      final userId = FirebaseAuth.instance.currentUser?.uid;

      // Run embedding + FAQ load in parallel
      final results = await Future.wait([
        _generateEmbeddingCached(question),
        _ensureFAQCacheLoaded(),
      ]);

      final currentEmbedding = results[0] as List<double>;
      final existingFAQ = _findBestFAQMatch(question, currentEmbedding);

      // Determine category
      String questionCategory;
      if (existingFAQ != null && existingFAQ['category'] != null) {
        questionCategory = existingFAQ['category'] as String;
        print('✅ Using FAQ category: $questionCategory');
      } else {
        questionCategory = await _classifyQuestionCategoryFast(question);
        print('✅ Classified category: $questionCategory');
      }

      // Create user message
      final userMessageRef =
          _firestore
              .collection('conversations')
              .doc(conversationId!)
              .collection('messages')
              .doc();

      final userMsg = Message(
        id: userMessageRef.id,
        conversationId: conversationId!,
        content: question,
        userID: userId,
        category: questionCategory,
        sender: 'user',
        status: 'sent',
        isAnswered: false,
        type: 'text',
        sentAt: DateTime.now(),
        count: count,
      );

      // Add to local state FIRST
      _messages.add(userMsg);
      _processedMessages.add(userMsg.id);
      notifyListeners();
      _onMessageAdded?.call();

      // Save to Firestore
      userMessageRef.set(_messageToMap(userMsg)).catchError((e) {
        print('Error saving user message: $e');
      });

      // Increment user message count
      await _updateUserMessageCount();

      // Update conversation title if needed
      bool shouldUpdateTitle = false;
      if (currentConversation != null) {
        final title = currentConversation!.title.toLowerCase();
        shouldUpdateTitle =
            (title.contains('new conversation') ||
                title == 'untitled' ||
                title.trim().isEmpty) &&
            _messages.where((m) => m.sender == 'user').length <= 1;
      }

      if (shouldUpdateTitle) {
        await _updateConversationTitleNow(question);
      }

      // ✅ FIX: Build complete conversation history with BOTH user and bot messages
      final allMessages =
          _messages.where((m) => m.conversationId == conversationId).toList();
      allMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      // Take last 10 messages (5 exchanges) for context
      final recentHistory =
          allMessages.length > 10
              ? allMessages.sublist(allMessages.length - 10)
              : allMessages;

      print('📝 Sending conversation history:');
      print('   Total messages in conversation: ${allMessages.length}');
      print('   Recent messages being sent: ${recentHistory.length}');
      for (var msg in recentHistory) {
        print(
          '   - ${msg.sender}: ${msg.content.substring(0, min(50, msg.content.length))}...',
        );
      }

      // Create bot message placeholder
      final botMessageId = "bot_${userMsg.id}";
      final botMessage = Message(
        id: botMessageId,
        conversationId: conversationId!,
        content: "",
        sender: "bot",
        status: "sent",
        type: "text",
        sentAt: DateTime.now(),
        count: count,
      );

      // Add bot message to UI immediately
      _messages.add(botMessage);
      _streamingContent[botMessageId] = "";
      notifyListeners();
      _onMessageAdded?.call();

      String finalAnswer = "";

      // Fast path: FAQ answer
      if (existingFAQ != null) {
        final String answer = existingFAQ["answer"];
        final int chunkSize = 20;

        for (int i = 0; i < answer.length; i += chunkSize) {
          final chunk = answer.substring(
            i,
            (i + chunkSize < answer.length) ? i + chunkSize : answer.length,
          );

          _streamingContent[botMessageId] =
              _streamingContent[botMessageId]! + chunk;

          if (i % (chunkSize * 3) == 0) {
            notifyListeners();
            _onMessageAdded?.call();
          }
        }

        finalAnswer = answer;
        unawaited(_incrementFAQSimilarityCountAsync(existingFAQ["question"]));
      } else {
        // RAG streaming with complete history
        int chunkCounter = 0;

        await for (final streamedText in _retriever.generateAnswerStream(
          question,
          conversationHistory:
              recentHistory, // ✅ Now includes both user and bot messages
          conversationId: conversationId!,
        )) {
          chunkCounter++;
          _streamingContent[botMessageId] = streamedText;

          if (chunkCounter % 4 == 0) {
            notifyListeners();
            _onMessageAdded?.call();
          }

          finalAnswer = streamedText;
        }
      }

      // Remove streaming content
      _streamingContent.remove(botMessageId);

      // Remove duplication
      String verified = finalAnswer;
      if (verified.length > 300) {
        final half = verified.length ~/ 2;
        if (verified.substring(0, half) == verified.substring(half)) {
          verified = verified.substring(0, half);
        }
      }

      // Update bot message locally
      final idx = _messages.indexWhere((m) => m.id == botMessageId);
      if (idx >= 0) {
        _messages[idx] = botMessage.copyWith(content: verified);
      }

      notifyListeners();
      _onMessageAdded?.call();

      final totalMs = DateTime.now().difference(startTime).inMilliseconds;
      print("⚡ Total response time: ${totalMs}ms");

      // Save bot message to Firestore (background)
      unawaited(() async {
        final batch = _firestore.batch();

        final botRef = _firestore
            .collection('conversations')
            .doc(conversationId!)
            .collection('messages')
            .doc(botMessageId);

        batch.set(botRef, _messageToMap(_messages[idx]));

        batch.update(userMessageRef, {
          "isAnswered": true,
          "answeredAt": Timestamp.now(),
          "responseTimeMs": totalMs,
        });

        await batch.commit();
      }());

      // Update title and reload conversation info
      await _updateConversationTitleIfNeeded(question);

      // Background tasks
      unawaited(
        _handlePostResponseTasks(
          context,
          question,
          verified,
          currentEmbedding,
          questionCategory,
          userId,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
      _onMessageAdded?.call();
    }
  }

  Future<void> _updateConversationTitleNow(String question) async {
    if (conversationId == null) return;

    try {
      print('🔄 Updating conversation title for first message...');

      final titlePrompt = '''
Generate a short, descriptive title (max 5 words) for the following user question:

Question:
$question
''';

      final newTitle = await _cohere!.generateResponse(titlePrompt);
      print('Generated title from Cohere: "$newTitle"');

      if (newTitle != null && newTitle.trim().isNotEmpty) {
        final updatedTitle = newTitle.trim();

        // ✅ Update Firestore
        await _firestore
            .collection('conversations')
            .doc(conversationId!)
            .update({'title': updatedTitle});

        print('✅ Updated conversation title to: "$updatedTitle"');

        // ✅ Update local state
        if (currentConversation != null) {
          currentConversation = Conversation(
            id: currentConversation!.id,
            userId: currentConversation!.userId,
            title: updatedTitle,
            status: currentConversation!.status,
            createdAt: currentConversation!.createdAt,
          );
        }

        // ✅ Update UserConstant cache
        final convIndex = UserConstant.recentConversations.indexWhere(
          (c) => c['id'] == conversationId,
        );
        if (convIndex != -1) {
          UserConstant.recentConversations[convIndex]['title'] = updatedTitle;
        }

        // ✅ Force UI update
        notifyListeners();

        print('✅ Title update complete and UI notified');
      }
    } catch (titleError) {
      print('❌ Error updating conversation title: $titleError');
    }
  }

  Map<String, dynamic>? _findBestFAQMatch(
    String question,
    List<double> questionEmbedding,
  ) {
    try {
      double highestSimilarity = 0.0;
      Map<String, dynamic>? bestMatch;

      print('🔍 Checking ${FAQCache.cache.length} FAQs for match');
      print('🔍 Question: "$question"');

      for (var entry in FAQCache.cache.entries) {
        final data = entry.value;

        // ✅ CRITICAL: Validate embedding exists
        if (!data.containsKey('embedding') || data['embedding'] == null) {
          print('⚠️ FAQ missing embedding: ${data['question']}');
          continue;
        }

        // ✅ CRITICAL: Validate answer exists and is not empty
        final answer = data['answer'] as String?;
        if (answer == null || answer.trim().isEmpty) {
          print('⚠️ FAQ has empty answer: ${data['question']}');
          continue;
        }

        List<double> faqEmbedding;
        try {
          faqEmbedding = List<double>.from(data['embedding']);
        } catch (e) {
          print('⚠️ Invalid embedding format for: ${data['question']}');
          continue;
        }

        // ✅ Validate embedding dimensions match
        if (faqEmbedding.length != questionEmbedding.length) {
          print(
            '⚠️ Embedding dimension mismatch: FAQ=${faqEmbedding.length}, Query=${questionEmbedding.length}',
          );
          continue;
        }

        final similarity = cosineSimilarity(questionEmbedding, faqEmbedding);

        print(
          '📊 FAQ: "${(data['question'] as String).substring(0, min(50, (data['question'] as String).length))}..."',
        );
        print('   Answer length: ${answer.length} chars');
        print('   Category: ${data['category'] ?? 'N/A'}'); // ✅ ADDED
        print('   Similarity: ${similarity.toStringAsFixed(4)}');

        // ✅ LOWERED THRESHOLD: Changed from 0.85 to 0.75 for better matching
        if (similarity > 0.75 && similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatch = {
            'question': data['question'],
            'answer': answer,
            'category': data['category'] ?? 'General', // ✅ INCLUDE CATEGORY
            'similarity': similarity,
          };
          print('   🎯 NEW BEST MATCH!');
        }
      }

      if (bestMatch != null) {
        print('✅ Found FAQ match:');
        print('   Question: ${bestMatch['question']}');
        print('   Category: ${bestMatch['category']}'); // ✅ ADDED
        print('   Similarity: ${highestSimilarity.toStringAsFixed(4)}');
        print(
          '   Answer length: ${(bestMatch['answer'] as String).length} chars',
        );
      } else {
        print(
          '❌ No FAQ match found (best similarity: ${highestSimilarity.toStringAsFixed(4)})',
        );
      }

      return bestMatch;
    } catch (e) {
      print('❌ Error finding FAQ match: $e');
      return null;
    }
  }

  // ✅ SIMPLIFIED: Only Admission, Scholarship, Placement, or General
  Future<String> _classifyQuestionCategoryFast(String question) async {
    final q = question.toLowerCase();

    // ✅ Admission keywords
    if (RegExp(
      r'\b(admission|admit|admitted|enroll|enrollment|application|apply|applying|entrance|entry|requirement|requirements|eligibility|qualify|acceptance|accepted|applicant)\b',
    ).hasMatch(q)) {
      return 'Admission';
    }

    // ✅ Scholarship keywords
    if (RegExp(
      r'\b(scholarship|scholarships|scholar|grant|grants|financial\s*aid|funding|stipend|allowance|tuition\s*fee\s*discount|free\s*tuition|financial\s*support)\b',
    ).hasMatch(q)) {
      return 'Scholarship';
    }

    // ✅ Placement keywords
    if (RegExp(
      r'\b(placement|job|jobs|career|careers|internship|intern|employment|work|hiring|vacancy|vacancies|position|positions|ojt|practicum|on[- ]the[- ]job|training)\b',
    ).hasMatch(q)) {
      return 'Placement';
    }

    // ✅ SIMPLIFIED: Fall back to LLM classification (only 3 categories + General)
    try {
      final prompt =
          '''Classify this question into ONE category: Admission, Scholarship, Placement, or General.

Categories:
- Admission: enrollment, application process, requirements, eligibility, cmucat, 
- Scholarship: financial aid, grants, scholarships, tuition assistance
- Placement: jobs, internships, career services, OJT, employment
- General: anything else

Question: "$question"

Return ONLY the category name (Admission, Scholarship, Placement, or General):''';

      final category = await _cohere?.generateResponse(prompt);

      if (category != null && category.trim().isNotEmpty) {
        final normalized = category.trim().replaceAll(RegExp(r'[^a-zA-Z]'), '');

        // ✅ Check if response contains any of the 3 main categories
        if (normalized.toLowerCase().contains('admission')) return 'Admission';
        if (normalized.toLowerCase().contains('scholarship'))
          return 'Scholarship';
        if (normalized.toLowerCase().contains('placement')) return 'Placement';

        print('⚠️ LLM returned: "$category", using General');
      }
    } catch (e) {
      print('❌ Classification error: $e');
    }

    print('ℹ️ No specific category matched, using General');
    return 'General';
  }

  // ✅ ALSO UPDATE: _ensureFAQCacheLoaded to validate data
  Future<void> _ensureFAQCacheLoaded() async {
    if (FAQCache.isExpired || FAQCache.cache.isEmpty) {
      try {
        print('🔄 Refreshing FAQ cache...');

        // ✅ CRITICAL: Only fetch FAQs with non-empty answers AND embeddings
        final faqSnapshot =
            await _firestore
                .collection('faqs')
                .where('answer', isNotEqualTo: "")
                .get();

        print('📚 Found ${faqSnapshot.docs.length} FAQs in Firestore');

        // ✅ Filter and validate before caching
        Map<String, Map<String, dynamic>> validFAQs = {};
        int skippedCount = 0;

        for (var doc in faqSnapshot.docs) {
          final data = doc.data();
          final question = data['question'] as String?;
          final answer = data['answer'] as String?;
          final embedding = data['embedding'];

          // Validate all required fields
          if (question == null || question.isEmpty) {
            print('⚠️ Skipping FAQ ${doc.id}: No question');
            skippedCount++;
            continue;
          }

          if (answer == null || answer.trim().isEmpty) {
            print('⚠️ Skipping FAQ ${doc.id}: Empty answer');
            skippedCount++;
            continue;
          }

          if (embedding == null ||
              !(embedding is List) ||
              (embedding as List).isEmpty) {
            print(
              '⚠️ Skipping FAQ ${doc.id}: No embedding - "${question.substring(0, min(50, question.length))}"',
            );
            skippedCount++;
            continue;
          }

          // ✅ Only add valid FAQs to cache
          validFAQs[doc.id] = data;
          print(
            '✅ Cached FAQ: "${question.substring(0, min(50, question.length))}" (${answer.length} chars)',
          );
        }

        FAQCache.cache.clear();
        FAQCache.cache.addAll(validFAQs);
        FAQCache.lastCacheUpdate = DateTime.now();

        print('✅ FAQ Cache updated:');
        print('   Valid FAQs: ${validFAQs.length}');
        print('   Skipped: $skippedCount');
        print('   Total in cache: ${FAQCache.cache.length}');
      } catch (e) {
        print('❌ Error loading FAQ cache: $e');
      }
    } else {
      print('ℹ️ Using cached FAQs (${FAQCache.cache.length} entries)');
    }
  }

  Future<List<double>> _generateEmbeddingCached(String text) async {
    final cached = EmbeddingCache.get(text);
    if (cached != null) {
      return cached;
    }

    final embedding = await generateEmbedding(text);
    EmbeddingCache.put(text, embedding);
    return embedding;
  }

  Future<void> _handlePostResponseTasks(
    BuildContext context,
    String question,
    String answerText,
    List<double> currentEmbedding,
    String category,
    String? userId,
  ) async {
    try {
      await Future.wait([
        _logMessageAction(question, answerText),
        checkEscalation(context, answerText, userId, question),
        _checkAndPromoteToFAQOptimized(
          question,
          currentEmbedding,
          answerText,
          category,
        ),
        _updateConversationTitleIfNeeded(question),
      ]);
    } catch (e) {
      print('Error in post-response tasks: $e');
    }
  }

  Future<void> checkEscalation(
    BuildContext context,
    String answerText,
    String? userId,
    String question,
  ) async {
    if (conversationId == null) return;

    final lowerAnswer = answerText.toLowerCase();

    for (var keyword in escalationResponseKeywords) {
      if (lowerAnswer.contains(keyword)) {
        // ✅ NEW: Use same dialog as manual escalation
        await _showAutoEscalationDialog(context, question, answerText, keyword);
        break;
      }
    }
  }

  Future<void> _showAutoEscalationDialog(
    BuildContext context,
    String question,
    String answerText,
    String triggerKeyword,
  ) async {
    String selectedReason = 'Bot response not accurate';
    String? userReason;

    try {
      final Map<String, dynamic>?
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          final TextEditingController reasonController =
              TextEditingController();
          bool isSubmitting = false;

          return StatefulBuilder(
            builder:
                (dialogState, setDialogState) => WillPopScope(
                  onWillPop: () async => !isSubmitting,
                  child: Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    insetPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 500,
                        maxHeight:
                            MediaQuery.of(dialogContext).size.height * 0.85,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF43A047),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.support_agent,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Request Staff Assistance',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Get personalized help from our team',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white70,
                                          letterSpacing: 0.0,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      isSubmitting
                                          ? null
                                          : () => Navigator.of(
                                            dialogContext,
                                          ).pop(null),
                                  icon: Icon(
                                    Icons.close,
                                    color:
                                        isSubmitting
                                            ? Colors.white38
                                            : Colors.white70,
                                    size: 24,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Info message
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.blue.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'I couldn\'t provide a complete answer to your question. A staff member can provide personalized assistance.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade900,
                                              height: 1.5,
                                              letterSpacing: 0.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Reason selection
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        size: 18,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'What went wrong?',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildReasonTile(
                                          context: dialogContext,
                                          title: 'Bot response not accurate',
                                          icon: Icons.error_outline,
                                          value: 'Bot response not accurate',
                                          groupValue: selectedReason,
                                          onChanged:
                                              isSubmitting
                                                  ? (_) {}
                                                  : (val) {
                                                    setDialogState(() {
                                                      selectedReason =
                                                          val ?? selectedReason;
                                                    });
                                                  },
                                          isFirst: true,
                                        ),
                                        Divider(
                                          height: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildReasonTile(
                                          context: dialogContext,
                                          title:
                                              'Bot did not understand my question',
                                          icon: Icons.help_outline,
                                          value:
                                              'Bot did not understand my question',
                                          groupValue: selectedReason,
                                          onChanged:
                                              isSubmitting
                                                  ? (_) {}
                                                  : (val) {
                                                    setDialogState(() {
                                                      selectedReason =
                                                          val ?? selectedReason;
                                                    });
                                                  },
                                        ),
                                        Divider(
                                          height: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildReasonTile(
                                          context: dialogContext,
                                          title:
                                              'Need clarification from staff',
                                          icon: Icons.contact_support_outlined,
                                          value:
                                              'Need clarification from staff',
                                          groupValue: selectedReason,
                                          onChanged:
                                              isSubmitting
                                                  ? (_) {}
                                                  : (val) {
                                                    setDialogState(() {
                                                      selectedReason =
                                                          val ?? selectedReason;
                                                    });
                                                  },
                                          isLast: true,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Additional details
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 18,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Additional details (optional)',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  TextField(
                                    controller: reasonController,
                                    maxLines: 3,
                                    maxLength: 200,
                                    textInputAction: TextInputAction.done,
                                    enabled: !isSubmitting,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey.shade800,
                                      height: 1.5,
                                      letterSpacing: 0.0,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Tell us more about what you need help with...',
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade400,
                                        letterSpacing: 0.0,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2E7D32),
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor:
                                          isSubmitting
                                              ? Colors.grey.shade100
                                              : Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(14),
                                      counterStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade500,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Buttons
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        isSubmitting
                                            ? null
                                            : () => Navigator.of(
                                              dialogContext,
                                            ).pop(null),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      side: BorderSide(
                                        color:
                                            isSubmitting
                                                ? Colors.grey.shade200
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color:
                                            isSubmitting
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15.5,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        isSubmitting
                                            ? null
                                            : () async {
                                              setDialogState(() {
                                                isSubmitting = true;
                                              });

                                              await Future.delayed(
                                                Duration(milliseconds: 800),
                                              );

                                              if (dialogContext.mounted) {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop({
                                                  'submit': true,
                                                  'selectedReason':
                                                      selectedReason,
                                                  'userReason':
                                                      reasonController.text
                                                          .trim(),
                                                });
                                              }
                                            },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isSubmitting
                                              ? Colors.grey.shade400
                                              : const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      elevation: isSubmitting ? 0 : 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                    child:
                                        isSubmitting
                                            ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Submitting...',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15.5,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.send, size: 19),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Submit',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15.5,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          );
        },
      );

      if (result == null || result['submit'] != true || !context.mounted) {
        print('ℹ️ Auto-escalation cancelled by user');
        return;
      }

      selectedReason = result['selectedReason'] as String;
      userReason = result['userReason'] as String?;

      final fullReason =
          userReason != null && userReason.isNotEmpty
              ? '$selectedReason — $userReason'
              : selectedReason;

      // Get category from current conversation
      String messageCategory = 'General';
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].sender == 'user') {
          messageCategory = _messages[i].category ?? 'General';
          print('✅ Found category for auto-escalation: $messageCategory');
          break;
        }
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      final escalatedData = {
        'escalationId': escalationId,
        'userId': userId,
        'conversationId': conversationId!,
        'question': question,
        'botAnswer': answerText,
        'status': 'pending',
        'reason': fullReason,
        'category': messageCategory,
        'createdAt': Timestamp.now(),
      };

      await escalationRef.set(escalatedData);

      print('✅ Auto-escalation created: $escalationId');
      print('📂 Category: $messageCategory');
      print('📝 Reason: $fullReason');

      // ✅ Show success dialog
      if (context.mounted) {
        await _showEscalationSuccessDialog(context);
      }
    } catch (e) {
      print('❌ Error creating auto-escalation: $e');
    }
  }

  Widget _buildReasonTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String value,
    required String groupValue,
    required Function(String?) onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32).withOpacity(0.05) : null,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(12) : Radius.zero,
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade800,
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF2E7D32),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Success dialog (reuse from chat_page.dart)
  Future<void> _showEscalationSuccessDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Request Submitted!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                            letterSpacing: -0.8,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your request has been escalated to our staff team.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade700,
                            height: 1.5,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'Got it, thanks!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processAutoEscalation(
    String? userId,
    BuildContext context,
    String question,
    String answerText,
    String triggerKeyword, {
    String? userReason,
  }) async {
    try {
      // ✅ NEW: Get category from the current conversation's last user message
      String messageCategory = 'General';

      final messages =
          Provider.of<ChatProvider>(context, listen: false).messages;

      // Find the most recent user message to get category
      for (int i = messages.length - 1; i >= 0; i--) {
        if (messages[i].sender == 'user') {
          messageCategory = messages[i].category ?? 'General';
          print('✅ Found category for auto-escalation: $messageCategory');
          break;
        }
      }

      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      // ✅ UPDATED: Include category in escalation data
      final escalatedData = {
        'escalationId': escalationId,
        'userId': userId,
        'conversationId': conversationId!,
        'question': question,
        'botAnswer': answerText,
        'status': 'pending',
        'reason': userReason ?? 'Auto-escalated: $triggerKeyword',
        'category': messageCategory, // ✅ NEW: Add category
        'userReason': userReason,
        'triggerKeyword': triggerKeyword,
        'createdAt': Timestamp.now(),
      };

      await escalationRef.set(escalatedData);

      print('✅ Auto-escalation created: $escalationId');
      print('📂 Category: $messageCategory'); // ✅ NEW: Log category
    } catch (e) {
      print('❌ Error creating auto-escalation: $e');
    }
  }

  Future<void> _checkAndPromoteToFAQOptimized(
    String question,
    List<double> currentEmbedding,
    String botAnswer,
    String category,
  ) async {
    try {
      // Only process if answer and question are worthy
      if (!_isAnswerWorthyOfFAQ(botAnswer) ||
          !_isQuestionWorthyOfFAQ(question)) {
        return;
      }

      // Calculate date 30 days ago
      final oneMonthAgo = DateTime.now().subtract(Duration(days: 30));
      final oneMonthAgoTimestamp = Timestamp.fromDate(oneMonthAgo);

      // Query messages from the last 30 days only
      final querySnapshot =
          await _firestore
              .collectionGroup('messages')
              .where('sender', isEqualTo: 'user')
              .where('isAnswered', isEqualTo: true)
              .where('category', isEqualTo: category)
              .where('sent_at', isGreaterThanOrEqualTo: oneMonthAgoTimestamp)
              .orderBy('sent_at', descending: true)
              .limit(100)
              .get();

      Map<String, QuestionGroup> questionGroups = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final pastQuestion = data['content'] as String?;
        final pastEmbeddingData = data['embedding'];

        if (pastQuestion == null || pastEmbeddingData == null) continue;
        if (!_isQuestionWorthyOfFAQ(pastQuestion)) continue;

        try {
          final pastEmbedding =
              (pastEmbeddingData as List)
                  .map((e) => (e as num).toDouble())
                  .toList();

          if (pastEmbedding.length != currentEmbedding.length) continue;

          final similarity = cosineSimilarity(currentEmbedding, pastEmbedding);

          if (similarity > 0.88) {
            final contextKey = _extractContextualKey(pastQuestion);
            final groupKey = '${category}_$contextKey';

            questionGroups.putIfAbsent(groupKey, () => QuestionGroup());
            questionGroups[groupKey]!.addQuestion(
              pastQuestion,
              data,
              similarity,
            );
          }
        } catch (e) {
          continue;
        }
      }

      // ✅ FIX 2: Changed threshold from 10 to 3
      final batch = _firestore.batch();
      bool hasBatchOperations = false;

      for (var group in questionGroups.values) {
        // ✅ NEW THRESHOLD: More than 3 questions with avg similarity > 0.90
        if (group.questionCount > 3 && group.averageSimilarity > 0.90) {
          final representativeQuestion = group.getMostRepresentativeQuestion();

          final existing =
              await _firestore
                  .collection('faqs')
                  .where('question', isEqualTo: representativeQuestion)
                  .limit(1)
                  .get();

          if (existing.docs.isEmpty) {
            final faqRef = _firestore.collection('faqs').doc();
            final faqData = {
              'question': representativeQuestion,
              'answer': botAnswer,
              'category': category,
              'isPredefined': false,
              'createdAt': Timestamp.now(),
              'embedding': currentEmbedding,
              'promotionReason':
                  'Auto-promoted: ${group.questionCount} similar questions in last 30 days',
              'similarityCount': group.questionCount,
              'averageSimilarity': group.averageSimilarity,
              'promotionPeriod': '30_days',
              'promotionDate': Timestamp.now(),
            };

            batch.set(faqRef, faqData);
            hasBatchOperations = true;

            print('🎯 Auto-adding FAQ: $representativeQuestion');
            print('   Questions in group: ${group.questionCount}');
            print(
              '   Average similarity: ${group.averageSimilarity.toStringAsFixed(3)}',
            );
            print('   Category: $category');
          }
        } else if (group.questionCount > 2) {
          // Log groups approaching threshold
          print('📊 Question group approaching threshold:');
          print('   Context: ${_extractContextualKey(group.questions.first)}');
          print('   Count: ${group.questionCount}/4 (need >3)');
          print(
            '   Avg similarity: ${group.averageSimilarity.toStringAsFixed(3)}',
          );
        }
      }

      if (hasBatchOperations) {
        await batch.commit();
        FAQCache.lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
        print('✅ FAQ promotion batch committed successfully');
      }
    } catch (e) {
      print('❌ Error in FAQ promotion: $e');
    }
  }

  String _extractContextualKey(String question) {
    final lowercaseQuestion = question.toLowerCase();

    final contextPatterns = {
      'vacant_position': [
        'vacant',
        'opening',
        'available position',
        'job vacancy',
      ],
      'placement_opportunity': [
        'placement',
        'opportunity',
        'program',
        'service',
      ],
      'internship': ['internship', 'intern', 'training', 'practicum'],
      'scholarship': ['scholarship', 'grant', 'financial aid', 'funding'],
      'admission': ['admission', 'enrollment', 'application', 'entry'],
      'requirement': ['requirement', 'needed', 'prerequisite', 'criteria'],
      'deadline': ['deadline', 'due date', 'when', 'schedule'],
      'fee': ['fee', 'cost', 'payment', 'tuition', 'amount'],
    };

    for (var entry in contextPatterns.entries) {
      final contextType = entry.key;
      final keywords = entry.value;

      for (var keyword in keywords) {
        if (lowercaseQuestion.contains(keyword)) {
          return contextType;
        }
      }
    }

    final words =
        lowercaseQuestion
            .split(' ')
            .where(
              (word) =>
                  word.length > 3 &&
                  ![
                    'what',
                    'how',
                    'when',
                    'where',
                    'why',
                    'who',
                  ].contains(word),
            )
            .toList();

    return words.isNotEmpty ? words.first : 'general';
  }

  bool _isQuestionWorthyOfFAQ(String question) {
    final cleanQuestion = question.trim().toLowerCase();

    if (cleanQuestion.length < 10) return false;

    final lowQualityPatterns = [
      RegExp(r'^(hi|hello|hey|ok|okay|yes|no|thanks|thank you)$'),
      RegExp(r'^(what are those|what is that|those|that|this)$'),
      RegExp(r'^[?.!,\s]*$'),
      RegExp(r'^\w{1,3}$'),
    ];

    for (var pattern in lowQualityPatterns) {
      if (pattern.hasMatch(cleanQuestion)) {
        return false;
      }
    }

    final meaningfulWords =
        cleanQuestion.split(' ').where((word) => word.length > 3).toList();

    if (meaningfulWords.length < 2) return false;

    final questionWords = [
      'what',
      'how',
      'when',
      'where',
      'why',
      'who',
      'which',
      'can',
      'is',
      'are',
      'do',
      'does',
      'will',
      'would',
      'should',
    ];
    final hasQuestionWord = questionWords.any(
      (qw) => cleanQuestion.contains(qw),
    );
    final isQuestion = cleanQuestion.contains('?') || hasQuestionWord;

    return isQuestion;
  }

  bool _isAnswerWorthyOfFAQ(String answer) {
    final cleanAnswer = answer.trim().toLowerCase();

    final lowQualityAnswers = [
      "sorry, i don't have information about that",
      "i don't know",
      "i'm not sure",
      "contact support",
      "please contact oasp staff",
    ];

    for (var badAnswer in lowQualityAnswers) {
      if (cleanAnswer.contains(badAnswer)) {
        return false;
      }
    }

    return cleanAnswer.length >= 20;
  }

  Future<bool> canUserInteract() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    return canSendMessage;
  }

  Future<void> _incrementFAQSimilarityCountAsync(String faqQuestion) async {
    try {
      final faqSnapshot =
          await _firestore
              .collection('faqs')
              .where('question', isEqualTo: faqQuestion)
              .limit(1)
              .get();

      if (faqSnapshot.docs.isNotEmpty) {
        await faqSnapshot.docs.first.reference.update({
          'similarityCount': FieldValue.increment(1),
          'lastAsked': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Error incrementing FAQ similarity count: $e');
    }
  }

  void unawaited(Future<void> future) {
    future.catchError((error) {
      print('Unawaited future error: $error');
    });
  }

  Future<void> _logMessageAction(String message, String reply) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final currentUserDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

        if (currentUserDoc.exists) {
          final data = currentUserDoc.data() as Map<String, dynamic>;
          actorName = data['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef =
          FirebaseFirestore.instance.collection('message_logs').doc();

      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'message': message,
        'reply': reply,
        'time': Timestamp.now(),
      });
    } catch (e) {
      print('Failed to log message: $e');
    }
  }

  Future<void> _updateConversationTitleIfNeeded(String question) async {
    if (conversationId == null) return;

    bool shouldUpdateTitle = false;

    if (currentConversation == null) {
      await loadConversationInfo();
    }

    if (currentConversation != null) {
      final title = currentConversation!.title.toLowerCase();
      shouldUpdateTitle =
          (title.contains('new conversation') ||
              title == 'untitled' ||
              title.trim().isEmpty) &&
          _messages.where((m) => m.sender == 'user').length <= 1;
    }

    if (shouldUpdateTitle) {
      try {
        final titlePrompt = '''
Generate a short, descriptive title (max 5 words) for the following user question:

Question:
$question
''';

        final newTitle = await _cohere!.generateResponse(titlePrompt);
        print('Generated title from Cohere: "$newTitle"');

        if (newTitle != null && newTitle.trim().isNotEmpty) {
          final updatedTitle = newTitle.trim();

          // ✅ Update Firestore first
          await _firestore
              .collection('conversations')
              .doc(conversationId!)
              .update({'title': updatedTitle});

          print('Updated conversation title to: "$updatedTitle"');

          // ✅ Update local state immediately
          if (currentConversation != null) {
            currentConversation = Conversation(
              id: currentConversation!.id,
              userId: currentConversation!.userId,
              title: updatedTitle, // New title
              status: currentConversation!.status,
              createdAt: currentConversation!.createdAt,
            );
          }

          // ✅ Update UserConstant cache
          final convIndex = UserConstant.recentConversations.indexWhere(
            (c) => c['id'] == conversationId,
          );
          if (convIndex != -1) {
            UserConstant.recentConversations[convIndex]['title'] = updatedTitle;
          }

          // ✅ Force UI update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });

          print('✅ Title update complete and UI notified');
        }
      } catch (titleError) {
        print('Error updating conversation title: $titleError');
      }
    }
  }

  //  Future<List<double>> generateEmbedding(String question) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse("https://api.cohere.ai/v1/embed"),
  //       headers: {
  //         'Authorization': 'Bearer $_apiKey',
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode({
  //         "texts": [question],
  //         "model": "embed-multilingual-v3.0",  // ✅ Changed to v3
  //         "input_type": "search_query",         // ✅ Required for v3 - queries
  //       }),
  //     );

  //     if (response.statusCode != 200) {
  //       throw Exception('Failed to generate embedding: ${response.statusCode}');
  //     }

  //     final data = jsonDecode(response.body);
  //     final embedding = (data['embeddings'][0] as List)
  //         .map((e) => (e as num).toDouble())
  //         .toList();

  //     print('✅ Generated v3 embedding: ${embedding.length} dimensions');
  //     return embedding;
  //   } catch (e) {
  //     print('Error generating embedding: $e');
  //     rethrow;
  //   }
  // }

  Future<List<double>> generateEmbedding(String question) async {
    try {
      print(
        '🔧 Generating Gemini embedding for: "${question.substring(0, min(50, question.length))}..."',
      );

      final response = await http.post(
        Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$_geminiApiKey",
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": "models/text-embedding-004",
          "content": {
            "parts": [
              {"text": question},
            ],
          },
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Gemini API error: ${response.statusCode}');
        print('   Response: ${response.body}');
        throw Exception('Failed to generate embedding: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final embedding =
          (data['embedding']['values'] as List)
              .map((e) => (e as num).toDouble())
              .toList();

      print('✅ Generated Gemini embedding: ${embedding.length} dimensions');
      return embedding;
    } catch (e) {
      print('❌ Error generating Gemini embedding: $e');
      rethrow;
    }
  }

  Future<void> rateMessage(
    String messageId,
    bool isLiked,
    String conversationId,
  ) async {
    try {
      final rating = isLiked ? 'like' : 'dislike';

      // Update cache immediately
      _pendingRatingsCache[messageId] = rating;

      // Update Firestore in background
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'rating': rating, 'rated_at': Timestamp.now()});

      print('Message $messageId rated successfully');
    } catch (e) {
      print('Error rating message: $e');
      // Remove from cache on error
      _pendingRatingsCache.remove(messageId);
      rethrow;
    }
  }

  Future<void> incrementFAQSimilarityCount(String faqQuestion) async {
    try {
      // ✅ NEW: Check if user can interact before incrementing
      final canInteract = await canUserInteract();
      if (!canInteract) {
        print('⏭️ Skipping FAQ similarity increment - user at message limit');
        return;
      }

      final faqSnapshot =
          await _firestore
              .collection('faqs')
              .where('question', isEqualTo: faqQuestion)
              .get();

      if (faqSnapshot.docs.isNotEmpty) {
        final faqDoc = faqSnapshot.docs.first;
        await faqDoc.reference.update({
          'similarityCount': FieldValue.increment(1),
          'lastAsked': Timestamp.now(),
        });

        print('✅ Incremented similarity count for FAQ: $faqQuestion');
      }
    } catch (e) {
      print('❌ Error incrementing FAQ similarity count: $e');
    }
  }

  void handleFAQSelection(String question) {
    incrementFAQSimilarityCount(question);
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    return denominator == 0 ? 0.0 : dotProduct / denominator;
  }

  void clearMessages() {
    print('🧹 ChatProvider.clearMessages called');

    // Cancel subscriptions
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _escalationSubscription?.cancel(); // ✅ NEW: Cancel escalation listener
    _escalationSubscription = null;

    // Clear all data structures
    _messages.clear();
    _processedMessages.clear();
    _streamingContent.clear();
    _pendingRatingsCache.clear();

    // Clear conversation references
    conversationId = null;
    currentConversation = null;

    // Reset all flags
    _isLoading = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    print('✅ ChatProvider cleared (including escalation listener)');
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _escalationSubscription?.cancel();
    _userMessageCountSubscription?.cancel(); // ✅ NEW
    super.dispose();
  }
}

// Helper class for grouping similar questions
class QuestionGroup {
  final List<String> questions = [];
  final List<Map<String, dynamic>> questionData = [];
  final List<double> similarities = [];

  int get questionCount => questions.length;
  double get averageSimilarity =>
      similarities.isEmpty
          ? 0.0
          : similarities.reduce((a, b) => a + b) / similarities.length;

  void addQuestion(
    String question,
    Map<String, dynamic> data,
    double similarity,
  ) {
    questions.add(question);
    questionData.add(data);
    similarities.add(similarity);
  }

  String getMostRepresentativeQuestion() {
    if (questions.isEmpty) return '';

    double bestScore = 0.0;
    String bestQuestion = questions.first;

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final similarity = similarities[i];
      final qualityScore = _calculateQuestionQuality(question);
      final combinedScore = similarity * 0.7 + qualityScore * 0.3;

      if (combinedScore > bestScore) {
        bestScore = combinedScore;
        bestQuestion = question;
      }
    }

    return bestQuestion;
  }
}

// Helper function to calculate question quality
double _calculateQuestionQuality(String question) {
  double score = 0.0;
  final cleanQuestion = question.trim().toLowerCase();

  // Length bonus (up to 1.0)
  score += (cleanQuestion.length / 100).clamp(0.0, 1.0);

  // Question word bonus
  final questionWords = ['what', 'how', 'when', 'where', 'why', 'who'];
  if (questionWords.any((qw) => cleanQuestion.startsWith(qw))) {
    score += 0.5;
  }

  // Academic/domain words bonus
  final domainWords = [
    'admission',
    'scholarship',
    'placement',
    'course',
    'program',
    'requirement',
    'deadline',
    'fee',
    'exam',
  ];
  final domainMatches =
      domainWords.where((dw) => cleanQuestion.contains(dw)).length;
  score += (domainMatches * 0.3);

  return score.clamp(0.0, 5.0);
}

extension DoubleExtension on double {
  String toFixed(int decimals) {
    return toStringAsFixed(decimals);
  }
}
