import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/paginated_list.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/user_demographics_data.dart';
import 'package:capstone_project/modules/admin_module/widgets/date_range_filter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/modules/admin_module/widgets/custom_dropdown_button.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

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
  final DateTime timestamp;
  final Map<String, dynamic>? quickStats;

  DashboardCache({this.inq, this.ud, required this.timestamp, this.quickStats});

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
  State<DashboardPage> createState() => _Dashboardmodulestate();
}

class _Dashboardmodulestate extends State<DashboardPage> {
  String selectedTimeFrame = 'This Month';
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();

  final Map<String, DashboardCache> _cache = {};

  DateTimeRange? customDateRange;
  bool showDateRangePicker = false;

  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;
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
      _firebaseService.getInquiryReportsData(selectedTimeFrame, customDateRange),
      _firebaseService.getUserDemographicsReportsData(selectedTimeFrame, customDateRange),
    ]);

    if (!mounted) return;

    final inquiryData = results[0] as InquiryReportsData;
    final userDemoData = results[1] as UserDemographicsReportsData;

    _cache[selectedTimeFrame] = DashboardCache(
      inq: inquiryData,
      ud: userDemoData,
      timestamp: DateTime.now(),
      quickStats: quickStats,
    );

    setState(() {
      inq = inquiryData;
      ud = userDemoData;
    });
  } catch (e) {
    print('Error fetching data: $e');
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
    return await _firebaseService.getQuickStats(selectedTimeFrame, customDateRange);
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

  // If Custom is selected, just update the UI to show the DateRangeFilter
  if (newValue == 'Custom') {
    if (mounted) {
      setState(() {
        selectedTimeFrame = 'Custom';
        // Keep existing customDateRange if any, otherwise null
      });
    }
    // Don't load data yet - wait for user to select a date range
    return;
  }

  // Normal timeframe selection
  setState(() {
    selectedTimeFrame = newValue;
    customDateRange = null; // Clear custom range when selecting preset
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
    _showSnackBar('Failed to load data for selected date range', isError: true);
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
        backgroundColor: Colors.grey[100],
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
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
      // 📱 MOBILE LAYOUT: Dropdown on the left, smaller arrangement
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
  String userName,
  Map<String, int>? quickStats,
    DateTimeRange? customDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
) {
  final totalMessages = quickStats?['totalMessages'] ?? inq?.totalMessages ?? 0;
  final answeredMessages =
      quickStats?['answered'] ?? inq?.answeredMessages ?? 0;
  final totalUsers = quickStats?['totalUsers'] ?? ud?.totalUsers ?? 0;

  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1100;

        Widget statCards() {
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
                        'Answered Messages',
                        '$answeredMessages',
                        Colors.green,
                        Icons.check_circle,
                        onTap:
                            () => _showAnsweredMessagesDialog(
                              context,
                              selectedTimeFrame,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: buildStatCard(
                        'Total Users',
                        '$totalUsers',
                        Colors.red,
                        Icons.people,
                        onTap:
                            () => _showUsersDialog(context, selectedTimeFrame),
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
                SizedBox(width: isTablet ? 12 : 20),
                Expanded(
                  child: buildStatCard(
                    'Answered Messages',
                    '$answeredMessages',
                    Colors.green,
                    Icons.check_circle,
                    onTap:
                        () => _showAnsweredMessagesDialog(
                          context,
                          selectedTimeFrame,
                        ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 20),
                Expanded(
                  child: buildStatCard(
                    'Total Users',
                    '$totalUsers',
                    Colors.red,
                    Icons.people,
                    onTap: () => _showUsersDialog(context, selectedTimeFrame),
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
            builder: (context) => buildInquiryTrendCard(
              inq?.inquiryTrend ?? [],
              selectedTimeFrame,
              context, // Add context parameter
              startDate: selectedTimeFrame == 'Custom' ? null : null,
              endDate: selectedTimeFrame == 'Custom' ? null : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 350,
          child: LazyLoadWidget(
            delay: const Duration(milliseconds: 300),
            builder: (context) => buildSystemLogsCard(
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
            builder: (context) => buildMessageLogsCard(
              inq?.msgLogs ?? [],
              selectedTimeFrame,
              context, // Add context parameter
            ),
          ),
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
                  builder: (context) => buildInquiryTrendCard(
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
                  builder: (context) => buildSystemLogsCard(
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
                  builder: (context) => buildMessageLogsCard(
                    inq?.msgLogs ?? [],
                    selectedTimeFrame,
                    context,
                  ),
                ),
              ),
            ],
          ),
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
              _buildHeader(
                selectedTimeFrame,
                onTimeFrameChanged,
                onRefresh,
                isRefreshing,
                userName,
                customDateRange,
                onDateRangeChanged,
              ),
              const SizedBox(height: 32),
              statCards(),
              const SizedBox(height: 32),
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
    builder: (context) => PaginatedListDialog(
      title: 'Total Messages',
      headerColor: Colors.blue,
      dataFetcher: (page, pageSize) async {
        final startDate = _getStartDateForDialog(timeFrame);
        final snapshot = await FirebaseFirestore.instance
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
            'Date': timestamp != null 
                ? _formatTimestamp(timestamp) 
                : 'N/A',
          };
        }).toList();
      },
    ),
  );
}

void _showAnsweredMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder: (context) => PaginatedListDialog(
      title: 'Answered Messages',
      headerColor: Colors.green,
      dataFetcher: (page, pageSize) async {
        final startDate = _getStartDateForDialog(timeFrame);
        final snapshot = await FirebaseFirestore.instance
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
            'Date': timestamp != null 
                ? _formatTimestamp(timestamp) 
                : 'N/A',
          };
        }).toList();
      },
    ),
  );
}

void _showUsersDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder: (context) => PaginatedListDialog(
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
        
        final snapshot = await query
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
            'Joined': timestamp != null 
                ? _formatTimestamp(timestamp) 
                : 'N/A',
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
                        color: Colors.green,
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


String _formatDate(DateTime date) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month]} ${date.year}';
}