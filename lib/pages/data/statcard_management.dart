// import 'package:cloud_firestore/cloud_firestore.dart';

// class InquiryReportsData {
//   final int totalMessages;
//   final int answeredMessages;
//   final int unAnsweredMessages;
//   final int escalatedMessages;
//   final String mostFrequentCategory;
//   final Map<String, int> categoryDistribution;
//   final List<ChartData> inquiryTrend;
//   final Map<String, int> highestFAQs;

//   final List<SystemLog> recentLogs;
//   final List<MessageLogs> msgLogs;
//   final int totalLikes;
//   final int totalDislikes;
//   final int totalNeutral;
//   final double satisfactionScore;
//   final double growthRate;
//   final List<String> top5UnansweredInquiries;
//   final List<String> top5EscalatedInquiries;
//   final Map<String, double> responseDistribution;
//   final Map<String, int> seasonalTrends;

//   const InquiryReportsData({
//     required this.totalMessages,
//     required this.answeredMessages,
//     required this.unAnsweredMessages,
//     required this.escalatedMessages,
//     required this.mostFrequentCategory,
//     required this.categoryDistribution,
//     required this.inquiryTrend,
//     required this.highestFAQs,

//     required this.recentLogs,
//     required this.msgLogs,
//     required this.totalLikes,
//     required this.totalDislikes,
//     required this.totalNeutral,
//     required this.satisfactionScore,
//     required this.growthRate,
//     required this.top5UnansweredInquiries,
//     required this.top5EscalatedInquiries,
//     required this.responseDistribution,
//     required this.seasonalTrends,
//   });
// }

// // Chatbot usage-specific reports data
// class ChatbotUsageReportsData {
//   final int totalSessions;
//   final double averageResponseTime;
//   final List<ChartData>? usageTrendByTimeOfDay;
//   final Map<String, int>? sessionTypes;
//   final double botAccuracyRate;
//   final Map<int, int> peakUsageByHour;
//   final double averageMessagesPerUser;
//   final double averageSessionLength;
//   final List<ChartData>? dailySessions;
//   final List<ChartData>? weeklySessions;
//   final List<ChartData>? monthlySessions;

//   // NEW FIELDS
//   final List<MapEntry<String, int>>? top10ActiveUsers;
//   final Map<String, int>? usersByYearLevel;
//   final Map<String, int>? usersByCourse;
//   final List<ChartData>? responseTimeTrend;

//   const ChatbotUsageReportsData({
//     required this.totalSessions,
//     required this.averageResponseTime,
//     required this.usageTrendByTimeOfDay,
//     required this.sessionTypes,
//     required this.botAccuracyRate,
//     required this.peakUsageByHour,
//     required this.averageMessagesPerUser,
//     required this.averageSessionLength,
//     required this.dailySessions,
//     required this.weeklySessions,
//     required this.monthlySessions,

//     // NEW FIELDS
//     required this.top10ActiveUsers,
//     required this.usersByYearLevel,
//     required this.usersByCourse,
//     required this.responseTimeTrend,
//   });
// }

// // User demographics-specific reports data
// class UserDemographicsReportsData {
//   final int activeUsers;
//   final int newlyRegisteredUsers;
//   final int affiliatedUsers;
//   final int totalUsers;
//   final Map<String, int> usersByYear;
//   final Map<String, int> usersByProgram;
//   final Map<String, int>? userAffiliations;

//   // NEW FIELDS
//   final Map<String, int>?
//   scholarshipStatus; // "Has Scholarship" vs "No Scholarship"
//   final Map<String, int>?
//   scholarshipTypes; // Academic, Athletic, Government, Private
//   final Map<String, int>? enrollmentStatus; // "Enrolled" vs "Not Enrolled"

//   const UserDemographicsReportsData({
//     required this.activeUsers,
//     required this.newlyRegisteredUsers,
//     required this.affiliatedUsers,
//     required this.totalUsers,
//     required this.usersByYear,
//     required this.usersByProgram,
//     required this.userAffiliations,
//     // NEW FIELDS
//     required this.scholarshipStatus,
//     required this.scholarshipTypes,
//     required this.enrollmentStatus,
//   });
// }

// class ChartData {
//   final String date;
//   final int count;
//   final Map<String, int> categoryBreakdown;

//   const ChartData({
//     required this.date,
//     required this.count,
//     this.categoryBreakdown = const {},
//   });

//   factory ChartData.fromMap(Map<String, dynamic> map) {
//     return ChartData(
//       categoryBreakdown:
//           map['categoryBreakdown'] != null
//               ? Map<String, int>.from(map['categoryBreakdown'])
//               : {},
//       count: map['count'] ?? 0,
//       date: map['date'] ?? '',
//     );
//   }
// }

// class SystemLog {
//   final String user;
//   final DateTime time;
//   final String action;

//   SystemLog({required this.user, required this.time, required this.action});

//   factory SystemLog.fromMap(Map<String, dynamic> map) {
//     return SystemLog(
//       user: map['user'] ?? '',
//       action: map['action'] ?? '',
//       time: (map['time'] as Timestamp).toDate(),
//     );
//   }
// }

// class MessageLogs {
//   final String user;
//   final DateTime time;
//   final String message;
//   final String reply;

//   MessageLogs({required this.user, required this.time, required this.message, required this.reply});

//   factory MessageLogs.fromMap(Map<String, dynamic> map) {
//     return MessageLogs(
//       user: map['user'] ?? '',
//       message: map['message'] ?? '',
//       reply: map['reply'] ?? '',
//       time: (map['time'] as Timestamp).toDate(),
//     );
//   }
// }


// class FirebaseService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   static final Map<String, InquiryReportsData> _inquiryCache = {};
//   static final Map<String, ChatbotUsageReportsData> _chatbotCache = {};
//   static final Map<String, UserDemographicsReportsData> _demographicsCache = {};

//   // Cache for frequently accessed data
//   static final Map<String, dynamic> _cache = {};
//   static DateTime? _lastCacheTime;

//   Future<InquiryReportsData> getInquiryReportsData(String timeFrame) async {
//     final cacheKey = 'inquiry_$timeFrame';
//     final now = DateTime.now();

//     if (_inquiryCache.containsKey(cacheKey) &&
//         _lastCacheTime != null &&
//         now.difference(_lastCacheTime!).inMinutes < 5) {
//       return _inquiryCache[cacheKey]!;
//     }

//     try {
//       final startDate = _getStartDate(timeFrame);

//       final futures = await Future.wait([
//         _getMessages(startDate),
//         _getFAQs(),
//         _getLogs(),
//         _getEscalatedMessages(),
//         _getUnansweredMessages(),
//         _getMessageLogs()
//       ]);

//       final data = _processInquiryReportsData(
//         messages: futures[0] as List<QueryDocumentSnapshot>,
//         faqs: futures[1] as QuerySnapshot,
//         logs: futures[2] as List<QueryDocumentSnapshot>,
//         escalations: futures[3] as List<QueryDocumentSnapshot>,
//         unanswered: futures[4] as List<QueryDocumentSnapshot>,
//         msgLogs: futures[5] as List<QueryDocumentSnapshot>,
//         startDate: startDate,
//         timeFrame: timeFrame,
//       );

//       _inquiryCache[cacheKey] = data;
//       _lastCacheTime = now;

//       return data;
//     } catch (e) {
//       print('Error fetching inquiry data: $e');
//       return _getEmptyInquiryReportsData();
//     }
//   }

  
//   Future<ChatbotUsageReportsData> getChatbotUsageReportsData(
//     String timeFrame,
//   ) async {
//     final cacheKey = 'chatbot_$timeFrame';
//     final now = DateTime.now();

//     if (_chatbotCache.containsKey(cacheKey) &&
//         _lastCacheTime != null &&
//         now.difference(_lastCacheTime!).inMinutes < 5) {
//       return _chatbotCache[cacheKey]!;
//     }

//     try {
//       final startDate = _getStartDate(timeFrame);

//       final futures = await Future.wait([
//         _getConversations(startDate), // Pass startDate to filter conversations
//         _getMessages(startDate),
//       ]);

//       final data = _processChatbotUsageReportsData(
//         sessions: futures[0],
//         messages: futures[1],
//         startDate: startDate,
//         timeFrame: timeFrame,
//       );

//       _chatbotCache[cacheKey] = data;
//       _lastCacheTime = now;

//       return data;
//     } catch (e) {
//       print('Error fetching chatbot usage data: $e');
//       return _getEmptyChatbotUsageReportsData();
//     }
//   }

// Future<UserDemographicsReportsData> getUserDemographicsReportsData(
//   String timeFrame,
// ) async {
//   final cacheKey = 'demographics_$timeFrame';
//   final now = DateTime.now();

//   if (_demographicsCache.containsKey(cacheKey) &&
//       _lastCacheTime != null &&
//       now.difference(_lastCacheTime!).inMinutes < 5) {
//     return _demographicsCache[cacheKey]!;
//   }

//   try {
//     final startDate = _getStartDate(timeFrame);

//     final futures = await Future.wait([
//       _getUsers(),
//       _getActiveUsers(),
//       _getNewUsers(timeFrame),
//       _getMessages(startDate),
   
//       _getConversations(),
//     ]);

//     final data = _processUserDemographicsReportsData(
//       users: futures[0] as QuerySnapshot,
//       activeUsers: futures[1] as List<QueryDocumentSnapshot>,
//       newUsers: futures[2] as List<QueryDocumentSnapshot>,
//       messages: futures[3] as List<QueryDocumentSnapshot>,

//     );

//     _demographicsCache[cacheKey] = data;
//     _lastCacheTime = now;

//     return data;
//   } catch (e) {
//     print('Error fetching user demographics data: $e');
//     return _getEmptyUserDemographicsReportsData();
//   }
// }

//   Future<List<QueryDocumentSnapshot>> _getMessages(DateTime startDate) async {
//     final snapshot =
//         await _firestore
//             .collectionGroup('messages')
//             .where('sent_at', isGreaterThanOrEqualTo: startDate)
//             .where('sender', isEqualTo: 'user')
//             .orderBy('sent_at', descending: true)
//             .get();
//     return snapshot.docs;
//   }

//  Future<List<QueryDocumentSnapshot>> _getLogs() async {
//     final snapshot =
//         await _firestore
//             .collection('logs')
//             .orderBy('time', descending: true)
//             .limit(5)
//             .get();
//     return snapshot.docs;
//   }



//  Future<List<QueryDocumentSnapshot>> _getMessageLogs() async {
//     final snapshot =
//         await _firestore
//             .collection('message_logs')
//             .orderBy('time', descending: true)
//             .limit(5)
//             .get();
//     return snapshot.docs;
//   }


//  Future<QuerySnapshot> _getUsers() async {
//   return await _firestore.collection('users').get();
// }

//   Future<List<QueryDocumentSnapshot>> _getConversations([
//     DateTime? startDate,
//   ]) async {
//     Query query = _firestore.collection('conversations');

//     if (startDate != null) {
//       query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
//     }

//     final snapshot = await query.orderBy('createdAt', descending: true).get();
//     return snapshot.docs;
//   }

//   Future<List<QueryDocumentSnapshot>> _getEscalatedMessages() async {
//     final snapshot = await _firestore.collection('escalations').get();
//     return snapshot.docs;
//   }

//   Future<QuerySnapshot> _getFAQs() async {
//     return await _firestore
//         .collection('faqs')
//         .orderBy('similarityCount', descending: true)
//         .limit(10)
//         .get();
//   }


// Future<List<QueryDocumentSnapshot>> _getActiveUsers() async {

  
//   final snapshot = await _firestore
//       .collection('users')
//       .where('isActive', isEqualTo: true)
//       .get();

//   return snapshot.docs;
// }

// Future<List<QueryDocumentSnapshot>> _getNewUsers(String timeFrame) async {
//   final startDate = _getStartDate(timeFrame);
  
//   final snapshot = await _firestore
//       .collection('users')
//       .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
//       .orderBy('createdAt', descending: true)
//       .get();

//   return snapshot.docs;
// }




//   Future<List<QueryDocumentSnapshot>> _getUnansweredMessages() async {
//     final snapshot =
//         await _firestore
//             .collectionGroup('messages')
//             .where('isAnswered', isEqualTo: false)
//             .where('sender', isEqualTo: 'user')
//             .orderBy('sent_at', descending: true)
//             .limit(5)
//             .get();
//     return snapshot.docs;
//   }

//   Map<int, int> _generatePeakUsageByHour(List<QueryDocumentSnapshot> sessions) {
//     final hourCounts = <int, int>{};

//     for (final doc in sessions) {
//       final data = doc.data() as Map<String, dynamic>;
//       final timestamp = data['createdAt'];
//       if (timestamp is Timestamp) {
//         final hour = timestamp.toDate().hour;
//         hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
//       }
//     }

//     return hourCounts;
//   }

//   DateTime _getStartDate(String timeFrame) {
//     final now = DateTime.now();
//     return switch (timeFrame) {
//       'Today' => DateTime(now.year, now.month, now.day),
//       'This Week' => _getStartOfWeek(now), // Fixed this line
//       'This Month' => DateTime(now.year, now.month, 1),
//       'This Year' => DateTime(now.year, 1, 1),
//       _ => DateTime(now.year, now.month, 1),
//     };
//   }

//    DateTime _getStartOfWeek(DateTime date) {
//     // Get Monday as start of week (weekday 1 = Monday, 7 = Sunday)
//     final daysFromMonday = date.weekday - 1;
//     return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
//   }

//    InquiryReportsData _processInquiryReportsData({
//     required List<QueryDocumentSnapshot> messages,
//     required QuerySnapshot faqs,
//     required List<QueryDocumentSnapshot> logs,
//     required List<QueryDocumentSnapshot> escalations,
//     required List<QueryDocumentSnapshot> unanswered,
//     required List<QueryDocumentSnapshot> msgLogs,
//     required DateTime startDate,
//     required String timeFrame,
//   }) {
//     // Process messages
//     final categoryDistribution = <String, int>{};

//     final seasonalTrends = <String, int>{};
//     int answeredMessages = 0;
//     int unAnsweredMessages = 0;
//     int totalLikes = 0;
//     int totalDislikes = 0;
//     int totalNeutral = 0;

//     for (final doc in messages) {
//       final data = doc.data() as Map<String, dynamic>;
//       final feedback = data['feedback'] ?? 'neutral';

//       if (data['isAnswered'] == true) answeredMessages++;
//       if (data['isAnswered'] == false) unAnsweredMessages++;

//       final category = (data['category'] as String?)?.trim() ?? 'General';
//       categoryDistribution[category] =
//           (categoryDistribution[category] ?? 0) + 1;

//       final timestamp = data['sent_at'];
//       if (timestamp is Timestamp) {
//         final month = timestamp.toDate().month;
//         final season = _getSeason(month);
//         seasonalTrends[season] = (seasonalTrends[season] ?? 0) + 1;
//       }

//       if (feedback == 'like') {
//         totalLikes++;
//       } else if (feedback == 'dislike') {
//         totalDislikes++;
//       } else {
//         totalNeutral++;
//       }
//     }

//     final satisfactionScore =
//         (totalLikes + totalDislikes) == 0
//             ? 0
//             : (totalLikes / (totalLikes + totalDislikes)) * 100;

//     // Process FAQs
//     final highestFAQs = <String, int>{};
//     for (final doc in faqs.docs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final question = data['question'] as String? ?? 'Unknown';
//       final count = data['similarityCount'] as int? ?? 1;
//       highestFAQs[question] = count;
//     }

//     // Process logs
//     final recentLogs = <SystemLog>[];
//     for (final doc in logs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final user = data['user'] as String? ?? 'Unknown';
//       final time =
//           (data['time'] is Timestamp)
//               ? (data['time'] as Timestamp).toDate()
//               : DateTime.now();
//       final action = data['action'] as String? ?? 'Unknown';

//       recentLogs.add(SystemLog(user: user, time: time, action: action));
//     }

//         final messageLogs = <MessageLogs>[];
        
//     for (final doc in msgLogs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final user = data['user'] as String? ?? 'Unknown';
//       final time =
//           (data['time'] is Timestamp)
//               ? (data['time'] as Timestamp).toDate()
//               : DateTime.now();
//       final message = data['message'] as String? ?? 'Unknown';
//       final reply = data['reply'] as String? ?? 'Unknown';

//       messageLogs.add(MessageLogs(user: user, time: time, message: message, reply: reply));
//     }


//     // Process top unanswered inquiries
//     final top5UnansweredInquiries = <String>[];
//     for (final doc in unanswered) {
//       final data = doc.data() as Map<String, dynamic>;
//       final message = data['message'] as String? ?? 'Unknown';
//       top5UnansweredInquiries.add(message);
//     }

//     // Process top escalated inquiries
//     final top5EscalatedInquiries = <String>[];
//     for (final doc in escalations) {
//       final data = doc.data() as Map<String, dynamic>;
//       final message = data['question'] ?? 'Unknown';
//       if (top5EscalatedInquiries.length < 5) {
//         top5EscalatedInquiries.add(message);
//       }
//     }

//     // Calculate response distribution percentages
//     final total = messages.length;
//     final responseDistribution = <String, double>{
//       'Answered': total > 0 ? (answeredMessages / total) * 100 : 0,
//       'Unanswered': total > 0 ? (unAnsweredMessages / total) * 100 : 0,
//       'Escalated': total > 0 ? (escalations.length / total) * 100 : 0,
//     };

//     // Calculate growth rate (simplified - would need historical data)
//     final growthRate = 0.0; // Placeholder

//     return InquiryReportsData(
//       totalMessages: messages.length,
//       answeredMessages: answeredMessages,
//       unAnsweredMessages: unAnsweredMessages,
//       escalatedMessages: escalations.length,
//       mostFrequentCategory: _getMostFrequentCategory(categoryDistribution),
//       categoryDistribution: categoryDistribution,
//       inquiryTrend: generateInquiryTrend(messages, startDate, timeFrame),

//       highestFAQs: highestFAQs,
//       recentLogs: recentLogs,
//       msgLogs: messageLogs,
//       totalLikes: totalLikes,
//       totalDislikes: totalDislikes,
//       totalNeutral: totalNeutral,
//       satisfactionScore: satisfactionScore.toDouble(),
//       growthRate: growthRate,
//       top5UnansweredInquiries: top5UnansweredInquiries,
//       top5EscalatedInquiries: top5EscalatedInquiries,
//       responseDistribution: responseDistribution,
//       seasonalTrends: seasonalTrends,
//     );
//   }

//   ChatbotUsageReportsData _processChatbotUsageReportsData({
//   required List<QueryDocumentSnapshot> sessions,
//   required List<QueryDocumentSnapshot> messages,
//   required DateTime startDate,
//   required String timeFrame,
// }) {
//   // Process sessions (conversations)
//   final sessionTypes = <String, int>{'Single-turn': 0, 'Multi-turn': 0};
//   double totalSessionDuration = 0;
//   int completedSessionsCount = 0;
//   final userSessionCounts = <String, int>{};
//   final userYearLevels = <String, int>{};
//   final userPrograms = <String, int>{};

//   for (final doc in sessions) {
//     final data = doc.data() as Map<String, dynamic>;
//     final messageCount = data['messageCount'] as int? ?? 1;
//     final userId = data['userId'] as String? ?? 'unknown';
//     final createdAt = data['createdAt'] as Timestamp?;
//     final endedAt = data['endedAt'] as Timestamp?;
//     final status = data['status'] as String? ?? 'unknown';

//     // Get user info from session data
//     final userYear = data['year'] as String? ?? 'Unknown';
//     final userProgram = data['program'] as String? ?? 'Unknown';

//     if (messageCount > 2) {
//       sessionTypes['Multi-turn'] = (sessionTypes['Multi-turn'] ?? 0) + 1;
//     } else {
//       sessionTypes['Single-turn'] = (sessionTypes['Single-turn'] ?? 0) + 1;
//     }

//     if (createdAt != null && endedAt != null && status == 'ended') {
//       final duration = endedAt.toDate().difference(createdAt.toDate());
//       totalSessionDuration += duration.inSeconds.toDouble();
//       completedSessionsCount++;
//     }

//     userSessionCounts[userId] = (userSessionCounts[userId] ?? 0) + 1;
//     userYearLevels[userYear] = (userYearLevels[userYear] ?? 0) + 1;
//     userPrograms[userProgram] = (userPrograms[userProgram] ?? 0) + 1;
//   }

//   // Calculate averages
//   final averageSessionLength =
//       completedSessionsCount > 0
//           ? totalSessionDuration / completedSessionsCount
//           : 0.0;

//   final averageMessagesPerUser =
//       userSessionCounts.isNotEmpty
//           ? sessions.length / userSessionCounts.length.toDouble()
//           : 0.0;

//   // Process messages for bot accuracy, response time, and user demographics
//   int answeredCount = 0;
//   double totalResponseTime = 0;
//   int responseTimeCount = 0;
//   final yearMessageCounts = <String, int>{};
//   final programMessageCounts = <String, int>{};
//   final responseTimeData = <String, List<double>>{};

//   for (final doc in messages) {
//     final data = doc.data() as Map<String, dynamic>;

//     // Bot accuracy calculation
//     if (data['isAnswered'] == true) answeredCount++;

//     // Response time calculation and trend - FIXED
//     final responseTimeMs = data['responseTimeMs'] as num?;
//     final sentAt = data['sent_at'] as Timestamp?;

//     if (responseTimeMs != null && responseTimeMs > 0) {
//       final responseTimeSeconds = responseTimeMs.toDouble() / 1000;
//       totalResponseTime += responseTimeSeconds;
//       responseTimeCount++;

//       // Group response times for trend analysis
//       if (sentAt != null) {
//         final timeKey = _getTimeKey(sentAt.toDate(), timeFrame);
//         responseTimeData.putIfAbsent(timeKey, () => []);
//         responseTimeData[timeKey]!.add(responseTimeSeconds);
//       }
//     }

//     // User demographics from messages
//     final userId = data['userID'] as String?;
//     if (userId != null) {
//       final year = data['year'] as String? ?? 'Unknown';
//       final program = data['program'] as String? ?? 'Unknown';

//       yearMessageCounts[year] = (yearMessageCounts[year] ?? 0) + 1;
//       programMessageCounts[program] = (programMessageCounts[program] ?? 0) + 1;
//     }
//   }

//   final botAccuracyRate =
//       messages.isNotEmpty ? (answeredCount / messages.length) * 100 : 0.0;

//   final averageResponseTime =
//       responseTimeCount > 0 ? totalResponseTime / responseTimeCount : 0.0;

//   // Generate top 10 active users
//   final top10ActiveUsers = userSessionCounts.entries.toList()
//     ..sort((a, b) => b.value.compareTo(a.value));
//   final top10 = top10ActiveUsers.take(10).toList();

//   // Generate response time trend
//   final responseTimeTrend = _generateResponseTimeTrend(responseTimeData, timeFrame) ?? <ChartData>[];

//   // Generate trend data
//   final usageTrendByTimeOfDay = _generateHourlyUsageTrend(sessions) ?? <ChartData>[];
//   final dailySessions = _generateDailySessionTrend(sessions, timeFrame) ?? <ChartData>[];
//   final weeklySessions = _generateWeeklySessionTrend(sessions, timeFrame) ?? <ChartData>[];
//   final monthlySessions = _generateMonthlySessionTrend(sessions, timeFrame) ?? <ChartData>[];
//   final peakUsageByHour = _generatePeakUsageByHour(sessions);

//   return ChatbotUsageReportsData(
//     totalSessions: sessions.length,
//     averageResponseTime: averageResponseTime,
//     sessionTypes: sessionTypes.isNotEmpty ? sessionTypes : <String, int>{},
//     botAccuracyRate: botAccuracyRate,
//     averageMessagesPerUser: averageMessagesPerUser,
//     averageSessionLength: averageSessionLength,
//     usageTrendByTimeOfDay: usageTrendByTimeOfDay,
//     dailySessions: dailySessions,
//     weeklySessions: weeklySessions,
//     monthlySessions: monthlySessions,
//     responseTimeTrend: responseTimeTrend,
//     peakUsageByHour: peakUsageByHour.isNotEmpty ? peakUsageByHour : <int, int>{},
//     top10ActiveUsers: top10,
//     usersByYearLevel: userYearLevels.isNotEmpty ? userYearLevels : <String, int>{},
//     usersByCourse: userPrograms.isNotEmpty ? userPrograms : <String, int>{},
//   );
// }

// UserDemographicsReportsData _processUserDemographicsReportsData({
//   required QuerySnapshot users,
//   required List<QueryDocumentSnapshot> activeUsers,
//   required List<QueryDocumentSnapshot> newUsers,
//   required List<QueryDocumentSnapshot> messages,
// }) {
//   print('Processing ${users.docs.length} users');
  
//   // Initialize data structures
//   final usersByYear = <String, int>{};
//   final usersByProgram = <String, int>{};
//   final scholarshipStatus = <String, int>{
//     'Has Scholarship': 0,
//     'No Scholarship': 0,
//   };
//   final enrollmentStatus = <String, int>{'Enrolled': 0, 'Not Enrolled': 0};
//   final scholarshipTypes = <String, int>{};
//   final affiliationTypes = <String, int>{};
  
//   int affiliatedCount = 0;

//   // Process each user
//   for (final doc in users.docs) {
//     final data = doc.data() as Map<String, dynamic>;
    
//     print('Processing user: ${data['name']} with data: $data');
    
//     final year = data['year']?.toString() ?? 'Unknown';
//     final program = data['program']?.toString() ?? 'Unknown';
//     final affiliationValue = data['affiliation']?.toString();
//     final scholarshipValue = data['scholarship']?.toString();
// final isEnrolled = data['isEnrolled'];

//     // Users by year/program
//     usersByYear[year] = (usersByYear[year] ?? 0) + 1;
//     usersByProgram[program] = (usersByProgram[program] ?? 0) + 1;

//     // Process affiliation
//     if (affiliationValue != null && 
//         affiliationValue.isNotEmpty && 
//         affiliationValue != 'null' && 
//         affiliationValue.toLowerCase() != 'null') {
//       print('Found affiliation: $affiliationValue');
//       affiliatedCount++;
//       affiliationTypes[affiliationValue] = (affiliationTypes[affiliationValue] ?? 0) + 1;
//     }

//     // Process scholarship
//     if (scholarshipValue != null && 
//         scholarshipValue.isNotEmpty && 
//         scholarshipValue != 'null' && 
//         scholarshipValue.toLowerCase() != 'null') {
//       print('Found scholarship: $scholarshipValue');
//       scholarshipStatus['Has Scholarship'] = (scholarshipStatus['Has Scholarship'] ?? 0) + 1;
//       scholarshipTypes[scholarshipValue] = (scholarshipTypes[scholarshipValue] ?? 0) + 1;
//     } else {
//       scholarshipStatus['No Scholarship'] = (scholarshipStatus['No Scholarship'] ?? 0) + 1;
//     }

//     // Enrollment status
// if (isEnrolled == true) {
//   // Explicitly enrolled
//   enrollmentStatus['Enrolled'] = (enrollmentStatus['Enrolled'] ?? 0) + 1;
// } else {
//   // Either false or missing → count as Not Enrolled
//   enrollmentStatus['Not Enrolled'] = (enrollmentStatus['Not Enrolled'] ?? 0) + 1;
// }
//   }

//   print('Final results:');
//   print('- Affiliation types: $affiliationTypes');
//   print('- Scholarship types: $scholarshipTypes');
//   print('- Scholarship status: $scholarshipStatus');
//   print('- Enrollment status: $enrollmentStatus');

//   return UserDemographicsReportsData(
//     activeUsers: activeUsers.length,
//     newlyRegisteredUsers: newUsers.length,
//     affiliatedUsers: affiliatedCount,
//     totalUsers: users.docs.length,
//     usersByYear: usersByYear,
//     usersByProgram: usersByProgram,
//     userAffiliations: affiliationTypes,
//     scholarshipStatus: scholarshipStatus,
//     scholarshipTypes: scholarshipTypes,
//     enrollmentStatus: enrollmentStatus,
//   );
// }

// List<ChartData>? _generateResponseTimeTrend(
//   Map<String, List<double>> responseTimeData,
//   String timeFrame,
// ) {
//   try {
//     return _generateTrendDataFromAverages(responseTimeData, timeFrame);
//   } catch (e) {
//     print('Error generating response time trend: $e');
//     return <ChartData>[];
//   }
// }

// // Fix the _generateTrendDataFromAverages method
// List<ChartData> _generateTrendDataFromAverages(
//   Map<String, List<double>> data,
//   String timeFrame,
// ) {
//   final trendData = <ChartData>[];
//   final sortedKeys = data.keys.toList()..sort();

//   for (final key in sortedKeys) {
//     final values = data[key]!;
//     final average = values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 0.0;
//     trendData.add(ChartData(date: key, count: average.round()));
//   }

//   return trendData;
// }


//   String _getSeason(int month) {
//     if (month >= 3 && month <= 5) return 'CMUCAT Admission and Scholarship Application';
//     if (month >= 6 && month <= 8) return 'Enrollment';
//     if (month >= 9 && month <= 11) return 'Regular Classes';
//     return 'Christmas';
//   }

//  List<ChartData>? _generateHourlyUsageTrend(
//     List<QueryDocumentSnapshot> sessions,
//   ) {
//     try {
//       final hourCounts = <int, int>{};

//       for (final doc in sessions) {
//         final data = doc.data() as Map<String, dynamic>;
//         final timestamp = data['createdAt'];
//         if (timestamp is Timestamp) {
//           final hour = timestamp.toDate().hour;
//           hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
//         }
//       }

//       return List.generate(24, (hour) {
//         return ChartData(
//           date: "${hour.toString().padLeft(2, '0')}:00",
//           count: hourCounts[hour] ?? 0,
//         );
//       });
//     } catch (e) {
//       print('Error generating hourly usage trend: $e');
//       return <ChartData>[];
//     }
//   }

//   List<ChartData>? _generateDailySessionTrend(
//     List<QueryDocumentSnapshot> sessions,
//     String timeFrame,
//   ) {
//     try {
//       final dailyCounts = <String, int>{};
//       final now = DateTime.now();

//       // Filter sessions by the current timeframe
//       for (final doc in sessions) {
//         final data = doc.data() as Map<String, dynamic>;
//         final timestamp = data['createdAt'];
//         if (timestamp is Timestamp) {
//           final date = timestamp.toDate();
//           final dateKey =
//               "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
//           dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
//         }
//       }

//       // Generate data based on timeframe
//       switch (timeFrame) {
//         case 'Today':
//           // Show last 24 hours by hour
//           return List.generate(24, (i) {
//             final hour = DateTime(now.year, now.month, now.day, i);
//             final hourKey = "${hour.hour.toString().padLeft(2, '0')}:00";
//             final dayKey =
//                 "${hour.year}-${hour.month.toString().padLeft(2, '0')}-${hour.day.toString().padLeft(2, '0')}";
//             return ChartData(date: hourKey, count: dailyCounts[dayKey] ?? 0);
//           });

//         case 'This Week':
//           // Show last 7 days - FIXED
//           final startOfWeek = _getStartOfWeek(now);
//           return List.generate(7, (i) {
//             final date = startOfWeek.add(Duration(days: i));
//             final dateKey =
//                 "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
//             return ChartData(
//               date: "${date.day}/${date.month}",
//               count: dailyCounts[dateKey] ?? 0,
//             );
//           });

//         case 'This Month':
//           // Show last 30 days
//           return List.generate(30, (i) {
//             final date = now.subtract(Duration(days: 29 - i));
//             final dateKey =
//                 "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
//             return ChartData(
//               date: "${date.day}/${date.month}",
//               count: dailyCounts[dateKey] ?? 0,
//             );
//           });

//         default:
//           // Show last 365 days for 'This Year' or any other case
//           return List.generate(12, (i) {
//             final month = DateTime(now.year, now.month - (11 - i));
//             final monthKey =
//                 "${month.year}-${month.month.toString().padLeft(2, '0')}";

//             // Sum all days in this month
//             int monthCount = 0;
//             final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
//             for (int day = 1; day <= daysInMonth; day++) {
//               final dayKey =
//                   "${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
//               monthCount += dailyCounts[dayKey] ?? 0;
//             }

//             final monthNames = [
//               'Jan',
//               'Feb',
//               'Mar',
//               'Apr',
//               'May',
//               'Jun',
//               'Jul',
//               'Aug',
//               'Sep',
//               'Oct',
//               'Nov',
//               'Dec',
//             ];
//             return ChartData(
//               date: monthNames[month.month - 1],
//               count: monthCount,
//             );
//           });
//       }
//     } catch (e) {
//       print('Error generating daily session trend: $e');
//       return <ChartData>[];
//     }
//   }


//   List<ChartData>? _generateWeeklySessionTrend(
//     List<QueryDocumentSnapshot> sessions,
//     String timeFrame,
//   ) {
//     try {
//       final weeklyCounts = <String, int>{};
//       final now = DateTime.now();

//       for (final doc in sessions) {
//         final data = doc.data() as Map<String, dynamic>;
//         final timestamp = data['createdAt'];
//         if (timestamp is Timestamp) {
//           final date = timestamp.toDate();
//           // Calculate week number based on the year
//           final startOfYear = DateTime(date.year, 1, 1);
//           final dayOfYear = date.difference(startOfYear).inDays + 1;
//           final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
//           final weekKey =
//               "${date.year}-W${weekOfYear.toString().padLeft(2, '0')}";
//           weeklyCounts[weekKey] = (weeklyCounts[weekKey] ?? 0) + 1;
//         }
//       }

//       switch (timeFrame) {
//         case 'Today':
//         case 'This Week':
//           // Show last 4 weeks for short timeframes
//           return List.generate(4, (i) {
//             final weekStart = now.subtract(
//               Duration(days: now.weekday - 1 + (3 - i) * 7),
//             );
//             final startOfYear = DateTime(weekStart.year, 1, 1);
//             final dayOfYear = weekStart.difference(startOfYear).inDays + 1;
//             final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
//             final weekKey =
//                 "${weekStart.year}-W${weekOfYear.toString().padLeft(2, '0')}";

//             return ChartData(
//               date: "Week ${weekOfYear}",
//               count: weeklyCounts[weekKey] ?? 0,
//             );
//           });

//         case 'This Month':
//           // Show last 8 weeks for monthly view
//           return List.generate(8, (i) {
//             final weekStart = now.subtract(
//               Duration(days: now.weekday - 1 + (7 - i) * 7),
//             );
//             final startOfYear = DateTime(weekStart.year, 1, 1);
//             final dayOfYear = weekStart.difference(startOfYear).inDays + 1;
//             final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
//             final weekKey =
//                 "${weekStart.year}-W${weekOfYear.toString().padLeft(2, '0')}";

//             return ChartData(
//               date: "W${weekOfYear}",
//               count: weeklyCounts[weekKey] ?? 0,
//             );
//           });

//         default:
//           // Show last 12 weeks for yearly view
//           return List.generate(12, (i) {
//             final weekStart = now.subtract(
//               Duration(days: now.weekday - 1 + (11 - i) * 7),
//             );
//             final startOfYear = DateTime(weekStart.year, 1, 1);
//             final dayOfYear = weekStart.difference(startOfYear).inDays + 1;
//             final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
//             final weekKey =
//                 "${weekStart.year}-W${weekOfYear.toString().padLeft(2, '0')}";

//             return ChartData(
//               date: "W${weekOfYear}",
//               count: weeklyCounts[weekKey] ?? 0,
//             );
//           });
//       }
//     } catch (e) {
//       print('Error generating weekly session trend: $e');
//       return <ChartData>[];
//     }
//   }

//   List<ChartData>? _generateMonthlySessionTrend(
//     List<QueryDocumentSnapshot> sessions,
//     String timeFrame,
//   ) {
//     try {
//       final monthlyCounts = <String, int>{};
//       final now = DateTime.now();

//       for (final doc in sessions) {
//         final data = doc.data() as Map<String, dynamic>;
//         final timestamp = data['createdAt'];
//         if (timestamp is Timestamp) {
//           final date = timestamp.toDate();
//           final monthKey =
//               "${date.year}-${date.month.toString().padLeft(2, '0')}";
//           monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
//         }
//       }

//       // Always show 12 months, but adjust the range based on timeframe
//       int monthsToShow;
//       switch (timeFrame) {
//         case 'Today':
//         case 'This Week':
//           monthsToShow = 3; // Show last 3 months for short timeframes
//           break;
//         case 'This Month':
//           monthsToShow = 6; // Show last 6 months
//           break;
//         default:
//           monthsToShow = 12; // Show full year
//           break;
//       }

//       return List.generate(monthsToShow, (i) {
//         final month = DateTime(now.year, now.month - (monthsToShow - 1 - i));
//         final monthKey =
//             "${month.year}-${month.month.toString().padLeft(2, '0')}";
//         final monthNames = [
//           'Jan',
//           'Feb',
//           'Mar',
//           'Apr',
//           'May',
//           'Jun',
//           'Jul',
//           'Aug',
//           'Sep',
//           'Oct',
//           'Nov',
//           'Dec',
//         ];

//         return ChartData(
//           date: monthNames[month.month - 1],
//           count: monthlyCounts[monthKey] ?? 0,
//         );
//       });
//     } catch (e) {
//       print('Error generating monthly session trend: $e');
//       return <ChartData>[];
//     }
//   }

//   // Empty data methods
// InquiryReportsData _getEmptyInquiryReportsData() {
//     return const InquiryReportsData(
//       totalMessages: 0,
//       answeredMessages: 0,
//       unAnsweredMessages: 0,
//       escalatedMessages: 0,
//       mostFrequentCategory: 'Unknown',
//       categoryDistribution: {},
//       inquiryTrend: [],
//       highestFAQs: {},
//       recentLogs: [],
//       msgLogs: [],
//       totalLikes: 0,
//       totalDislikes: 0,
//       totalNeutral: 0,
//       satisfactionScore: 0.0,
//       growthRate: 0.0,
//       top5UnansweredInquiries: [],
//       top5EscalatedInquiries: [],
//       responseDistribution: {},
//       seasonalTrends: {},
//     );
//   }

//   ChatbotUsageReportsData _getEmptyChatbotUsageReportsData() {
//     return ChatbotUsageReportsData(
//       totalSessions: 0,
//       averageResponseTime: 0.0,
//       usageTrendByTimeOfDay: <ChartData>[],
//       sessionTypes: <String, int>{},
//       botAccuracyRate: 0.0,
//       averageMessagesPerUser: 0.0,
//       averageSessionLength: 0.0,
//       dailySessions: <ChartData>[],
//       weeklySessions: <ChartData>[],
//       monthlySessions: <ChartData>[],
//       peakUsageByHour: <int, int>{},
//       top10ActiveUsers: [],
//       usersByYearLevel: <String, int>{},
//       usersByCourse: <String, int>{},
//       responseTimeTrend: <ChartData>[],
//     );
//   }

// UserDemographicsReportsData _getEmptyUserDemographicsReportsData() {
//   return const UserDemographicsReportsData(
//     activeUsers: 0,
//     newlyRegisteredUsers: 0,
//     affiliatedUsers: 0,
//     totalUsers: 0,
//     usersByYear: {},
//     usersByProgram: {},
//     userAffiliations: {},
//     scholarshipStatus: {'Has Scholarship': 0, 'No Scholarship': 0},
//     scholarshipTypes: {},
//     enrollmentStatus: {'Enrolled': 0, 'Not Enrolled': 0},
//   );
// }
// }


// String _getMostFrequentCategory(Map<String, int> categories) {
//   if (categories.isEmpty) return 'Unknown';
//   return categories.entries.reduce((a, b) => a.value > b.value ? a : b).key;
// }

// List<ChartData> generateInquiryTrend(
//   List<QueryDocumentSnapshot> messages,
//   DateTime startDate,
//   String timeFrame,
// ) {
//   final timeCategoryCounts = <String, Map<String, int>>{};

//   for (final doc in messages) {
//     final data = doc.data() as Map<String, dynamic>;
//     final timestamp = data['sent_at'];
//     if (timestamp is! Timestamp) continue;

//     final timeKey = _getTimeKey(timestamp.toDate(), timeFrame);
//     final category = (data['category'] as String?)?.trim() ?? 'General';

//     timeCategoryCounts.putIfAbsent(timeKey, () => {});
//     timeCategoryCounts[timeKey]![category] =
//         (timeCategoryCounts[timeKey]![category] ?? 0) + 1;
//   }

//   return generateTrendData(startDate, timeFrame, timeCategoryCounts);
// }

// List<ChartData> generateConversationTrend(
//   List<QueryDocumentSnapshot> sessions,
//   DateTime startDate,
//   String timeFrame,
// ) {
//   final timeCounts = <String, int>{};

//   // Process sessions to count conversations by time period
//   for (final doc in sessions) {
//     final data = doc.data() as Map<String, dynamic>;
//     final timestamp = data['createdAt'];
//     if (timestamp is! Timestamp) continue;

//     final timeKey = _getTimeKey(timestamp.toDate(), timeFrame);
//     timeCounts[timeKey] = (timeCounts[timeKey] ?? 0) + 1;
//   }

//   // Generate complete time series data
//   return generateConversationTrendData(startDate, timeFrame, timeCounts);
// }

// String _getTimeKey(DateTime dateTime, String timeFrame) {
//   return switch (timeFrame) {
//     'Today' => "${dateTime.hour.toString().padLeft(2, '0')}:00",
//     'This Week' =>
//       "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}",
//     'This Month' => "Week ${_getWeekOfMonth(dateTime)}",
//     'This Year' =>
//       "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}",
//     _ => "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}",
//   };
// }

// List<ChartData> generateTrendData(
//   DateTime startDate,
//   String timeFrame,
//   Map<String, Map<String, int>> timeCategoryCounts,
// ) {
//   return switch (timeFrame) {
//     'Today' => _generateHourlyTrend(timeCategoryCounts),
//     'This Week' => _generateWeeklyTrend(startDate, timeCategoryCounts),
//     'This Month' => _generateMonthlyTrend(timeCategoryCounts),
//     'This Year' => _generateYearlyTrend(startDate, timeCategoryCounts),
//     _ => _generateYearlyTrend(startDate, timeCategoryCounts),
//   };
// }

// List<ChartData> generateConversationTrendData(
//   DateTime startDate,
//   String timeFrame,
//   Map<String, int> timeCounts,
// ) {
//   switch (timeFrame) {
//     case 'Today':
//       return generateHourlyConversationTrend(timeCounts);
//     case 'This Week':
//       return generateWeeklyConversationTrend(startDate, timeCounts);
//     case 'This Month':
//       return generateMonthlyConversationTrend(timeCounts);
//     case 'This Year':
//       return generateYearlyConversationTrend(startDate, timeCounts);
//     default:
//       return generateYearlyConversationTrend(startDate, timeCounts);
//   }
// }

// List<ChartData> generateHourlyConversationTrend(Map<String, int> timeCounts) {
//   return List.generate(24, (hour) {
//     final timeKey = "${hour.toString().padLeft(2, '0')}:00";
//     return ChartData(date: timeKey, count: timeCounts[timeKey] ?? 0);
//   });
// }

// List<ChartData> generateWeeklyConversationTrend(
//   DateTime startDate,
//   Map<String, int> timeCounts,
// ) {
//   final trend = <ChartData>[];
//   var current = startDate;

//   for (int i = 0; i < 7; i++) {
//     final dateKey =
//         "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
//     final displayKey = "${current.day}/${current.month}";
//     trend.add(ChartData(date: displayKey, count: timeCounts[dateKey] ?? 0));
//     current = current.add(const Duration(days: 1));
//   }

//   return trend;
// }

// List<ChartData> generateMonthlyConversationTrend(Map<String, int> timeCounts) {
//   return List.generate(5, (week) {
//     final weekKey = "Week ${week + 1}";
//     return ChartData(date: weekKey, count: timeCounts[weekKey] ?? 0);
//   });
// }

// List<ChartData> generateYearlyConversationTrend(
//   DateTime startDate,
//   Map<String, int> timeCounts,
// ) {
//   return List.generate(12, (month) {
//     final monthKey =
//         "${startDate.year}-${(month + 1).toString().padLeft(2, '0')}";
//     final monthName = _getMonthName(month + 1);
//     return ChartData(date: monthName, count: timeCounts[monthKey] ?? 0);
//   });
// }

// List<ChartData> _generateHourlyTrend(Map<String, Map<String, int>> data) {
//   return List.generate(24, (hour) {
//     final timeKey = "${hour.toString().padLeft(2, '0')}:00";
//     final categoryBreakdown = data[timeKey] ?? <String, int>{};
//     final totalCount = categoryBreakdown.values.fold(
//       0,
//       (sum, count) => sum + count,
//     );

//     return ChartData(
//       date: timeKey,
//       count: totalCount,
//       categoryBreakdown: categoryBreakdown,
//     );
//   });
// }

// List<ChartData> _generateWeeklyTrend(
//   DateTime startDate,
//   Map<String, Map<String, int>> data,
// ) {
//   final trend = <ChartData>[];
//   var current = startDate;

//   for (int i = 0; i < 7; i++) {
//     final dateKey =
//         "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
//     final displayKey = _getDayName(current.weekday);
//     final categoryBreakdown = data[dateKey] ?? <String, int>{};
//     final totalCount = categoryBreakdown.values.fold(
//       0,
//       (sum, count) => sum + count,
//     );

//     trend.add(
//       ChartData(
//         date: displayKey,
//         count: totalCount,
//         categoryBreakdown: categoryBreakdown,
//       ),
//     );

//     current = current.add(const Duration(days: 1));
//   }

//   return trend;
// }

// List<ChartData> _generateMonthlyTrend(Map<String, Map<String, int>> data) {
//   return List.generate(5, (week) {
//     final weekKey = "Week ${week + 1}";
//     final categoryBreakdown = data[weekKey] ?? <String, int>{};
//     final totalCount = categoryBreakdown.values.fold(
//       0,
//       (sum, count) => sum + count,
//     );

//     return ChartData(
//       date: weekKey,
//       count: totalCount,
//       categoryBreakdown: categoryBreakdown,
//     );
//   });
// }

// List<ChartData> _generateYearlyTrend(
//   DateTime startDate,
//   Map<String, Map<String, int>> data,
// ) {
//   return List.generate(12, (month) {
//     final monthKey =
//         "${startDate.year}-${(month + 1).toString().padLeft(2, '0')}";
//     final displayKey = _getMonthName(month + 1);
//     final categoryBreakdown = data[monthKey] ?? <String, int>{};
//     final totalCount = categoryBreakdown.values.fold(
//       0,
//       (sum, count) => sum + count,
//     );

//     return ChartData(
//       date: displayKey,
//       count: totalCount,
//       categoryBreakdown: categoryBreakdown,
//     );
//   });
// }

// // Utility functions
// int _getWeekOfMonth(DateTime date) {
//   final firstDay = DateTime(date.year, date.month, 1);
//   return ((date.difference(firstDay).inDays) ~/ 7) + 1;
// }

// String _getDayName(int weekday) {
//   const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//   return days[weekday - 1];
// }

// String _getMonthName(int month) {
//   const months = [
//     'Jan',
//     'Feb',
//     'Mar',
//     'Apr',
//     'May',
//     'Jun',
//     'Jul',
//     'Aug',
//     'Sep',
//     'Oct',
//     'Nov',
//     'Dec',
//   ];
//   return months[month - 1];
// }

// double getGridInterval(List<ChartData> trendData) {
//   if (trendData.isEmpty) return 1;

//   int maxValue = trendData.map((e) => e.count).reduce((a, b) => a > b ? a : b);
//   if (maxValue <= 5) return 1;
//   if (maxValue <= 20) return 5;
//   if (maxValue <= 50) return 10;
//   return (maxValue / 5).ceil().toDouble();
// }

// double getBottomTitleInterval(int dataLength) {
//   if (dataLength <= 7) return 1;
//   if (dataLength <= 14) return 2;
//   return (dataLength / 6).ceil().toDouble();
// }

// String formatBottomTitle(String date) {
//   // Truncate long dates for better display
//   if (date.length > 6) {
//     return date.substring(0, 6);
//   }
//   return date;
// }

// extension DateTimeExtension on DateTime {
//   int get dayOfYear {
//     return difference(DateTime(year, 1, 1)).inDays + 1;
//   }
// }