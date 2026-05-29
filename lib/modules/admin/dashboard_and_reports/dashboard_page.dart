import 'package:capstone_project/modules/admin/dashboard_and_reports/admin_dashboard_data.dart';

import 'package:capstone_project/modules/admin/dashboard_and_reports/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/export_button.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/gemini_billing_section.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/inquiry_trends_charts.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/paginated_list.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/user_demographics_data.dart';

import 'package:capstone_project/widgets/date_range_filter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:capstone_project/modules/admin/dashboard_and_reports/charts.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/reports.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart' hide DateRangePickerDialog;
import '../../../widgets/custom_dropdown_button.dart';

const _kNavy = Color(0xFF0F172A);
const _kSlate = Color(0xFF1E293B);
const _kCardBg = Color(0xFFFFFFFF);
const _kPageBg = Color(0xFFEDF0F7);
const _kAccent = Color(0xFF6366F1);
const _kAccentLight = Color(0xFFEEF2FF);
const _kGreen = Color(0xFF10B981);
const _kGreenLight = Color(0xFFD1FAE5);
const _kOrange = Color(0xFFF59E0B);
const _kOrangeLight = Color(0xFFFEF3C7);
const _kRed = Color(0xFFEF4444);
const _kRedLight = Color(0xFFFEE2E2);
const _kTextPrimary = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonBox({super.key, this.width, this.height, this.borderRadius});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.grey[300]!, Colors.grey[200]!, Colors.grey[300]!],
              stops:
                  [
                    _animation.value - 0.3,
                    _animation.value,
                    _animation.value + 0.3,
                  ].map((v) => v.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonBox(width: 80, height: 16),
                SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SkeletonBox(width: 60, height: 32),
          ],
        ),
      ),
    );
  }
}

class SkeletonChartCard extends StatelessWidget {
  const SkeletonChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 150, height: 20),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonLogsCard extends StatelessWidget {
  const SkeletonLogsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 120, height: 20),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        width: double.infinity,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      SkeletonBox(
                        width: 100,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LAZY LOADING WRAPPER - FIXED
// ============================================================================

class LazyLoadWidget extends StatefulWidget {
  final Widget Function(BuildContext) builder;
  final Duration delay;

  const LazyLoadWidget({
    super.key,
    required this.builder,
    this.delay = const Duration(milliseconds: 100),
  });

  @override
  State<LazyLoadWidget> createState() => _LazyLoadWidgetState();
}

class _LazyLoadWidgetState extends State<LazyLoadWidget> {
  bool _shouldBuild = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() {
            _shouldBuild = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldBuild) {
      return const SkeletonChartCard();
    }
    return widget.builder(context);
  }
}

// ============================================================================
// ENHANCED CACHE MODEL
// ============================================================================

class DashboardCache {
  final InquiryReportsData? inq;
  final UserDemographicsReportsData? ud;
  final AdminDashboardData? ad; //  ADD THIS
  final DateTime timestamp;
  final Map<String, dynamic>? quickStats;

  DashboardCache({
    this.inq,
    this.ud,
    this.ad, //  ADD THIS
    required this.timestamp,
    this.quickStats,
  });

  bool get isValid {
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes < 5;
  }

  bool get isStale {
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes >= 3;
  }
}

// ============================================================================
// OPTIMIZED DASHBOARD PAGE
// ============================================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardModulestate();
}

class _DashboardModulestate extends State<DashboardPage> {
  String selectedTimeFrame = 'This Month';
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();

  final Map<String, DashboardCache> _cache = {};

  DateTimeRange? customDateRange;
  bool showDateRangePicker = false;

  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;
  AdminDashboardData? ad; //  ADD THIS
  String? userName;
  Map<String, int>? quickStats;

  bool isInitialLoad = true;
  bool isRefreshing = false;
  bool isLazyLoading = false;
  bool showSkeleton = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ============================================================================
  // OPTIMIZED LOADING STRATEGY
  // ============================================================================

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      isInitialLoad = true;
      showSkeleton = true;
    });

    try {
      // Phase 1: Load critical data first (username + quick stats)
      await _loadCriticalData();

      // Phase 2: Hide skeleton and show cached/fresh data
      if (mounted) {
        setState(() {
          showSkeleton = false;
          isInitialLoad = false;
        });
      }

      // Phase 3: Load full data in background
      await _loadFullData();
    } catch (e) {
      print('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          showSkeleton = false;
          isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _loadCriticalData() async {
    // Load username and quick stats in parallel
    final results = await Future.wait([_fetchUserName(), _fetchQuickStats()]);

    if (!mounted) return;

    setState(() {
      userName = results[0] as String?;
      quickStats = results[1] as Map<String, int>?;
    });
  }

  Future<void> _loadFullData() async {
    // Check cache first
    if (_cache.containsKey(selectedTimeFrame) &&
        _cache[selectedTimeFrame]!.isValid) {
      final cached = _cache[selectedTimeFrame]!;

      if (mounted) {
        setState(() {
          inq = cached.inq;
          ud = cached.ud;
          ad = cached.ad; //  LOAD FROM CACHE
          quickStats = cached.quickStats as Map<String, int>?;
        });
      }

      // Refresh in background if stale
      if (cached.isStale) {
        _refreshInBackground();
      }
      return;
    }

    // Fetch fresh data
    await _fetchAndCacheData();
  }

  Future<void> _fetchAndCacheData() async {
    try {
      final results = await Future.wait([
        _firebaseService.getAdminDashboardData(
          selectedTimeFrame,
          customDateRange,
        ),
        _firebaseService.getUserDemographicsReportsData(
          selectedTimeFrame,
          customDateRange,
        ),
        //  ADD: Fetch inquiry data separately
        _firebaseService.getInquiryReportsData(
          selectedTimeFrame,
          customDateRange,
        ),
      ]);

      if (!mounted) return;

      final adminData = results[0] as AdminDashboardData;
      final userDemoData = results[1] as UserDemographicsReportsData;
      final inquiryReportData = results[2] as InquiryReportsData;

      //   Use inquiryReportData directly instead of creating from adminData
      final inquiryData = InquiryReportsData(
        totalMessages: inquiryReportData.totalMessages,
        userMessages: inquiryReportData.userMessages,
        botMessages: inquiryReportData.botMessages,
        escalatedMessages: inquiryReportData.escalatedMessages,
        escalationRate: inquiryReportData.escalationRate,
        resolvedMessages: inquiryReportData.resolvedMessages,
        resolutionRate: inquiryReportData.resolutionRate,
        inquiryTrend: inquiryReportData.inquiryTrend,
        categoryDistribution: inquiryReportData.categoryDistribution,
        topQuestions: inquiryReportData.topQuestions,
        escalationsOverTime: inquiryReportData.escalationsOverTime,
        staffPerformance: inquiryReportData.staffPerformance,
        botVsHumanAnswers: inquiryReportData.botVsHumanAnswers,
        allEscalations:
            inquiryReportData.allEscalations, //  This now has the correct value
        recentLogs: inquiryReportData.recentLogs,
        msgLogs: inquiryReportData.msgLogs,
      );

      //  UPDATE CACHE
      _cache[selectedTimeFrame] = DashboardCache(
        inq: inquiryData,
        ud: userDemoData,
        ad: adminData,
        timestamp: DateTime.now(),
      );

      setState(() {
        inq = inquiryData;
        ud = userDemoData;
        ad = adminData;

        //  DEBUG PRINTS
        print(' Inquiry Data Updated:');
        print('   All Escalations: ${inquiryData.allEscalations}');
        print('   Escalated Messages: ${inquiryData.escalatedMessages}');
        print('   Admin Pending Escalations: ${adminData.pendingEscalations}');
        print(
          '   Top Escalated Messages: ${adminData.topEscalatedMessages.length}',
        );
      });
    } catch (e) {
      print(' Error fetching data: $e');
      rethrow;
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      await _fetchAndCacheData();
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  Future<String?> _fetchUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'User';

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      return userDoc.exists ? (userDoc.data()?['name'] ?? 'User') : 'User';
    } catch (e) {
      print('Error fetching user name: $e');
      return 'User';
    }
  }

  Future<Map<String, int>?> _fetchQuickStats() async {
    try {
      return await _firebaseService.getQuickStats(
        selectedTimeFrame,
        customDateRange,
      );
    } catch (e) {
      print('Error fetching quick stats: $e');
      return null;
    }
  }

  Future<void> _refreshData() async {
    if (!mounted || isRefreshing) return;

    setState(() {
      isRefreshing = true;
    });

    try {
      _cache.remove(selectedTimeFrame);
      await Future.wait([
        _fetchQuickStats().then((stats) {
          if (mounted) {
            setState(() {
              quickStats = stats;
            });
          }
        }),
        _fetchAndCacheData(),
      ]);

      if (mounted) {
        _showSnackBar('Dashboard refreshed successfully', isError: false);
      }
    } catch (e) {
      print('Error refreshing dashboard: $e');
      if (mounted) {
        _showSnackBar('Failed to refresh dashboard', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> _onTimeFrameChanged(String newValue) async {
    if (newValue == selectedTimeFrame && newValue != 'Custom') return;

    //  CORRECT: Show modal when Custom is selected
    if (newValue == 'Custom') {
      final DateTimeRange? selectedRange = await showDialog<DateTimeRange>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (BuildContext context) {
          //  IMPORTANT: Import statement needed
          // Make sure _DateRangePickerDialog is accessible
          return DateRangePickerDialog(
            initialDateRange: customDateRange,
            firstDate: DateTime(2020, 1, 1),
            lastDate: DateTime.now(),
          );
        },
      );

      // If user selected a range, apply it
      if (selectedRange != null) {
        _onDateRangeChanged(selectedRange);
      }
      // If user cancelled (selectedRange is null), don't change anything
      return;
    }

    // Normal timeframe selection
    setState(() {
      selectedTimeFrame = newValue;
      customDateRange = null;
      isLazyLoading = true;
    });

    try {
      await Future.wait([
        _fetchQuickStats().then((stats) {
          if (mounted) {
            setState(() {
              quickStats = stats;
            });
          }
        }),
        _loadFullData(),
      ]);
    } catch (e) {
      print('Error changing timeframe: $e');
      _showSnackBar('Failed to load data for $newValue', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLazyLoading = false;
        });
      }
    }
  }

  // Add this new method to handle date range changes:
  Future<void> _onDateRangeChanged(DateTimeRange? range) async {
    if (range == null) {
      // User cleared the date range, revert to "This Month"
      setState(() {
        customDateRange = null;
        selectedTimeFrame = 'This Month';
        isLazyLoading = true;
      });
    } else {
      // User selected a custom date range
      setState(() {
        customDateRange = range;
        selectedTimeFrame = 'Custom';
        isLazyLoading = true;
      });
    }

    try {
      // Clear cache for custom range
      _cache.remove('Custom');

      await Future.wait([
        _fetchQuickStats().then((stats) {
          if (mounted) {
            setState(() {
              quickStats = stats;
            });
          }
        }),
        _loadFullData(),
      ]);
    } catch (e) {
      print('Error loading custom date range: $e');
      _showSnackBar(
        'Failed to load data for selected date range',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLazyLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: isMobile ? 15 : (isTablet ? 16 : 17),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red[600] : null,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 14 : 16,
        ),
        margin: EdgeInsets.only(
          bottom: 20,
          right: 20,
          left: isMobile ? 20 : (screenWidth - (isTablet ? 380 : 420)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show skeleton during initial load
    if (showSkeleton || userName == null) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 1, 124, 17),
        body: _buildSkeletonDashboard(),
      );
    }

    return Stack(
      children: [
        ResponsiveLayout(
          mobileBody: MobileDashboard(
            selectedTimeFrame: selectedTimeFrame,
            onTimeFrameChanged: _onTimeFrameChanged,
            onRefresh: _refreshData,
            isRefreshing: isRefreshing,
            inq: inq,
            ud: ud,
            ad: ad,
            userName: userName!,
            quickStats: quickStats,
            customDateRange: customDateRange,
            onDateRangeChanged: _onDateRangeChanged,
          ),
          tabletBody: TabletDashboard(
            selectedTimeFrame: selectedTimeFrame,
            onTimeFrameChanged: _onTimeFrameChanged,
            onRefresh: _refreshData,
            isRefreshing: isRefreshing,
            inq: inq,
            ud: ud,
            ad: ad,
            userName: userName!,
            quickStats: quickStats,
            customDateRange: customDateRange,
            onDateRangeChanged: _onDateRangeChanged,
          ),
          desktopBody: DesktopDashboard(
            selectedTimeFrame: selectedTimeFrame,
            onTimeFrameChanged: _onTimeFrameChanged,
            onRefresh: _refreshData,
            isRefreshing: isRefreshing,
            inq: inq,
            ud: ud,
            ad: ad,
            userName: userName!,
            quickStats: quickStats,
            customDateRange: customDateRange,
            onDateRangeChanged: _onDateRangeChanged,
          ),
        ),
        if (isLazyLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1),
                        ),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Loading data...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonDashboard() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonHeader(),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobile = screenWidth < 600;

              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(child: SkeletonStatCard()),
                        SizedBox(width: 12),
                        Expanded(child: SkeletonStatCard()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SkeletonStatCard(),
                  ],
                );
              } else {
                return const Row(
                  children: [
                    Expanded(child: SkeletonStatCard()),
                    SizedBox(width: 20),
                    Expanded(child: SkeletonStatCard()),
                    SizedBox(width: 20),
                    Expanded(child: SkeletonStatCard()),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 32),
          const Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: SkeletonChartCard()),
                SizedBox(width: 20),
                Expanded(child: SkeletonChartCard()),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(child: SkeletonLogsCard()),
                SizedBox(width: 20),
                Expanded(flex: 2, child: SkeletonLogsCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      //  MOBILE LAYOUT: Dropdown on the left, smaller arrangement
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(
                width: 140,
                height: 38,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              SkeletonBox(
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title centered or left (depending on your style)
          const SkeletonBox(width: 180, height: 22),

          const SizedBox(height: 8),
          const SkeletonBox(width: 250, height: 14),
        ],
      );
    }

    // 💻 DESKTOP LAYOUT (unchanged)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SkeletonBox(width: 200, height: 24),
            Row(
              children: [
                SkeletonBox(
                  width: 120,
                  height: 40,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SkeletonBox(width: 300, height: 14),
      ],
    );
  }

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }
}

// ============================================================================
// DASHBOARD IMPLEMENTATIONS
// ============================================================================

class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final InquiryReportsData? inq;
  final UserDemographicsReportsData? ud;
  final AdminDashboardData? ad;
  final String userName;
  final Map<String, int>? quickStats;
  final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const DesktopDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    this.inq,
    this.ud,
    this.ad,
    required this.userName,
    this.quickStats,
    required this.customDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return dashboardContents(
      selectedTimeFrame,
      onTimeFrameChanged,
      onRefresh,
      isRefreshing,
      inq,
      ud,
      ad,
      userName,
      quickStats,
      customDateRange,
      onDateRangeChanged,
    );
  }
}

class TabletDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final InquiryReportsData? inq;
  final UserDemographicsReportsData? ud;
  final AdminDashboardData? ad;
  final String userName;
  final Map<String, int>? quickStats;
  final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const TabletDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    this.inq,
    this.ud,
    this.ad,
    required this.userName,
    this.quickStats,
    required this.customDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return dashboardContents(
      selectedTimeFrame,
      onTimeFrameChanged,
      onRefresh,
      isRefreshing,
      inq,
      ud,
      ad,
      userName,
      quickStats,
      customDateRange,
      onDateRangeChanged,
    );
  }
}

class MobileDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final InquiryReportsData? inq;
  final UserDemographicsReportsData? ud;
  final AdminDashboardData? ad;
  final String userName;
  final Map<String, int>? quickStats;
  final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const MobileDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    this.inq,
    this.ud,
    this.ad,
    required this.userName,
    this.quickStats,
    required this.customDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return dashboardContents(
      selectedTimeFrame,
      onTimeFrameChanged,
      onRefresh,
      isRefreshing,
      inq,
      ud,
      ad,
      userName,
      quickStats,
      customDateRange,
      onDateRangeChanged,
    );
  }
}

Widget dashboardContents(
  String selectedTimeFrame,
  ValueChanged<String> onTimeFrameChanged,
  VoidCallback onRefresh,
  bool isRefreshing,
  InquiryReportsData? inq,
  UserDemographicsReportsData? ud,
  AdminDashboardData? ad,
  String userName,
  Map<String, int>? quickStats,
  DateTimeRange? customDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
) {
  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 239, 247, 237),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1100;

        Widget statCards() {
          final totalMessages = inq?.totalMessages ?? 0;
          final totalUsers = ud?.totalUsers ?? 0;
          final escalated = inq?.escalatedMessages ?? 0;
          final resolved = inq?.resolvedMessages ?? 0;

          // Calculate ratios
          final escalationRate = inq?.escalationRate ?? 0.0;
          final resolutionRate = inq?.resolutionRate ?? 0.0;

          if (isMobile) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: buildStatCard(
                        'Total Messages',
                        '$totalMessages',
                        Colors.blue,
                        Icons.message,
                        onTap:
                            () =>
                                _showMessagesDialog(context, selectedTimeFrame),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildStatCard(
                        'Total Users',
                        '$totalUsers',
                        Colors.green,
                        Icons.people,
                        onTap:
                            () => _showUsersDialog(context, selectedTimeFrame),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: buildStatCard(
                        'Escalation Rate',
                        '${escalationRate.toStringAsFixed(1)}%',
                        Colors.red,
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildStatCard(
                        'Resolution Rate',
                        '${resolutionRate.toStringAsFixed(1)}%',
                        Colors.purple,
                        Icons.check_circle,
                      ),
                    ),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: buildStatCard(
                    'Total Messages',
                    '$totalMessages',
                    Colors.blue,
                    Icons.message,
                    onTap:
                        () => _showMessagesDialog(context, selectedTimeFrame),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: buildStatCard(
                    'Total Users',
                    '$totalUsers',
                    Colors.green,
                    Icons.people,
                    onTap: () => _showUsersDialog(context, selectedTimeFrame),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: buildStatCard(
                    'Escalated Messages',
                    '${inq?.allEscalations}',
                    Colors.orange,
                    Icons.warning_amber_rounded,
                    onTap:
                        () => _showEscalatedMessagesDialog(
                          context,
                          selectedTimeFrame,
                        ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: buildStatCard(
                    'Escalation and Resolution Rate Ratio ',
                    '${escalationRate.toStringAsFixed(2)}% : ${resolutionRate.toStringAsFixed(2)}%',

                    Colors.red,
                    Icons.analytics,
                  ),
                ),
              ],
            );
          }
        }

        Widget cardsSection() {
          if (isMobile) {
            return Column(
              children: [
                // SizedBox(
                //   height: 400,
                //   child: LazyLoadWidget(
                //     delay: const Duration(milliseconds: 100),
                //     builder: (context) => buildCategoryDistributionCard(
                //       inq?.categoryDistribution ?? {},
                //       selectedTimeFrame,
                //       context, // Add context parameter
                //     ),
                //   ),
                // ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 400,
                  child: LazyLoadWidget(
                    delay: const Duration(milliseconds: 200),
                    builder:
                        (context) => buildInquiryTrendCard(
                          inq?.inquiryTrend ?? [],
                          selectedTimeFrame,
                          context, // Add context parameter
                          startDate:
                              selectedTimeFrame == 'Custom' ? null : null,
                          endDate: selectedTimeFrame == 'Custom' ? null : null,
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: LazyLoadWidget(
                    delay: const Duration(milliseconds: 300),
                    builder:
                        (context) => buildSystemLogsCard(
                          inq?.recentLogs ?? [],
                          selectedTimeFrame,
                          context, // Add context parameter
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: LazyLoadWidget(
                    delay: const Duration(milliseconds: 400),
                    builder:
                        (context) => buildMessageLogsCard(
                          inq?.msgLogs ?? [],
                          selectedTimeFrame,
                          context, // Add context parameter
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: LazyLoadWidget(
                    delay: const Duration(milliseconds: 400),
                    builder:
                        (context) => buildEscalatedMessagesList(
                          ad?.topEscalatedMessages ?? [],
                          selectedTimeFrame,
                          context, // Add context parameter
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: LazyLoadWidget(
                    delay: const Duration(milliseconds: 400),
                    builder:
                        (context) => buildEscalationsOverTimeCard(
                          inq?.escalationsOverTime ?? [],
                          selectedTimeFrame,
                          context, // Add context parameter
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                GeminiBillingSection(
                  timeFrame: selectedTimeFrame,
                  customDateRange: customDateRange,
                ),
              ],
            );
          } else {
            // Desktop/Tablet layout - same updates
            return Column(
              children: [
                SizedBox(
                  height: 400,
                  child: Row(
                    children: [
                      // Expanded(
                      //   child: LazyLoadWidget(
                      //     delay: const Duration(milliseconds: 100),
                      //     builder: (context) => buildCategoryDistributionCard(
                      //       inq?.categoryDistribution ?? {},
                      //       selectedTimeFrame,
                      //       context,
                      //     ),
                      //   ),
                      // ),
                      Expanded(
                        child: LazyLoadWidget(
                          delay: const Duration(milliseconds: 200),
                          builder:
                              (context) => buildInquiryTrendCard(
                                inq?.inquiryTrend ?? [],
                                selectedTimeFrame,
                                context,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: LazyLoadWidget(
                          delay: const Duration(milliseconds: 300),
                          builder:
                              (context) => buildSystemLogsCard(
                                inq?.recentLogs ?? [],
                                selectedTimeFrame,
                                context,
                              ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: LazyLoadWidget(
                          delay: const Duration(milliseconds: 400),
                          builder:
                              (context) => buildMessageLogsCard(
                                inq?.msgLogs ?? [],
                                selectedTimeFrame,
                                context,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: LazyLoadWidget(
                          delay: const Duration(milliseconds: 300),
                          builder:
                              (context) => buildEscalationsOverTimeCard(
                                inq?.escalationsOverTime ?? [],
                                selectedTimeFrame,
                                context,
                              ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      Expanded(
                        flex: 1,
                        child: LazyLoadWidget(
                          delay: const Duration(milliseconds: 400),
                          builder:
                              (context) => buildEscalatedMessagesList(
                                ad?.topEscalatedMessages ?? [],
                                selectedTimeFrame,
                                context,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GeminiBillingSection(
                  timeFrame: selectedTimeFrame,
                  customDateRange: customDateRange,
                ),
              ],
            );
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeaderCard(
                selectedTimeFrame: selectedTimeFrame,
                onTimeFrameChanged: onTimeFrameChanged,
                isRefreshing: isRefreshing,
                userName: userName,
                customDateRange: customDateRange,
                onDateRangeChanged: onDateRangeChanged,
                inq: inq,
                ud: ud,
                ad: ad,
                isMobile: isMobile,
              ),
              const SizedBox(height: 20),
              statCards(),
              const SizedBox(height: 20),
              cardsSection(),
            ],
          ),
        );
      },
    ),
  );
}

void _showMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Total Messages',
          headerColor: Colors.blue,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            final snapshot =
                await FirebaseFirestore.instance
                    .collectionGroup('messages')
                    .where('sender', isEqualTo: 'user')
                    .where('sent_at', isGreaterThanOrEqualTo: startDate)
                    .orderBy('sent_at', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['sent_at'] as Timestamp?;
              return {
                'Message': data['text'] ?? 'N/A',
                'Category': data['category'] ?? 'General',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showAnsweredMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Answered Messages',
          headerColor: Colors.green,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            final snapshot =
                await FirebaseFirestore.instance
                    .collectionGroup('messages')
                    .where('sender', isEqualTo: 'user')
                    .where('isAnswered', isEqualTo: true)
                    .where('sent_at', isGreaterThanOrEqualTo: startDate)
                    .orderBy('sent_at', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['sent_at'] as Timestamp?;
              return {
                'Message': data['text'] ?? 'N/A',
                'Category': data['category'] ?? 'General',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showUsersDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Total Users',
          headerColor: Colors.red,
          dataFetcher: (page, pageSize) async {
            Query query = FirebaseFirestore.instance.collection('users');

            if (timeFrame != 'All') {
              final startDate = _getStartDateForDialog(timeFrame);
              query = query.where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              );
            }

            final snapshot =
                await query
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Name': data['name'] ?? 'N/A',
                'Email': data['email'] ?? 'N/A',
                'Program': data['program'] ?? 'N/A',
                'Year': data['year']?.toString() ?? 'N/A',
                'Joined':
                    timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

DateTime _getStartDateForDialog(String timeFrame) {
  final now = DateTime.now();
  return switch (timeFrame) {
    'All' => DateTime(2000, 1, 1),
    'Today' => DateTime(now.year, now.month, now.day),
    'This Week' => now.subtract(Duration(days: now.weekday - 1)),
    'This Month' => DateTime(now.year, now.month, 1),
    'This Year' => DateTime(now.year, 1, 1),
    _ => DateTime(now.year, now.month, 1),
  };
}

String _formatTimestamp(Timestamp timestamp) {
  final date = timestamp.toDate();
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

Widget _buildHeader(
  String selectedTimeFrame,
  ValueChanged<String> onTimeFrameChanged,
  VoidCallback onRefresh,
  bool isRefreshing,
  String userName,
  DateTimeRange? customDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
  //  ADD THESE PARAMETERS
  InquiryReportsData? inq,
  UserDemographicsReportsData? ud,
  AdminDashboardData? ad,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $userName!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CustomDropdownButton(
                          items: [
                            'All',
                            'Today',
                            'This Week',
                            'This Month',
                            'This Year',
                            'Custom',
                          ],
                          initialValue: selectedTimeFrame,
                          onChanged: onTimeFrameChanged,
                        ),
                      ),
                      if (selectedTimeFrame == 'Custom') ...[
                        const SizedBox(width: 8),
                        DateRangeFilter(
                          selectedDateRange: customDateRange,
                          onDateRangeChanged: onDateRangeChanged,
                        ),
                      ],
                      //  ADD EXPORT BUTTON
                      const SizedBox(width: 8),
                      ExportButton(
                        pageType: 'dashboard',
                        timeFrame: selectedTimeFrame,
                        userName: userName,
                        inq: inq,
                        ud: ud,
                        ad: ad,
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Welcome back, $userName!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      CustomDropdownButton(
                        items: [
                          'All',
                          'Today',
                          'This Week',
                          'This Month',
                          'This Year',
                          'Custom',
                        ],
                        initialValue: selectedTimeFrame,
                        onChanged: onTimeFrameChanged,
                      ),
                      if (selectedTimeFrame == 'Custom') ...[
                        const SizedBox(width: 12),
                        DateRangeFilter(
                          selectedDateRange: customDateRange,
                          onDateRangeChanged: onDateRangeChanged,
                        ),
                      ],
                      //  ADD EXPORT BUTTON
                      const SizedBox(width: 12),
                      ExportButton(
                        pageType: 'dashboard',
                        timeFrame: selectedTimeFrame,
                        userName: userName,
                        inq: inq,
                        ud: ud,
                        ad: ad,
                      ),
                    ],
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 12 : 8),
          Text(
            selectedTimeFrame == 'Custom' && customDateRange != null
                ? "Here's an overview of student inquiries from ${_formatDate(customDateRange.start)} to ${_formatDate(customDateRange.end)}."
                : "Here's an overview of recent student inquiries for $selectedTimeFrame.",
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
          ),
        ],
      );
    },
  );
}

void _showEscalatedMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Escalated Messages',
          headerColor: Colors.orange,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('escalations')
                    .where('createdAt', isGreaterThanOrEqualTo: startDate)
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Message': data['question'] ?? 'N/A',
                'Status': data['status'] ?? 'N/A',
                'User': data['userId']?['name'] ?? 'N/A',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

// ============================================================================
// _ModernStatCard
// ============================================================================
class _ModernStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color lightColor;
  final VoidCallback? onTap;

  const _ModernStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.lightColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: isMobile ? 18 : 20),
                  ),
                  if (onTap != null)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _kPageBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: _kTextSecondary,
                      ),
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 19 : 23,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                height: 3,
                width: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _SectionLabel
// ============================================================================
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _DashboardHeaderCard
// ============================================================================
class _DashboardHeaderCard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final bool isRefreshing;
  final String userName;
  final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final InquiryReportsData? inq;
  final UserDemographicsReportsData? ud;
  final AdminDashboardData? ad;
  final bool isMobile;

  const _DashboardHeaderCard({
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.isRefreshing,
    required this.userName,
    required this.customDateRange,
    required this.onDateRangeChanged,
    required this.inq,
    required this.ud,
    required this.ad,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final subtitle =
        selectedTimeFrame == 'Custom' && customDateRange != null
            ? 'Showing data from ${_formatDate(customDateRange!.start)} to ${_formatDate(customDateRange!.end)}'
            : 'Overview of OASP Assist — $selectedTimeFrame';

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kNavy, _kSlate],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + controls row
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _greetingBlock(greeting),
                  const SizedBox(height: 16),
                  _controlsRow(context),
                ],
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_greetingBlock(greeting), _controlsRow(context)],
              ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.12), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.45),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _greetingBlock(String greeting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.55),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Text(
              userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kAccent.withOpacity(0.45), width: 1),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA5B4FC),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _controlsRow(BuildContext context) {
    return Row(
      children: [
        CustomDropdownButton(
          items: [
            'All',
            'Today',
            'This Week',
            'This Month',
            'This Year',
            'Custom',
          ],
          initialValue: selectedTimeFrame,
          onChanged: onTimeFrameChanged,
        ),
        if (selectedTimeFrame == 'Custom') ...[
          const SizedBox(width: 8),
          DateRangeFilter(
            selectedDateRange: customDateRange,
            onDateRangeChanged: onDateRangeChanged,
          ),
        ],
        const SizedBox(width: 8),
        ExportButton(
          pageType: 'dashboard',
          timeFrame: selectedTimeFrame,
          inq: inq,
          ud: ud,
          ad: ad,
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    '',
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
  return '${date.day} ${months[date.month]} ${date.year}';
}
