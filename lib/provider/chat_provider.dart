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
  bool _isCreatingMessage = false;

  VoidCallback? _onMessageAdded;

  ChatProvider(this._retriever);

  final Map<String, String> _pendingRatingsCache = {};
  String? getCachedRating(String messageId) => _pendingRatingsCache[messageId];

  final List<Message> _messages = [];
  List<Message> get messages => _messages;

  String? conversationId;
  Conversation? currentConversation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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

  void setScrollCallback(VoidCallback callback) {
    _onMessageAdded = callback;
  }

  void clearScrollCallback() {
    _onMessageAdded = null;
  }

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  final String _apiKey = "IhyfOnMhPrpfgiDSqf3c0ayCmGpHAicG1JqbGVOY";

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
      _isCreatingMessage = false;

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
        currentConversation = Conversation.fromJson(doc.data()!);
      } else {
        currentConversation = null;
      }

      // ✅ CRITICAL FIX: Schedule notification after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print('Error loading conversation info: $e');
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
                final escalation = change.doc.data() as Map<String, dynamic>?;
                if (escalation == null) continue;

                final staffResponse = escalation['staffResponse'] as String?;
                final respondedBy =
                    escalation['respondedBy'] as String? ?? 'Staff';
                final escalationId = change.doc.id;

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
      if (_isLoading) {
        print('⏭️ Skipping listener update - message creation in progress');
        return;
      }
      
      bool changed = false;

      print('📩 Message snapshot received: ${snapshot.docs.length} total messages');
      print('   Changes: ${snapshot.docChanges.length}');

      for (var change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final message = Message.fromJson(data);
        final index = _messages.indexWhere((m) => m.id == message.id);

        if (change.type == DocumentChangeType.added) {
          final isCurrentlyStreaming = _streamingContent.containsKey(message.id);
          
          if (index == -1 && !_processedMessages.contains(message.id) && !isCurrentlyStreaming) {
            print('➕ Adding message: ${message.id}');
            print('   Sender: ${message.sender}');
            print('   Content: ${message.content.substring(0, min(50, message.content.length))}...');
            
            _messages.add(message);
            _processedMessages.add(message.id);
            changed = true;
          } else {
            print('⏭️ Skipping duplicate/streaming: ${message.id}');
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
  // In ChatProvider class, replace askQuestionWithStreaming method:

  // In ChatProvider class, replace askQuestionWithStreaming method:

 Future<void> askQuestionWithStreaming(
  BuildContext context,
  String question,
) async {
  if (_isLoading) return;

  // ✅ FIX: Create conversation if none exists
  if (conversationId == null || conversationId!.isEmpty) {
    print('⚠️ No conversation ID - creating new conversation');
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {

      return;
    }

    try {
      // Create new conversation
      final newConversationId = await UserConstant.createNewConversation(userId);
      
      // Set it in the provider
      await setConversationId(newConversationId);
      
      print('✅ Created new conversation: $newConversationId');
      
      // Small delay to ensure setup completes
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('❌ Error creating conversation: $e');
 
      return;
    }
  }

  // ✅ Double-check conversation exists
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

      // ───────────────────────────────────────────────
      //  ✅ 1. Create user message immediately (UI fast)
      // ───────────────────────────────────────────────
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

      // Save user message in background (no await)
      unawaited(userMessageRef.set(_messageToMap(userMsg)));

      // ───────────────────────────────────────────────
      //  ⚡ 2. Limit history to last 5 messages only
      // ───────────────────────────────────────────────
      final history =
          _messages.where((m) => m.conversationId == conversationId).toList();

      history.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      final recentHistory =
          history.length > 5 ? history.sublist(history.length - 5) : history;

      // ───────────────────────────────────────────────
      //  ⚡ 3. Run embedding + category + FAQ load fully in parallel
      // ───────────────────────────────────────────────
      final results = await Future.wait([
        _generateEmbeddingCached(question),
        _classifyQuestionCategoryFast(question),
        _ensureFAQCacheLoaded(),
      ]);

      final currentEmbedding = results[0] as List<double>;
      final classifiedCategory = results[1] as String;
      final existingFAQ = _findBestFAQMatch(question, currentEmbedding);

      // ───────────────────────────────────────────────
      //  ⚡ 4. Prepare bot message placeholder immediately
      // ───────────────────────────────────────────────
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
      _streamingContent[botMessageId] = "";
      notifyListeners();
      _onMessageAdded?.call();

      String finalAnswer = "";

      // ───────────────────────────────────────────────
      //  ⚡ 5. FAST PATH: FAQ answer (no RAG, no LLM)
      // ───────────────────────────────────────────────
      if (existingFAQ != null) {
        final String answer = existingFAQ["answer"];
        final int chunkSize = 20; // faster streaming

        for (int i = 0; i < answer.length; i += chunkSize) {
          final chunk = answer.substring(
            i,
            (i + chunkSize < answer.length) ? i + chunkSize : answer.length,
          );

          _streamingContent[botMessageId] =
              _streamingContent[botMessageId]! + chunk;

          // Update UI only every 3 chunks (fast!)
          if (i % (chunkSize * 3) == 0) {
            notifyListeners();
            _onMessageAdded?.call();
          }
        }

        finalAnswer = answer;
        unawaited(_incrementFAQSimilarityCountAsync(existingFAQ["question"]));
      } else {
        // ───────────────────────────────────────────────
        //  ⚡ 6. RAG STREAMING (optimized UI updates)
        // ───────────────────────────────────────────────
        int chunkCounter = 0;

        await for (final streamedText in _retriever.generateAnswerStream(
          question,
          conversationHistory: recentHistory,
          conversationId: conversationId!,
        )) {
          chunkCounter++;

          _streamingContent[botMessageId] = streamedText;

          // Update UI only every 3–5 chunks instead of every chunk
          if (chunkCounter % 4 == 0) {
            notifyListeners();
            _onMessageAdded?.call();
          }

          finalAnswer = streamedText;
        }
      }

      // Remove temporary streaming content
      _streamingContent.remove(botMessageId);

      // ───────────────────────────────────────────────
      //  ⚡ 7. Remove duplication only if VERY long
      // ───────────────────────────────────────────────
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

      // ───────────────────────────────────────────────
      //  ⚡ 8. Compute response time (ms)
      // ───────────────────────────────────────────────
      final totalMs = DateTime.now().difference(startTime).inMilliseconds;
      print("⚡ Optimized total response time: ${totalMs}ms");

      // ───────────────────────────────────────────────
      //  ⚡ 9. Save bot message + update user message (async)
      //      This removes 400–900ms from critical path!
      // ───────────────────────────────────────────────
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

      // ───────────────────────────────────────────────
      //  ⚡ 10. Background tasks (not blocking)
      // ───────────────────────────────────────────────
      unawaited(
        _handlePostResponseTasks(
          context,
          question,
          verified,
          currentEmbedding,
          classifiedCategory,
          userId,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
      _onMessageAdded?.call();
    }
  }

  Future<String> _classifyQuestionCategoryFast(String question) async {
    final lowercaseQuestion = question.toLowerCase();

    // Use keyword matching first (instant)
    if (lowercaseQuestion.contains(
      RegExp(
        r'\b(admission|admit|enroll|application|apply|entrance|entry|requirements?|eligibility|qualify)\b',
      ),
    )) {
      return 'Admission';
    } else if (lowercaseQuestion.contains(
      RegExp(
        r'\b(scholarship|grant|financial|aid|funding|stipend|allowance|discount|free)\b',
      ),
    )) {
      return 'Scholarship';
    } else if (lowercaseQuestion.contains(
      RegExp(
        r'\b(placement|job|career|internship|work|employment|company|companies|hiring)\b',
      ),
    )) {
      return 'Placement';
    }

    // If no keyword match, return General (skip LLM classification for speed)
    return 'General';
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
        print('⚠️ Embedding dimension mismatch: FAQ=${faqEmbedding.length}, Query=${questionEmbedding.length}');
        continue;
      }

      final similarity = cosineSimilarity(questionEmbedding, faqEmbedding);

      print('📊 FAQ: "${(data['question'] as String).substring(0, min(50, (data['question'] as String).length))}..."');
      print('   Answer length: ${answer.length} chars');
      print('   Similarity: ${similarity.toStringAsFixed(4)}');

      // ✅ LOWERED THRESHOLD: Changed from 0.85 to 0.75 for better matching
      if (similarity > 0.75 && similarity > highestSimilarity) {
        highestSimilarity = similarity;
        bestMatch = {
          'question': data['question'],
          'answer': answer,
          'similarity': similarity,
        };
        print('   🎯 NEW BEST MATCH!');
      }
    }

    if (bestMatch != null) {
      print('✅ Found FAQ match:');
      print('   Question: ${bestMatch['question']}');
      print('   Similarity: ${highestSimilarity.toStringAsFixed(4)}');
      print('   Answer length: ${(bestMatch['answer'] as String).length} chars');
    } else {
      print('❌ No FAQ match found (best similarity: ${highestSimilarity.toStringAsFixed(4)})');
    }

    return bestMatch;
  } catch (e) {
    print('❌ Error finding FAQ match: $e');
    return null;
  }
}

// ✅ ALSO UPDATE: _ensureFAQCacheLoaded to validate data
Future<void> _ensureFAQCacheLoaded() async {
  if (FAQCache.isExpired || FAQCache.cache.isEmpty) {
    try {
      print('🔄 Refreshing FAQ cache...');
      
      // ✅ CRITICAL: Only fetch FAQs with non-empty answers AND embeddings
      final faqSnapshot = await _firestore
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

        if (embedding == null || !(embedding is List) || (embedding as List).isEmpty) {
          print('⚠️ Skipping FAQ ${doc.id}: No embedding - "${question.substring(0, min(50, question.length))}"');
          skippedCount++;
          continue;
        }

        // ✅ Only add valid FAQs to cache
        validFAQs[doc.id] = data;
        print('✅ Cached FAQ: "${question.substring(0, min(50, question.length))}" (${answer.length} chars)');
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
        _updateConversationTitleIfNeeded(question), // ✅ ADD THIS LINE
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
        final reasonController = TextEditingController();

        final bool? escalate = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Need Human Help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "I couldn't provide a complete answer to your question. Would you like me to escalate this to OASP staff for personalized assistance?",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "A staff member will review your question and respond directly.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Reason for escalation (optional)",
                      hintText:
                          "e.g. I need clarification about scholarship requirements",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    _processAutoEscalation(
                      userId,
                      question,
                      answerText,
                      keyword,
                      userReason:
                          reasonController.text.trim().isNotEmpty
                              ? reasonController.text.trim()
                              : null,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Yes, Get Help',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );

        break;
      }
    }
  }

  Future<void> _processAutoEscalation(
    String? userId,
    String question,
    String answerText,
    String triggerKeyword, {
    String? userReason,
  }) async {
    try {
      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      final escalatedData = {
        'escalationId': escalationId,
        'userId': userId,
        'conversationId': conversationId!,
        'question': question,
        'botAnswer': answerText,
        'status': 'pending',
        'userReason': userReason,
        'createdAt': Timestamp.now(),
      };

      await escalationRef.set(escalatedData);

      // The Cloud Function will handle creating notifications
      // No need to create them manually here anymore

      print('Auto-escalation created: $escalationId');
    } catch (e) {
      print('Error creating auto-escalation: $e');
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

      final querySnapshot =
          await _firestore
              .collectionGroup('messages')
              .where('sender', isEqualTo: 'user')
              .where('isAnswered', isEqualTo: true)
              .where('category', isEqualTo: category)
              .orderBy('sent_at', descending: true)
              .limit(50)
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

          if (similarity > 0.90) {
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

      // Promote groups that meet the threshold
      final batch = _firestore.batch();
      bool hasBatchOperations = false;

      for (var group in questionGroups.values) {
        if (group.questionCount >= 5 && group.averageSimilarity > 0.92) {
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
                  'Auto-promoted after ${group.questionCount} similar questions',
              'similarityCount': group.questionCount,
              'averageSimilarity': group.averageSimilarity,
            };

            batch.set(faqRef, faqData);
            hasBatchOperations = true;

            print('Auto-adding FAQ: $representativeQuestion');
          }
        }
      }

      if (hasBatchOperations) {
        await batch.commit();
        FAQCache.lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      }
    } catch (e) {
      print('Error in FAQ promotion: $e');
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

          await _firestore
              .collection('conversations')
              .doc(conversationId!)
              .update({'title': updatedTitle});

          print('Updated conversation title to: "$updatedTitle"');

          if (currentConversation != null) {
            currentConversation = Conversation(
              id: currentConversation!.id,
              title: updatedTitle,
              userId: currentConversation!.userId,
              status: currentConversation!.status,
              createdAt: currentConversation!.createdAt,
            );
            notifyListeners();
          }
        }
      } catch (titleError) {
        print('Error updating conversation title: $titleError');
      }
    }
  }

  Future<List<double>> generateEmbedding(String question) async {
    try {
      final response = await http.post(
        Uri.parse("https://api.cohere.ai/v1/embed"),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "texts": [question],
          "model": "embed-english-v2.0",
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate embedding: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return (data['embeddings'][0] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (e) {
      print('Error generating embedding: $e');
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

        print('Incremented similarity count for FAQ: $faqQuestion');
      }
    } catch (e) {
      print('Error incrementing FAQ similarity count: $e');
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
    _isCreatingMessage = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    print('✅ ChatProvider cleared (including escalation listener)');
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _escalationSubscription?.cancel(); // ✅ NEW: Cancel on dispose
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