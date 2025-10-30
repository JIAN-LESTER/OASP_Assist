
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:capstone_project/models/conversations.dart';
import 'package:capstone_project/models/message.dart';
import 'package:capstone_project/models/notification.dart';
import 'package:capstone_project/provider/embedding.dart';
import 'package:capstone_project/services/answer_retrieval.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/services/answer_retrieval.dart';

// Cache classes for better performance
class FAQCache {
  static Map<String, Map<String, dynamic>> cache = {};
  static DateTime lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration cacheExpiry = Duration(hours: 1);
  
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
  static const int maxSize = 500;
  
  static List<double>? get(String key) => _cache[key];
  
  static void put(String key, List<double> value) {
    if (_cache.length >= maxSize) {
      // Remove oldest entries
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

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  final String _apiKey = "IhyfOnMhPrpfgiDSqf3c0ayCmGpHAicG1JqbGVOY";

  Future<void> setConversationId(String id) async {
    conversationId = id;
    _messages.clear();
    currentConversation = null;

    await loadConversationInfo();
    await loadExistingMessages();

    _messagesSubscription?.cancel();
    listenToMessages();
  }

  Future<void> loadConversationInfo() async {
    if (conversationId == null) return;
    
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId!)
          .get();
      if (doc.exists) {
        currentConversation = Conversation.fromJson(doc.data()!);
      } else {
        currentConversation = null;
      }
      notifyListeners();
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
      'responded_at': message.respondedAt != null
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
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId!)
          .collection('messages')
          .orderBy('sent_at', descending: false)
          .get();

      _messages.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final message = Message.fromJson(data);
        _messages.add(message);
        
        // Pre-populate local ratings cache
        if (message.rating != null && message.rating!.isNotEmpty) {
          _pendingRatingsCache[message.id] = message.rating!;
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error loading existing messages: $e');
    }
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
            bool changed = false;
            for (var change in snapshot.docChanges) {
              final data = change.doc.data() as Map<String, dynamic>?;
              if (data == null) continue;
              
              final message = Message.fromJson(data);
              final exists = _messages.any((m) => m.id == message.id);
              
              if (change.type == DocumentChangeType.added && !exists) {
                _messages.add(message);
                changed = true;
              }
            }
            if (changed) {
              _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
              notifyListeners();
            }
          },
          onError: (error) {
            print('Error listening to messages: $error');
          },
        );
  }

  Future<void> askQuestion(BuildContext context,String question) async {
    if (_isLoading || conversationId == null || conversationId!.isEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    final startTime = DateTime.now();

    try {
      _cohere ??= CohereService();
      final userId = FirebaseAuth.instance.currentUser?.uid;

      // Create user message
      final userMessageRef = _firestore
          .collection('conversations')
          .doc(conversationId!)
          .collection('messages')
          .doc();

      final userMessage = Message(
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

      _messages.add(userMessage);
      notifyListeners();

      print('Starting question processing: "$question"');

      // Get conversation history for context
      final conversationHistory = _messages
          .where((m) => m.conversationId == conversationId)
          .toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      
      final recentHistory = conversationHistory.length > 10 
          ? conversationHistory.sublist(conversationHistory.length - 10)
          : conversationHistory;

      // Parallel execution for better performance
      final futures = await Future.wait([
        _generateEmbeddingCached(question),
        _classifyQuestionCategory(question),
        userMessageRef.set(_messageToMap(userMessage)),
        _ensureFAQCacheLoaded(),
      ]);

      final currentEmbedding = futures[0] as List<double>;
      final classifiedCategory = futures[1] as String;

      print('Embedding generated, Category: $classifiedCategory');

      // Update user message with category and embedding
      await Future.wait([
        userMessageRef.update({
          'category': classifiedCategory,
          'embedding': currentEmbedding,
        }),
        _updateConversationTitleIfNeeded(question),
      ]);

      // Try FAQ first
      final existingFAQ = _findMatchingFAQWithContext(
        question, 
        currentEmbedding, 
        recentHistory
      );

      String answerText;
      if (existingFAQ != null) {
        answerText = existingFAQ['answer'] as String;
        print('Using FAQ answer');
        // Async increment FAQ usage count
        unawaited(_incrementFAQSimilarityCountAsync(existingFAQ['question'] as String));
      } else {
        print('Generating answer from knowledge base...');
        answerText = await _retriever.generateAnswer(
          question,
          conversationHistory: recentHistory,
          conversationId: conversationId!,
        );
      }

      // Save bot reply
      final botMessageRef = _firestore
          .collection('conversations')
          .doc(conversationId!)
          .collection('messages')
          .doc();

      final botMessage = Message(
        id: botMessageRef.id,
        conversationId: conversationId!,
        content: answerText,
        sender: 'bot',
        status: 'sent',
        type: 'text',
        sentAt: DateTime.now(),
        count: count,
      );
      

      final totalResponseTime = DateTime.now().difference(startTime).inMilliseconds;
      final responseTime = totalResponseTime / 1000;

      print('Total response time: ${responseTime.toStringAsFixed(2)}s');

      // Save to database with batch write
      final batch = _firestore.batch();
      batch.set(botMessageRef, _messageToMap(botMessage));
      batch.update(userMessageRef, {
        'responded_at': Timestamp.fromDate(botMessage.sentAt),
        'isAnswered': true,
        'responseTimeMs': responseTime,
      });
      batch.update(_firestore.collection('conversations').doc(conversationId!), {
        'messageCount': FieldValue.increment(2),
        'lastActivity': Timestamp.now(),
      });

      await batch.commit();

      // Handle post-response tasks asynchronously
      unawaited(_handlePostResponseTasks(
        context,
        question, 
        answerText, 
        currentEmbedding, 
        classifiedCategory, 
        userId
      ));

      print('Question processing completed successfully');

    } catch (e, stackTrace) {
      print('askQuestion error: $e');
      print('Stack trace: $stackTrace');
      await _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _findMatchingFAQWithContext(
    String question,
    List<double> questionEmbedding,
    List<Message> conversationHistory,
  ) {
    try {
      // Check if this is a follow-up question
      final isFollowUp = _isFollowUpQuestion(question);
      
      if (isFollowUp && conversationHistory.isNotEmpty) {
        final lastBotMessage = conversationHistory
            .where((m) => m.sender == 'bot')
            .lastOrNull;
        
        if (lastBotMessage != null) {
          final contextualQuestion = "${lastBotMessage.content} $question";
          print('Treating as follow-up: "$contextualQuestion"');
          return _findBestFAQMatch(contextualQuestion, questionEmbedding);
        }
      }
      
      return _findBestFAQMatch(question, questionEmbedding);
    } catch (e) {
      print('Error in contextual FAQ matching: $e');
      return null;
    }
  }

  bool _isFollowUpQuestion(String question) {
    final followUpPatterns = [
      RegExp(r'\b(what are those|what are these|those|these|that|this)\b', caseSensitive: false),
      RegExp(r'\b(how many|how much|which ones)\b', caseSensitive: false),
      RegExp(r'\b(tell me more|more info|details|elaborate)\b', caseSensitive: false),
      RegExp(r'^\w{1,5}(\?|\.)*$'),
    ];
    
    return followUpPatterns.any((pattern) => pattern.hasMatch(question.trim()));
  }

  Map<String, dynamic>? _findBestFAQMatch(
    String question,
    List<double> questionEmbedding,
  ) {
    try {
      for (var entry in FAQCache.cache.entries) {
        final data = entry.value;
        
        if (!data.containsKey('embedding')) continue;
        
        final faqEmbedding = List<double>.from(data['embedding']);
        final similarity = cosineSimilarity(questionEmbedding, faqEmbedding);

        if (similarity > 0.90) {
          print('Found matching FAQ with similarity: $similarity');
          return data;
        }
      }
      
      return null;
    } catch (e) {
      print('Error finding FAQ match: $e');
      return null;
    }
  }

  Future<void> _handleError(dynamic error) async {
    String errorMessage;
    
    if (error.toString().contains('network') || error.toString().contains('connection')) {
      errorMessage = 'Network error. Please check your internet connection and try again.';
    } else if (error.toString().contains('embedding') || error.toString().contains('cohere')) {
      errorMessage = 'I\'m having trouble processing your question. Please try rephrasing it or contact OASP staff.';
    } else if (error.toString().contains('pinecone') || error.toString().contains('retrieval')) {
      errorMessage = 'I\'m having trouble accessing the knowledge base. Please contact OASP staff for assistance.';
    } else {
      errorMessage = 'Sorry, I encountered an unexpected error. Please try again or contact OASP staff if the problem persists.';
    }

    if (conversationId != null) {
      final errorMsgRef = _firestore
          .collection('conversations')
          .doc(conversationId!)
          .collection('messages')
          .doc();

      final errorMsg = Message(
        id: errorMsgRef.id,
        conversationId: conversationId!,
        content: errorMessage,
        sender: 'system',
        status: 'error',
        type: 'text',
        sentAt: DateTime.now(),
        count: count,
      );

      try {
        await errorMsgRef.set(_messageToMap(errorMsg));
        _messages.add(errorMsg);
        notifyListeners();
      } catch (saveError) {
        print('Failed to save error message: $saveError');
      }
    }
  }

  Future<String> _classifyQuestionCategory(String question) async {
  final lowercaseQuestion = question.toLowerCase();
  
  if (lowercaseQuestion.contains(RegExp(r'\b(admission|admit|enroll|application|apply|entrance|entry|requirements?|eligibility|qualify)\b'))) {
    return 'Admission';
  } else if (lowercaseQuestion.contains(RegExp(r'\b(scholarship|grant|financial|aid|funding|stipend|allowance|discount|free)\b'))) {
    return 'Scholarship';
  } else if (lowercaseQuestion.contains(RegExp(r'\b(placement|job|career|internship|work|employment|company|companies|hiring)\b'))) {
    return 'Placement';
  }
  
  try {
    final categoryPrompt = '''
Classify this educational query into exactly one category: Admission, Scholarship, Placement, or General.

Message: "$question"

Category:''';

    final result = await _cohere!.generateResponse(categoryPrompt);

    // Normalize the output
    var category = result?.trim() ?? 'General';
    category = category.replaceAll(RegExp(r'[^\w\s]'), ''); // remove punctuation
    category = category[0].toUpperCase() + category.substring(1).toLowerCase(); // capitalize

    const validCategories = ['Admission', 'Scholarship', 'Placement', 'General'];
    return validCategories.contains(category) ? category : 'General';
  } catch (e) {
    print('Classification error: $e');
    return 'General';
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

  Future<void> _ensureFAQCacheLoaded() async {
    if (FAQCache.isExpired || FAQCache.cache.isEmpty) {
      try {
        final faqSnapshot = await _firestore
            .collection('faqs')
            .where('answer', isNotEqualTo: "")
            .get();
        
        FAQCache.updateCache(faqSnapshot.docs);
      } catch (e) {
        print('Error loading FAQ cache: $e');
      }
    }
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
        _checkAndPromoteToFAQOptimized(question, currentEmbedding, answerText, category),
      ]);
    } catch (e) {
      print('Error in post-response tasks: $e');
    }
  }



Future<void> checkEscalation(
  BuildContext context, 
  String answerText, 
  String? userId, 
  String question
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
                      Icon(Icons.info_outline, 
                          color: Colors.blue.shade600, size: 16),
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
                    hintText: "e.g. I need clarification about scholarship requirements",
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
                    userReason: reasonController.text.trim().isNotEmpty 
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
  }
) async {
  try {
    final escalationId = _firestore.collection('escalations').doc().id;

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


    await _firestore.collection('escalations').add(escalatedData);
    print('Auto-escalation logged due to AI response: $triggerKeyword');

    // Notification for the user
    final userNotification = Notifications(
      notificationId: _firestore.collection('notifications').doc().id,
      userId: userId,
      title: 'Your question was escalated',
      body: 'Your question could not be answered by AI and has been sent to staff for review.',
      type: 'escalation',
      relatedId: escalationId,
      targetRole: 'user',
      read: false,
      createdAt: Timestamp.now(),
    );

    await _firestore.collection('notifications').add(userNotification.toMap());
    print('Notification created for user $userId');

    // Notification for staff
    final staffNotification = Notifications(
      notificationId: _firestore.collection('notifications').doc().id,
      userId: null, // staff notifications don't have a specific user
      title: 'New escalated question',
      body: 'A user question could not be answered by AI. Please review and respond.',
      type: 'escalation',
      relatedId: escalationId,
      targetRole: 'staff',
      read: false,
      createdAt: Timestamp.now(),
    );

    await _firestore.collection('notifications').add(staffNotification.toMap());
    print('Notification created for staff');

  } catch (e) {
    print('Error creating auto-escalation or notifications: $e');
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
      if (!_isAnswerWorthyOfFAQ(botAnswer) || !_isQuestionWorthyOfFAQ(question)) {
        return;
      }

      final querySnapshot = await _firestore
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
          final pastEmbedding = (pastEmbeddingData as List)
              .map((e) => (e as num).toDouble())
              .toList();

          if (pastEmbedding.length != currentEmbedding.length) continue;

          final similarity = cosineSimilarity(currentEmbedding, pastEmbedding);
          
          if (similarity > 0.90) {
            final contextKey = _extractContextualKey(pastQuestion);
            final groupKey = '${category}_$contextKey';
            
            questionGroups.putIfAbsent(groupKey, () => QuestionGroup());
            questionGroups[groupKey]!.addQuestion(pastQuestion, data, similarity);
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
          
          final existing = await _firestore
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
              'promotionReason': 'Auto-promoted after ${group.questionCount} similar questions',
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
      'vacant_position': ['vacant', 'opening', 'available position', 'job vacancy'],
      'placement_opportunity': ['placement', 'opportunity', 'program', 'service'],
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
    
    final words = lowercaseQuestion.split(' ')
        .where((word) => word.length > 3 && !['what', 'how', 'when', 'where', 'why', 'who'].contains(word))
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
    
    final meaningfulWords = cleanQuestion.split(' ')
        .where((word) => word.length > 3)
        .toList();
    
    if (meaningfulWords.length < 2) return false;
    
    final questionWords = ['what', 'how', 'when', 'where', 'why', 'who', 'which', 'can', 'is', 'are', 'do', 'does', 'will', 'would', 'should'];
    final hasQuestionWord = questionWords.any((qw) => cleanQuestion.contains(qw));
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
      final faqSnapshot = await _firestore
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
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (currentUserDoc.exists) {
          final data = currentUserDoc.data() as Map<String, dynamic>;
          actorName = data['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef = FirebaseFirestore.instance.collection('message_logs').doc();

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
      shouldUpdateTitle = (title.contains('new conversation') ||
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

 Future<void> rateMessage(String messageId, bool isLiked, String conversationId) async {
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
        .update({
      'rating': rating,
      'rated_at': Timestamp.now(),
    });

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
      final faqSnapshot = await _firestore
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
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}

// Helper class for grouping similar questions
class QuestionGroup {
  final List<String> questions = [];
  final List<Map<String, dynamic>> questionData = [];
  final List<double> similarities = [];
  
  int get questionCount => questions.length;
  double get averageSimilarity => similarities.isEmpty ? 0.0 : 
      similarities.reduce((a, b) => a + b) / similarities.length;
  
  void addQuestion(String question, Map<String, dynamic> data, double similarity) {
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
  final domainWords = ['admission', 'scholarship', 'placement', 'course', 'program', 'requirement', 'deadline', 'fee', 'exam'];
  final domainMatches = domainWords.where((dw) => cleanQuestion.contains(dw)).length;
  score += (domainMatches * 0.3);
  
  return score.clamp(0.0, 5.0);
}
