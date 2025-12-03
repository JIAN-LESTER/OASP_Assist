import 'package:capstone_project/pages/data/chatbot_usage_data.dart';
import 'package:capstone_project/pages/data/inquiry_trends_data.dart';
import 'package:capstone_project/pages/data/user_demographics_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChartData {
  final String date;
  final int count;
  final Map<String, int> categoryBreakdown;

  const ChartData({
    required this.date,
    required this.count,
    this.categoryBreakdown = const {},
  });

  factory ChartData.fromMap(Map<String, dynamic> map) {
    return ChartData(
      categoryBreakdown:
          map['categoryBreakdown'] != null
              ? Map<String, int>.from(map['categoryBreakdown'])
              : {},
      count: map['count'] ?? 0,
      date: map['date'] ?? '',
    );
  }
}

class SystemLog {
  final String user;
  final DateTime time;
  final String action;

  SystemLog({required this.user, required this.time, required this.action});

  factory SystemLog.fromMap(Map<String, dynamic> map) {
    return SystemLog(
      user: map['user'] ?? '',
      action: map['action'] ?? '',
      time: (map['time'] as Timestamp).toDate(),
    );
  }
}

class MessageLogs {
  final String user;
  final DateTime time;
  final String message;
  final String reply;

  MessageLogs({
    required this.user,
    required this.time,
    required this.message,
    required this.reply,
  });

  factory MessageLogs.fromMap(Map<String, dynamic> map) {
    return MessageLogs(
      user: map['user'] ?? '',
      message: map['message'] ?? '',
      reply: map['reply'] ?? '',
      time: (map['time'] as Timestamp).toDate(),
    );
  }
}

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Enhanced caching with individual report caches
  static final Map<String, InquiryReportsData> _inquiryCache = {};
  static final Map<String, ChatbotUsageReportsData> _chatbotCache = {};
  static final Map<String, UserDemographicsReportsData> _demographicsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // NEW: Cache for user lookup data (persists across all queries)
  static Map<String, Map<String, dynamic>>? _userLookupCache;
  static DateTime? _userLookupCacheTime;

  static const int _cacheDurationMinutes = 5;
  static const int _userLookupCacheDurationMinutes = 10;

  bool _isCacheValid(String cacheKey) {
    if (!_cacheTimestamps.containsKey(cacheKey)) return false;
    final now = DateTime.now();
    return now.difference(_cacheTimestamps[cacheKey]!).inMinutes <
        _cacheDurationMinutes;
  }

  void _updateCacheTimestamp(String cacheKey) {
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  // NEW: Check if user lookup cache is valid
  bool _isUserLookupCacheValid() {
    if (_userLookupCache == null || _userLookupCacheTime == null) return false;
    final now = DateTime.now();
    return now.difference(_userLookupCacheTime!).inMinutes <
        _userLookupCacheDurationMinutes;
  }

  // NEW: Get or create user lookup cache
  Future<Map<String, Map<String, dynamic>>> _getUserLookup() async {
    if (_isUserLookupCacheValid()) {
      return _userLookupCache!;
    }

    final users = await _getUsers();
    final userLookup = <String, Map<String, dynamic>>{};

    for (final u in users) {
      final data = u.data() as Map<String, dynamic>;
      final uid = data['uid'] as String?;
      if (uid != null) {
        userLookup[uid] = {
          'year': data['year'] ?? 'N/A',
          'program': data['program'] ?? 'N/A',
        };
      }
    }

    _userLookupCache = userLookup;
    _userLookupCacheTime = DateTime.now();

    return userLookup;
  }

  Future<InquiryReportsData> getInquiryReportsData(String timeFrame) async {
    final cacheKey = 'inquiry_$timeFrame';

    if (_inquiryCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _inquiryCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame);

      // Parallel fetch with indexed queries
      final results = await Future.wait([
        _getMessagesOptimized(startDate),
        _getFAQs(),
        _getLogs(),
        _getEscalatedMessages(),
        _getResolvedEscalatedMessages(),
        _getUnansweredMessages(),
        _getMessageLogs(),
      ]);

      final data = _processInquiryReportsData(
        messages: results[0],
        faqs: results[1],
        logs: results[2],
        escalations: results[3],
        resolvedEscalations: results[4],
        unanswered: results[5],
        msgLogs: results[6],
        startDate: startDate,
        timeFrame: timeFrame,
      );

      _inquiryCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching inquiry data: $e');
      return getEmptyInquiryReportsData();
    }
  }

  Future<ChatbotUsageReportsData> getChatbotUsageReportsData(
    String timeFrame,
  ) async {
    final cacheKey = 'chatbot_$timeFrame';

    if (_chatbotCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _chatbotCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame);

      // NEW: Get user lookup first (cached)
      final userLookup = await _getUserLookup();

      // Optimized parallel fetch - removed users query since we have it cached
      final results = await Future.wait([
        _getConversationsOptimized(startDate),
        _getMessagesOptimized(startDate),
      ]);

      final data = _processChatbotUsageReportsData(
        sessions: results[0],
        messages: results[1],
        userLookup: userLookup,
        startDate: startDate,
        timeFrame: timeFrame,
      );

      _chatbotCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching chatbot usage data: $e');
      return getEmptyChatbotUsageReportsData();
    }
  }

  Future<UserDemographicsReportsData> getUserDemographicsReportsData(
    String timeFrame,
  ) async {
    final cacheKey = 'demographics_$timeFrame';

    if (_demographicsCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _demographicsCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame);

      final results = await Future.wait([
        _getUsers(),
        _getActiveUsers(),
        _getNewUsers(timeFrame),
        _getMessagesOptimized(startDate),
      ]);

      final data = _processUserDemographicsReportsData(
        users: results[0],
        activeUsers: results[1],
        newUsers: results[2],
        messages: results[3],
      );

      _demographicsCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching user demographics data: $e');
      return getEmptyUserDemographicsReportsData();
    }
  }

  

  Future<List<QueryDocumentSnapshot>> _getMessagesOptimized(
    DateTime startDate,
  ) async {
    final snapshot =
        await _firestore
            .collectionGroup('messages')
            .where('sender', isEqualTo: 'user')
            .where('sent_at', isGreaterThanOrEqualTo: startDate)
            .orderBy('sent_at', descending: true)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getLogs() async {
    final snapshot =
        await _firestore
            .collection('logs')
            .orderBy('time', descending: true)
            .limit(5)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getMessageLogs() async {
    final snapshot =
        await _firestore
            .collection('message_logs')
            .orderBy('time', descending: true)
            .limit(5)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getConversationsOptimized([
    DateTime? startDate,
  ]) async {
    Query query = _firestore.collection('conversations');

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }

    final snapshot = await query.orderBy('createdAt', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getEscalatedMessages() async {
    final snapshot = await _firestore.collection('escalations').get();
    return snapshot.docs;
  }

    Future<List<QueryDocumentSnapshot>> _getResolvedEscalatedMessages() async {
    final snapshot = await _firestore.collection('escalations').where('status', isEqualTo: 'resolved').get();
    return snapshot.docs;
  }


  Future<List<QueryDocumentSnapshot>> _getFAQs() async {
    final snapshot =
        await _firestore
            .collection('faqs')
            .orderBy('similarityCount', descending: true)
            .limit(5)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getActiveUsers() async {
    final snapshot =
        await _firestore
            .collection('users')
            .where('isActive', isEqualTo: true)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getNewUsers(String timeFrame) async {
    final startDate = _getStartDate(timeFrame);
    final snapshot =
        await _firestore
            .collection('users')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getUnansweredMessages() async {
    final snapshot =
        await _firestore
            .collectionGroup('messages')
            .where('sender', isEqualTo: 'user')
            .where('isAnswered', isEqualTo: false)
            .orderBy('sent_at', descending: true)
            .limit(5)
            .get();
    return snapshot.docs;
  }

  Map<int, int> _generatePeakUsageByHour(List<QueryDocumentSnapshot> sessions) {
    final hourCounts = <int, int>{};

    for (final doc in sessions) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'];
      if (timestamp is Timestamp) {
        final hour = timestamp.toDate().hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
    }

    return hourCounts;
  }

  DateTime _getStartDate(String timeFrame) {
    final now = DateTime.now();
    return switch (timeFrame) {
      'All' => DateTime(2000, 1, 1), // Far past date to get all data
      'Today' => DateTime(now.year, now.month, now.day),
      'This Week' => _getStartOfWeek(now),
      'This Month' => DateTime(now.year, now.month, 1),
      'This Year' => DateTime(now.year, 1, 1),
      _ => DateTime(now.year, now.month, 1),
    };
  }

  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysFromMonday));
  }

  InquiryReportsData _processInquiryReportsData({
    required List<QueryDocumentSnapshot> messages,
    required List<QueryDocumentSnapshot> faqs,

    required List<QueryDocumentSnapshot> logs,
    required List<QueryDocumentSnapshot> escalations,
    required List<QueryDocumentSnapshot> resolvedEscalations,
    required List<QueryDocumentSnapshot> unanswered,
    required List<QueryDocumentSnapshot> msgLogs,
    required DateTime startDate,
    required String timeFrame,
  }) {
    final categoryDistribution = <String, int>{};
    final seasonalTrends = <String, int>{};
    int answeredMessages = 0;
    int unAnsweredMessages = 0;

    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['isAnswered'] == true) answeredMessages++;
      if (data['isAnswered'] == false) unAnsweredMessages++;

      final category = (data['category'] as String?)?.trim() ?? 'General';
      categoryDistribution[category] =
          (categoryDistribution[category] ?? 0) + 1;

      final timestamp = data['sent_at'];
      if (timestamp is Timestamp) {
        final month = timestamp.toDate().month;
        final season = _getSeason(month);
        seasonalTrends[season] = (seasonalTrends[season] ?? 0) + 1;
      }
    }

    final highestFAQs = <String, int>{};
    for (final doc in faqs) {
      final data = doc.data() as Map<String, dynamic>;
      final question = data['question'] as String? ?? 'Unknown';
      final count = data['similarityCount'] as int? ?? 1;
      highestFAQs[question] = count;
    }

    final recentLogs = <SystemLog>[];
    for (final doc in logs) {
      final data = doc.data() as Map<String, dynamic>;
      recentLogs.add(SystemLog.fromMap(data));
    }

    final messageLogs = <MessageLogs>[];
    for (final doc in msgLogs) {
      final data = doc.data() as Map<String, dynamic>;
      messageLogs.add(MessageLogs.fromMap(data));
    }

    return InquiryReportsData(
      totalMessages: messages.length,
      answeredMessages: answeredMessages,
      unAnsweredMessages: unAnsweredMessages,
      escalatedMessages: escalations.length,
      resolvedEscalatedMessages: resolvedEscalations.length,
      mostFrequentCategory: _getMostFrequentCategory(categoryDistribution),
      categoryDistribution: categoryDistribution,
      inquiryTrend: generateInquiryTrend(messages, startDate, timeFrame),
      highestFAQs: highestFAQs,
      recentLogs: recentLogs,
      msgLogs: messageLogs,
      seasonalTrends: seasonalTrends,
    );
  }

  // FIXED: Now uses cached userLookup instead of QuerySnapshot
ChatbotUsageReportsData _processChatbotUsageReportsData({
  required List<QueryDocumentSnapshot> sessions,
  required List<QueryDocumentSnapshot> messages,
  required Map<String, Map<String, dynamic>> userLookup,
  required DateTime startDate,
  required String timeFrame,
}) {
  // ✅ FIX 1: Process sessions with better error handling
  double totalSessionDuration = 0;
  int completedSessionsCount = 0;
  final userSessionCounts = <String, int>{};

  // Track UNIQUE users by year/program who have active sessions
  final uniqueUsersByYear = <String, Set<String>>{};
  final uniqueUsersByProgram = <String, Set<String>>{};

  for (final doc in sessions) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data['userId'] as String? ?? 'unknown';
    final createdAt = data['createdAt'] as Timestamp?;
    final endedAt = data['endedAt'] as Timestamp?;
    final status = data['status'] as String? ?? 'unknown';

    // Get user info from cached lookup
    final userInfo = userLookup[userId];
    if (userInfo != null) {
      final year = userInfo['year'] ?? 'N/A';
      final program = userInfo['program'] ?? 'N/A';

      uniqueUsersByYear.putIfAbsent(year, () => <String>{});
      uniqueUsersByYear[year]!.add(userId);

      uniqueUsersByProgram.putIfAbsent(program, () => <String>{});
      uniqueUsersByProgram[program]!.add(userId);
    }

    // ✅ FIX 2: Better session duration calculation
    if (createdAt != null && endedAt != null && status == 'ended') {
      final duration = endedAt.toDate().difference(createdAt.toDate());
      
      // Only count reasonable session durations (between 10 seconds and 2 hours)
      if (duration.inSeconds >= 10 && duration.inSeconds <= 7200) {
        totalSessionDuration += duration.inSeconds.toDouble();
        completedSessionsCount++;
        print('✅ Valid session: ${duration.inSeconds}s');
      } else {
        print('⚠️ Skipped invalid session duration: ${duration.inSeconds}s');
      }
    }

    userSessionCounts[userId] = (userSessionCounts[userId] ?? 0) + 1;
  }

  // Convert sets to counts
  final sessionYearCounts = <String, int>{};
  uniqueUsersByYear.forEach((year, userIds) {
    sessionYearCounts[year] = userIds.length;
  });

  final sessionProgramCounts = <String, int>{};
  uniqueUsersByProgram.forEach((program, userIds) {
    sessionProgramCounts[program] = userIds.length;
  });

  final averageSessionLength =
      completedSessionsCount > 0
          ? totalSessionDuration / completedSessionsCount
          : 0.0;

  print('📊 Session Stats:');
  print('   Total sessions: ${sessions.length}');
  print('   Completed sessions: $completedSessionsCount');
  print('   Average session length: ${averageSessionLength.toStringAsFixed(2)}s');

  final averageMessagesPerUser =
      userSessionCounts.isNotEmpty
          ? sessions.length / userSessionCounts.length.toDouble()
          : 0.0;

  // ✅ FIX 3: Enhanced response time calculation
  double totalResponseTime = 0;
  int responseTimeCount = 0;
  final responseTimeByDate = <String, List<double>>{};

  print('📊 Processing ${messages.length} messages for response time');

  for (final doc in messages) {
    final data = doc.data() as Map<String, dynamic>;
    final responseTimeMs = data['responseTimeMs'];
    final sentAt = data['sent_at'] as Timestamp?;

    if (responseTimeMs != null && responseTimeMs is num && responseTimeMs > 0) {
      final responseTimeSeconds = responseTimeMs.toDouble() / 1000;
      
      // ✅ Only count reasonable response times (between 0.1s and 60s)
      if (responseTimeSeconds >= 0.1 && responseTimeSeconds <= 60) {
        totalResponseTime += responseTimeSeconds;
        responseTimeCount++;
        
        // Group by date for trend
        if (sentAt != null) {
          final dateKey = _getDateKey(sentAt.toDate(), timeFrame);
          responseTimeByDate.putIfAbsent(dateKey, () => []);
          responseTimeByDate[dateKey]!.add(responseTimeSeconds);
        }
        
        print('   ✅ Valid response time: ${responseTimeSeconds.toStringAsFixed(2)}s');
      } else {
        print('   ⚠️ Skipped outlier: ${responseTimeSeconds.toStringAsFixed(2)}s');
      }
    }
  }

  final averageResponseTime =
      responseTimeCount > 0 ? totalResponseTime / responseTimeCount : 0.0;

  print('📈 Response Time Summary:');
  print('   Valid messages: $responseTimeCount / ${messages.length}');
  print('   Average: ${averageResponseTime.toStringAsFixed(2)}s');
  print('   Total: ${totalResponseTime.toStringAsFixed(2)}s');

  // ✅ FIX 4: Build response time trend data
  final responseTimeTrend = _buildResponseTimeTrend(
    responseTimeByDate,
    timeFrame,
    startDate,
  );

  return ChatbotUsageReportsData(
    totalSessions: sessions.length,
    averageResponseTime: averageResponseTime, // ✅ Now correctly calculated
    averageMessagesPerUser: averageMessagesPerUser,
    averageSessionLength: averageSessionLength, // ✅ Now correctly calculated
    usageTrendByTimeOfDay: _generateHourlyUsageTrend(sessions) ?? [],
    dailySessions: _generateDailySessionTrend(sessions, timeFrame) ?? [],
    weeklySessions: _generateWeeklySessionTrend(sessions, timeFrame) ?? [],
    monthlySessions: _generateMonthlySessionTrend(sessions, timeFrame) ?? [],
    responseTimeTrend: responseTimeTrend,
    peakUsageByHour: _generatePeakUsageByHour(sessions),
    usersByYearLevel:
        sessionYearCounts.isNotEmpty ? sessionYearCounts : <String, int>{},
    usersByCourse:
        sessionProgramCounts.isNotEmpty
            ? sessionProgramCounts
            : <String, int>{},
  );
}

  UserDemographicsReportsData _processUserDemographicsReportsData({
  required List<QueryDocumentSnapshot> users,
  required List<QueryDocumentSnapshot> activeUsers,
  required List<QueryDocumentSnapshot> newUsers,
  required List<QueryDocumentSnapshot> messages,
}) {
  final usersByYear = <String, int>{};
  final usersByProgram = <String, int>{};
  final enrollmentStatus = <String, int>{'Enrolled': 0, 'Not Enrolled': 0};
  final scholarshipTypes = <String, int>{};
  final affiliationTypes = <String, int>{};

  int affiliationCount = 0; // <-- ONLY Freshman Applicant count

  for (final doc in users) {
    final data = doc.data() as Map<String, dynamic>;

    final year = data['year']?.toString() ?? 'N/A';
    final program = data['program']?.toString() ?? 'N/A';
    final rawAffiliation = data['affiliation']?.toString();
final affiliationValue = rawAffiliation?.trim();

    final scholarshipValue = data['scholarship']?.toString();
    final isEnrolled = data['isEnrolled'];

    usersByYear[year] = (usersByYear[year] ?? 0) + 1;
    usersByProgram[program] = (usersByProgram[program] ?? 0) + 1;

    // --------------------------------------------------------
    // 1️⃣ affiliationTypes → counts ALL affiliation values
    // --------------------------------------------------------
    if (affiliationValue != null &&
        affiliationValue.isNotEmpty &&
        affiliationValue != 'null' &&
        affiliationValue.toLowerCase() != 'null') {
      affiliationTypes[affiliationValue] =
          (affiliationTypes[affiliationValue] ?? 0) + 1;
    }

    // --------------------------------------------------------
    // 2️⃣ affiliationCount → ONLY count “Incoming Freshman Applicant”
    // --------------------------------------------------------
    const targetAffiliation = 'Incoming Freshman Applicant';

  if (affiliationValue?.toLowerCase() == targetAffiliation.toLowerCase()) {
  affiliationCount++;
}


    // --------------------------------------------------------
    // Scholarship Type Count
    // --------------------------------------------------------
    if (scholarshipValue != null &&
        scholarshipValue.isNotEmpty &&
        scholarshipValue != 'null' &&
        scholarshipValue.toLowerCase() != 'null') {
      scholarshipTypes[scholarshipValue] =
          (scholarshipTypes[scholarshipValue] ?? 0) + 1;
    }

    // --------------------------------------------------------
    // Enrollment Status Count
    // --------------------------------------------------------
    if (isEnrolled == true) {
      enrollmentStatus['Enrolled'] = (enrollmentStatus['Enrolled'] ?? 0) + 1;
    } else {
      enrollmentStatus['Not Enrolled'] =
          (enrollmentStatus['Not Enrolled'] ?? 0) + 1;
    }
  }

  return UserDemographicsReportsData(
    activeUsers: activeUsers.length,
    newlyRegisteredUsers: newUsers.length,
    affiliatedUsers: affiliationCount, // <-- ONLY freshman applicants
    totalUsers: users.length,
    usersByYear: usersByYear,
    usersByProgram: usersByProgram,
    userAffiliations: affiliationTypes, // <-- ALL affiliations
    scholarshipTypes: scholarshipTypes,
    enrollmentStatus: enrollmentStatus,
  );
}

  String _getDateKey(DateTime date, String timeFrame) {
  switch (timeFrame) {
    case 'Today':
      return "${date.hour.toString().padLeft(2, '0')}:00";
    case 'This Week':
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    case 'This Month':
      final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
      return "Week $weekOfMonth";
    case 'This Year':
      return "${date.year}-${date.month.toString().padLeft(2, '0')}";
    default:
      return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }
}

Future<Map<String, int>> getQuickStats(String timeFrame) async {
    final startDate = _getStartDate(timeFrame);

    try {
      // Single optimized query for counts
      final messagesSnapshot = await _firestore
          .collectionGroup('messages')
          .where('sender', isEqualTo: 'user')
          .where('sent_at', isGreaterThanOrEqualTo: startDate)
          .count()
          .get();

      final answeredSnapshot = await _firestore
          .collectionGroup('messages')
          .where('sender', isEqualTo: 'user')
          .where('sent_at', isGreaterThanOrEqualTo: startDate)
          .where('isAnswered', isEqualTo: true)
          .count()
          .get();

      final usersSnapshot = await _firestore
          .collection('users')
          .count()
          .get();

      return {
        'totalMessages': messagesSnapshot.count ?? 0,
        'answered': answeredSnapshot.count ?? 0,
        'totalUsers': usersSnapshot.count ?? 0,
      };
    } catch (e) {
      print('Error getting quick stats: $e');
      return {'totalMessages': 0, 'answered': 0, 'totalUsers': 0};
    }
  }

// ✅ NEW METHOD: Build response time trend
List<ChartData> _buildResponseTimeTrend(
  Map<String, List<double>> responseTimeByDate,
  String timeFrame,
  DateTime startDate,
) {
  if (responseTimeByDate.isEmpty) {
    return [];
  }

  final trendData = <ChartData>[];
  final sortedKeys = responseTimeByDate.keys.toList()..sort();

  for (final key in sortedKeys) {
    final times = responseTimeByDate[key]!;
    if (times.isEmpty) continue;
    
    // Calculate average for this time period
    final average = times.reduce((a, b) => a + b) / times.length;
    
    // Convert to milliseconds for display (more readable)
    final averageMs = (average * 1000).round();
    
    trendData.add(ChartData(
      date: key,
      count: averageMs, // Store as milliseconds
    ));
  }

  print('📈 Response Time Trend: ${trendData.length} data points');
  for (var data in trendData) {
    print('   ${data.date}: ${data.count}ms');
  }

  return trendData;
}


String _getSeason(int month) {
  switch (month) {
    case 1:
      return 'January';
    case 2:
      return 'February';
    case 3:
      return 'March';
    case 4:
      return 'April';
    case 5:
      return 'May';
    case 6:
      return 'June';
    case 7:
      return 'July';
    case 8:
      return 'August';
    case 9:
      return 'September';
    case 10:
      return 'October';
    case 11:
      return 'November';
    case 12:
      return 'December';
    default:
      return 'Invalid Month';
  }
}

Color getMonthColor(int month) {
  switch (month) {
    case 1:
      return const Color(0xFF4A90E2);
    case 2:
      return const Color(0xFFE26A6A);
    case 3:
      return const Color(0xFF81C784);
    case 4:
      return const Color(0xFFFFC107);
    case 5:
      return const Color(0xFFFFA726);
    case 6:
      return const Color(0xFF29B6F6);
    case 7:
      return const Color(0xFFAB47BC);
    case 8:
      return const Color(0xFFD4E157);
    case 9:
      return const Color(0xFF66BB6A);
    case 10:
      return const Color(0xFFFF7043);
    case 11:
      return const Color(0xFF8D6E63);
    case 12:
      return const Color(0xFF1976D2);
    default:
      return Colors.grey;
  }
}





  List<ChartData>? _generateHourlyUsageTrend(
    List<QueryDocumentSnapshot> sessions,
  ) {
    try {
      final hourCounts = <int, int>{};

      for (final doc in sessions) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['createdAt'];
        if (timestamp is Timestamp) {
          final hour = timestamp.toDate().hour;
          hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        }
      }

      return List.generate(24, (hour) {
        return ChartData(
          date: "${hour.toString().padLeft(2, '0')}:00",
          count: hourCounts[hour] ?? 0,
        );
      });
    } catch (e) {
      print('Error generating hourly usage trend: $e');
      return [];
    }
  }

  List<ChartData>? _generateDailySessionTrend(
    List<QueryDocumentSnapshot> sessions,
    String timeFrame,
  ) {
    try {
      final dailyCounts = <String, int>{};
      final now = DateTime.now();

      for (final doc in sessions) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['createdAt'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          final dateKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      }

      switch (timeFrame) {
        case 'Today':
          return List.generate(24, (i) {
            final hour = DateTime(now.year, now.month, now.day, i);
            final hourKey = "${hour.hour.toString().padLeft(2, '0')}:00";
            final dayKey =
                "${hour.year}-${hour.month.toString().padLeft(2, '0')}-${hour.day.toString().padLeft(2, '0')}";
            return ChartData(date: hourKey, count: dailyCounts[dayKey] ?? 0);
          });

        case 'This Week':
          final startOfWeek = _getStartOfWeek(now);
          return List.generate(7, (i) {
            final date = startOfWeek.add(Duration(days: i));
            final dateKey =
                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            return ChartData(
              date: "${date.day}/${date.month}",
              count: dailyCounts[dateKey] ?? 0,
            );
          });

        case 'This Month':
          return List.generate(30, (i) {
            final date = now.subtract(Duration(days: 29 - i));
            final dateKey =
                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            return ChartData(
              date: "${date.day}/${date.month}",
              count: dailyCounts[dateKey] ?? 0,
            );
          });

        default:
          return List.generate(12, (i) {
            final month = DateTime(now.year, now.month - (11 - i));
            int monthCount = 0;
            final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
            for (int day = 1; day <= daysInMonth; day++) {
              final dayKey =
                  "${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
              monthCount += dailyCounts[dayKey] ?? 0;
            }
            final monthNames = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ];
            return ChartData(
              date: monthNames[month.month - 1],
              count: monthCount,
            );
          });
      }
    } catch (e) {
      print('Error generating daily session trend: $e');
      return [];
    }
  }

  List<ChartData>? _generateWeeklySessionTrend(
    List<QueryDocumentSnapshot> sessions,
    String timeFrame,
  ) {
    try {
      final weeklyCounts = <String, int>{};
      final now = DateTime.now();

      for (final doc in sessions) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['createdAt'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          final startOfYear = DateTime(date.year, 1, 1);
          final dayOfYear = date.difference(startOfYear).inDays + 1;
          final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
          final weekKey =
              "${date.year}-W${weekOfYear.toString().padLeft(2, '0')}";
          weeklyCounts[weekKey] = (weeklyCounts[weekKey] ?? 0) + 1;
        }
      }

      switch (timeFrame) {
        case 'Today':
        case 'This Week':
          return List.generate(4, (i) {
            final weekStart = now.subtract(
              Duration(days: now.weekday - 1 + (3 - i) * 7),
            );
            final startOfYear = DateTime(weekStart.year, 1, 1);
            final dayOfYear = weekStart.difference(startOfYear).inDays + 1;
            final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
            final weekKey =
                "${weekStart.year}-W${weekOfYear.toString().padLeft(2, '0')}";
            return ChartData(
              date: "Week $weekOfYear",
              count: weeklyCounts[weekKey] ?? 0,
            );
          });

        case 'This Month':
          return List.generate(8, (i) {
            final weekStart = now.subtract(
              Duration(days: now.weekday - 1 + (7 - i) * 7),
            );
            final startOfYear = DateTime(weekStart.year, 1, 1);
            final dayOfYear = weekStart.difference(startOfYear).inDays + 1;
            final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
            final weekKey =
                "${weekStart.year}-W${weekOfYear.toString().padLeft(2, '0')}";
            return ChartData(
              date: "W$weekOfYear",
              count: weeklyCounts[weekKey] ?? 0,
            );
          });

        default:
          return List.generate(12, (i) {
            final weekStart = now.subtract(
              Duration(days: now.weekday - 1 + (11 - i) * 7),
            );
            final startOfYear = DateTime(weekStart.year, 1, 1);
            final dayOfYear = weekStart.difference(startOfYear).inDays + 1;
            final weekOfYear = ((dayOfYear - 1) ~/ 7) + 1;
            final weekKey =
                "${weekStart.year}-W${weekOfYear.toString().padLeft(2, '0')}";
            return ChartData(
              date: "W$weekOfYear",
              count: weeklyCounts[weekKey] ?? 0,
            );
          });
      }
    } catch (e) {
      print('Error generating weekly session trend: $e');
      return [];
    }
  }

  List<ChartData>? _generateMonthlySessionTrend(
    List<QueryDocumentSnapshot> sessions,
    String timeFrame,
  ) {
    try {
      final monthlyCounts = <String, int>{};
      final now = DateTime.now();

      for (final doc in sessions) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['createdAt'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          final monthKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}";
          monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
        }
      }

      int monthsToShow;
      switch (timeFrame) {
        case 'Today':
        case 'This Week':
          monthsToShow = 3;
          break;
        case 'This Month':
          monthsToShow = 6;
          break;
        default:
          monthsToShow = 12;
          break;
      }

      return List.generate(monthsToShow, (i) {
        final month = DateTime(now.year, now.month - (monthsToShow - 1 - i));
        final monthKey =
            "${month.year}-${month.month.toString().padLeft(2, '0')}";
        final monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

        return ChartData(
          date: monthNames[month.month - 1],
          count: monthlyCounts[monthKey] ?? 0,
        );
      });
    } catch (e) {
      print('Error generating monthly session trend: $e');
      return [];
    }
  }
}

String _getMostFrequentCategory(Map<String, int> categories) {
  if (categories.isEmpty) return 'Unknown';
  return categories.entries.reduce((a, b) => a.value > b.value ? a : b).key;
}

List<ChartData> generateInquiryTrend(
  List<QueryDocumentSnapshot> messages,
  DateTime startDate,
  String timeFrame,
) {
  final timeCategoryCounts = <String, Map<String, int>>{};

  for (final doc in messages) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['sent_at'];
    if (timestamp is! Timestamp) continue;

    final timeKey = _getTimeKey(timestamp.toDate(), timeFrame);
    final category = (data['category'] as String?)?.trim() ?? 'General';

    timeCategoryCounts.putIfAbsent(timeKey, () => {});
    timeCategoryCounts[timeKey]![category] =
        (timeCategoryCounts[timeKey]![category] ?? 0) + 1;
  }

  return generateTrendData(startDate, timeFrame, timeCategoryCounts);
}

List<ChartData> generateConversationTrend(
  List<QueryDocumentSnapshot> sessions,
  DateTime startDate,
  String timeFrame,
) {
  final timeCounts = <String, int>{};

  for (final doc in sessions) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'];
    if (timestamp is! Timestamp) continue;

    final timeKey = _getTimeKey(timestamp.toDate(), timeFrame);
    timeCounts[timeKey] = (timeCounts[timeKey] ?? 0) + 1;
  }

  return generateConversationTrendData(startDate, timeFrame, timeCounts);
}

String _getTimeKey(DateTime dateTime, String timeFrame) {
  return switch (timeFrame) {
    'Today' => "${dateTime.hour.toString().padLeft(2, '0')}:00",
    'This Week' =>
      "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}",
    'This Month' => "Week ${_getWeekOfMonth(dateTime)}",
    'This Year' =>
      "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}",
    _ => "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}",
  };
}

List<ChartData> generateTrendData(
  DateTime startDate,
  String timeFrame,
  Map<String, Map<String, int>> timeCategoryCounts,
) {
  return switch (timeFrame) {
    'Today' => _generateHourlyTrend(timeCategoryCounts),
    'This Week' => _generateWeeklyTrend(startDate, timeCategoryCounts),
    'This Month' => _generateMonthlyTrend(timeCategoryCounts),
    'This Year' => _generateYearlyTrend(startDate, timeCategoryCounts),
    _ => _generateYearlyTrend(startDate, timeCategoryCounts),
  };
}

List<ChartData> generateConversationTrendData(
  DateTime startDate,
  String timeFrame,
  Map<String, int> timeCounts,
) {
  switch (timeFrame) {
    case 'Today':
      return generateHourlyConversationTrend(timeCounts);
    case 'This Week':
      return generateWeeklyConversationTrend(startDate, timeCounts);
    case 'This Month':
      return generateMonthlyConversationTrend(timeCounts);
    case 'This Year':
      return generateYearlyConversationTrend(startDate, timeCounts);
    default:
      return generateYearlyConversationTrend(startDate, timeCounts);
  }
}

List<ChartData> generateHourlyConversationTrend(Map<String, int> timeCounts) {
  return List.generate(24, (hour) {
    final timeKey = "${hour.toString().padLeft(2, '0')}:00";
    return ChartData(date: timeKey, count: timeCounts[timeKey] ?? 0);
  });
}

List<ChartData> generateWeeklyConversationTrend(
  DateTime startDate,
  Map<String, int> timeCounts,
) {
  final trend = <ChartData>[];
  var current = startDate;

  for (int i = 0; i < 7; i++) {
    final dateKey =
        "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
    final displayKey = "${current.day}/${current.month}";
    trend.add(ChartData(date: displayKey, count: timeCounts[dateKey] ?? 0));
    current = current.add(const Duration(days: 1));
  }

  return trend;
}

List<ChartData> generateMonthlyConversationTrend(Map<String, int> timeCounts) {
  return List.generate(5, (week) {
    final weekKey = "Week ${week + 1}";
    return ChartData(date: weekKey, count: timeCounts[weekKey] ?? 0);
  });
}

List<ChartData> generateYearlyConversationTrend(
  DateTime startDate,
  Map<String, int> timeCounts,
) {
  return List.generate(12, (month) {
    final monthKey =
        "${startDate.year}-${(month + 1).toString().padLeft(2, '0')}";
    final monthName = _getMonthName(month + 1);
    return ChartData(date: monthName, count: timeCounts[monthKey] ?? 0);
  });
}

List<ChartData> _generateHourlyTrend(Map<String, Map<String, int>> data) {
  return List.generate(24, (hour) {
    final timeKey = "${hour.toString().padLeft(2, '0')}:00";
    final categoryBreakdown = data[timeKey] ?? <String, int>{};
    final totalCount = categoryBreakdown.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return ChartData(
      date: timeKey,
      count: totalCount,
      categoryBreakdown: categoryBreakdown,
    );
  });
}

List<ChartData> _generateWeeklyTrend(
  DateTime startDate,
  Map<String, Map<String, int>> data,
) {
  final trend = <ChartData>[];
  var current = startDate;

  for (int i = 0; i < 7; i++) {
    final dateKey =
        "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
    final displayKey = _getDayName(current.weekday);
    final categoryBreakdown = data[dateKey] ?? <String, int>{};
    final totalCount = categoryBreakdown.values.fold(
      0,
      (sum, count) => sum + count,
    );

    trend.add(
      ChartData(
        date: displayKey,
        count: totalCount,
        categoryBreakdown: categoryBreakdown,
      ),
    );

    current = current.add(const Duration(days: 1));
  }

  return trend;
}

List<ChartData> _generateMonthlyTrend(Map<String, Map<String, int>> data) {
  return List.generate(5, (week) {
    final weekKey = "Week ${week + 1}";
    final categoryBreakdown = data[weekKey] ?? <String, int>{};
    final totalCount = categoryBreakdown.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return ChartData(
      date: weekKey,
      count: totalCount,
      categoryBreakdown: categoryBreakdown,
    );
  });
}

List<ChartData> _generateYearlyTrend(
  DateTime startDate,
  Map<String, Map<String, int>> data,
) {
  return List.generate(12, (month) {
    final monthKey =
        "${startDate.year}-${(month + 1).toString().padLeft(2, '0')}";
    final displayKey = _getMonthName(month + 1);
    final categoryBreakdown = data[monthKey] ?? <String, int>{};
    final totalCount = categoryBreakdown.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return ChartData(
      date: displayKey,
      count: totalCount,
      categoryBreakdown: categoryBreakdown,
    );
  });
}

// Utility functions
int _getWeekOfMonth(DateTime date) {
  final firstDay = DateTime(date.year, date.month, 1);
  return ((date.difference(firstDay).inDays) ~/ 7) + 1;
}

String _getDayName(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[weekday - 1];
}

String _getMonthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

double getGridInterval(List<ChartData> trendData) {
  if (trendData.isEmpty) return 1;

  int maxValue = trendData.map((e) => e.count).reduce((a, b) => a > b ? a : b);
  if (maxValue <= 5) return 1;
  if (maxValue <= 20) return 5;
  if (maxValue <= 50) return 10;
  return (maxValue / 5).ceil().toDouble();
}

double getBottomTitleInterval(int dataLength) {
  if (dataLength <= 7) return 1;
  if (dataLength <= 14) return 2;
  return (dataLength / 6).ceil().toDouble();
}

String formatBottomTitle(String date) {
  if (date.length > 6) {
    return date.substring(0, 6);
  }
  return date;
}

extension DateTimeExtension on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays + 1;
  }
}
