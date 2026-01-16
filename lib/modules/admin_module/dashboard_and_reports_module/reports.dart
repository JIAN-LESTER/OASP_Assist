import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/user_demographics_data.dart';

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

 Future<InquiryReportsData> getInquiryReportsData(
  String timeFrame, [
  DateTimeRange? customRange,
]) async {
  final cacheKey = timeFrame == 'Custom' && customRange != null
      ? 'inquiry_${customRange.start.toString()}_${customRange.end.toString()}'
      : 'inquiry_$timeFrame';

  if (_inquiryCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
    return _inquiryCache[cacheKey]!;
  }

  try {
    final startDate = getStartDate(timeFrame, customRange);
    final endDate = getEndDate(timeFrame, customRange);

    // Parallel fetch with indexed queries
    final results = await Future.wait([
      _getMessages(startDate, endDate),
      _getFAQs(),
      _getLogs(),
      _getEscalatedMessages(startDate, endDate),
      _getResolvedEscalatedMessages(startDate, endDate),
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
      endDate: endDate,
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
  String timeFrame, [
  DateTimeRange? customRange,
]) async {
  final cacheKey = timeFrame == 'Custom' && customRange != null
      ? 'chatbot_${customRange.start.toString()}_${customRange.end.toString()}'
      : 'chatbot_$timeFrame';

  if (_chatbotCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
    return _chatbotCache[cacheKey]!;
  }

  try {
    final startDate = getStartDate(timeFrame, customRange);
    final endDate = getEndDate(timeFrame, customRange);

    final userLookup = await _getUserLookup();

    final results = await Future.wait([
      _getConversationsOptimized(startDate, endDate),
      _getMessages(startDate, endDate),
    ]);

    final data = _processChatbotUsageReportsData(
      sessions: results[0],
      messages: results[1],
      userLookup: userLookup,
      startDate: startDate,
      endDate: endDate,
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
  String timeFrame, [
  DateTimeRange? customRange,
]) async {
  final cacheKey = timeFrame == 'Custom' && customRange != null
      ? 'demographics_${customRange.start.toString()}_${customRange.end.toString()}'
      : 'demographics_$timeFrame';

  if (_demographicsCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
    return _demographicsCache[cacheKey]!;
  }

  try {
    final startDate = getStartDate(timeFrame, customRange);
    final endDate = getEndDate(timeFrame, customRange);

    final results = await Future.wait([
      _getUsers(), // Get all users (for total count)
      _getActiveUsers(), // Get enrolled users
      _getNewUsers(timeFrame, customRange), // Get new users in period
      _getMessages(startDate, endDate), // Get messages in period
    ]);

    final data = _processUserDemographicsReportsData(
      users: results[0],
      activeUsers: results[1],
      newUsers: results[2],
      messages: results[3],
      timeFrame: timeFrame,
      startDate: startDate,
      endDate: endDate,
    );

    _demographicsCache[cacheKey] = data;
    _updateCacheTimestamp(cacheKey);

    return data;
  } catch (e) {
    print('Error fetching user demographics data: $e');
    return getEmptyUserDemographicsReportsData();
  }
}


  Future<List<QueryDocumentSnapshot>> _getMessages(
  DateTime startDate, [
  DateTime? endDate,
]) async {
  Query query = _firestore
      .collectionGroup('messages')
      .where('sender', isEqualTo: 'user')
      .where('sent_at', isGreaterThanOrEqualTo: startDate);

  if (endDate != null) {
    query = query.where('sent_at', isLessThanOrEqualTo: endDate);
  }

  final snapshot = await query.orderBy('sent_at', descending: true).get();
  return snapshot.docs;
}

  Future<List<QueryDocumentSnapshot>> _getEscalatedMessages(
  DateTime startDate, [
  DateTime? endDate,
]) async {
  Query query = _firestore
      .collectionGroup('escalations')
      .where('status', isEqualTo: 'pending')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));

  if (endDate != null) {
    query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
  }

  final snapshot = await query.orderBy('createdAt', descending: true).get();
  return snapshot.docs;
}

  Future<List<QueryDocumentSnapshot>> _getResolvedEscalatedMessages(
  DateTime startDate, [
  DateTime? endDate,
]) async {
  Query query = _firestore
      .collectionGroup('escalations')
      .where('status', isEqualTo: 'resolved')
      .where('createdAt', isGreaterThanOrEqualTo: startDate);

  if (endDate != null) {
    query = query.where('createdAt', isLessThanOrEqualTo: endDate);
  }

  final snapshot = await query.orderBy('createdAt', descending: true).get();
  return snapshot.docs;
}


Future<List<QueryDocumentSnapshot>> _getConversationsOptimized(
  DateTime startDate, [
  DateTime? endDate,
]) async {
  Query query = _firestore
      .collection('conversations')
      .where('createdAt', isGreaterThanOrEqualTo: startDate);

  if (endDate != null) {
    query = query.where('createdAt', isLessThanOrEqualTo: endDate);
  }

  final snapshot = await query.orderBy('createdAt', descending: true).get();
  return snapshot.docs;
}

Future<List<QueryDocumentSnapshot>> _getNewUsers(
  String timeFrame, [
  DateTimeRange? customRange,
]) async {
  final startDate = getStartDate(timeFrame, customRange);
  final endDate = getEndDate(timeFrame, customRange);

  Query query = _firestore.collection('users').where(
    'createdAt',
    isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
  );

  if (endDate != null) {
    query = query.where(
      'createdAt',
      isLessThanOrEqualTo: Timestamp.fromDate(endDate),
    );
  }

  final snapshot = await query.orderBy('createdAt', descending: true).get();
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

DateTime getStartDate(String timeFrame, [DateTimeRange? customRange]) {
  if (timeFrame == 'Custom' && customRange != null) {
    return DateTime(
      customRange.start.year,
      customRange.start.month,
      customRange.start.day,
      0, 0, 0, // Start of day
    );
  }

  final now = DateTime.now();
  return switch (timeFrame) {
    'All' => DateTime(2000, 1, 1),
    'Today' => DateTime(now.year, now.month, now.day),
    'This Week' => _getStartOfWeek(now),
    'This Month' => DateTime(now.year, now.month, 1),
    'This Year' => DateTime(now.year, 1, 1),
    _ => DateTime(now.year, now.month, 1),
  };
}

DateTime? getEndDate(String timeFrame, [DateTimeRange? customRange]) {
  if (timeFrame == 'Custom' && customRange != null) {
    return DateTime(
      customRange.end.year,
      customRange.end.month,
      customRange.end.day,
      23, 59, 59, 999, // End of day
    );
  }
  return null; // For other timeframes, no end date filter
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
  DateTime? endDate,
  required String timeFrame,
}) {
  // Filter messages within date range
  final filteredMessages = messages.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['sent_at'] as Timestamp?;
    if (timestamp == null) return false;
    
    final date = timestamp.toDate();
    if (endDate != null && date.isAfter(endDate)) return false;
    return true;
  }).toList();

  final categoryDistribution = <String, int>{};
  int answeredMessages = 0;
  int unAnsweredMessages = 0;

  for (final doc in filteredMessages) {
    final data = doc.data() as Map<String, dynamic>;

    if (data['isAnswered'] == true) answeredMessages++;
    if (data['isAnswered'] == false) unAnsweredMessages++;

    final category = (data['category'] as String?)?.trim() ?? 'General';
    categoryDistribution[category] = (categoryDistribution[category] ?? 0) + 1;
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
    totalMessages: filteredMessages.length,
    answeredMessages: answeredMessages,
    unAnsweredMessages: unAnsweredMessages,
    escalatedMessages: escalations.length,
    resolvedEscalatedMessages: resolvedEscalations.length,
    mostFrequentCategory: _getMostFrequentCategory(categoryDistribution),
    categoryDistribution: categoryDistribution,
    inquiryTrend: generateInquiryTrend(filteredMessages, startDate, timeFrame, endDate),
      highestFAQs: highestFAQs,
      recentLogs: recentLogs,
      msgLogs: messageLogs,
    );
  }

  // FIXED: Now uses cached userLookup instead of QuerySnapshot
ChatbotUsageReportsData _processChatbotUsageReportsData({
  required List<QueryDocumentSnapshot> sessions,
  required List<QueryDocumentSnapshot> messages,
  required Map<String, Map<String, dynamic>> userLookup,
  required DateTime startDate,
  DateTime? endDate,
  required String timeFrame,
}) {
  // Filter sessions within date range
  final filteredSessions = sessions.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp == null) return false;
    
    final date = timestamp.toDate();
    if (endDate != null && date.isAfter(endDate)) return false;
    return true;
  }).toList();

  // Filter messages within date range
  final filteredMessages = messages.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['sent_at'] as Timestamp?;
    if (timestamp == null) return false;
    
    final date = timestamp.toDate();
    if (endDate != null && date.isAfter(endDate)) return false;
    return true;
  }).toList();
    // Process sessions
    double totalSessionDuration = 0;
    int completedSessionsCount = 0;
    final userSessionCounts = <String, int>{};

    final uniqueUsersByYear = <String, Set<String>>{};
    final uniqueUsersByProgram = <String, Set<String>>{};

    for (final doc in sessions) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String? ?? 'unknown';
      final createdAt = data['createdAt'] as Timestamp?;
      final endedAt = data['endedAt'] as Timestamp?;
      final status = data['status'] as String? ?? 'unknown';

      final userInfo = userLookup[userId];
      if (userInfo != null) {
        final year = userInfo['year'] ?? 'N/A';
        final program = userInfo['program'] ?? 'N/A';

        uniqueUsersByYear.putIfAbsent(year, () => <String>{});
        uniqueUsersByYear[year]!.add(userId);

        uniqueUsersByProgram.putIfAbsent(program, () => <String>{});
        uniqueUsersByProgram[program]!.add(userId);
      }

      if (createdAt != null && endedAt != null && status == 'ended') {
        final duration = endedAt.toDate().difference(createdAt.toDate());

        if (duration.inSeconds >= 10 && duration.inSeconds <= 7200) {
          totalSessionDuration += duration.inSeconds.toDouble();
          completedSessionsCount++;
        }
      }

      userSessionCounts[userId] = (userSessionCounts[userId] ?? 0) + 1;
    }

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

    final averageMessagesPerUser =
        userSessionCounts.isNotEmpty
            ? sessions.length / userSessionCounts.length.toDouble()
            : 0.0;

    // ✅ FIXED: Response time in SECONDS with proper date grouping
    double totalResponseTime = 0;
    int responseTimeCount = 0;
    final responseTimeByDate = <String, List<double>>{};

    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      final responseTimeMs = data['responseTimeMs'];
      final sentAt = data['sent_at'] as Timestamp?;

      if (responseTimeMs != null &&
          responseTimeMs is num &&
          responseTimeMs > 0) {
        final responseTimeSeconds =
            responseTimeMs.toDouble() / 1000; // Convert to seconds

        if (responseTimeSeconds >= 0.1 && responseTimeSeconds <= 60) {
          totalResponseTime += responseTimeSeconds;
          responseTimeCount++;

          if (sentAt != null) {
            final dateKey = _getDateKey(sentAt.toDate(), timeFrame);
            responseTimeByDate.putIfAbsent(dateKey, () => []);
            responseTimeByDate[dateKey]!.add(responseTimeSeconds);
          }
        }
      }
    }

    final averageResponseTime =
        responseTimeCount > 0 ? totalResponseTime / responseTimeCount : 0.0;

    // ✅ FIXED: Build complete response time trend with all dates
    final responseTimeTrend = _buildResponseTimeTrend(
      responseTimeByDate,
      timeFrame,
      startDate,
    );

    return ChatbotUsageReportsData(
      
         totalSessions: filteredSessions.length,
      averageResponseTime: averageResponseTime,
      averageMessagesPerUser: averageMessagesPerUser,
      averageSessionLength: averageSessionLength,
      usageTrendByTimeOfDay: _generateHourlyUsageTrend(sessions) ?? [],

      // ✅ THIS IS WHAT YOU SHOULD USE FOR THE CHART:
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
  required String timeFrame,
  DateTime? startDate,
  DateTime? endDate,
}) {
  // ✅ Filter users who were active during the timeframe
  // Active = users who sent messages in the selected period
  final activeUserIds = <String>{};
  for (final doc in messages) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data['userId'] as String?;
    if (userId != null) {
      activeUserIds.add(userId);
    }
  }

  // ✅ Get only users who were active in the timeframe
  final activeUsersInPeriod = users.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = data['uid'] as String?;
    return uid != null && activeUserIds.contains(uid);
  }).toList();

  // ✅ Process only active users for demographics
  final usersByYear = <String, int>{};
  final usersByProgram = <String, int>{};
  final enrollmentStatus = <String, int>{'Enrolled': 0, 'Not Enrolled': 0};
  final scholarshipTypes = <String, int>{};
  final affiliationTypes = <String, int>{};

  int affiliationCount = 0; // Count for "Incoming Freshman Applicant"

  for (final doc in activeUsersInPeriod) {
    final data = doc.data() as Map<String, dynamic>;

    final year = data['year']?.toString() ?? 'N/A';
    final program = data['program']?.toString() ?? 'N/A';
    final rawAffiliation = data['affiliation']?.toString();
    final affiliationValue = rawAffiliation?.trim();
    final scholarshipValue = data['scholarship']?.toString();
    final isEnrolled = data['isEnrolled'];

    // Count by year
    usersByYear[year] = (usersByYear[year] ?? 0) + 1;

    // Count by program
    usersByProgram[program] = (usersByProgram[program] ?? 0) + 1;

    // Count all affiliations
    if (affiliationValue != null &&
        affiliationValue.isNotEmpty &&
        affiliationValue != 'null' &&
        affiliationValue.toLowerCase() != 'null') {
      affiliationTypes[affiliationValue] =
          (affiliationTypes[affiliationValue] ?? 0) + 1;
    }

    // Count specific affiliation: "Incoming Freshman Applicant"
    const targetAffiliation = 'Incoming Freshman Applicant';
    if (affiliationValue?.toLowerCase() == targetAffiliation.toLowerCase()) {
      affiliationCount++;
    }

    // Count scholarships
    if (scholarshipValue != null &&
        scholarshipValue.isNotEmpty &&
        scholarshipValue != 'null' &&
        scholarshipValue.toLowerCase() != 'null') {
      scholarshipTypes[scholarshipValue] =
          (scholarshipTypes[scholarshipValue] ?? 0) + 1;
    }

    // Count enrollment status
    if (isEnrolled == true) {
      enrollmentStatus['Enrolled'] = (enrollmentStatus['Enrolled'] ?? 0) + 1;
    } else {
      enrollmentStatus['Not Enrolled'] =
          (enrollmentStatus['Not Enrolled'] ?? 0) + 1;
    }
  }

  return UserDemographicsReportsData(
    activeUsers: activeUsersInPeriod.length, // ✅ Active users in period
    newlyRegisteredUsers: scholarshipTypes.values.fold(0, (sum, count) => sum + count), // ✅ Users with scholarships
    affiliatedUsers: affiliationCount, // ✅ Only freshman applicants
    totalUsers: users.length, // ✅ Total users (all time)
    usersByYear: usersByYear,
    usersByProgram: usersByProgram,
    userAffiliations: affiliationTypes,
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

  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysFromMonday));
  }

  Future<Map<String, int>> getQuickStats(
  String timeFrame, [
  DateTimeRange? customRange,
]) async {
  final startDate = getStartDate(timeFrame, customRange);
  final endDate = getEndDate(timeFrame, customRange);

  try {
    Query messagesQuery = _firestore
        .collectionGroup('messages')
        .where('sender', isEqualTo: 'user')
        .where('sent_at', isGreaterThanOrEqualTo: startDate);

    Query answeredQuery = _firestore
        .collectionGroup('messages')
        .where('sender', isEqualTo: 'user')
        .where('sent_at', isGreaterThanOrEqualTo: startDate)
        .where('isAnswered', isEqualTo: true);

    if (endDate != null) {
      messagesQuery = messagesQuery.where('sent_at', isLessThanOrEqualTo: endDate);
      answeredQuery = answeredQuery.where('sent_at', isLessThanOrEqualTo: endDate);
      answeredQuery = answeredQuery.where('sent_at', isLessThanOrEqualTo: endDate);
    }

    final messagesSnapshot = await messagesQuery.where("sent_at", isLessThanOrEqualTo: endDate).count().get();
    final answeredSnapshot = await answeredQuery.where('sent_at', isLessThanOrEqualTo: endDate).count().get();
    final usersSnapshot = await _firestore.collection('users').where("createdAt", isGreaterThanOrEqualTo: startDate).count().get();

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

    final now = DateTime.now();
    final trendData = <ChartData>[];

    switch (timeFrame) {
      case 'Today':
        // Generate all 24 hours
        for (int hour = 0; hour < 24; hour++) {
          final hourKey = "${hour.toString().padLeft(2, '0')}:00";
          final times = responseTimeByDate[hourKey] ?? [];

          if (times.isNotEmpty) {
            final average = times.reduce((a, b) => a + b) / times.length;
            trendData.add(
              ChartData(
                date: hourKey,
                count:
                    (average * 100)
                        .round(), // Store as centiseconds for precision
              ),
            );
          } else {
            trendData.add(ChartData(date: hourKey, count: 0));
          }
        }
        break;

      case 'This Week':
        // Generate all 7 days of the week with day names
        final startOfWeek = _getStartOfWeek(now);
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          final displayKey = dayNames[i]; // Use day name instead of date
          final times = responseTimeByDate[dateKey] ?? [];

          if (times.isNotEmpty) {
            final average = times.reduce((a, b) => a + b) / times.length;
            trendData.add(
              ChartData(date: displayKey, count: (average * 100).round()),
            );
          } else {
            trendData.add(ChartData(date: displayKey, count: 0));
          }
        }
        break;

      case 'This Month':
        // Generate all weeks of the month
        for (int week = 1; week <= 5; week++) {
          final weekKey = "Week $week";
          final times = responseTimeByDate[weekKey] ?? [];

          if (times.isNotEmpty) {
            final average = times.reduce((a, b) => a + b) / times.length;
            trendData.add(
              ChartData(date: weekKey, count: (average * 100).round()),
            );
          } else {
            trendData.add(ChartData(date: weekKey, count: 0));
          }
        }
        break;

      case 'This Year':
      default:
        // Generate all 12 months
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
        for (int month = 1; month <= 12; month++) {
          final monthKey = "${now.year}-${month.toString().padLeft(2, '0')}";
          final times = responseTimeByDate[monthKey] ?? [];

          if (times.isNotEmpty) {
            final average = times.reduce((a, b) => a + b) / times.length;
            trendData.add(
              ChartData(
                date: monthNames[month - 1],
                count: (average * 100).round(),
              ),
            );
          } else {
            trendData.add(ChartData(date: monthNames[month - 1], count: 0));
          }
        }
        break;
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
  String timeFrame, [
  DateTime? startDate,
  DateTime? endDate,
]) {
  try {
    final now = DateTime.now();

    // ✅ CUSTOM DATE RANGE HANDLING
    if (timeFrame == 'Custom' && startDate != null && endDate != null) {
      final interval = _getDataGroupingInterval(startDate, endDate);
      final sessionCounts = <String, int>{};

      // Filter and group sessions
      for (final doc in sessions) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['createdAt'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          
          // Only count sessions within the custom range
          if (date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
              date.isBefore(endDate.add(const Duration(seconds: 1)))) {
            final timeKey = _getTimeKeyForInterval(date, interval);
            sessionCounts[timeKey] = (sessionCounts[timeKey] ?? 0) + 1;
          }
        }
      }

      // Generate complete data points based on interval
      return _generateCompleteDataPoints(
        startDate,
        endDate,
        interval,
        sessionCounts,
      );
    }

    // ✅ EXISTING PRESET TIMEFRAME LOGIC
    switch (timeFrame) {
      case 'Today':
        final hourlyCounts = <int, int>{};
        for (final doc in sessions) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['createdAt'];
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            if (date.year == now.year &&
                date.month == now.month &&
                date.day == now.day) {
              hourlyCounts[date.hour] = (hourlyCounts[date.hour] ?? 0) + 1;
            }
          }
        }
        return List.generate(24, (hour) {
          final hourKey = "${hour.toString().padLeft(2, '0')}:00";
          return ChartData(date: hourKey, count: hourlyCounts[hour] ?? 0);
        });

      case 'This Week':
        final startOfWeek = _getStartOfWeek(now);
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        final dailyCounts = <int, int>{};

        for (final doc in sessions) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['createdAt'];
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
                date.isBefore(endOfWeek)) {
              final daysSinceStart = date.difference(startOfWeek).inDays;
              if (daysSinceStart >= 0 && daysSinceStart < 7) {
                dailyCounts[daysSinceStart] =
                    (dailyCounts[daysSinceStart] ?? 0) + 1;
              }
            }
          }
        }

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return List.generate(7, (i) {
          return ChartData(date: dayNames[i], count: dailyCounts[i] ?? 0);
        });

      case 'This Month':
        final weeklyCounts = <int, int>{};
        for (final doc in sessions) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['createdAt'];
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            if (date.year == now.year && date.month == now.month) {
              final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
              weeklyCounts[weekOfMonth] = (weeklyCounts[weekOfMonth] ?? 0) + 1;
            }
          }
        }
        return List.generate(5, (week) {
          final weekNumber = week + 1;
          final weekKey = "Week $weekNumber";
          return ChartData(date: weekKey, count: weeklyCounts[weekNumber] ?? 0);
        });

      case 'This Year':
      default:
        final monthlyCounts = <int, int>{};
        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];

        for (final doc in sessions) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['createdAt'];
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            if (date.year == now.year) {
              monthlyCounts[date.month] = (monthlyCounts[date.month] ?? 0) + 1;
            }
          }
        }

        return List.generate(12, (i) {
          final month = i + 1;
          return ChartData(date: monthNames[i], count: monthlyCounts[month] ?? 0);
        });
    }
  } catch (e) {
    print('Error generating daily session trend: $e');
    return [];
  }
}

List<ChartData> _generateCompleteDataPoints(
  DateTime startDate,
  DateTime endDate,
  String interval,
  Map<String, int> dataCounts,
) {
  final dataPoints = <ChartData>[];

  switch (interval) {
    case 'hourly':
      // Generate all 24 hours for the single day
      for (int hour = 0; hour < 24; hour++) {
        final hourKey = "${hour.toString().padLeft(2, '0')}:00";
        dataPoints.add(ChartData(
          date: hourKey,
          count: dataCounts[hourKey] ?? 0,
        ));
      }
      break;

    case 'daily':
      // Generate all days in the range
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
        final dateKey =
            "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
        final displayKey = dayNames[currentDate.weekday - 1];
        
        dataPoints.add(ChartData(
          date: displayKey,
          count: dataCounts[dateKey] ?? 0,
        ));
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
      break;

    case 'weekly':
      // Generate all weeks in the range
      final daysDiff = endDate.difference(startDate).inDays;
      final weeksCount = (daysDiff / 7).ceil();
      
      for (int week = 1; week <= weeksCount; week++) {
        final weekKey = "Week $week";
        dataPoints.add(ChartData(
          date: weekKey,
          count: dataCounts[weekKey] ?? 0,
        ));
      }
      break;

    case 'monthly':
      // Generate all months in the range
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      
      var currentMonth = DateTime(startDate.year, startDate.month);
      final endMonth = DateTime(endDate.year, endDate.month);

      while (currentMonth.isBefore(endMonth.add(const Duration(days: 32))) ||
             currentMonth.month == endMonth.month && currentMonth.year == endDate.year) {
        final monthKey =
            "${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}";
        final displayKey = monthNames[currentMonth.month - 1];
        
        dataPoints.add(ChartData(
          date: displayKey,
          count: dataCounts[monthKey] ?? 0,
        ));
        
        // Move to next month
        if (currentMonth.month == 12) {
          currentMonth = DateTime(currentMonth.year + 1, 1);
        } else {
          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
        }
      }
      break;
  }

  return dataPoints;
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

// String _getDataGroupingInterval(DateTimeRange range) {
//   final daysDifference = range.end.difference(range.start).inDays;

//   if (daysDifference <= 1) {
//     return 'hourly'; // Show hourly data
//   } else if (daysDifference <= 31) {
//     return 'daily'; // Show daily data
//   } else if (daysDifference <= 90) {
//     return 'weekly'; // Show weekly data
//   } else if (daysDifference <= 365) {
//     return 'monthly'; // Show monthly data
//   } else {
//     return 'yearly'; // Show yearly data
//   }
// }

String _getMostFrequentCategory(Map<String, int> categories) {
  if (categories.isEmpty) return 'Unknown';
  return categories.entries.reduce((a, b) => a.value > b.value ? a : b).key;
}

List<ChartData> generateInquiryTrend(
  List<QueryDocumentSnapshot> messages,
  DateTime startDate,
  String timeFrame, [
  DateTime? endDate,
]) {
  final timeCategoryCounts = <String, Map<String, int>>{};

  // Determine interval for custom ranges
  String interval = timeFrame;
  if (timeFrame == 'Custom' && endDate != null) {
    interval = _getDataGroupingInterval(startDate, endDate);
  }

  for (final doc in messages) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['sent_at'];
    if (timestamp is! Timestamp) continue;

    final date = timestamp.toDate();
    
    // Filter by endDate if provided
    if (endDate != null && date.isAfter(endDate)) continue;

    // Get appropriate time key based on interval
    String timeKey;
    if (timeFrame == 'Custom' && endDate != null) {
      timeKey = _getTimeKeyForInterval(date, interval);
    } else {
      timeKey = _getTimeKey(date, timeFrame);
    }

    final category = (data['category'] as String?)?.trim() ?? 'General';

    timeCategoryCounts.putIfAbsent(timeKey, () => {});
    timeCategoryCounts[timeKey]![category] =
        (timeCategoryCounts[timeKey]![category] ?? 0) + 1;
  }

  return generateTrendData(startDate, timeFrame, timeCategoryCounts, endDate);
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
    'All' => "${dateTime.year}", // Group by year for "All"
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
  Map<String, Map<String, int>> timeCategoryCounts, [
  DateTime? endDate,
]) {
  // Handle custom date ranges
  if (timeFrame == 'Custom' && endDate != null) {
    final interval = _getDataGroupingInterval(startDate, endDate);
    return _generateCustomRangeTrend(
      startDate,
      endDate,
      interval,
      timeCategoryCounts,
    );
  }

  // Existing preset timeframe logic
  return switch (timeFrame) {
    'All' => _generateAllTimeTrend(startDate, timeCategoryCounts),
    'Today' => _generateHourlyTrend(timeCategoryCounts),
    'This Week' => _generateWeeklyTrend(startDate, timeCategoryCounts),
    'This Month' => _generateMonthlyTrend(timeCategoryCounts),
    'This Year' => _generateYearlyTrend(startDate, timeCategoryCounts),
    _ => _generateYearlyTrend(startDate, timeCategoryCounts),
  };
}

List<ChartData> _generateCustomRangeTrend(
  DateTime startDate,
  DateTime endDate,
  String interval,
  Map<String, Map<String, int>> timeCategoryCounts,
) {
  final trend = <ChartData>[];

  switch (interval) {
    case 'hourly':
      // Generate all 24 hours
      for (int hour = 0; hour < 24; hour++) {
        final hourKey = "${hour.toString().padLeft(2, '0')}:00";
        final categoryBreakdown = timeCategoryCounts[hourKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(0, (sum, count) => sum + count);

        trend.add(ChartData(
          date: hourKey,
          count: totalCount,
          categoryBreakdown: categoryBreakdown,
        ));
      }
      break;

    case 'daily':
      // Generate all days in range
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
        final dateKey =
            "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
        final displayKey = dayNames[currentDate.weekday - 1];
        final categoryBreakdown = timeCategoryCounts[dateKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(0, (sum, count) => sum + count);

        trend.add(ChartData(
          date: displayKey,
          count: totalCount,
          categoryBreakdown: categoryBreakdown,
        ));

        currentDate = currentDate.add(const Duration(days: 1));
      }
      break;

    case 'weekly':
      // Generate all weeks
      final daysDiff = endDate.difference(startDate).inDays;
      final weeksCount = (daysDiff / 7).ceil();

      for (int week = 1; week <= weeksCount; week++) {
        final weekKey = "Week $week";
        final categoryBreakdown = timeCategoryCounts[weekKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(0, (sum, count) => sum + count);

        trend.add(ChartData(
          date: weekKey,
          count: totalCount,
          categoryBreakdown: categoryBreakdown,
        ));
      }
      break;

    case 'monthly':
      // Generate all months in range
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

      var currentMonth = DateTime(startDate.year, startDate.month);
      final endMonth = DateTime(endDate.year, endDate.month);

      while (currentMonth.isBefore(endMonth.add(const Duration(days: 32))) ||
             (currentMonth.month == endMonth.month && currentMonth.year == endDate.year)) {
        final monthKey =
            "${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}";
        final displayKey = monthNames[currentMonth.month - 1];
        final categoryBreakdown = timeCategoryCounts[monthKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(0, (sum, count) => sum + count);

        trend.add(ChartData(
          date: displayKey,
          count: totalCount,
          categoryBreakdown: categoryBreakdown,
        ));

        // Move to next month
        if (currentMonth.month == 12) {
          currentMonth = DateTime(currentMonth.year + 1, 1);
        } else {
          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
        }
      }
      break;
  }

  return trend;
}

List<ChartData> _generateAllTimeTrend(
  DateTime startDate,
  Map<String, Map<String, int>> data,
) {
  // Find the earliest and latest years in the data
  final years =
      data.keys
          .map((key) => int.tryParse(key))
          .where((year) => year != null)
          .cast<int>()
          .toList();

  if (years.isEmpty) {
    return [];
  }

  years.sort();
  final earliestYear = years.first;
  final latestYear = DateTime.now().year;

  // Generate data for all years from earliest to current
  final trend = <ChartData>[];
  for (int year = earliestYear; year <= latestYear; year++) {
    final yearKey = year.toString();
    final categoryBreakdown = data[yearKey] ?? <String, int>{};
    final totalCount = categoryBreakdown.values.fold(
      0,
      (sum, count) => sum + count,
    );

    trend.add(
      ChartData(
        date: yearKey,
        count: totalCount,
        categoryBreakdown: categoryBreakdown,
      ),
    );
  }

  return trend;
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

String _getDataGroupingInterval(DateTime startDate, DateTime endDate) {
  final daysDifference = endDate.difference(startDate).inDays;

  if (daysDifference == 0) {
    return 'hourly'; // Same day - show hourly data
  } else if (daysDifference <= 7) {
    return 'daily'; // Up to 7 days - show daily data
  } else if (daysDifference <= 31) {
    return 'weekly'; // Up to 31 days - show weekly data
  } else {
    return 'monthly'; // More than 31 days - show monthly data
  }
}

/// Gets the appropriate time key based on grouping interval
String _getTimeKeyForInterval(DateTime dateTime, String interval) {
  switch (interval) {
    case 'hourly':
      return "${dateTime.hour.toString().padLeft(2, '0')}:00";
    case 'daily':
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
    case 'weekly':
      final weekOfMonth = ((dateTime.day - 1) ~/ 7) + 1;
      return "Week $weekOfMonth";
    case 'monthly':
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}";
    default:
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}";
  }
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
