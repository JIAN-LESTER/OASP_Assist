import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Widget buildCompactStatCard(
  String title,
  String value,
  Color color,
  IconData icon,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 14,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 34 : 36,
              height: isMobile ? 34 : 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isMobile ? 16 : 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                  letterSpacing: 0,
                  height: 1.1,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: isMobile ? 28 : 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.3)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
    },
  );
}



class StatData {
  final String date;
  final int count;
  final Map<String, int> categoryBreakdown;

  const StatData({
    required this.date,
    required this.count,
    this.categoryBreakdown = const {},
  });

  factory StatData.fromMap(Map<String, dynamic> map) {
    return StatData(
      categoryBreakdown:
          map['categoryBreakdown'] != null
              ? Map<String, int>.from(map['categoryBreakdown'])
              : {},
      count: map['count'] ?? 0,
      date: map['date'] ?? '',
    );
  }
}

class InformationBankData {
  final int totalDocuments;
  final String latestUpload;
  final String mostFrequentCategory;

  const InformationBankData({
    required this.totalDocuments,
    required this.latestUpload,
    required this.mostFrequentCategory,
  });
}

class FAQsData {
  final int totalFAQs;
  final String latestFAQ;
  final String mostAskedQuestion;
  final String mostFrequentCategory;

  const FAQsData({
    required this.totalFAQs,
    required this.latestFAQ,
    required this.mostFrequentCategory,
    required this.mostAskedQuestion,
  });
}

class UserData {
  final int totalUsers;
  final int activeUsers;
  final int newUsersThisMonth;
  final int usersLoggedInToday;

  const UserData({
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsersThisMonth,
    required this.usersLoggedInToday,
  });
}

class AffiliationData {
  final int totalAffiliations;
  final String dominantAffiliation; // Changed from int to String

  const AffiliationData({
    required this.totalAffiliations,
    required this.dominantAffiliation,
  });
}

class ProgramData {
  final int totalProgram;
  final String dominantProgram; // Changed from int to String

  const ProgramData({
    required this.totalProgram,
    required this.dominantProgram,
  });
}

class AdmissionData {
  final int latestAdmission;
  final int totalAdmission;

  const AdmissionData({
    required this.latestAdmission,
    required this.totalAdmission,
  });
}

class ScholarshipData {
  final int totalScholarship;
  final String newScholarship;
  final String approachingDeadline;

  const ScholarshipData({
    required this.totalScholarship,
    required this.newScholarship,
    required this.approachingDeadline,
  });
}

class PlacementData {
  final int totalCompanies;
  final String vacantCompanies;
  final String approachingDeadline;

  const PlacementData({
    required this.totalCompanies,
    required this.vacantCompanies,
    required this.approachingDeadline,
  });
}

class StatDataManagement {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Enhanced caching with individual report caches
  static final Map<String, InformationBankData> _ibCache = {};
  static final Map<String, FAQsData> _faqCache = {};
  static final Map<String, UserData> _userCache = {};

  static final Map<String, ProgramData> _programCache = {};
  static final Map<String, AdmissionData> _admissionCache = {};
  static final Map<String, ScholarshipData> _scholarshipCache = {};
  static final Map<String, PlacementData> _placementCache = {};

  static final Map<String, DateTime> _cacheTimestamps = {};

  static const int _cacheDurationMinutes = 5;

  bool _isCacheValid(String cacheKey) {
    if (!_cacheTimestamps.containsKey(cacheKey)) return false;
    final now = DateTime.now();
    return now.difference(_cacheTimestamps[cacheKey]!).inMinutes <
        _cacheDurationMinutes;
  }

  void _updateCacheTimestamp(String cacheKey) {
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  // ==================== INFORMATION BANK ====================
  Future<InformationBankData> getInformationBankData() async {
    const cacheKey = 'information_bank';

    if (_ibCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _ibCache[cacheKey]!;
    }

    try {
      final results = await Future.wait([
        _getInformationBank(),
        _getLatestInformationBank(),
      ]);

      final data = _processInformationBankData(
        ib: results[0],
        latestIB: results[1],
      );

      _ibCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching information bank data: $e');
      return const InformationBankData(
        totalDocuments: 0,
        latestUpload: 'N/A',
        mostFrequentCategory: 'N/A',
      );
    }
  }

  InformationBankData _processInformationBankData({
    required List<QueryDocumentSnapshot> ib,
    required List<QueryDocumentSnapshot> latestIB,
  }) {
    final categoryDistribution = <String, int>{};
    String latestUpload = 'N/A';

    for (final doc in ib) {
      final data = doc.data() as Map<String, dynamic>;

      final category = (data['category'] as String?)?.trim() ?? 'General';
      categoryDistribution[category] =
          (categoryDistribution[category] ?? 0) + 1;
    }

    // Get latest upload title from separate query
    if (latestIB.isNotEmpty) {
      final latestDoc = latestIB.first;
      final data = latestDoc.data() as Map<String, dynamic>;
      latestUpload = data['ib_title'] as String? ?? 'N/A';
    }

    return InformationBankData(
      totalDocuments: ib.length,
      mostFrequentCategory: _getMostFrequentCategory(categoryDistribution),
      latestUpload: latestUpload,
    );
  }

  // ==================== FAQs ====================
  Future<FAQsData> getFAQsData() async {
    const cacheKey = 'faqs';

    if (_faqCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _faqCache[cacheKey]!;
    }

    try {
      final results = await Future.wait([
        _getFAQs(),
        _getLatestFAQ(),
        _getMostAskedFAQ(),
      ]);

      final data = _processFAQsData(
        faqs: results[0],
        latestFAQ: results[1],
        mostAskedFAQ: results[2],
      );

      _faqCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching FAQs data: $e');
      return const FAQsData(
        totalFAQs: 0,
        latestFAQ: 'N/A',
        mostFrequentCategory: 'N/A',
        mostAskedQuestion: 'N/A',
      );
    }
  }

  FAQsData _processFAQsData({
    required List<QueryDocumentSnapshot> faqs,
    required List<QueryDocumentSnapshot> latestFAQ,
    required List<QueryDocumentSnapshot> mostAskedFAQ,
  }) {
    final categoryDistribution = <String, int>{};
    String latestFAQDate = 'N/A';
    String mostAskedQuestion = 'N/A';

    for (final doc in faqs) {
      final data = doc.data() as Map<String, dynamic>;

      final category = (data['category'] as String?)?.trim() ?? 'General';
      categoryDistribution[category] =
          (categoryDistribution[category] ?? 0) + 1;
    }

    if (latestFAQ.isNotEmpty) {
      final latestDoc = latestFAQ.first;
      final data = latestDoc.data() as Map<String, dynamic>;
      latestFAQDate = data['question'] as String? ?? 'N/A';
    }

    // Get most asked question from separate query
    if (mostAskedFAQ.isNotEmpty) {
      final mostAskedDoc = mostAskedFAQ.first;
      final data = mostAskedDoc.data() as Map<String, dynamic>;
      mostAskedQuestion = data['question'] as String? ?? 'N/A';
    }

    return FAQsData(
      totalFAQs: faqs.length,
      latestFAQ: latestFAQDate,
      mostFrequentCategory: _getMostFrequentCategory(categoryDistribution),
      mostAskedQuestion: mostAskedQuestion,
    );
  }

  // ==================== USER DATA ====================
  Future<UserData> getUserData() async {
    const cacheKey = 'users';

    if (_userCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _userCache[cacheKey]!;
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfDay = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        _getUsersOptimized(),
        _getActiveUsers(),
        _getNewUsers(startOfMonth),
        _getUsersLoggedInToday(startOfDay),
      ]);

      final data = _processUserData(
        users: results[0],
        activeUsers: results[1],
        newUsers: results[2],
        loggedInToday: results[3],
      );

      _userCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching user data: $e');
      return const UserData(
        totalUsers: 0,
        activeUsers: 0,
        newUsersThisMonth: 0,
        usersLoggedInToday: 0,
      );
    }
  }

  UserData _processUserData({
    required List<QueryDocumentSnapshot> users,
    required List<QueryDocumentSnapshot> activeUsers,
    required List<QueryDocumentSnapshot> newUsers,
    required List<QueryDocumentSnapshot> loggedInToday,
  }) {
    return UserData(
      totalUsers: users.length,
      activeUsers: activeUsers.length,
      newUsersThisMonth: newUsers.length,
      usersLoggedInToday: loggedInToday.length,
    );
  }

  // ==================== PROGRAM DATA ====================
  Future<ProgramData> getProgramData() async {
    const cacheKey = 'programs';

    if (_programCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _programCache[cacheKey]!;
    }

    try {
      final users = await _getUsersOptimized();
      final programs = await _getPrograms();
      final data = _processProgramData(users: users, programs: programs);

      _programCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching program data: $e');
      return const ProgramData(totalProgram: 0, dominantProgram: 'N/A');
    }
  }

  ProgramData _processProgramData({
    required List<QueryDocumentSnapshot> users,
    required List<QueryDocumentSnapshot> programs,
  }) {
    final programCounts = <String, int>{};

    String dominantProgram = 'N/A';
    if (programCounts.isNotEmpty) {
      dominantProgram =
          programCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return ProgramData(
      totalProgram: programs.length,
      dominantProgram: dominantProgram,
    );
  }

  // ==================== ADMISSION DATA ====================
  Future<AdmissionData> getAdmissionData() async {
    const cacheKey = 'admissions';

    if (_admissionCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _admissionCache[cacheKey]!;
    }

    try {
      final admissions = await _getAdmissions();
      final data = _processAdmissionData(admissions: admissions);

      _admissionCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching admission data: $e');
      return const AdmissionData(latestAdmission: 0, totalAdmission: 0);
    }
  }

  AdmissionData _processAdmissionData({
    required List<QueryDocumentSnapshot> admissions,
  }) {
    int latestAdmission = 0;

    if (admissions.isNotEmpty) {
      final latestDoc = admissions.first;
      final data = latestDoc.data() as Map<String, dynamic>;
      latestAdmission = data['applicantCount'] as int? ?? 0;
    }

    return AdmissionData(
      latestAdmission: latestAdmission,
      totalAdmission: admissions.length,
    );
  }

  // ==================== SCHOLARSHIP DATA ====================
  Future<ScholarshipData> getScholarshipData() async {
    const cacheKey = 'scholarships';

    if (_scholarshipCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _scholarshipCache[cacheKey]!;
    }

    try {
      final scholarships = await _getScholarships();
      final data = _processScholarshipData(scholarships: scholarships);

      _scholarshipCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching scholarship data: $e');
      return const ScholarshipData(
        totalScholarship: 0,
        newScholarship: 'N/A',
        approachingDeadline: 'N/A',
      );
    }
  }

  ScholarshipData _processScholarshipData({
    required List<QueryDocumentSnapshot> scholarships,
  }) {
    String newScholarship = 'N/A';
    String approachingDeadline = 'N/A';
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    if (scholarships.isNotEmpty) {
      final latestDoc = scholarships.first;
      final data = latestDoc.data() as Map<String, dynamic>;
      newScholarship = data['name'] as String? ?? 'N/A';
    }

    for (final doc in scholarships) {
      final data = doc.data() as Map<String, dynamic>;
      final deadline = data['deadline'];

      if (deadline is Timestamp) {
        final deadlineDate = deadline.toDate();
        if (deadlineDate.isAfter(now) &&
            deadlineDate.isBefore(sevenDaysFromNow)) {
          approachingDeadline = data['name'] as String? ?? 'N/A';
          break;
        }
      }
    }

    return ScholarshipData(
      totalScholarship: scholarships.length,
      newScholarship: newScholarship,
      approachingDeadline: approachingDeadline,
    );
  }


  Future<PlacementData> getPlacementData() async {
    const cacheKey = 'placements';

    if (_placementCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _placementCache[cacheKey]!;
    }

    try {
      final placements = await _getJobPlacements();
      final data = _processPlacementData(placements: placements);

      _placementCache[cacheKey] = data;
      _updateCacheTimestamp(cacheKey);

      return data;
    } catch (e) {
      print('Error fetching placement data: $e');
      return const PlacementData(
        totalCompanies: 0,
        vacantCompanies: 'N/A',
        approachingDeadline: 'N/A',
      );
    }
  }

PlacementData _processPlacementData({
  required List<QueryDocumentSnapshot> placements,
}) {
  int totalCompanies = placements.length;
  int vacantCount = 0;
  String approachingDeadline = 'N/A';

  final now = DateTime.now();
  final threeDaysFromNow = now.add(const Duration(days: 3));

  for (final doc in placements) {
    final data = doc.data() as Map<String, dynamic>;

    final company = data['companyName'] as String? ?? 'Unknown';
    final isVacant = data['isRecruiting'] as bool? ?? false;
    final deadline = data['deadline'];

    // ✅ Count all placements that are currently recruiting
    if (isVacant) {
      vacantCount++;
    }

    // ✅ Find the FIRST company with deadline within the next 3 days
    if (approachingDeadline == 'N/A' && deadline is Timestamp) {
      final deadlineDate = deadline.toDate();

      if (deadlineDate.isAfter(now) &&
          deadlineDate.isBefore(threeDaysFromNow)) {
        approachingDeadline = company;
      }
    }
  }

  return PlacementData(
    totalCompanies: totalCompanies,
    vacantCompanies: vacantCount.toString(),
    approachingDeadline: approachingDeadline,
  );
}
  // ==================== FIRESTORE QUERY METHODS ====================
  Future<List<QueryDocumentSnapshot>> _getUsersOptimized() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getFAQs() async {
    final snapshot = await _firestore.collection('faqs').get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getPrograms() async {
    final snapshot = await _firestore.collection('programs').get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getMostAskedFAQ() async {
    final snapshot =
        await _firestore
            .collection('faqs')
            .orderBy('similarityCount', descending: true)
            .limit(1)
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

  Future<List<QueryDocumentSnapshot>> _getInformationBank() async {
    final snapshot = await _firestore.collection('information_bank').get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getLatestInformationBank() async {
    final snapshot =
        await _firestore
            .collection('information_bank')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getLatestFAQ() async {
    final snapshot =
        await _firestore
            .collection('faqs')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getNewUsers(DateTime startDate) async {
    final snapshot =
        await _firestore
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getUsersLoggedInToday(
    DateTime startDate,
  ) async {
    final snapshot =
        await _firestore
            .collection('users')
            .where('lastLoginAt', isGreaterThanOrEqualTo: startDate)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getAdmissions() async {
    final snapshot =
        await _firestore
            .collection('admissions')
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getScholarships() async {
    final snapshot =
        await _firestore
            .collection('scholarships')
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getJobPlacements() async {
    final snapshot =
        await _firestore
            .collection('placements')
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs;
  }

  String _getMostFrequentCategory(Map<String, int> categories) {
    if (categories.isEmpty) return 'Unknown';
    return categories.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
