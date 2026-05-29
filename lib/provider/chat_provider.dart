import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:capstone_project/provider/embedding_cache.dart';
import 'package:capstone_project/provider/faq_cache.dart';
import 'package:capstone_project/provider/question_group.dart';
import 'package:capstone_project/responsive/user_constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:http/http.dart' as http;

import 'package:capstone_project/models/conversations.dart';
import 'package:capstone_project/models/message.dart';

import 'package:capstone_project/services/answer_retrieval.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

// Cache classes for better performance

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnswerRetrievalService _retriever;
  CohereService? _cohere;
  bool isNowAddedToFAQ = false;
  int count = 1;

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

  bool _isDisposed = false;

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

              if (newCount != _userDailyMessageCount ||
                  newResetDate != _userLastResetDate) {
                _userDailyMessageCount = newCount;
                _userLastResetDate = newResetDate;

<<<<<<< HEAD
                notifyListeners();
              }
            } else {
=======
                print(
                  ' Real-time update: User message count = $_userDailyMessageCount',
                  ' Real-time update: User message count = $_userDailyMessageCount',
                );
                notifyListeners();
              }
            } else {
              print(
                ' User document not found - will be created on first message',
                ' User document not found - will be created on first message',
              );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
              _userDailyMessageCount = 0;
              _userLastResetDate = null;
              notifyListeners();
            }
          },
          onError: (_) {

    return canSend;
  }

  static const int MAX_DAILY_ESCALATIONS = 2;

  StreamSubscription<DocumentSnapshot>? _userEscalationCountSubscription;

  int _userDailyEscalationCount = 0;
  DateTime? _userLastEscalationResetDate;

  int get userDailyEscalationCount => _userDailyEscalationCount;

  bool get canEscalate {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final now = DateTime.now();

    if (_userDailyEscalationCount == 0 &&
        _userLastEscalationResetDate == null) {
      print(' New user - allowing first escalation');
      return true;
    }

    if (_userLastEscalationResetDate != null) {
      final resetTime = DateTime(now.year, now.month, now.day, 8, 0, 0);

      final shouldReset =
          now.isAfter(resetTime) &&
          _userLastEscalationResetDate!.isBefore(resetTime);

      if (shouldReset) {
        print(' Escalation reset time reached - allowing escalation');
        return true;
      }
    }

    final canEsc = _userDailyEscalationCount < MAX_DAILY_ESCALATIONS;

    print(' Escalation limit check:');
    print('   Current count: $_userDailyEscalationCount');
    print('   Max allowed: $MAX_DAILY_ESCALATIONS');
    print('   Can escalate: $canEsc');
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66

    return canEsc;
  }

  bool get isEscalationLimitReached => !canEscalate;

  Duration getTimeUntilEscalationReset() {
    final now = DateTime.now();
    DateTime nextReset;

    final todayReset = DateTime(now.year, now.month, now.day, 8, 0, 0);

    if (now.isBefore(todayReset)) {
      nextReset = todayReset;
    } else {
      nextReset = DateTime(now.year, now.month, now.day + 1, 8, 0, 0);
    }

    return nextReset.difference(now);
  }

  Future<void> updateUserEscalationCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final userRef = _firestore.collection('users').doc(userId);

      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        await userRef.set({
          'dailyEscalationCount': 1,
          'lastEscalationResetDate': Timestamp.now(),
        }, SetOptions(merge: true));

        _userDailyEscalationCount = 1;
        _userLastEscalationResetDate = now;

        print(' New user first escalation - count set to 1');
        notifyListeners();
        return;
      }

      final data = userDoc.data()!;
      final currentCount = data['dailyEscalationCount'] ?? 0;
      final lastReset =
          (data['lastEscalationResetDate'] as Timestamp?)?.toDate();

      final resetTime = DateTime(now.year, now.month, now.day, 8, 0, 0);

      bool shouldReset = false;

      if (lastReset == null) {
        shouldReset = true;
      } else {
        if (lastReset.isBefore(resetTime) && now.isAfter(resetTime)) {
          shouldReset = true;
        }
      }

      if (shouldReset) {
        await userRef.update({
          'dailyEscalationCount': 1,
          'lastEscalationResetDate': Timestamp.now(),
        });

        _userDailyEscalationCount = 1;
        _userLastEscalationResetDate = now;

        print(' Escalation count RESET - new count: 1');
      } else {
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          final currentCount = snapshot.data()?['dailyEscalationCount'] ?? 0;
          final newCount = currentCount + 1;

          transaction.update(userRef, {'dailyEscalationCount': newCount});
        });

        _userDailyEscalationCount = currentCount + 1;

        print(' Escalation count incremented to $_userDailyEscalationCount');
      }

      notifyListeners();
    } catch (e) {
      print(' Error updating escalation count: $e');
    }
  }

  void listenToUserEscalationCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _userEscalationCountSubscription?.cancel();

    _userEscalationCountSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data()!;
              final newCount = data['dailyEscalationCount'] ?? 0;
              final newResetDate =
                  (data['lastEscalationResetDate'] as Timestamp?)?.toDate();

              if (newCount != _userDailyEscalationCount ||
                  newResetDate != _userLastEscalationResetDate) {
                _userDailyEscalationCount = newCount;
                _userLastEscalationResetDate = newResetDate;

                notifyListeners();
              }
            } else {
              _userDailyEscalationCount = 0;
              _userLastEscalationResetDate = null;
              notifyListeners();
            }
          },
          onError: (_) {
          onError: (error) {
            print(' Error in escalation count listener: $error');
          },
        );
  }

  Future<void> loadUserEscalationCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userDailyEscalationCount = data['dailyEscalationCount'] ?? 0;
        _userLastEscalationResetDate =
            (data['lastEscalationResetDate'] as Timestamp?)?.toDate();

<<<<<<< HEAD
=======
        print(
          ' Loaded escalation count: $_userDailyEscalationCount/$MAX_DAILY_ESCALATIONS',
          ' Loaded escalation count: $_userDailyEscalationCount/$MAX_DAILY_ESCALATIONS',
        );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
      } else {
        _userDailyEscalationCount = 0;
        _userLastEscalationResetDate = null;

        await _firestore.collection('users').doc(userId).set({
          'dailyEscalationCount': 0,
          'lastEscalationResetDate': Timestamp.now(),
        }, SetOptions(merge: true));

<<<<<<< HEAD
      }

      notifyListeners();
    } catch (_) {
=======
        print(
          ' Initialized new user escalation count: 0/$MAX_DAILY_ESCALATIONS',
          ' Initialized new user escalation count: 0/$MAX_DAILY_ESCALATIONS',
        );
      }

      notifyListeners();
    } catch (e) {
      print(' Error loading escalation count: $e');
    }
  }

  @override
  void dispose() {
    print(' ChatProvider disposing...');
    _isDisposed = true;

    _messagesSubscription?.cancel();
    _escalationSubscription?.cancel();
    _userMessageCountSubscription?.cancel();
    _userEscalationCountSubscription?.cancel();

    _messages.clear();
    _streamingContent.clear();
    _processedMessages.clear();

    super.dispose();
    print(' ChatProvider disposed');
  }

  bool get isMessageLimitReached => !canSendMessage;

  Duration getTimeUntilReset() {
    final now = DateTime.now();
    DateTime nextReset;

    final todayReset = DateTime(now.year, now.month, now.day, 8, 0, 0);

    if (now.isBefore(todayReset)) {
      nextReset = todayReset;
    } else {
      nextReset = DateTime(now.year, now.month, now.day + 1, 8, 0, 0);
    }

    return nextReset.difference(now);
  }

  Future<void> resetAllUserMessageCounts() async {
    try {
      final now = DateTime.now();
      final resetTime = DateTime(now.year, now.month, now.day, 8, 0, 0);

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int resetCount = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final lastReset =
            (data['lastMessageResetDate'] as Timestamp?)?.toDate();

        if (lastReset == null || lastReset.isBefore(resetTime)) {
          batch.update(doc.reference, {
            'dailyMessageCount': 0,
            'lastMessageResetDate': Timestamp.now(),
          });
          resetCount++;
        }
      }

      if (resetCount > 0) {
        await batch.commit();
        print(' Reset complete: $resetCount users reset');
      } else {
        print(' No users needed reset');
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        _userDailyMessageCount = 0;
        _userLastResetDate = now;
        notifyListeners();
      }
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Error in manual reset: $e');
    }
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

<<<<<<< HEAD
=======
        print(
          ' Loaded user message count: $_userDailyMessageCount/$MAX_DAILY_MESSAGES',
          ' Loaded user message count: $_userDailyMessageCount/$MAX_DAILY_MESSAGES',
        );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
      } else {
        _userDailyMessageCount = 0;
        _userLastResetDate = null;

        await _firestore.collection('users').doc(userId).set({
          'dailyMessageCount': 0,
          'lastMessageResetDate': Timestamp.now(),
        }, SetOptions(merge: true));

<<<<<<< HEAD
      }

      notifyListeners();
    } catch (_) {
=======
        print(
          ' Initialized new user with message count: 0/$MAX_DAILY_MESSAGES',
          ' Initialized new user with message count: 0/$MAX_DAILY_MESSAGES',
        );
      }

      notifyListeners();
    } catch (e) {
      print(' Error loading user message count: $e');
    }
  }

  Future<void> _updateUserMessageCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final userRef = _firestore.collection('users').doc(userId);

      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        await userRef.set({
          'dailyMessageCount': 1,
          'lastMessageResetDate': Timestamp.now(),
        }, SetOptions(merge: true));

        _userDailyMessageCount = 1;
        _userLastResetDate = now;

        print(' New user first message - count set to 1');
        notifyListeners();
        return;
      }

      final data = userDoc.data()!;
      final currentCount = data['dailyMessageCount'] ?? 0;
      final lastReset = (data['lastMessageResetDate'] as Timestamp?)?.toDate();

      final resetTime = DateTime(now.year, now.month, now.day, 8, 0, 0);

      bool shouldReset = false;

      if (lastReset == null) {
        shouldReset = true;
      } else {
        if (lastReset.isBefore(resetTime) && now.isAfter(resetTime)) {
          shouldReset = true;
        }
      }

      if (shouldReset) {
        await userRef.update({
          'dailyMessageCount': 1,
          'lastMessageResetDate': Timestamp.now(),
        });

        _userDailyMessageCount = 1;
        _userLastResetDate = now;

        print(' Message count RESET - new count: 1');
      } else {
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          final currentCount = snapshot.data()?['dailyMessageCount'] ?? 0;
          final newCount = currentCount + 1;

          transaction.update(userRef, {'dailyMessageCount': newCount});
        });

        _userDailyMessageCount = currentCount + 1;

        print(' User message count incremented to $_userDailyMessageCount');
      }

      notifyListeners();
    } catch (e) {
      print(' Error updating user message count: $e');
    }
  }

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _isSettingConversation = false;

  Future<void> setConversationId(String id) async {
    print(' ChatProvider.setConversationId: $id');

    if (_isSettingConversation) {
      print(' Already setting conversation, ignoring duplicate call');
      return;
    }

    if (conversationId == id && _messagesSubscription != null) {
      print(' Already set to conversation $id with active subscription');
      return;
    }

    _isSettingConversation = true;

    try {
      _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _escalationSubscription?.cancel();
      _escalationSubscription = null;

      _messages.clear();
      _processedMessages.clear();
      _streamingContent.clear();
      _pendingRatingsCache.clear();

      _isLoading = false;

      conversationId = id;
      currentConversation = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      await Future.delayed(Duration(milliseconds: 100));

      await loadConversationInfo();
      await loadExistingMessages();

      listenToMessages();
      listenToEscalationResponses();

      await loadUserEscalationCount();

      await Future.delayed(Duration(milliseconds: 100));

      print(' ChatProvider setup complete');
      print('   - Conversation ID: $conversationId');
      print('   - Messages: ${_messages.length}');
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
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
        print(' Loaded conversation: ${currentConversation!.title}');
      } else {
        currentConversation = null;
        print(' Conversation document does not exist');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Error loading conversation info: $e');
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
    } catch (_) {
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

        if (message.rating != null && message.rating!.isNotEmpty) {
          _pendingRatingsCache[message.id] = message.rating!;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (_) {
    }
  }

  StreamSubscription<QuerySnapshot>? _escalationSubscription;

  void listenToEscalationResponses() {
    if (conversationId == null) return;


    _escalationSubscription?.cancel();

    _escalationSubscription = _firestore
        .collection('escalations')
        .where('conversationId', isEqualTo: conversationId)
        .where('status', isEqualTo: 'resolved')
        .snapshots()
        .listen(
          (snapshot) async {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                final escalation = change.doc.data();
                if (escalation == null) continue;

                final staffResponse = escalation['staffResponse'] as String?;
                final respondedBy =
                    escalation['respondedBy'] as String? ?? 'Staff';

                if (staffResponse == null || staffResponse.isEmpty) continue;

                final staffMessageContent =
                    '**Staff Response from $respondedBy:**\n\n$staffResponse';

                final alreadyExists = _messages.any(
                  (msg) =>
                      msg.content == staffMessageContent &&
                      msg.sender == 'staff',
                );

                if (alreadyExists) continue;

                final existingInFirestore =
                    await _firestore
                        .collection('conversations')
                        .doc(conversationId!)
                        .collection('messages')
                        .where('sender', isEqualTo: 'staff')
                        .where('content', isEqualTo: staffMessageContent)
                        .limit(1)
                        .get();

                if (existingInFirestore.docs.isNotEmpty) continue;

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

                await saveMessageToFirebase(conversationId!, staffMessage);
              }
            }
          },
<<<<<<< HEAD
          onError: (_) {
=======
          onError: (error) {
            print(' Error in escalation listener: $error');
          },
        );
  }

  void listenToMessages() {
    if (conversationId == null) return;


    _messagesSubscription = _firestore
        .collection('conversations')
        .doc(conversationId!)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
            if (_isLoading) {
              return;
            }

            bool changed = false;

            for (var change in snapshot.docChanges) {
              final data = change.doc.data();
              if (data == null) continue;

              final message = Message.fromJson(data);
              final index = _messages.indexWhere((m) => m.id == message.id);

              if (change.type == DocumentChangeType.added) {
                final isAlreadyLocal = _messages.any((m) => m.id == message.id);
                final isCurrentlyStreaming = _streamingContent.containsKey(
                  message.id,
                );

                if (!isAlreadyLocal && !isCurrentlyStreaming) {
                  _messages.add(message);
                  _processedMessages.add(message.id);
                  changed = true;
                }
              } else if (change.type == DocumentChangeType.modified) {
                if (index != -1 && !_streamingContent.containsKey(message.id)) {
                  _messages[index] = message;
                  changed = true;
                }
              } else if (change.type == DocumentChangeType.removed) {
                if (index != -1) {
                  _messages.removeAt(index);
                  _processedMessages.remove(message.id);
                  changed = true;
                }
              }
            }

            if (changed) {
              _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifyListeners();
                _onMessageAdded?.call();
              });
            }
          },
<<<<<<< HEAD
          onError: (_) {
=======
          onError: (error) {
            print(' Error listening to messages: $error');
          },
        );
  }

  final Map<String, String> _streamingContent = {};
  final Set<String> _processedMessages = {};

  bool _showTypingIndicator = false;
  bool get showTypingIndicator => _showTypingIndicator;

  String? getStreamingContent(String messageId) => _streamingContent[messageId];

  Future<void> askQuestionWithStreaming(
    BuildContext context,
    String question,
  ) async {
    if (_isLoading) return;

    if (isMessageLimitReached) {
      print(' User daily message limit reached');
      return;
    }

    if (conversationId == null || conversationId!.isEmpty) {
      print(' No conversation ID - creating new conversation');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      try {
        final newConversationId = await UserConstant.createNewConversation(
          userId,
        );
        await setConversationId(newConversationId);
<<<<<<< HEAD
      } catch (_) {
=======
      } catch (e) {
        print(' Error creating conversation: $e');
        return;
      }
    }

    if (conversationId == null || conversationId!.isEmpty) {
      print(' Still no conversation ID after creation attempt');
      return;
    }

    _isLoading = true;

    notifyListeners();
    _onMessageAdded?.call();

    final startTime = DateTime.now();

    try {
      _cohere ??= CohereService();
      final userId = FirebaseAuth.instance.currentUser?.uid;

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
        category: 'General',
        sender: 'user',
        status: 'sent',
        isAnswered: false,
        type: 'text',
        sentAt: DateTime.now(),
        count: count,
      );

      _messages.add(userMsg);
      _processedMessages.add(userMsg.id);
      notifyListeners();
      _onMessageAdded?.call();

<<<<<<< HEAD
      userMessageRef.set(_messageToMap(userMsg)).catchError((_) {
      });

      _updateUserMessageCount().catchError((_) {
=======
      userMessageRef.set(_messageToMap(userMsg)).catchError((e) {
        print(' Background save error: $e');
        print(' Background save error: $e');
      });

      _updateUserMessageCount().catchError((e) {
        print(' Background count update error: $e');
      });

      final embeddingFuture = _generateEmbeddingCached(question);
      final faqFuture = _ensureFAQCacheLoaded();

      await Future.wait([embeddingFuture, faqFuture]);
      final currentEmbedding = await embeddingFuture;
      final existingFAQ = _findBestFAQMatch(question, currentEmbedding);

      String questionCategory;
      if (existingFAQ != null && existingFAQ['category'] != null) {
        questionCategory = existingFAQ['category'] as String;
      } else {
        questionCategory = await _classifyQuestionCategoryFast(question);
      }

<<<<<<< HEAD
      userMessageRef.update({'category': questionCategory}).catchError((_) {
=======
      userMessageRef.update({'category': questionCategory}).catchError((e) {
        print(' Background category update error: $e');
      });

      if (currentConversation != null) {
        final title = currentConversation!.title.toLowerCase();
        final shouldUpdateTitle =
            (title.contains('new conversation') ||
                title == 'untitled' ||
                title.trim().isEmpty) &&
            _messages.where((m) => m.sender == 'user').length <= 1;

        if (shouldUpdateTitle) {
<<<<<<< HEAD
          _updateConversationTitleNow(question).catchError((_) {
=======
          _updateConversationTitleNow(question).catchError((e) {
            print(' Background title update error: $e');
          });
        }
      }

      final allMessages =
          _messages.where((m) => m.conversationId == conversationId).toList();
      allMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      final recentHistory =
          allMessages.length > 10
              ? allMessages.sublist(allMessages.length - 10)
              : allMessages;

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

      _messages.add(botMessage);
      _processedMessages.add(botMessageId);
      _streamingContent[botMessageId] = "";

      notifyListeners();
      _onMessageAdded?.call();

      String finalAnswer = "";

      if (existingFAQ != null) {
        final String answer = existingFAQ["answer"];
        const int chunkSize = 50;

        for (int i = 0; i < answer.length; i += chunkSize) {
          final chunk = answer.substring(
            i,
            (i + chunkSize < answer.length) ? i + chunkSize : answer.length,
          );

          _streamingContent[botMessageId] =
              _streamingContent[botMessageId]! + chunk;

          notifyListeners();
          _onMessageAdded?.call();

          await Future.delayed(Duration(milliseconds: 20));
        }

        finalAnswer = answer;

        _incrementFAQSimilarityCountAsync(existingFAQ["question"]).catchError((
          _,
        ) {
          print(' Background FAQ count error: $e');
        });
      } else {
        await for (final streamedText in _retriever.generateAnswerStream(
          question,
          conversationHistory: recentHistory,
          conversationId: conversationId!,
        )) {
          _streamingContent[botMessageId] = streamedText;

          notifyListeners();
          _onMessageAdded?.call();

          finalAnswer = streamedText;
        }
      }

      _streamingContent.remove(botMessageId);

      String verified = finalAnswer;
      if (verified.length > 300) {
        final half = verified.length ~/ 2;
        if (verified.substring(0, half) == verified.substring(half)) {
          verified = verified.substring(0, half);
        }
      }

      final idx = _messages.indexWhere((m) => m.id == botMessageId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(content: verified);
      }

      notifyListeners();
      _onMessageAdded?.call();

      final totalMs = DateTime.now().difference(startTime).inMilliseconds;

      Future(() async {
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
<<<<<<< HEAD
      }).catchError((_) {
=======
      }).catchError((e) {
        print(' Background batch save error: $e');
      });

      _handlePostResponseTasks(
        context,
        question,
        verified,
        currentEmbedding,
        questionCategory,
        userId,
<<<<<<< HEAD
      ).catchError((_) {
=======
      ).catchError((e) {
        print(' Background post-response error: $e');
      });
    } finally {
      _isLoading = false;
      notifyListeners();
      _onMessageAdded?.call();
    }
  }

  String _cleanTitle(String title) {
    String cleaned = title.trim();

    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    if (cleaned.startsWith("'") && cleaned.endsWith("'")) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    return cleaned.trim();
  }

  Future<void> _updateConversationTitleNow(String question) async {
    if (conversationId == null) return;

    try {
      final titlePrompt = '''
Generate a short, descriptive title (max 5 words) for the following user question:

Question:
$question
''';

      final newTitle = await _cohere!.generateResponse(titlePrompt);

      if (newTitle != null && newTitle.trim().isNotEmpty) {
        final updatedTitle = _cleanTitle(newTitle);

        await _firestore
            .collection('conversations')
            .doc(conversationId!)
            .update({'title': updatedTitle});

        if (currentConversation != null) {
          currentConversation = Conversation(
            id: currentConversation!.id,
            userId: currentConversation!.userId,
            title: updatedTitle,
            status: currentConversation!.status,
            createdAt: currentConversation!.createdAt,
          );
        }

        final convIndex = UserConstant.recentConversations.indexWhere(
          (c) => c['id'] == conversationId,
        );
        if (convIndex != -1) {
          UserConstant.recentConversations[convIndex]['title'] = updatedTitle;
        }

        notifyListeners();
      }
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (titleError) {
      print(' Error updating conversation title: $titleError');
    }
  }

  Future<void> cleanExistingConversationTitles() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final conversationsSnapshot =
          await _firestore
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .get();

      final batch = _firestore.batch();
      int cleanedCount = 0;

      for (var doc in conversationsSnapshot.docs) {
        final data = doc.data();
        final currentTitle = data['title'] as String?;

        if (currentTitle != null && currentTitle.isNotEmpty) {
          final cleanedTitle = _cleanTitle(currentTitle);

          if (cleanedTitle != currentTitle) {
            batch.update(doc.reference, {'title': cleanedTitle});
            cleanedCount++;
          }
        }
      }

      if (cleanedCount > 0) {
        await batch.commit();
        print(' Cleaned $cleanedCount conversation titles');
      }
    } catch (e) {
      print(' Error cleaning titles: $e');
    }
  }

  // =========================================================================
  // FIX 1: FAQ Match - resolve embedding field (handles both 'embedding' and
  // 'geminiEmbedding') so predefined and auto-promoted FAQs both work.
  // =========================================================================
  Map<String, dynamic>? _findBestFAQMatch(
    String question,
    List<double> questionEmbedding,
  ) {
    try {
      double highestSimilarity = 0.0;
      Map<String, dynamic>? bestMatch;

      print(' Checking ${FAQCache.cache.length} FAQs for match');
      print(' Question: "$question"');

      for (var entry in FAQCache.cache.entries) {
        final data = entry.value;

        //  Accept both 'embedding' (auto-promoted) and 'geminiEmbedding'
        // (predefined/server-generated) so no FAQ is silently skipped.
        final rawEmbedding = data['embedding'] ?? data['geminiEmbedding'];

        if (rawEmbedding == null) {
          print(' FAQ missing embedding: ${data['question']}');
          continue;
        }

        final answer = data['answer'] as String?;
        if (answer == null || answer.trim().isEmpty) {
          print(' FAQ has empty answer: ${data['question']}');
          continue;
        }

        List<double> faqEmbedding;
        try {
          faqEmbedding = List<double>.from(
            (rawEmbedding as List).map((e) => (e as num).toDouble()),
          );
<<<<<<< HEAD
        } catch (_) {
=======
        } catch (e) {
          print(' Invalid embedding format for: ${data['question']}');
          continue;
        }

        //  Strict dimension check - only compare 768-dim embeddings.
        // Mixing different embedding models produces nonsense similarity scores.
        if (faqEmbedding.length != 768 || questionEmbedding.length != 768) {
<<<<<<< HEAD
=======
          print(
            ' Embedding dimension mismatch or wrong model: '
            ' Embedding dimension mismatch or wrong model: '
            'FAQ=${faqEmbedding.length}, Query=${questionEmbedding.length} '
            '(expected 768). Skipping.',
          );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
          continue;
        }

        final similarity = cosineSimilarity(questionEmbedding, faqEmbedding);

<<<<<<< HEAD
=======
        print(
          ' FAQ: "${(data['question'] as String).substring(0, min(50, (data['question'] as String).length))}..."',
          ' FAQ: "${(data['question'] as String).substring(0, min(50, (data['question'] as String).length))}..."',
        );
        print('   Answer length: ${answer.length} chars');
        print('   Category: ${data['category'] ?? 'N/A'}');
        print('   Similarity: ${similarity.toStringAsFixed(4)}');
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66

        if (similarity > 0.75 && similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatch = {
            'question': data['question'],
            'answer': answer,
            'category': data['category'] ?? 'General',
            'similarity': similarity,
          };
          print('    NEW BEST MATCH!');
        }
      }

      if (bestMatch != null) {
        print(' Found FAQ match:');
        print(' Found FAQ match:');
        print('   Question: ${bestMatch['question']}');
        print('   Category: ${bestMatch['category']}');
        print('   Similarity: ${highestSimilarity.toStringAsFixed(4)}');
      } else {
        print(
          ' No FAQ match found (best similarity: ${highestSimilarity.toStringAsFixed(4)})',
          ' No FAQ match found (best similarity: ${highestSimilarity.toStringAsFixed(4)})',
        );
      }

      return bestMatch;
    } catch (e) {
      print(' Error finding FAQ match: $e');
      return null;
    }
  }

  Future<String> _classifyQuestionCategoryFast(String question) async {
    final q = question.toLowerCase();

    if (RegExp(
      r'\b(admission|admit|admitted|enroll|enrollment|application|apply|applying|entrance|entry|requirement|requirements|eligibility|qualify|acceptance|accepted|applicant)\b',
    ).hasMatch(q)) {
      return 'Admission';
    }

    if (RegExp(
      r'\b(scholarship|scholarships|scholar|grant|grants|financial\s*aid|funding|stipend|allowance|tuition\s*fee\s*discount|free\s*tuition|financial\s*support)\b',
    ).hasMatch(q)) {
      return 'Scholarship';
    }

    if (RegExp(
      r'\b(placement|job|jobs|career|careers|internship|intern|employment|work|hiring|vacancy|vacancies|position|positions|ojt|practicum|on[- ]the[- ]job|training)\b',
    ).hasMatch(q)) {
      return 'Placement';
    }

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

        if (normalized.toLowerCase().contains('admission')) return 'Admission';
        if (normalized.toLowerCase().contains('scholarship'))
          return 'Scholarship';
        if (normalized.toLowerCase().contains('placement')) return 'Placement';
      }
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Classification error: $e');
    }

    return 'General';
  }

  // =========================================================================
  // FIX 2: FAQ cache loader - resolve both embedding field names and enforce
  // 768-dimension check so mismatched embeddings never enter the cache.
  // =========================================================================
  Future<void> _ensureFAQCacheLoaded() async {
    if (FAQCache.isExpired || FAQCache.cache.isEmpty) {
      try {
        print(' Refreshing FAQ cache...');

        final faqSnapshot =
            await _firestore
                .collection('faqs')
                .where('answer', isNotEqualTo: "")
                .get();

        print(' Found ${faqSnapshot.docs.length} FAQs in Firestore');

        Map<String, Map<String, dynamic>> validFAQs = {};
        int skippedCount = 0;

        for (var doc in faqSnapshot.docs) {
          final data = doc.data();
          final question = data['question'] as String?;
          final answer = data['answer'] as String?;

          if (question == null || question.isEmpty) {
            skippedCount++;
            continue;
          }

          if (answer == null || answer.trim().isEmpty) {
            skippedCount++;
            continue;
          }

          //  Accept both field names; normalise to 'embedding' in cache
          // so _findBestFAQMatch always finds it under 'embedding'.
          final rawEmbedding = data['embedding'] ?? data['geminiEmbedding'];

          if (rawEmbedding == null ||
              rawEmbedding is! List ||
              (rawEmbedding as List).isEmpty) {
<<<<<<< HEAD
=======
            print(
              ' Skipping FAQ ${doc.id}: No embedding - '
              ' Skipping FAQ ${doc.id}: No embedding - '
              '"${question.substring(0, min(50, question.length))}"',
            );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
            skippedCount++;
            continue;
          }

          //  Enforce 768 dimensions - reject wrong-model embeddings.
          if ((rawEmbedding as List).length != 768) {
<<<<<<< HEAD
=======
            print(
              ' Skipping FAQ ${doc.id}: Wrong embedding size '
              ' Skipping FAQ ${doc.id}: Wrong embedding size '
              '${rawEmbedding.length} (expected 768) - '
              '"${question.substring(0, min(50, question.length))}"',
            );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
            skippedCount++;
            continue;
          }

          // Normalise: always store under 'embedding' key in memory cache.
          final normalisedData = Map<String, dynamic>.from(data);
          normalisedData['embedding'] = rawEmbedding;
          normalisedData.remove('geminiEmbedding');

          validFAQs[doc.id] = normalisedData;
<<<<<<< HEAD
=======
          print(
            ' Cached FAQ: "${question.substring(0, min(50, question.length))}" '
            ' Cached FAQ: "${question.substring(0, min(50, question.length))}" '
            '(${answer.length} chars, ${rawEmbedding.length}d)',
          );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
        }

        FAQCache.cache.clear();
        FAQCache.cache.addAll(validFAQs);
        FAQCache.lastCacheUpdate = DateTime.now();

        print(' FAQ Cache updated:');
        print('   Valid FAQs: ${validFAQs.length}');
        print('   Skipped: $skippedCount');
      } catch (e) {
        print(' Error loading FAQ cache: $e');
        print(' Error loading FAQ cache: $e');
      }
    } else {
      print(' Using cached FAQs (${FAQCache.cache.length} entries)');
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
    } catch (_) {
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

                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
        print(' Auto-escalation cancelled by user');
        return;
      }

      selectedReason = result['selectedReason'] as String;
      userReason = result['userReason'] as String?;

      final fullReason =
          userReason != null && userReason.isNotEmpty
              ? '$selectedReason — $userReason'
              : selectedReason;

      String messageCategory = 'General';
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].sender == 'user') {
          messageCategory = _messages[i].category ?? 'General';
          break;
        }
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown User';

      final userId = FirebaseAuth.instance.currentUser?.uid;
      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      final escalatedData = {
        'escalationId': escalationId,
        'userId': userId,
        'user': userName,
        'conversationId': conversationId!,
        'question': question,
        'botAnswer': answerText,
        'status': 'pending',
        'reason': fullReason,
        'category': messageCategory,
        'createdAt': Timestamp.now(),
      };

      await escalationRef.set(escalatedData);

      print(' Auto-escalation created: $escalationId');

      if (context.mounted) {
        await _showEscalationSuccessDialog(context);
      }
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Error creating auto-escalation: $e');
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
      String messageCategory = 'General';

      final messages =
          Provider.of<ChatProvider>(context, listen: false).messages;

      for (int i = messages.length - 1; i >= 0; i--) {
        if (messages[i].sender == 'user') {
          messageCategory = messages[i].category ?? 'General';
          break;
        }
      }

      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      final escalatedData = {
        'escalationId': escalationId,
        'userId': userId,
        'conversationId': conversationId!,
        'question': question,
        'botAnswer': answerText,
        'status': 'pending',
        'reason': userReason ?? 'Auto-escalated: $triggerKeyword',
        'category': messageCategory,
        'userReason': userReason,
        'triggerKeyword': triggerKeyword,
        'createdAt': Timestamp.now(),
      };

      await escalationRef.set(escalatedData);
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Error creating auto-escalation: $e');
    }
  }

  Future<void> _checkAndPromoteToFAQOptimized(
    String question,
    List<double> currentEmbedding,
    String botAnswer,
    String category,
  ) async {
    try {
      if (!_isAnswerWorthyOfFAQ(botAnswer) ||
          !_isQuestionWorthyOfFAQ(question)) {
        return;
      }

      final querySnapshot =
          await _firestore
              .collectionGroup('messages')
              .where('sender', isEqualTo: 'user')
              .where('isAnswered', isEqualTo: true)
              .where('category', isEqualTo: category)
              .orderBy('sent_at', descending: true)
              .limit(200)
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

          if (pastEmbedding.length != 768 || currentEmbedding.length != 768) {
            continue;
          }

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
        } catch (_) {
          continue;
        }
      }

      for (var group in questionGroups.values) {
        // Threshold: 10+ occurrences this month to become a candidate.
        if (group.questionCount >= 10 && group.averageSimilarity > 0.90) {
          final representativeQuestion = group.getMostRepresentativeQuestion();

          // -- Duplicate guard: skip if a live FAQ already covers this --
          final exactFAQMatch =
              await _firestore
                  .collection('faqs')
                  .where('question', isEqualTo: representativeQuestion)
                  .limit(1)
                  .get();

          if (exactFAQMatch.docs.isNotEmpty) {
            print(' Live FAQ already exists for: $representativeQuestion');
            continue;
          }

          // Semantic duplicate check against live FAQs in cache.
          bool semanticDuplicateFound = false;
          for (var cacheEntry in FAQCache.cache.values) {
            final rawEmb =
                cacheEntry['embedding'] ?? cacheEntry['geminiEmbedding'];
            if (rawEmb == null) continue;
            try {
              final existingEmb = List<double>.from(
                (rawEmb as List).map((e) => (e as num).toDouble()),
              );
              if (existingEmb.length != 768) continue;
              final sim = cosineSimilarity(currentEmbedding, existingEmb);
              if (sim > 0.92) {
<<<<<<< HEAD
=======
                print(
                  ' Semantic duplicate found in live FAQs '
                  ' Semantic duplicate found in live FAQs '
                  '(sim=${sim.toStringAsFixed(3)}): '
                  '${cacheEntry['question']}',
                );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
                semanticDuplicateFound = true;
                break;
              }
            } catch (_) {
              continue;
            }
          }
          if (semanticDuplicateFound) continue;

          // -- Duplicate guard: skip if a pending candidate already exists --
          final existingCandidate =
              await _firestore
                  .collection('faq_candidates')
                  .where('question', isEqualTo: representativeQuestion)
                  .where('status', isEqualTo: 'pending')
                  .limit(1)
                  .get();

          final now = Timestamp.now();

          if (existingCandidate.docs.isNotEmpty) {
            // Candidate already exists — just bump the occurrence count and
            // update the lastSeen timestamp so the admin sees fresh numbers.
            await existingCandidate.docs.first.reference.update({
              'occurrenceCount': group.questionCount,
              'lastSeen': now,
              'averageSimilarity': group.averageSimilarity,
            });
            continue;
          }

          // -- New candidate --
          // Also do a semantic duplicate check against existing pending
          // candidates to prevent near-duplicate entries.
          final pendingCandidates =
              await _firestore
                  .collection('faq_candidates')
                  .where('status', isEqualTo: 'pending')
                  .where('category', isEqualTo: category)
                  .get();

          bool candidateDuplicateFound = false;
          for (var cd in pendingCandidates.docs) {
            final cdData = cd.data();
            final cdEmb = cdData['embedding'];
            if (cdEmb == null) continue;
            try {
              final embList = List<double>.from(
                (cdEmb as List).map((e) => (e as num).toDouble()),
              );
              if (embList.length != 768) continue;
              final sim = cosineSimilarity(currentEmbedding, embList);
              if (sim > 0.92) {
                // Bump that existing candidate instead.
                await cd.reference.update({
                  'occurrenceCount': FieldValue.increment(group.questionCount),
                  'lastSeen': now,
                });
<<<<<<< HEAD
=======
                print(
                  ' Merged into existing candidate '
                  ' Merged into existing candidate '
                  '(sim=${sim.toStringAsFixed(3)}): ${cdData['question']}',
                );
>>>>>>> 6e2c8251070fdc1d1de6c498996660a7989f8b66
                candidateDuplicateFound = true;
                break;
              }
            } catch (_) {
              continue;
            }
          }
          if (candidateDuplicateFound) continue;

          // Write the new candidate.
          await _firestore.collection('faq_candidates').add({
            'question': representativeQuestion,
            'answer': botAnswer,
            'category': category,
            'embedding': currentEmbedding,
            'occurrenceCount': group.questionCount,
            'averageSimilarity': group.averageSimilarity,
            'firstSeen': now,
            'lastSeen': now,
            'status': 'pending',
          });

<<<<<<< HEAD
        }
      }
    } catch (_) {
=======
          print(
            ' New FAQ candidate queued for admin review: '
            ' New FAQ candidate queued for admin review: '
            '$representativeQuestion',
          );
          print('   Occurrences : ${group.questionCount}');
          print(
            '   Avg similarity: '
            '${group.averageSimilarity.toStringAsFixed(3)}',
          );
          print('   Category    : $category');
        } else if (group.questionCount >= 5) {
          print(
            ' Group approaching threshold: ${group.questionCount}/10 '
            ' Group approaching threshold: ${group.questionCount}/10 '
            '(avg sim: ${group.averageSimilarity.toStringAsFixed(3)})',
          );
        }
      }
    } catch (e) {
      print(' Error in FAQ candidate promotion: $e');
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
      'admission': ['admission', 'enrollment', 'exam', 'entry'],
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
    } catch (_) {
    }
  }

  void unawaited(Future<void> future) {
    future.catchError((_) {
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
    } catch (_) {
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

        if (newTitle != null && newTitle.trim().isNotEmpty) {
          final updatedTitle = _cleanTitle(newTitle.trim());

          await _firestore
              .collection('conversations')
              .doc(conversationId!)
              .update({'title': updatedTitle});

          if (currentConversation != null) {
            currentConversation = Conversation(
              id: currentConversation!.id,
              userId: currentConversation!.userId,
              title: updatedTitle,
              status: currentConversation!.status,
              createdAt: currentConversation!.createdAt,
            );
          }

          final convIndex = UserConstant.recentConversations.indexWhere(
            (c) => c['id'] == conversationId,
          );
          if (convIndex != -1) {
            UserConstant.recentConversations[convIndex]['title'] = updatedTitle;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        }
      } catch (_) {
      }
    }
  }

  late final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<List<double>> generateEmbedding(String question) async {
    if (!kIsWeb && Platform.isWindows) {
      return await _generateEmbeddingDirect(question);
    } else {
      return await _generateEmbeddingFirebase(question);
    }
  }

  Future<List<double>> _generateEmbeddingDirect(String question) async {
    try {

      if (_geminiApiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY is not defined.');
      }

      final response = await http.post(
        Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=$_geminiApiKey",
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "content": {
            "parts": [
              {"text": question},
            ],
          },
          "outputDimensionality": 768,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Gemini API error: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final embedding =
          (data['embedding']['values'] as List)
              .map((e) => (e as num).toDouble())
              .toList();

      // Safety assertion: ensure we always get 768 dimensions.
      if (embedding.length != 768) {
        throw Exception(
          'Unexpected embedding dimension: ${embedding.length} (expected 768)',
        );
      }

      return embedding;
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Direct Embedding Error: $e');
      rethrow;
    }
  }

  Future<List<double>> _generateEmbeddingFirebase(String question) async {
    try {
      print(' Mobile/Web: Generating Gemini embedding via Firebase');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateEmbedding',
      );
      final result = await callable.call({'text': question});

      final embedding =
          (result.data['embedding'] as List)
              .map((e) => (e as num).toDouble())
              .toList();

      // Safety assertion: ensure we always get 768 dimensions.
      if (embedding.length != 768) {
        throw Exception(
          'Unexpected embedding dimension from Firebase: ${embedding.length} '
          '(expected 768)',
        );
      }

      return embedding;
<<<<<<< HEAD
    } catch (_) {
=======
    } catch (e) {
      print(' Firebase Functions Error: $e');
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

      _pendingRatingsCache[messageId] = rating;

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'rating': rating, 'rated_at': Timestamp.now()});

    } catch (_) {
      _pendingRatingsCache.remove(messageId);
      rethrow;
    }
  }

  Future<void> incrementFAQSimilarityCount(String faqQuestion) async {
    try {
      final canInteract = await canUserInteract();
      if (!canInteract) {
        print(' Skipping FAQ similarity increment - user at message limit');
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

        print(' Incremented similarity count for FAQ: $faqQuestion');
      }
    } catch (e) {
      print(' Error incrementing FAQ similarity count: $e');
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
    print(' ChatProvider.clearMessages called');

    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _escalationSubscription?.cancel();
    _escalationSubscription = null;

    _messages.clear();
    _processedMessages.clear();
    _streamingContent.clear();
    _pendingRatingsCache.clear();

    conversationId = null;
    currentConversation = null;

    _isLoading = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    print('✅ ChatProvider cleared');
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
