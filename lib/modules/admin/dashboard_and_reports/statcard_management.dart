import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/services/firebase_usage_logger.dart';

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

Widget buildManagementTableSkeleton({
  int statCardCount = 4,
  bool showTabs = false,
}) {
  return _ManagementSkeletonShimmer(
    child: Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          final cardCount = statCardCount.clamp(1, 4).toInt();

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTabs) ...[
                  Row(
                    children: [
                      _managementSkeletonBox(width: 120, height: 38),
                      const SizedBox(width: 12),
                      _managementSkeletonBox(width: 150, height: 38),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _managementSkeletonPageHeader(isMobile),
                const SizedBox(height: 16),
                _managementSkeletonStats(cardCount, isMobile),
                const SizedBox(height: 8),
                _managementSkeletonActions(isMobile),
                const SizedBox(height: 16),
                _managementSkeletonTable(isMobile),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget buildSmoothManagementTransition({
  required bool isLoading,
  required Widget loading,
  required Widget child,
}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: KeyedSubtree(
      key: ValueKey(isLoading ? 'management-loading' : 'management-content'),
      child: isLoading ? loading : child,
    ),
  );
}

Widget _managementSkeletonPageHeader(bool isMobile) {
  if (isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _managementSkeletonBox(width: 220, height: 24),
        const SizedBox(height: 10),
        _managementSkeletonBox(width: 180, height: 14),
        const SizedBox(height: 16),
        _managementSkeletonBox(width: 150, height: 48, radius: 8),
      ],
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _managementSkeletonBox(width: 230, height: 24),
          const SizedBox(height: 10),
          _managementSkeletonBox(width: 190, height: 14),
        ],
      ),
      _managementSkeletonBox(width: 168, height: 48, radius: 8),
    ],
  );
}

Widget _managementSkeletonStats(int count, bool isMobile) {
  final cards = List.generate(
    count,
    (_) => Expanded(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _managementSkeletonBox(width: 36, height: 36, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: _managementSkeletonBox(height: 12),
            ),
            const SizedBox(width: 12),
            _managementSkeletonBox(width: 34, height: 16),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF93C5FD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (isMobile) {
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          Row(
            children: [
              cards[i],
              if (i + 1 < cards.length) ...[
                const SizedBox(width: 12),
                cards[i + 1],
              ],
            ],
          ),
          if (i + 2 < cards.length) const SizedBox(height: 12),
        ],
      ],
    );
  }

  return Row(
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        cards[i],
        if (i != cards.length - 1) const SizedBox(width: 16),
      ],
    ],
  );
}

Widget _managementSkeletonActions(bool isMobile) {
  if (isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _managementSkeletonBox(width: double.infinity, height: 44, radius: 6),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _managementSkeletonBox(height: 44, radius: 6)),
            const SizedBox(width: 10),
            _managementSkeletonBox(width: 116, height: 44, radius: 6),
          ],
        ),
      ],
    );
  }

  return Row(
    children: [
      Expanded(child: _managementSkeletonBox(height: 44, radius: 6)),
      const SizedBox(width: 16),
      _managementSkeletonBox(width: 150, height: 44, radius: 6),
    ],
  );
}

Widget _managementSkeletonTable(bool isMobile) {
  return Container(
    padding: EdgeInsets.fromLTRB(
      isMobile ? 14 : 24,
      isMobile ? 14 : 24,
      isMobile ? 14 : 24,
      0,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              _managementSkeletonBox(
                width: 18,
                height: 18,
                radius: 4,
                color: Colors.white.withOpacity(0.55),
              ),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _managementSkeletonHeaderBox()),
              if (!isMobile) ...[
                Expanded(child: _managementSkeletonHeaderBox()),
                Expanded(child: _managementSkeletonHeaderBox()),
                Expanded(flex: 2, child: _managementSkeletonHeaderBox()),
              ],
              Expanded(child: _managementSkeletonHeaderBox()),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            for (var i = 0; i < 8; i++) ...[
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: i.isOdd ? const Color(0xFFF6FFFC) : Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    _managementSkeletonBox(width: 18, height: 18, radius: 4),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _managementSkeletonBox(width: 150, height: 13),
                          const SizedBox(height: 6),
                          _managementSkeletonBox(width: 120, height: 11),
                        ],
                      ),
                    ),
                    if (!isMobile) ...[
                      Expanded(child: _managementSkeletonBox(width: 92, height: 26, radius: 4)),
                      Expanded(child: _managementSkeletonBox(width: 46, height: 12)),
                      Expanded(flex: 2, child: _managementSkeletonBox(width: 260, height: 12)),
                    ],
                    Expanded(child: _managementSkeletonBox(width: 52, height: 24, radius: 4)),
                    _managementSkeletonBox(width: 24, height: 12),
                  ],
                ),
              ),
              if (i != 7) const SizedBox(height: 6),
            ],
          ],
        ),
        _managementSkeletonPagination(isMobile),
      ],
    ),
  );
}

Widget _managementSkeletonHeaderBox() {
  return Align(
    alignment: Alignment.centerLeft,
    child: _managementSkeletonBox(
      width: 72,
      height: 13,
      color: Colors.white.withOpacity(0.75),
    ),
  );
}

Widget _managementSkeletonPagination(bool isMobile) {
  if (isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _managementSkeletonBox(width: 108, height: 14),
          const Spacer(),
          _managementSkeletonBox(width: 118, height: 34, radius: 8),
        ],
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
    child: Row(
      children: [
        _managementSkeletonBox(width: 136, height: 14),
        const SizedBox(width: 22),
        _managementSkeletonBox(width: 190, height: 14),
        const Spacer(),
        for (var i = 0; i < 5; i++) ...[
          _managementSkeletonBox(width: 34, height: 34, radius: 8),
          if (i != 4) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

Widget _managementSkeletonBox({
  double? width,
  required double height,
  double radius = 8,
  Color color = const Color(0xFFE2E8F0),
}) {
  return _ManagementSkeletonShimmerBox(
    width: width,
    height: height,
    radius: radius,
    baseColor: color,
  );
}

class _ManagementSkeletonShimmer extends StatefulWidget {
  final Widget child;

  const _ManagementSkeletonShimmer({required this.child});

  @override
  State<_ManagementSkeletonShimmer> createState() =>
      _ManagementSkeletonShimmerState();
}

class _ManagementSkeletonShimmerState extends State<_ManagementSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ManagementSkeletonShimmerScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ManagementSkeletonShimmerScope extends InheritedNotifier<Animation<double>> {
  final Animation<double> animation;

  const _ManagementSkeletonShimmerScope({
    required this.animation,
    required super.child,
  }) : super(notifier: animation);

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ManagementSkeletonShimmerScope>()
        ?.animation;
  }
}

class _ManagementSkeletonShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final Color baseColor;

  const _ManagementSkeletonShimmerBox({
    this.width,
    required this.height,
    required this.radius,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final animation = _ManagementSkeletonShimmerScope.maybeOf(context);
    if (animation == null) return _buildBox(baseColor);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(
          animation.value < 0.5
              ? animation.value * 2
              : (1 - animation.value) * 2,
        );
        final color = Color.lerp(baseColor, Colors.white, 0.22 * pulse)!;

        return RepaintBoundary(child: _buildBox(color));
      },
    );
  }

  Widget _buildBox(Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
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

  Future<void> _logDisplayedReads(
    String source,
    Map<String, List<QueryDocumentSnapshot>> groups,
  ) async {
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      await FirebaseUsageLogger.logRead(
        collection: entry.key,
        count: entry.value.length,
        source: source,
      );
    }
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
      await _logDisplayedReads('information_bank_statcard', {
        'information_bank': [
          ...results[0],
          ...results[1],
        ],
      });

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
      await _logDisplayedReads('faq_statcard', {
        'faqs': [
          ...results[0],
          ...results[1],
          ...results[2],
        ],
      });

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
      await _logDisplayedReads('user_statcard', {
        'users': [
          ...results[0],
          ...results[1],
          ...results[2],
          ...results[3],
        ],
      });

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
      await _logDisplayedReads('program_statcard', {
        'users': users,
        'programs': programs,
      });
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
      await _logDisplayedReads('admission_statcard', {
        'admissions': admissions,
      });
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
      await _logDisplayedReads('scholarship_statcard', {
        'scholarships': scholarships,
      });
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
      await _logDisplayedReads('placement_statcard', {
        'placements': placements,
      });
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

      //  Count all placements that are currently recruiting
      if (isVacant) {
        vacantCount++;
      }

      //  Find the FIRST company with deadline within the next 3 days
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
