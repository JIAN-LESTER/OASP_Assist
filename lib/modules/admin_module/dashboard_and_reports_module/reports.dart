import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/admin_dashboard_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/escalation_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/staff_dashboard_data.dart';
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

  static final Map<String, InquiryReportsData> _inquiryCache = {};
  static final Map<String, ChatbotUsageReportsData> _chatbotCache = {};
  static final Map<String, UserDemographicsReportsData> _demographicsCache = {};
  static final Map<String, AdminDashboardData> _adminCache = {};
  static final Map<String, StaffDashboardData> _staffCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

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

  bool _isUserLookupCacheValid() {
    if (_userLookupCache == null || _userLookupCacheTime == null) return false;
    final now = DateTime.now();
    return now.difference(_userLookupCacheTime!).inMinutes <
        _userLookupCacheDurationMinutes;
  }

  // Future<Map<String, Map<String, dynamic>>> _getUserLookup() async {
  //   if (_isUserLookupCacheValid()) {
  //     return _userLookupCache!;
  //   }

  //   final users = await _getUsers(start);
  //   final userLookup = <String, Map<String, dynamic>>{};

  //   for (final u in users) {
  //     final data = u.data() as Map<String, dynamic>;
  //     final uid = data['uid'] as String?;
  //     if (uid != null) {
  //       userLookup[uid] = {
  //         'year': data['year'] ?? 'N/A',
  //         'program': data['program'] ?? 'N/A',
  //         'affiliation': data['affiliation'] ?? 'N/A',
  //         'scholarship': data['scholarship'],
  //         'isEnrolled': data['isEnrolled'] ?? false,
  //       };
  //     }
  //   }

  //   _userLookupCache = userLookup;
  //   _userLookupCacheTime = DateTime.now();

  //   return userLookup;
  // }

  Future<InquiryReportsData> getInquiryReportsData(
    String timeFrame, [
    DateTimeRange? customRange,
  ]) async {
    final cacheKey =
        timeFrame == 'Custom' && customRange != null
            ? 'inquiry_${customRange.start.toString()}_${customRange.end.toString()}'
            : 'inquiry_$timeFrame';

    if (_inquiryCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      print('✅ Using cached data for $cacheKey');
      return _inquiryCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame, customRange);
      final endDate = _getEndDate(timeFrame, customRange);

      print('🔥 Fetching inquiry data: timeFrame=$timeFrame');
      print('🔥 Date range: $startDate to $endDate');

      final results = await Future.wait([
        _getTotalMessages(startDate, endDate),
        _getMessages(startDate, endDate, 'user'),
        _getMessages(startDate, endDate, 'bot'),
        _getEscalatedMessages(startDate, endDate),
        _getResolvedEscalatedMessages(startDate, endDate),
        _getFAQs(startDate, endDate), // Initial fetch with time filter
        _getLogs(startDate, endDate),
        _getMessageLogs(startDate, endDate),
        _getAllEscalations(startDate, endDate),
        _getStaffResolutions(startDate, endDate),
      ]);

      // Check if FAQs are empty, if so fetch top FAQs without time filter
      List<QueryDocumentSnapshot> faqs = results[5];
      if (faqs.isEmpty) {
        print(
          '⚠️ No FAQs found in selected timeframe, fetching top FAQs from all time',
        );
        faqs = await _getTopFAQsAllTime();
      }

      print('🔥 Fetched ${results[1].length} user messages');
      print('🔥 Fetched ${faqs.length} FAQs');

      final data = _processInquiryReportsData(
        totalMessages: results[0],
        userMessages: results[1],
        botMessages: results[2],
        escalations: results[3],
        resolvedEscalations: results[4],
        faqs: faqs, // Use the potentially fallback FAQs
        logs: results[6],
        msgLogs: results[7],
        allEscalations: results[8],
        staffResolutions: results[9],
        startDate: startDate,
        endDate: endDate,
        timeFrame: timeFrame,
      );

      _inquiryCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('❌ Error fetching inquiry data: $e');
      return getEmptyInquiryReportsData();
    }
  }

  Future<ChatbotUsageReportsData> getChatbotUsageReportsData(
    String timeFrame, [
    DateTimeRange? customRange,
  ]) async {
    final cacheKey =
        timeFrame == 'Custom' && customRange != null
            ? 'chatbot_${customRange.start.toString()}_${customRange.end.toString()}'
            : 'chatbot_$timeFrame';

    if (_chatbotCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _chatbotCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame, customRange);
      final endDate = _getEndDate(timeFrame, customRange);

      final results = await Future.wait([
        _getConversations(startDate, endDate),
        _getMessages(startDate, endDate, 'user'),
        _getUnansweredMessages(startDate, endDate),
        _getUsersWithLimitData(startDate, endDate), // NEW
      ]);

      final data = _processChatbotUsageReportsData(
        conversations: results[0],
        messages: results[1],
        unansweredMessages: results[2],
        users: results[3], // NEW
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
    final cacheKey =
        timeFrame == 'Custom' && customRange != null
            ? 'demographics_${customRange.start.toString()}_${customRange.end.toString()}'
            : 'demographics_$timeFrame';

    if (_demographicsCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _demographicsCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame, customRange);
      final endDate = _getEndDate(timeFrame, customRange);

      final results = await Future.wait([
        _getUsers(startDate, endDate), // Users in timeframe (for "new users")
        _getNewUsers(startDate, endDate),
        _getActiveUsers(startDate, endDate),
        _getMessages(startDate, endDate, 'user'),
        _getAllUsersWithTimestamps(), // For user growth over time
      ]);

      final data = _processUserDemographicsReportsData(
        users: results[0], // Users in timeframe
        newUsers: results[1],
        activeUsers: results[2],
        messages: results[3],
        allUsersWithTimestamps: results[4],

        startDate: startDate,
        endDate: endDate,
        timeFrame: timeFrame,
      );

      _demographicsCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching user demographics data: $e');
      return getEmptyUserDemographicsReportsData();
    }
  }

  Future<AdminDashboardData> getAdminDashboardData(
    String timeFrame, [
    DateTimeRange? customRange,
  ]) async {
    final cacheKey =
        timeFrame == 'Custom' && customRange != null
            ? 'admin_${customRange.start.toString()}_${customRange.end.toString()}'
            : 'admin_$timeFrame';

    if (_adminCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _adminCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame, customRange);
      final endDate = _getEndDate(timeFrame, customRange);

      final results = await Future.wait([
        _getMessages(startDate, endDate, 'user'),
        _getMessages(startDate, endDate, 'bot'),
        _getUsers(startDate, endDate),
        _getEscalatedMessages(startDate, endDate),
        _getResolvedEscalatedMessages(startDate, endDate),
        _getAllEscalations(startDate, endDate),
        _getLogs(startDate, endDate),
        _getMessageLogs(startDate, endDate),
      ]);

      final data = _processAdminDashboardData(
        userMessages: results[0],
        botMessages: results[1],
        users: results[2],
        pendingEscalations: results[3],
        resolvedEscalations: results[4],
        allEscalations: results[5],
        systemLogs: results[6],
        messageLogs: results[7],
        startDate: startDate,
        endDate: endDate,
        timeFrame: timeFrame,
      );

      _adminCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching admin dashboard data: $e');
      return getEmptyAdminDashboardData();
    }
  }

  Future<StaffDashboardData> getStaffDashboardData(
    String staffId,
    String timeFrame, [
    DateTimeRange? customRange,
  ]) async {
    final cacheKey =
        timeFrame == 'Custom' && customRange != null
            ? 'staff_${staffId}_${customRange.start.toString()}_${customRange.end.toString()}'
            : 'staff_${staffId}_$timeFrame';

    if (_staffCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _staffCache[cacheKey]!;
    }

    try {
      final startDate = _getStartDate(timeFrame, customRange);
      final endDate = _getEndDate(timeFrame, customRange);

      final results = await Future.wait([
        _getMessages(startDate, endDate, 'user'),
        _getMessages(startDate, endDate, 'bot'),
        _getEscalatedMessages(startDate, endDate),
        _getResolvedEscalatedMessages(startDate, endDate),
        _getStaffEscalationsResponded(staffId, startDate, endDate),
        _getAllEscalations(startDate, endDate),
        _getMessageLogs(startDate, endDate),
      ]);

      final data = _processStaffDashboardData(
        userMessages: results[0],
        botMessages: results[1],
        pendingEscalations: results[2],
        resolvedEscalations: results[3],
        staffEscalationsResponded: results[4],
        allEscalations: results[5],
        messageLogs: results[6],
        startDate: startDate,
        endDate: endDate,
        timeFrame: timeFrame,
      );

      _staffCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching staff dashboard data: $e');
      return getEmptyStaffDashboardData();
    }
  }

  Future<List<QueryDocumentSnapshot>> _getMessages(
    DateTime startDate,
    DateTime? endDate,
    String sender,
  ) async {
    Query query = _firestore
        .collectionGroup('messages')
        .where('sender', isEqualTo: sender)
        .where(
          'sent_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'sent_at',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.orderBy('sent_at', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getTotalMessages(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collectionGroup('messages')
        .where(
          'sent_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'sent_at',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.orderBy('sent_at', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getEscalatedMessages(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('escalations')
        .where('status', isEqualTo: 'pending')
        .where(
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

  Future<List<QueryDocumentSnapshot>> _getResolvedEscalatedMessages(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('escalations')
        .where('status', isEqualTo: 'resolved')
        .where(
          'respondedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'respondedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.orderBy('respondedAt', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getAllEscalations(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('escalations')
        .where(
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

  Future<List<QueryDocumentSnapshot>> _getStaffResolutions(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('escalations')
        .where('status', isEqualTo: 'resolved')
        .where(
          'respondedAt', // Changed from 'resolvedAt'
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'respondedAt', // Changed from 'resolvedAt'
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.orderBy('respondedAt', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getStaffEscalationsResponded(
    String staffId,
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('escalations')
        .where('respondedBy', isEqualTo: staffId) // Changed from 'resolvedBy'
        .where(
          'respondedAt', // Changed from 'resolvedAt'
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'respondedAt', // Changed from 'resolvedAt'
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.orderBy('respondedAt', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getConversations(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('conversations')
        .where(
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

  Future<List<QueryDocumentSnapshot>> _getUsersWithLimitData(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore.collection('users');

    // Get all users, we'll filter by date in processing
    final snapshot = await query.get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getUnansweredMessages(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collectionGroup('messages')
        .where('sender', isEqualTo: 'user')
        .where('isAnswered', isEqualTo: false)
        .where(
          'sent_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'sent_at',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.orderBy('sent_at', descending: true).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getUsers(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('users')
        .where(
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

  Future<List<QueryDocumentSnapshot>> _getNewUsers(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('users')
        .where(
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

  Future<List<QueryDocumentSnapshot>> _getAllUsersWithTimestamps() async {
    final snapshot =
        await _firestore
            .collection('users')
            .orderBy('createdAt', descending: false)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getFAQs(
    DateTime startDate,
    DateTime? endDate, {
    bool fallbackToAllTime = false,
  }) async {
    if (fallbackToAllTime) {
      return _getTopFAQsAllTime();
    }

    Query query = _firestore
        .collection('faqs')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot =
        await query.orderBy('createdAt', descending: true).limit(5).get();

    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getLogs(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('logs')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));

    if (endDate != null) {
      query = query.where(
        'time',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot =
        await query.orderBy('time', descending: true).limit(10).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getMessageLogs(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('message_logs')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));

    if (endDate != null) {
      query = query.where(
        'time',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot =
        await query.orderBy('time', descending: true).limit(10).get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getTopFAQsAllTime() async {
    final snapshot =
        await _firestore
            .collection('faqs')
            .orderBy('similarityCount', descending: true)
            .limit(5)
            .get();

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

  Future<List<QueryDocumentSnapshot>> _getActiveUsers(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    Query query = _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .where(
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

Map<int, int> _generatePeakUsageByHour(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
) {
  final hourCounts = <int, int>{};

  // Initialize all 24 hours with 0
  for (int hour = 0; hour < 24; hour++) {
    hourCounts[hour] = 0;
  }

  for (final doc in conversations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp != null) {
      final date = timestamp.toDate();

      // Filter by date range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      final hour = date.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
  }

  return hourCounts;
}


  DateTime _getStartDate(String timeFrame, [DateTimeRange? customRange]) {
    if (timeFrame == 'Custom' && customRange != null) {
      return DateTime(
        customRange.start.year,
        customRange.start.month,
        customRange.start.day,
        0,
        0,
        0,
      );
    }

    final now = DateTime.now();
    return switch (timeFrame) {
      'All' => DateTime(2000, 1, 1),
      'Today' => DateTime(now.year, now.month, now.day, 0, 0, 0),
      'This Week' => _getStartOfWeek(now),
      'This Month' => DateTime(now.year, now.month, 1, 0, 0, 0),
      'This Year' => DateTime(now.year, 1, 1, 0, 0, 0),
      _ => DateTime(now.year, now.month, 1, 0, 0, 0),
    };
  }

  DateTime? _getEndDate(String timeFrame, [DateTimeRange? customRange]) {
    if (timeFrame == 'Custom' && customRange != null) {
      return DateTime(
        customRange.end.year,
        customRange.end.month,
        customRange.end.day,
        23,
        59,
        59,
        999,
      );
    }

    if (timeFrame == 'All') {
      return null; // No end date for "All"
    }

    // For other timeframes, set end date to now
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

 InquiryReportsData _processInquiryReportsData({
  required List<QueryDocumentSnapshot> totalMessages,
  required List<QueryDocumentSnapshot> userMessages,
  required List<QueryDocumentSnapshot> botMessages,
  required List<QueryDocumentSnapshot> escalations,
  required List<QueryDocumentSnapshot> resolvedEscalations,
  required List<QueryDocumentSnapshot> faqs,
  required List<QueryDocumentSnapshot> logs,
  required List<QueryDocumentSnapshot> msgLogs,
  required List<QueryDocumentSnapshot> allEscalations,
  required List<QueryDocumentSnapshot> staffResolutions,
  required DateTime startDate,
  DateTime? endDate,
  required String timeFrame,
}) {
  // Calculate stat cards
  final totalMessageCount = totalMessages.length;
  final userMessageCount = userMessages.length;
  final botMessageCount = botMessages.length;
  final escalatedCount = escalations.length;  // PENDING escalations
  final resolvedCount = resolvedEscalations.length;  // RESOLVED escalations
  final totalEscalations = allEscalations.length;  // ✅ TOTAL escalations (pending + resolved)

  // ✅ FIX: Calculate rates based on correct denominators
  final escalationRate =
      userMessageCount > 0 ? (totalEscalations / userMessageCount) * 100 : 0.0;
  
  // ✅ FIX: Resolution rate = resolved / total escalations (not pending)
  final resolutionRate =
      totalEscalations > 0 ? (resolvedCount / totalEscalations) * 100 : 0.0;

    // Category distribution
    final categoryDistribution = <String, int>{};
    for (final doc in userMessages) {
      final data = doc.data() as Map<String, dynamic>;
      final category = (data['category'] as String?)?.trim() ?? 'General';
      categoryDistribution[category] =
          (categoryDistribution[category] ?? 0) + 1;
    }

    // Top questions (FAQs) - Updated processing
    final topQuestions = <String, int>{};
    for (final doc in faqs) {
      final data = doc.data() as Map<String, dynamic>;
      final question = data['question'] as String? ?? 'Unknown';
      final count = data['similarityCount'] as int? ?? 1;
      topQuestions[question] = count;
    }

    // Sort and limit to top 5
    final sortedTopQuestions =
        Map.fromEntries(
          topQuestions.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        ).entries.take(5).toList();

    final finalTopQuestions = Map<String, int>.fromEntries(sortedTopQuestions);

    print('📊 Top Questions: ${finalTopQuestions.length} questions');

    // Inquiry trend
    final inquiryTrend = _generateInquiryTrend(
      userMessages,
      startDate,
      endDate,
      timeFrame,
    );

    final escalationsOverTime = _generateEscalationsTrend(
      allEscalations,
      startDate,
      endDate,
      timeFrame,
    );

    final staffPerformance = _calculateStaffPerformance(staffResolutions);

    int botAnswered = 0;
    int humanAnswered = 0;
    for (final doc in userMessages) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isAnswered'] == true) {
        if (data['answeredBy'] == 'bot' || data['answeredBy'] == null) {
          botAnswered++;
        } else {
          humanAnswered++;
        }
      }
    }

    final recentLogs =
        logs
            .map((doc) => SystemLog.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
    final messageLogs =
        msgLogs
            .map(
              (doc) => MessageLogs.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();

    return InquiryReportsData(
      totalMessages: totalMessageCount,
      userMessages: userMessageCount,
      botMessages: botMessageCount,
      escalatedMessages: escalatedCount,
      escalationRate: escalationRate,
      resolvedMessages: resolvedCount,
      resolutionRate: resolutionRate,
      inquiryTrend: inquiryTrend,
      categoryDistribution: categoryDistribution,
      topQuestions: finalTopQuestions, // Use the sorted and limited FAQs
      escalationsOverTime: escalationsOverTime,
      staffPerformance: staffPerformance,
      botVsHumanAnswers: {'bot': botAnswered, 'human': humanAnswered},
      allEscalations: allEscalations.length,
      recentLogs: recentLogs,
      msgLogs: messageLogs,
    );
  }

  // FIXED: Now uses cached userLookup instead of QuerySnapshot
ChatbotUsageReportsData _processChatbotUsageReportsData({
  required List<QueryDocumentSnapshot> conversations,
  required List<QueryDocumentSnapshot> messages,
  required List<QueryDocumentSnapshot> unansweredMessages,
  required List<QueryDocumentSnapshot> users,
  required DateTime startDate,
  DateTime? endDate,
  required String timeFrame,
}) {
  final actualEndDate = endDate ?? DateTime.now();
  final interval =
      timeFrame == 'Custom'
          ? _getDataGroupingInterval(startDate, actualEndDate)
          : timeFrame;

    // Calculate average response time
    double totalResponseTime = 0;
    int responseCount = 0;
    final responseTimeByDate = <String, List<double>>{};

    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      final responseTimeMs = data['responseTimeMs'];
      final sentAt = data['sent_at'] as Timestamp?;

      if (responseTimeMs != null &&
          responseTimeMs is num &&
          responseTimeMs > 0 &&
          sentAt != null) {
        final date = sentAt.toDate();

        // Skip if outside date range
        if (date.isBefore(startDate) || date.isAfter(actualEndDate)) continue;

        final responseTimeSeconds = responseTimeMs.toDouble() / 1000;
        if (responseTimeSeconds >= 0.1 && responseTimeSeconds <= 60) {
          totalResponseTime += responseTimeSeconds;
          responseCount++;

          final dateKey = _getTimeKeyForInterval(
            date,
            interval,
            startDate,
            actualEndDate,
          );
          responseTimeByDate.putIfAbsent(dateKey, () => []);
          responseTimeByDate[dateKey]!.add(responseTimeSeconds);
        }
      }
    }

    final averageResponseTime =
        responseCount > 0 ? totalResponseTime / responseCount : 0.0;

    // Calculate conversation metrics
    double totalConversationTime = 0;
    int completedConversations = 0;
    final userConversationCounts = <String, int>{};

    for (final doc in conversations) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String? ?? 'unknown';
      final createdAt = data['createdAt'] as Timestamp?;
      final endedAt = data['endedAt'] as Timestamp?;
      final status = data['status'] as String? ?? 'unknown';

      userConversationCounts[userId] =
          (userConversationCounts[userId] ?? 0) + 1;

      if (createdAt != null && endedAt != null && status == 'ended') {
        final duration = endedAt.toDate().difference(createdAt.toDate());
        if (duration.inSeconds >= 10 && duration.inSeconds <= 7200) {
          totalConversationTime += duration.inSeconds.toDouble();
          completedConversations++;
        }
      }
    }

    final averageConversationTime =
        completedConversations > 0
            ? totalConversationTime / completedConversations
            : 0.0;

    final averageMessagesPerUser =
        userConversationCounts.isNotEmpty
            ? conversations.length / userConversationCounts.length.toDouble()
            : 0.0;

    // NEW: Calculate limit reach rates
    final limitData = _calculateLimitReachRates(
      users,
      startDate,
      actualEndDate,
      timeFrame,
    );

    // Conversations over time
    final conversationsOverTime = _generateConversationsTrend(
      conversations,
      startDate,
      actualEndDate,
      interval,
    );

    // Peak usage - dynamically filtered by date range
     final peakUsageByHour = _generatePeakUsageByHour(conversations, startDate, actualEndDate);
  final peakUsageByDay = _generatePeakUsageByDay(
    conversations,
    startDate,
    actualEndDate,
  );
  final peakUsageByMonth = _generatePeakUsageByMonth(
    conversations,
    startDate,
    actualEndDate,
    timeFrame
  );
  
  // NEW: Add year and all-time peak usage
  final peakUsageByYear = _generatePeakUsageByYear(
    conversations,
    startDate,
    actualEndDate,
  );
  final peakUsageByAllYears = _generatePeakUsageByAllYears(
    conversations,
    startDate,
    actualEndDate,
  );

    // Response time trend
    final responseTimeTrend = _buildResponseTimeTrend(
      responseTimeByDate,
      interval,
      startDate,
      actualEndDate,
    );

    // Unanswered reasons
    final unansweredReasons = _processUnansweredReasons(unansweredMessages);

    return ChatbotUsageReportsData(
    averageResponseTime: averageResponseTime,
    totalConversations: conversations.length,
    averageMessagesPerUser: averageMessagesPerUser,
    averageConversationTime: averageConversationTime,
    chatLimitReachRate: limitData['chatLimitReachRate']!,
    escalationLimitReachRate: limitData['escalationLimitReachRate']!,
    conversationsOverTime: conversationsOverTime,
    peakUsageByHour: peakUsageByHour,
    peakUsageByDay: peakUsageByDay,
    peakUsageByMonth: peakUsageByMonth,
    peakUsageByYear: peakUsageByYear, // NEW
    peakUsageByAllYears: peakUsageByAllYears, // NEW
    responseTimeTrend: responseTimeTrend,
    unansweredReasonsDistribution: unansweredReasons,
    chatLimitReachTrend: limitData['chatLimitReachTrend']!,
    escalationLimitReachTrend: limitData['escalationLimitReachTrend']!,
  );
}

  UserDemographicsReportsData _processUserDemographicsReportsData({
    required List<QueryDocumentSnapshot> users,
    required List<QueryDocumentSnapshot> newUsers,
    required List<QueryDocumentSnapshot> activeUsers,
    required List<QueryDocumentSnapshot> messages,
    required List<QueryDocumentSnapshot> allUsersWithTimestamps,

    required DateTime startDate,
    DateTime? endDate,
    required String timeFrame,
  }) {
    final activeUserIds = <String>{};

    for (final doc in activeUsers) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['uid'] as String?;

      if (userId != null) {
        activeUserIds.add(userId);
      }
    }

    // Process demographic distributions using ALL users
    final usersByYear = <String, int>{};
    final usersByProgram = <String, int>{};
    final userAffiliations = <String, int>{};
    final scholarshipDistribution = <String, int>{};

    int enrolledStudents = 0;
    int incomingFreshmen = 0;
    int usersWithScholarship = 0;
    int usersWithoutScholarship = 0;

    // Process ALL users for demographic charts
    for (final doc in users) {
      // Changed from 'users' to 'allUsers'
      final data = doc.data() as Map<String, dynamic>;
      final uid = data['uid'] as String?;

      if (uid != null) {
        // Process year level
        final year = data['year'];
        if (year != null &&
            year.toString().trim().isNotEmpty &&
            year.toString().toLowerCase() != 'null') {
          final yearStr = year.toString();
          usersByYear[yearStr] = (usersByYear[yearStr] ?? 0) + 1;
        }

        // Process program
        final program = data['program'];
        if (program != null &&
            program.toString().trim().isNotEmpty &&
            program.toString().toLowerCase() != 'null') {
          final programStr = program.toString();
          usersByProgram[programStr] = (usersByProgram[programStr] ?? 0) + 1;
        }

        // Process affiliation
        final affiliation = data['affiliation'];
        if (affiliation != null &&
            affiliation.toString().trim().isNotEmpty &&
            affiliation.toString().toLowerCase() != 'null') {
          final affiliationStr = affiliation.toString();
          userAffiliations[affiliationStr] =
              (userAffiliations[affiliationStr] ?? 0) + 1;

          if (affiliationStr.toLowerCase() == 'incoming freshman applicant') {
            incomingFreshmen++;
          }
        }

        // Process scholarship - THIS IS THE KEY FIX
        final scholarship = data['scholarship'];
        print(
          'DEBUG: User ${data['name']}: scholarship = $scholarship',
        ); // Debug log

        if (scholarship != null &&
            scholarship.toString().trim().isNotEmpty &&
            scholarship.toString().toLowerCase() != 'null' &&
            scholarship.toString().toLowerCase() != 'n/a') {
          final scholarshipStr = scholarship.toString().trim();
          scholarshipDistribution[scholarshipStr] =
              (scholarshipDistribution[scholarshipStr] ?? 0) + 1;
          usersWithScholarship++;
          print(
            'DEBUG: Added scholarship: $scholarshipStr, count: ${scholarshipDistribution[scholarshipStr]}',
          ); // Debug log
        } else {
          usersWithoutScholarship++;
        }

        // Process enrolled status
        final isEnrolled = data['isEnrolled'] as bool? ?? false;
        if (isEnrolled) {
          enrolledStudents++;
        }
      }
    }

    print(
      'DEBUG: Final scholarshipDistribution: $scholarshipDistribution',
    ); // Debug log
    print(
      'DEBUG: usersWithScholarship: $usersWithScholarship, usersWithoutScholarship: $usersWithoutScholarship',
    ); // Debug log

    // User growth over time
    final userGrowthOverTime = _generateUserGrowthTrend(
      allUsersWithTimestamps,
      startDate,
      endDate,
      timeFrame,
    );

    // Calculate ratios based on timeframe-filtered users
    final totalActiveUsers = activeUserIds.length;
    final inactiveUsers = users.length - activeUserIds.length;
    final activeUserRatio =
        totalActiveUsers > 0 || inactiveUsers > 0
            ? '$totalActiveUsers : $inactiveUsers'
            : '0 : 0';

    final enrolledRatio =
        enrolledStudents > 0 || incomingFreshmen > 0
            ? '$enrolledStudents : $incomingFreshmen'
            : '0 : 0';

    return UserDemographicsReportsData(
      totalUsers: users.length, // Changed to show all users
      newUsers: newUsers.length,
      activeUsers: activeUserIds.length,
      inactiveUsers: users.length - activeUserIds.length, // Changed
      enrolledStudents: enrolledStudents,
      incomingFreshmen: incomingFreshmen,
      userAffiliations: userAffiliations,
      scholarshipDistribution: scholarshipDistribution,
      usersWithScholarship: usersWithScholarship,
      usersWithoutScholarship: usersWithoutScholarship,
      userGrowthOverTime: userGrowthOverTime,
      usersByYear: usersByYear,
      usersByProgram: usersByProgram,
      activeUserRatio: activeUserRatio,
      enrolledRatio: enrolledRatio,
    );
  }

  AdminDashboardData _processAdminDashboardData({
    required List<QueryDocumentSnapshot> userMessages,
    required List<QueryDocumentSnapshot> botMessages,
    required List<QueryDocumentSnapshot> users,
    required List<QueryDocumentSnapshot> pendingEscalations,
    required List<QueryDocumentSnapshot> resolvedEscalations,
    required List<QueryDocumentSnapshot> allEscalations,
    required List<QueryDocumentSnapshot> systemLogs,
    required List<QueryDocumentSnapshot> messageLogs,
    required DateTime startDate,
    DateTime? endDate,
    required String timeFrame,
  }) {
    final totalMessages = userMessages.length + botMessages.length;
    final escalationRate =
        userMessages.isNotEmpty
            ? (pendingEscalations.length / userMessages.length) * 100
            : 0.0;
    final totalEscalations =
        pendingEscalations.length + resolvedEscalations.length;
    final resolutionRate =
        totalEscalations > 0
            ? (resolvedEscalations.length / totalEscalations) * 100
            : 0.0;

    // Inquiry trend
    final inquiryTrend = _generateInquiryTrend(
      userMessages,
      startDate,
      endDate,
      timeFrame,
    );

    // // Top escalated messages
    // final topEscalations =
    //     pendingEscalations.take(5).map((doc) {
    //       final data = doc.data() as Map<String, dynamic>;
    //       return EscalatedMessage.fromMap(data);
    //     }).toList();
    final topEscalations =
        pendingEscalations.take(5).map((doc) {
          print('📝 Mapping escalation: ${doc.id}'); // DEBUG
          return EscalatedMessage.fromMap(doc.data() as Map<String, dynamic>);
        }).toList();

    print('✅ Total top escalations: ${topEscalations.length}'); // DEBUG

    // Escalations over time
    final escalationsOverTime = _generateEscalationsTrend(
      allEscalations,
      startDate,
      endDate,
      timeFrame,
    );

    final msgLogs =
        messageLogs.map((doc) {
          return MessageLogs.fromMap(doc.data() as Map<String, dynamic>);
        }).toList();

    final logs =
        systemLogs.map((doc) {
          return SystemLog.fromMap(doc.data() as Map<String, dynamic>);
        }).toList();

    return AdminDashboardData(
      totalMessages: totalMessages,
      totalUsers: users.length,
      pendingEscalations: pendingEscalations.length,
      resolvedEscalations: resolvedEscalations.length,
      escalationRate: escalationRate,
      resolutionRate: resolutionRate,
      inquiryTrend: inquiryTrend,
      topEscalatedMessages: topEscalations,
      escalationsOverTime: escalationsOverTime,
      systemLogs: logs,
      messageLogs: msgLogs,
    );
  }

  StaffDashboardData _processStaffDashboardData({
    required List<QueryDocumentSnapshot> userMessages,
    required List<QueryDocumentSnapshot> botMessages,
    required List<QueryDocumentSnapshot> pendingEscalations,
    required List<QueryDocumentSnapshot> resolvedEscalations,
    required List<QueryDocumentSnapshot> staffEscalationsResponded,
    required List<QueryDocumentSnapshot> allEscalations,
    required List<QueryDocumentSnapshot> messageLogs,
    required DateTime startDate,
    DateTime? endDate,
    required String timeFrame,
  }) {
    final totalMessages = userMessages.length + botMessages.length;
    final escalationRate =
        userMessages.isNotEmpty
            ? (pendingEscalations.length / userMessages.length) * 100
            : 0.0;
    final totalEscalations =
        pendingEscalations.length + resolvedEscalations.length;
    final resolutionRate =
        totalEscalations > 0
            ? (resolvedEscalations.length / totalEscalations) * 100
            : 0.0;

    // Inquiry trend
    final inquiryTrend = _generateInquiryTrend(
      userMessages,
      startDate,
      endDate,
      timeFrame,
    );

    // Top escalated messages
    final topEscalations =
        pendingEscalations.take(5).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return EscalatedMessage.fromMap(data);
        }).toList();

    // Escalations over time
    final escalationsOverTime = _generateEscalationsTrend(
      allEscalations,
      startDate,
      endDate,
      timeFrame,
    );

    // Message logs
    final logs =
        messageLogs.map((doc) {
          return MessageLogs.fromMap(doc.data() as Map<String, dynamic>);
        }).toList();

    return StaffDashboardData(
      totalMessages: totalMessages,
      pendingEscalations: pendingEscalations.length,
      resolvedEscalations: resolvedEscalations.length,
      escalationsResponded: staffEscalationsResponded.length,
      escalationRate: escalationRate,
      resolutionRate: resolutionRate,
      inquiryTrend: inquiryTrend,
      topEscalatedMessages: topEscalations,
      escalationsOverTime: escalationsOverTime,
      messageLogs: logs,
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
    // Monday = 1, Sunday = 7
    final daysFromMonday = date.weekday - 1;
    final startOfWeek = DateTime(
      date.year,
      date.month,
      date.day,
      0,
      0,
      0,
    ).subtract(Duration(days: daysFromMonday));

    print(
      '🗓️ Start of week for $date: $startOfWeek (weekday: ${date.weekday})',
    );

    return startOfWeek;
  }

  Future<Map<String, int>> getQuickStats(
    String timeFrame, [
    DateTimeRange? customRange,
  ]) async {
    final startDate = _getStartDate(timeFrame, customRange);
    final endDate = _getEndDate(timeFrame, customRange);

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
        messagesQuery = messagesQuery.where(
          'sent_at',
          isLessThanOrEqualTo: endDate,
        );
        answeredQuery = answeredQuery.where(
          'sent_at',
          isLessThanOrEqualTo: endDate,
        );
        answeredQuery = answeredQuery.where(
          'sent_at',
          isLessThanOrEqualTo: endDate,
        );
      }

      final messagesSnapshot =
          await messagesQuery
              .where("sent_at", isLessThanOrEqualTo: endDate)
              .count()
              .get();
      final answeredSnapshot =
          await answeredQuery
              .where('sent_at', isLessThanOrEqualTo: endDate)
              .count()
              .get();
      final usersSnapshot =
          await _firestore
              .collection('users')
              .where("createdAt", isGreaterThanOrEqualTo: startDate)
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

  Map<String, dynamic> _calculateLimitReachRates(
    List<QueryDocumentSnapshot> users,
    DateTime startDate,
    DateTime endDate,
    String timeFrame,
  ) {
    const int DAILY_MESSAGE_LIMIT = 5; // Adjust based on your limit
    const int DAILY_ESCALATION_LIMIT = 2; // Adjust based on your limit

    int totalActiveUsers = 0;
    int usersHitMessageLimit = 0;
    int usersHitEscalationLimit = 0;

    final messageLimitByTime = <String, int>{};
    final escalationLimitByTime = <String, int>{};
    final interval =
        timeFrame == 'Custom'
            ? _getDataGroupingInterval(startDate, endDate)
            : timeFrame;

    for (final doc in users) {
      final data = doc.data() as Map<String, dynamic>;
      final dailyMessageCount = data['dailyMessageCount'] as int? ?? 0;
      final dailyEscalationCount = data['dailyEscalationCount'] as int? ?? 0;
      final lastMessageResetDate = data['lastMessageResetDate'] as Timestamp?;
      final lastEscalationResetDate =
          data['lastEscalationResetDate'] as Timestamp?;

      // Check if user was active in the selected period
      bool activeInPeriod = false;
      DateTime? activityDate;

      if (lastMessageResetDate != null) {
        final resetDate = lastMessageResetDate.toDate();
        if (resetDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            resetDate.isBefore(endDate.add(const Duration(seconds: 1)))) {
          activeInPeriod = true;
          activityDate = resetDate;
        }
      }

      if (lastEscalationResetDate != null && !activeInPeriod) {
        final resetDate = lastEscalationResetDate.toDate();
        if (resetDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            resetDate.isBefore(endDate.add(const Duration(seconds: 1)))) {
          activeInPeriod = true;
          activityDate = resetDate;
        }
      }

      if (!activeInPeriod) continue;

      totalActiveUsers++;

      // Check if user hit message limit
      if (dailyMessageCount >= DAILY_MESSAGE_LIMIT) {
        usersHitMessageLimit++;
        if (activityDate != null) {
          final timeKey = _getTimeKeyForInterval(
            activityDate,
            interval,
            startDate,
            endDate,
          );
          messageLimitByTime[timeKey] = (messageLimitByTime[timeKey] ?? 0) + 1;
        }
      }

      // Check if user hit escalation limit
      if (dailyEscalationCount >= DAILY_ESCALATION_LIMIT) {
        usersHitEscalationLimit++;
        if (activityDate != null) {
          final timeKey = _getTimeKeyForInterval(
            activityDate,
            interval,
            startDate,
            endDate,
          );
          escalationLimitByTime[timeKey] =
              (escalationLimitByTime[timeKey] ?? 0) + 1;
        }
      }
    }

    final chatLimitReachRate =
        totalActiveUsers > 0
            ? (usersHitMessageLimit / totalActiveUsers) * 100
            : 0.0;
    final escalationLimitReachRate =
        totalActiveUsers > 0
            ? (usersHitEscalationLimit / totalActiveUsers) * 100
            : 0.0;

    // Generate trend data
    final chatLimitReachTrend = _generateSimpleTrendData(
      startDate,
      endDate,
      interval,
      messageLimitByTime,
    );

    final escalationLimitReachTrend = _generateSimpleTrendData(
      startDate,
      endDate,
      interval,
      escalationLimitByTime,
    );

    return {
      'chatLimitReachRate': chatLimitReachRate,
      'escalationLimitReachRate': escalationLimitReachRate,
      'chatLimitReachTrend': chatLimitReachTrend,
      'escalationLimitReachTrend': escalationLimitReachTrend,
    };
  }
  // ✅ NEW METHOD: Build response time trend
  // List<ChartData> _buildResponseTimeTrend(
  //   Map<String, List<double>> responseTimeByDate,
  //   String timeFrame,
  //   DateTime startDate,
  //   DateTime endDate,
  // ) {
  //   if (responseTimeByDate.isEmpty) {
  //     return [];
  //   }

  //   final now = DateTime.now();
  //   final trendData = <ChartData>[];

  //   switch (timeFrame) {
  //     case 'Today':
  //       // Generate all 24 hours
  //       for (int hour = 0; hour < 24; hour++) {
  //         final hourKey = "${hour.toString().padLeft(2, '0')}:00";
  //         final times = responseTimeByDate[hourKey] ?? [];

  //         if (times.isNotEmpty) {
  //           final average = times.reduce((a, b) => a + b) / times.length;
  //           trendData.add(
  //             ChartData(
  //               date: hourKey,
  //               count:
  //                   (average * 100)
  //                       .round(), // Store as centiseconds for precision
  //             ),
  //           );
  //         } else {
  //           trendData.add(ChartData(date: hourKey, count: 0));
  //         }
  //       }
  //       break;

  //     case 'This Week':
  //       // Generate all 7 days of the week with day names
  //       final startOfWeek = _getStartOfWeek(now);
  //       final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  //       for (int i = 0; i < 7; i++) {
  //         final date = startOfWeek.add(Duration(days: i));
  //         final dateKey =
  //             "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  //         final displayKey = dayNames[i]; // Use day name instead of date
  //         final times = responseTimeByDate[dateKey] ?? [];

  //         if (times.isNotEmpty) {
  //           final average = times.reduce((a, b) => a + b) / times.length;
  //           trendData.add(
  //             ChartData(date: displayKey, count: (average * 100).round()),
  //           );
  //         } else {
  //           trendData.add(ChartData(date: displayKey, count: 0));
  //         }
  //       }
  //       break;

  //     case 'This Month':
  //       // Generate all weeks of the month
  //       for (int week = 1; week <= 5; week++) {
  //         final weekKey = "Week $week";
  //         final times = responseTimeByDate[weekKey] ?? [];

  //         if (times.isNotEmpty) {
  //           final average = times.reduce((a, b) => a + b) / times.length;
  //           trendData.add(
  //             ChartData(date: weekKey, count: (average * 100).round()),
  //           );
  //         } else {
  //           trendData.add(ChartData(date: weekKey, count: 0));
  //         }
  //       }
  //       break;

  //     case 'This Year':
  //     default:
  //       // Generate all 12 months
  //       final monthNames = [
  //         'Jan',
  //         'Feb',
  //         'Mar',
  //         'Apr',
  //         'May',
  //         'Jun',
  //         'Jul',
  //         'Aug',
  //         'Sep',
  //         'Oct',
  //         'Nov',
  //         'Dec',
  //       ];
  //       for (int month = 1; month <= 12; month++) {
  //         final monthKey = "${now.year}-${month.toString().padLeft(2, '0')}";
  //         final times = responseTimeByDate[monthKey] ?? [];

  //         if (times.isNotEmpty) {
  //           final average = times.reduce((a, b) => a + b) / times.length;
  //           trendData.add(
  //             ChartData(
  //               date: monthNames[month - 1],
  //               count: (average * 100).round(),
  //             ),
  //           );
  //         } else {
  //           trendData.add(ChartData(date: monthNames[month - 1], count: 0));
  //         }
  //       }
  //       break;
  //   }

  //   return trendData;
  // }

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
              final timeKey = _getTimeKeyForInterval(
                date,
                interval,
                startDate,
                endDate,
              );
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
              if (date.isAfter(
                    startOfWeek.subtract(const Duration(seconds: 1)),
                  ) &&
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
                weeklyCounts[weekOfMonth] =
                    (weeklyCounts[weekOfMonth] ?? 0) + 1;
              }
            }
          }
          return List.generate(5, (week) {
            final weekNumber = week + 1;
            final weekKey = "Week $weekNumber";
            return ChartData(
              date: weekKey,
              count: weeklyCounts[weekNumber] ?? 0,
            );
          });

        case 'This Year':
        default:
          final monthlyCounts = <int, int>{};
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

          for (final doc in sessions) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['createdAt'];
            if (timestamp is Timestamp) {
              final date = timestamp.toDate();
              if (date.year == now.year) {
                monthlyCounts[date.month] =
                    (monthlyCounts[date.month] ?? 0) + 1;
              }
            }
          }

          return List.generate(12, (i) {
            final month = i + 1;
            return ChartData(
              date: monthNames[i],
              count: monthlyCounts[month] ?? 0,
            );
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
          dataPoints.add(
            ChartData(date: hourKey, count: dataCounts[hourKey] ?? 0),
          );
        }
        break;

      case 'daily':
        // Generate all days in the range
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        var currentDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final end = DateTime(endDate.year, endDate.month, endDate.day);

        while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
          final dateKey =
              "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
          final displayKey = dayNames[currentDate.weekday - 1];

          dataPoints.add(
            ChartData(date: displayKey, count: dataCounts[dateKey] ?? 0),
          );

          currentDate = currentDate.add(const Duration(days: 1));
        }
        break;

      case 'weekly':
        // Generate all weeks in the range
        final daysDiff = endDate.difference(startDate).inDays;
        final weeksCount = (daysDiff / 7).ceil();

        for (int week = 1; week <= weeksCount; week++) {
          final weekKey = "Week $week";
          dataPoints.add(
            ChartData(date: weekKey, count: dataCounts[weekKey] ?? 0),
          );
        }
        break;

      case 'monthly':
        // Generate all months in the range
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

        var currentMonth = DateTime(startDate.year, startDate.month);
        final endMonth = DateTime(endDate.year, endDate.month);

        while (currentMonth.isBefore(endMonth.add(const Duration(days: 32))) ||
            currentMonth.month == endMonth.month &&
                currentMonth.year == endDate.year) {
          final monthKey =
              "${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}";
          final displayKey = monthNames[currentMonth.month - 1];

          dataPoints.add(
            ChartData(date: displayKey, count: dataCounts[monthKey] ?? 0),
          );

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

List<ChartData> _generateInquiryTrend(
  List<QueryDocumentSnapshot> messages,
  DateTime startDate,
  DateTime? endDate,
  String timeFrame,
) {
  final actualEndDate = endDate ?? DateTime.now();
  final timeCategoryCounts = <String, Map<String, int>>{};
  final interval =
      timeFrame == 'Custom'
          ? _getDataGroupingInterval(startDate, actualEndDate)
          : timeFrame;

  print('📊 _generateInquiryTrend: timeFrame=$timeFrame, interval=$interval');
  print('📊 Date range: $startDate to $actualEndDate');
  print('📊 Total messages to process: ${messages.length}');

  int processedCount = 0;
  int filteredCount = 0;

  // Process messages
  for (final doc in messages) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['sent_at'] as Timestamp?;
    if (timestamp == null) continue;

    final date = timestamp.toDate();

    // Filter by date range
    if (date.isBefore(startDate) || date.isAfter(actualEndDate)) {
      filteredCount++;
      continue;
    }

    processedCount++;
    final timeKey = _getTimeKeyForInterval(
      date,
      interval,
      startDate,
      actualEndDate,
    );
    final category = (data['category'] as String?)?.trim() ?? 'General';

    timeCategoryCounts.putIfAbsent(timeKey, () => {});
    timeCategoryCounts[timeKey]![category] =
        (timeCategoryCounts[timeKey]![category] ?? 0) + 1;
  }

  print('📊 Processed: $processedCount, Filtered out: $filteredCount');
  print('📊 Time keys with data: ${timeCategoryCounts.keys.toList()}');

  return _generateTrendData(
    startDate,
    actualEndDate,
    interval,
    timeCategoryCounts,
  );
}

List<ChartData> _generateEscalationsTrend(
  List<QueryDocumentSnapshot> escalations,
  DateTime startDate,
  DateTime? endDate,
  String timeFrame,
) {
  final timeCategoryCounts = <String, Map<String, int>>{};
  final interval =
      timeFrame == 'Custom' && endDate != null
          ? _getDataGroupingInterval(startDate, endDate)
          : timeFrame;

  for (final doc in escalations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp == null) continue;

    final date = timestamp.toDate();
    if (endDate != null && date.isAfter(endDate)) continue;

    final timeKey = _getTimeKeyForInterval(date, interval, startDate, endDate);
    final category = (data['category'] as String?)?.trim() ?? 'General';

    timeCategoryCounts.putIfAbsent(timeKey, () => {});
    timeCategoryCounts[timeKey]![category] =
        (timeCategoryCounts[timeKey]![category] ?? 0) + 1;
  }

  return _generateTrendData(startDate, endDate, interval, timeCategoryCounts);
}

List<ChartData> _generateConversationsTrend(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
  String interval,
) {
  final timeCounts = <String, int>{};

  for (final doc in conversations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp == null) continue;

    final date = timestamp.toDate();

    // ✅ Already has filtering - good!
    if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

    final timeKey = _getTimeKeyForInterval(date, interval, startDate, endDate);
    timeCounts[timeKey] = (timeCounts[timeKey] ?? 0) + 1;
  }

  return _generateSimpleTrendData(startDate, endDate, interval, timeCounts);
}

// 5. FIX: _buildResponseTimeTrend - Ensure proper data structure
List<ChartData> _buildResponseTimeTrend(
  Map<String, List<double>> responseTimeByDate,
  String interval,
  DateTime startDate,
  DateTime endDate,
) {
  final trendData = <ChartData>[];

  print('📈 _buildResponseTimeTrend: interval=$interval');
  print('📈 Response time data keys: ${responseTimeByDate.keys.toList()}');

  switch (interval) {
    case 'hourly':
    case 'Today':
      // Generate all 24 hours
      for (int hour = 0; hour < 24; hour++) {
        final hourKey = "${hour.toString().padLeft(2, '0')}:00";
        final times = responseTimeByDate[hourKey] ?? [];
        final avgTime =
            times.isNotEmpty
                ? (times.reduce((a, b) => a + b) / times.length) * 100
                : 0.0;

        trendData.add(ChartData(date: hourKey, count: avgTime.round()));
      }
      break;

    case 'daily':
    case 'This Week':
      // Map full date keys to day names
      final startOfWeek = _getStartOfWeek(endDate);
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateKey =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        final dayName = dayNames[i];

        // Get response times for this date
        final times = responseTimeByDate[dateKey] ?? [];
        final avgTime =
            times.isNotEmpty
                ? (times.reduce((a, b) => a + b) / times.length) * 100
                : 0.0;

        print(
          '📈 $dayName ($dateKey): ${times.length} samples, avg=${avgTime / 100}s',
        );

        trendData.add(ChartData(date: dayName, count: avgTime.round()));
      }
      break;

    case 'weekly':
    case 'This Month':
      // Generate 5 weeks
      for (int week = 1; week <= 5; week++) {
        final weekKey = "Week $week";
        final times = responseTimeByDate[weekKey] ?? [];
        final avgTime =
            times.isNotEmpty
                ? (times.reduce((a, b) => a + b) / times.length) * 100
                : 0.0;

        trendData.add(ChartData(date: weekKey, count: avgTime.round()));
      }
      break;

    case 'monthly':
    case 'This Year':
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
      final currentYear = endDate.year;

      for (int month = 1; month <= 12; month++) {
        final monthKey = "$currentYear-${month.toString().padLeft(2, '0')}";
        final monthName = monthNames[month - 1];

        final times = responseTimeByDate[monthKey] ?? [];
        final avgTime =
            times.isNotEmpty
                ? (times.reduce((a, b) => a + b) / times.length) * 100
                : 0.0;

        print(
          '📈 $monthName ($monthKey): ${times.length} samples, avg=${avgTime / 100}s',
        );

        trendData.add(ChartData(date: monthName, count: avgTime.round()));
      }
      break;

    case 'All':
      // Generate all years
      final startYear = startDate.year;
      final endYear = endDate.year;

      for (int year = startYear; year <= endYear; year++) {
        final yearKey = year.toString();
        final times = responseTimeByDate[yearKey] ?? [];
        final avgTime =
            times.isNotEmpty
                ? (times.reduce((a, b) => a + b) / times.length) * 100
                : 0.0;

        trendData.add(ChartData(date: yearKey, count: avgTime.round()));
      }
      break;
  }

  print('📈 Generated ${trendData.length} response time data points');
  return trendData;
}

List<ChartData> _generateUserGrowthTrend(
  List<QueryDocumentSnapshot> users,
  DateTime startDate,
  DateTime? endDate,
  String timeFrame,
) {
  final actualEndDate = endDate ?? DateTime.now();
  final interval =
      timeFrame == 'Custom'
          ? _getDataGroupingInterval(startDate, actualEndDate)
          : timeFrame;

  // Sort users by creation date
  final sortedUsers =
      users.toList()..sort((a, b) {
        final aTime =
            (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final bTime =
            (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

  final timeCounts = <String, int>{};

  // Generate all time keys first
  final allKeys = _generateAllTimeKeys(startDate, actualEndDate, interval);

  // Initialize all keys with 0
  for (final key in allKeys) {
    timeCounts[key] = 0;
  }

  // Calculate cumulative counts
  int cumulativeCount = 0;
  for (final doc in sortedUsers) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp == null) continue;

    final date = timestamp.toDate();

    // ✅ FIX: Only count users within the date range
    if (date.isBefore(startDate) || date.isAfter(actualEndDate)) continue;

    cumulativeCount++;
    final timeKey = _getTimeKeyForInterval(
      date,
      interval,
      startDate,
      actualEndDate,
    );

    // Update this key and all subsequent keys with cumulative count
    bool foundKey = false;
    for (final key in allKeys) {
      if (key == timeKey) foundKey = true;
      if (foundKey) {
        timeCounts[key] = cumulativeCount;
      }
    }
  }

  return _generateSimpleTrendData(
    startDate,
    actualEndDate,
    interval,
    timeCounts,
  );
}

// Replace the existing _calculateStaffPerformance function with this:

Map<String, double> _calculateStaffPerformance(
  List<QueryDocumentSnapshot> staffResolutions,
) {
  if (staffResolutions.isEmpty) {
    return {};
  }

  final staffStats = <String, List<double>>{};
  final staffResolutionCounts = <String, int>{};

  for (final doc in staffResolutions) {
    final data = doc.data() as Map<String, dynamic>;
    final staffName =
        data['respondedBy'] as String? ??
        'Unknown'; // Changed from 'resolvedBy'
    final createdAt = data['createdAt'] as Timestamp?;
    final respondedAt =
        data['respondedAt'] as Timestamp?; // Changed from 'resolvedAt'

    if (createdAt != null && respondedAt != null) {
      final responseTime = respondedAt.toDate().difference(createdAt.toDate());
      final hours = responseTime.inHours.toDouble();

      // Only count valid response times (between 1 minute and 7 days)
      if (hours >= 0.0166 && hours <= 168) {
        // 1 min to 7 days
        staffStats.putIfAbsent(staffName, () => []);
        staffStats[staffName]!.add(hours);

        staffResolutionCounts[staffName] =
            (staffResolutionCounts[staffName] ?? 0) + 1;
      }
    }
  }

  if (staffResolutionCounts.isEmpty) {
    return {};
  }

  // Calculate performance as percentage of total resolutions
  final totalResolutions = staffResolutionCounts.values.reduce((a, b) => a + b);
  final staffPerformance = <String, double>{};

  staffResolutionCounts.forEach((staff, count) {
    // Performance = (staff's resolutions / total resolutions) * 100
    staffPerformance[staff] = (count / totalResolutions) * 100;
  });

  return staffPerformance;
}

// 5. ALTERNATIVE: Performance based on speed + volume
Map<String, double> _calculateStaffPerformanceWithSpeed(
  List<QueryDocumentSnapshot> staffResolutions,
) {
  if (staffResolutions.isEmpty) {
    return {};
  }

  final staffStats = <String, List<double>>{};
  final staffResolutionCounts = <String, int>{};

  for (final doc in staffResolutions) {
    final data = doc.data() as Map<String, dynamic>;
    final staffName = data['respondedBy'] as String? ?? 'Unknown';
    final createdAt = data['createdAt'] as Timestamp?;
    final respondedAt = data['respondedAt'] as Timestamp?;

    if (createdAt != null && respondedAt != null) {
      final responseTime = respondedAt.toDate().difference(createdAt.toDate());
      final hours = responseTime.inHours.toDouble();

      if (hours >= 0.0166 && hours <= 168) {
        staffStats.putIfAbsent(staffName, () => []);
        staffStats[staffName]!.add(hours);

        staffResolutionCounts[staffName] =
            (staffResolutionCounts[staffName] ?? 0) + 1;
      }
    }
  }

  if (staffResolutionCounts.isEmpty) {
    return {};
  }

  final totalResolutions = staffResolutionCounts.values.reduce((a, b) => a + b);
  final staffPerformance = <String, double>{};

  staffStats.forEach((staff, times) {
    final count = staffResolutionCounts[staff] ?? 0;
    final avgTime = times.reduce((a, b) => a + b) / times.length;

    // Base score: percentage of resolutions handled
    final volumeScore = (count / totalResolutions) * 100;

    // Speed bonus/penalty
    // Faster than 1 hour = bonus, slower than 24 hours = penalty
    double speedModifier = 0;
    if (avgTime < 1) {
      speedModifier = 10; // Fast response bonus
    } else if (avgTime > 24) {
      speedModifier = -10; // Slow response penalty
    }

    staffPerformance[staff] = (volumeScore + speedModifier).clamp(0, 100);
  });

  return staffPerformance;
}

Map<int, int> _generatePeakUsageByHour(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
) {
  final hourCounts = <int, int>{};

  for (final doc in conversations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp != null) {
      final date = timestamp.toDate();

      // Filter by date range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      final hour = date.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
  }

  return hourCounts;
}

// UPDATED: Generate peak usage by day - filtered by date range
Map<String, int> _generatePeakUsageByDay(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
) {
  final dayCounts = <String, int>{};
  final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Initialize all days with 0
  for (final dayName in dayNames) {
    dayCounts[dayName] = 0;
  }

  for (final doc in conversations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp != null) {
      final date = timestamp.toDate();

      // Filter by date range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      final dayName = dayNames[date.weekday - 1];
      dayCounts[dayName] = (dayCounts[dayName] ?? 0) + 1;
    }
  }

  return dayCounts;
}


Map<String, int> _generatePeakUsageByYear(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
) {
  final monthCounts = <String, int>{};
  final monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // Initialize all months with 0
  for (final monthName in monthNames) {
    monthCounts[monthName] = 0;
  }

  // Count conversations for each month within the target year
  for (final doc in conversations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp != null) {
      final date = timestamp.toDate();

      // Filter by date range AND ensure it's within the start year
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;
      
      // Only count if within the same year as startDate
      if (date.year == startDate.year) {
        final monthName = monthNames[date.month - 1];
        monthCounts[monthName] = (monthCounts[monthName] ?? 0) + 1;
      }
    }
  }

  print('📊 Peak Usage by Year (${startDate.year}): $monthCounts');
  return monthCounts;
}


// Generate peak usage by all years
Map<String, int> _generatePeakUsageByAllYears(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
) {
  final yearCounts = <String, int>{};

  // Ensure all years in range are present (even with 0 count)
  final startYear = startDate.year;
  final endYear = endDate.year;
  
  for (int year = startYear; year <= endYear; year++) {
    yearCounts[year.toString()] = 0;
  }

  // Count conversations for each year
  for (final doc in conversations) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    if (timestamp != null) {
      final date = timestamp.toDate();

      // Filter by date range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      final yearKey = date.year.toString();
      yearCounts[yearKey] = (yearCounts[yearKey] ?? 0) + 1;
    }
  }

  // Sort by year
  final sortedYears = yearCounts.keys.toList()..sort();
  final sortedCounts = <String, int>{};
  for (final year in sortedYears) {
    sortedCounts[year] = yearCounts[year]!;
  }

  print('📊 Peak Usage by All Years: $sortedCounts');
  return sortedCounts;
}

// UPDATED: Generate peak usage by month - filtered by date range
Map<String, int> _generatePeakUsageByMonth(
  List<QueryDocumentSnapshot> conversations,
  DateTime startDate,
  DateTime endDate,
  String timeFrame,
) {
  final monthCounts = <String, int>{};
  
  // Determine if we should show weeks or months
  final daysDiff = endDate.difference(startDate).inDays;
  final showWeeks = timeFrame == 'This Month' || daysDiff <= 31;

  if (showWeeks) {
    // Initialize weeks
    for (int week = 1; week <= 5; week++) {
      monthCounts['Week $week'] = 0;
    }

    // Count by week of month
    for (final doc in conversations) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();

        // Filter by date range
        if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

        final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
        final weekKey = 'Week $weekOfMonth';
        monthCounts[weekKey] = (monthCounts[weekKey] ?? 0) + 1;
      }
    }
  } else {
    // Initialize all 12 months
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    for (final monthName in monthNames) {
      monthCounts[monthName] = 0;
    }

    // Count by month
    for (final doc in conversations) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();

        // Filter by date range
        if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

        final monthName = monthNames[date.month - 1];
        monthCounts[monthName] = (monthCounts[monthName] ?? 0) + 1;
      }
    }
  }

  return monthCounts;
}

Map<String, int> _processUnansweredReasons(
  List<QueryDocumentSnapshot> unansweredMessages,
) {
  final reasons = <String, int>{};

  for (final doc in unansweredMessages) {
    final data = doc.data() as Map<String, dynamic>;
    final reason = data['unansweredReason'] as String? ?? 'Unknown';
    reasons[reason] = (reasons[reason] ?? 0) + 1;
  }

  return reasons;
}

List<ChartData> _generateTrendData(
  DateTime startDate,
  DateTime? endDate,
  String interval,
  Map<String, Map<String, int>> timeCategoryCounts,
) {
  final actualEndDate = endDate ?? DateTime.now();
  final trendData = <ChartData>[];

  print(
    '🔍 _generateTrendData: interval=$interval, startDate=$startDate, endDate=$actualEndDate',
  );
  print('🔍 Data keys: ${timeCategoryCounts.keys.toList()}');

  switch (interval) {
    case 'hourly':
    case 'Today':
      // Generate all 24 hours
      for (int hour = 0; hour < 24; hour++) {
        final hourKey = "${hour.toString().padLeft(2, '0')}:00";
        final categoryBreakdown =
            timeCategoryCounts[hourKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        trendData.add(
          ChartData(
            date: hourKey,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;

    case 'daily':
    case 'This Week':
      // ✅ CRITICAL FIX: Properly map dates to day names
      final startOfWeek = _getStartOfWeek(
        actualEndDate,
      ); // Use current date's week
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      print('🔍 Week start: $startOfWeek');

      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateKey =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        final dayName = dayNames[i];

        final categoryBreakdown =
            timeCategoryCounts[dateKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        print('🔍 Day $dayName ($dateKey): count=$totalCount');

        trendData.add(
          ChartData(
            date: dayName,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;

    case 'weekly':
    case 'This Month':
      // Generate 5 weeks
      for (int week = 1; week <= 5; week++) {
        final weekKey = "Week $week";
        final categoryBreakdown =
            timeCategoryCounts[weekKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        trendData.add(
          ChartData(
            date: weekKey,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;

    case 'monthly':
    case 'This Year':
      // ✅ CRITICAL FIX: Generate all 12 months and map data correctly
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
      final currentYear = actualEndDate.year;

      print('🔍 Generating months for year: $currentYear');

      for (int month = 1; month <= 12; month++) {
        final monthKey = "$currentYear-${month.toString().padLeft(2, '0')}";
        final monthName = monthNames[month - 1];

        final categoryBreakdown =
            timeCategoryCounts[monthKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        print(
          '🔍 Month $monthName ($monthKey): count=$totalCount, data=${categoryBreakdown}',
        );

        trendData.add(
          ChartData(
            date: monthName,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;

    case 'All':
      // Generate all years
      final startYear = startDate.year;
      final endYear = actualEndDate.year;

      for (int year = startYear; year <= endYear; year++) {
        final yearKey = year.toString();
        final categoryBreakdown =
            timeCategoryCounts[yearKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        trendData.add(
          ChartData(
            date: yearKey,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;
  }

  print('🔍 Generated ${trendData.length} data points');
  return trendData;
}

List<ChartData> _generateSimpleTrendData(
  DateTime startDate,
  DateTime? endDate,
  String interval,
  Map<String, int> timeCounts,
) {
  final actualEndDate = endDate ?? DateTime.now();
  final trendData = <ChartData>[];

  print('📈 _generateSimpleTrendData: interval=$interval');
  print('📈 Data keys: ${timeCounts.keys.toList()}');

  switch (interval) {
    case 'hourly':
    case 'Today':
      for (int hour = 0; hour < 24; hour++) {
        final hourKey = "${hour.toString().padLeft(2, '0')}:00";
        trendData.add(
          ChartData(date: hourKey, count: timeCounts[hourKey] ?? 0),
        );
      }
      break;

    case 'daily':
    case 'This Week':
      final startOfWeek = _getStartOfWeek(actualEndDate);
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateKey =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        final dayName = dayNames[i];

        final count = timeCounts[dateKey] ?? 0;
        print('📈 $dayName ($dateKey): $count');

        trendData.add(ChartData(date: dayName, count: count));
      }
      break;

    case 'weekly':
    case 'This Month':
      for (int week = 1; week <= 5; week++) {
        final weekKey = "Week $week";
        trendData.add(
          ChartData(date: weekKey, count: timeCounts[weekKey] ?? 0),
        );
      }
      break;

    case 'monthly':
    case 'This Year':
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
      final currentYear = actualEndDate.year;

      for (int month = 1; month <= 12; month++) {
        final monthKey = "$currentYear-${month.toString().padLeft(2, '0')}";
        final monthName = monthNames[month - 1];
        final count = timeCounts[monthKey] ?? 0;

        print('📈 $monthName ($monthKey): $count');

        trendData.add(ChartData(date: monthName, count: count));
      }
      break;

    case 'All':
      final startYear = startDate.year;
      final endYear = actualEndDate.year;

      for (int year = startYear; year <= endYear; year++) {
        final yearKey = year.toString();
        trendData.add(
          ChartData(date: yearKey, count: timeCounts[yearKey] ?? 0),
        );
      }
      break;
  }

  return trendData;
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

DateTime _getStartOfWeek(DateTime date) {
  final daysFromMonday = date.weekday - 1;
  return DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: daysFromMonday));
}

String _getDataGroupingInterval(DateTime startDate, DateTime endDate) {
  final daysDifference = endDate.difference(startDate).inDays;

  if (daysDifference == 0) {
    return 'hourly'; // Same day
  } else if (daysDifference <= 7) {
    return 'daily'; // Up to 7 days
  } else if (daysDifference <= 31) {
    return 'weekly'; // Up to 31 days
  } else if (daysDifference <= 365) {
    return 'monthly'; // Up to 1 year
  } else {
    return 'yearly'; // More than 1 year
  }
}

String _getTimeKeyForInterval(
  DateTime dateTime,
  String interval,
  DateTime startDate,
  DateTime? endDate,
) {
  switch (interval) {
    case 'hourly':
    case 'Today':
      return "${dateTime.hour.toString().padLeft(2, '0')}:00";

    case 'daily':
    case 'This Week':
      // Return full date key for aggregation
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

    case 'weekly':
    case 'This Month':
      final weekOfMonth = ((dateTime.day - 1) ~/ 7) + 1;
      return "Week $weekOfMonth";

    case 'monthly':
    case 'This Year':
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}";

    case 'All':
      return "${dateTime.year}";

    default:
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}";
  }
}

List<String> _generateAllTimeKeys(
  DateTime startDate,
  DateTime? endDate,
  String interval,
) {
  final keys = <String>[];
  final end = endDate ?? DateTime.now();

  switch (interval) {
    case 'hourly':
    case 'Today':
      for (int hour = 0; hour < 24; hour++) {
        keys.add("${hour.toString().padLeft(2, '0')}:00");
      }
      break;

    case 'daily':
    case 'This Week':
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < 7; i++) {
        keys.add(dayNames[i]);
      }
      break;

    case 'weekly':
    case 'This Month':
      for (int week = 1; week <= 5; week++) {
        keys.add("Week $week");
      }
      break;

    case 'monthly':
    case 'This Year':
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
      // ✅ FIX: Always generate all 12 months for "This Year"
      for (int month = 1; month <= 12; month++) {
        keys.add(monthNames[month - 1]);
      }
      break;

    case 'All':
      final startYear = startDate.year;
      final endYear = end.year;
      for (int year = startYear; year <= endYear; year++) {
        keys.add(year.toString());
      }
      break;
  }

  return keys;
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
        final categoryBreakdown =
            timeCategoryCounts[hourKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        trend.add(
          ChartData(
            date: hourKey,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;

    case 'daily':
      // Generate all days in range
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      var currentDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
        final dateKey =
            "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
        final displayKey = dayNames[currentDate.weekday - 1];
        final categoryBreakdown =
            timeCategoryCounts[dateKey] ?? <String, int>{};
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

        currentDate = currentDate.add(const Duration(days: 1));
      }
      break;

    case 'weekly':
      // Generate all weeks
      final daysDiff = endDate.difference(startDate).inDays;
      final weeksCount = (daysDiff / 7).ceil();

      for (int week = 1; week <= weeksCount; week++) {
        final weekKey = "Week $week";
        final categoryBreakdown =
            timeCategoryCounts[weekKey] ?? <String, int>{};
        final totalCount = categoryBreakdown.values.fold(
          0,
          (sum, count) => sum + count,
        );

        trend.add(
          ChartData(
            date: weekKey,
            count: totalCount,
            categoryBreakdown: categoryBreakdown,
          ),
        );
      }
      break;

    case 'monthly':
      // Generate all months in range
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

      var currentMonth = DateTime(startDate.year, startDate.month);
      final endMonth = DateTime(endDate.year, endDate.month);

      while (currentMonth.isBefore(endMonth.add(const Duration(days: 32))) ||
          (currentMonth.month == endMonth.month &&
              currentMonth.year == endDate.year)) {
        final monthKey =
            "${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}";
        final displayKey = monthNames[currentMonth.month - 1];
        final categoryBreakdown =
            timeCategoryCounts[monthKey] ?? <String, int>{};
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
