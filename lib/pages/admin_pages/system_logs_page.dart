import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/colors.dart';
import 'package:capstone_project/modal_pages/log_info.dart';
import 'package:capstone_project/models/logs.dart';
import 'package:capstone_project/pages/admin_pages/widgets/date_range_filter.dart';
import 'package:capstone_project/pages/admin_pages/widgets/empty_state.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

import '../../crud/delete/delete.dart';

class UserActivityLogsPage extends StatefulWidget {
  const UserActivityLogsPage({super.key});

  @override
  State<UserActivityLogsPage> createState() => _UserActivityLogsPageState();
}

class _UserActivityLogsPageState extends State<UserActivityLogsPage> {
  DateTimeRange? selectedDateRange;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;
  String selectedRole = 'All Logs';
  int currentPage = 1;
  int itemsPerPage = 10;
  final List<Map<String, dynamic>> messages = [];

  void _onDateRangeChanged(DateTimeRange? dateRange) {
    setState(() {
      selectedDateRange = dateRange;
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      currentPage = page;
    });
  }

  void _onItemsPerPageChanged(int items) {
    setState(() {
      itemsPerPage = items;
      currentPage = 1; // Reset to first page when changing items per page
    });
  }

  void _onRefresh() {
    setState(() {
      isLoading = true;
    });

    // Simulate loading for empty state
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Activity logs refreshed'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: 16,
              right: 16,
              left: MediaQuery.of(context).size.width - 350,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: MobileUserActivityLogs(
        selectedDateRange: selectedDateRange,
        onDateRangeChanged: _onDateRangeChanged,
        searchController: _searchController,
        onRefresh: _onRefresh,
        isLoading: isLoading,

        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _onPageChanged,
        onItemsPerPageChanged: _onItemsPerPageChanged,
        messages: messages,
      ),
      tabletBody: TabletUserActivityLogs(
        selectedDateRange: selectedDateRange,
        onDateRangeChanged: _onDateRangeChanged,
        searchController: _searchController,
        onRefresh: _onRefresh,
        isLoading: isLoading,

        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _onPageChanged,
        onItemsPerPageChanged: _onItemsPerPageChanged,
        messages: messages,
      ),
      desktopBody: DesktopUserActivityLogs(
        selectedDateRange: selectedDateRange,
        onDateRangeChanged: _onDateRangeChanged,
        searchController: _searchController,
        onRefresh: _onRefresh,
        isLoading: isLoading,

        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _onPageChanged,
        onItemsPerPageChanged: _onItemsPerPageChanged,
        messages: messages,
      ),
    );
  }
}

// Desktop User Activity Logs
class DesktopUserActivityLogs extends StatefulWidget {
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final bool isLoading;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final List<Map<String, dynamic>> messages;

  const DesktopUserActivityLogs({
    super.key,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
    required this.searchController,
    required this.onRefresh,
    required this.isLoading,

    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.messages,
  });

  @override
  State<DesktopUserActivityLogs> createState() =>
      _DesktopUserActivityLogsState();
}

class _DesktopUserActivityLogsState extends State<DesktopUserActivityLogs> {
  @override
  Widget build(BuildContext context) {
    return mainContent(
      widget.selectedDateRange,
      widget.onDateRangeChanged,
      widget.searchController,
      () {
        widget.onRefresh();
        setState(() {}); // ✅ refresh handled here
      },
      widget.isLoading,

      widget.currentPage,
      widget.itemsPerPage,
      widget.onPageChanged,
      widget.onItemsPerPageChanged,
      widget.messages,
      context,
      24.0,

      () => setState(() {}), // ✅ search handled here
    );
  }
}

class TabletUserActivityLogs extends StatefulWidget {
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final bool isLoading;

  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final List<Map<String, dynamic>> messages;

  const TabletUserActivityLogs({
    super.key,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
    required this.searchController,
    required this.onRefresh,
    required this.isLoading,

    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.messages,
  });

  @override
  State<TabletUserActivityLogs> createState() => _TabletUserActivityLogsState();
}

class _TabletUserActivityLogsState extends State<TabletUserActivityLogs> {
  @override
  Widget build(BuildContext context) {
    return mainContent(
      widget.selectedDateRange,
      widget.onDateRangeChanged,
      widget.searchController,
      () {
        widget.onRefresh();
        setState(() {}); // ✅ refresh handled here
      },
      widget.isLoading,

      widget.currentPage,
      widget.itemsPerPage,
      widget.onPageChanged,
      widget.onItemsPerPageChanged,
      widget.messages,
      context,
      20.0,

      () => setState(() {}), // ✅ search handled here
    );
  }
}

// Mobile User Activity Logs
class MobileUserActivityLogs extends StatefulWidget {
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final bool isLoading;

  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final List<Map<String, dynamic>> messages;

  const MobileUserActivityLogs({
    super.key,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
    required this.searchController,
    required this.onRefresh,
    required this.isLoading,

    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.messages,
  });

  @override
  State<MobileUserActivityLogs> createState() => _MobileUserActivityLogsState();
}

class _MobileUserActivityLogsState extends State<MobileUserActivityLogs> {
  @override
  Widget build(BuildContext context) {
    return mainContent(
      widget.selectedDateRange,
      widget.onDateRangeChanged,
      widget.searchController,
      () {
        widget.onRefresh();
        setState(() {}); // ✅ refresh handled here
      },
      widget.isLoading,

      widget.currentPage,
      widget.itemsPerPage,
      widget.onPageChanged,
      widget.onItemsPerPageChanged,
      widget.messages,
      context,
      16.0,

      () => setState(() {}), // ✅ search handled here
    );
  }
}

Widget mainContent(
  DateTimeRange? selectedDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
  TextEditingController searchController,
  VoidCallback onRefresh,
  bool isLoading,
  int currentPage,
  int itemsPerPage,
  ValueChanged<int> onPageChanged,
  ValueChanged<int> onItemsPerPageChanged,
  List<Map<String, dynamic>> messages,
  BuildContext context,
  double padding,
  VoidCallback onSearchChanged, // 🔹 new param instead of setState
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            selectedDateRange,
            onDateRangeChanged,
            searchController,
            onRefresh, // 🔹 handled outside
            onSearchChanged, // 🔹 handled outside
          ),

          const SizedBox(height: 16),
          Expanded(

          child: Container(
            height: MediaQuery.of(context).size.height - 200,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTableHeader(),
                const SizedBox(height: 10),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('logs')
                            .orderBy('time', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return buildEmptyState(isLoading, true, 'Logs');
                      }

                      return _buildLogsList(
                        allLogs: snapshot.data!.docs,

                        searchQuery: searchController.text,
                        selectedDateRange: selectedDateRange,
                        currentPage: currentPage,
                        itemsPerPage: itemsPerPage,
                        onPageChanged: onPageChanged,
                        onItemsPerPageChanged: onItemsPerPageChanged,
                        messages: messages,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHeader(
  DateTimeRange? selectedDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
  TextEditingController searchController,
  VoidCallback onRefresh,
  VoidCallback onSearchChanged,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Refresh Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Activity Logs',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track user interactions and system events',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh,
                  size: isMobile ? 16 : 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Search and Filter Row
          isMobile
              ? Column(
                children: [
                  buildSearchField(
                    'user or actions',
                    searchController,
                    onSearchChanged: onSearchChanged,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DateRangeFilter(
                          selectedDateRange: selectedDateRange,
                          onDateRangeChanged: onDateRangeChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: buildSearchField(
                      'user or actions',
                      searchController,
                      onSearchChanged: onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                  DateRangeFilter(
                    selectedDateRange: selectedDateRange,
                    onDateRangeChanged: onDateRangeChanged,
                  ),
                ],
              ),
        ],
      );
    },
  );
}

Widget _buildTableHeader() {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      if (isMobile) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'User',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Action',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Time',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 14 : 16,
          horizontal: isTablet ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                'User',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Action',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                'Time',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildLogsList({
  required List<DocumentSnapshot> allLogs,

  required String searchQuery,
  required DateTimeRange? selectedDateRange,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required List<Map<String, dynamic>> messages,
}) {
  final filtered =
      allLogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        final Timestamp timestamp = data['time'] ?? Timestamp.now();
        final DateTime logDate = timestamp.toDate();
        final String formattedTime = DateFormat(
          'yyyy-MM-dd hh:mm a',
        ).format(logDate);

        final log = Logs(
          id: data['logId']?.toString().toLowerCase() ?? 'n/a',
          user: data['user']?.toString().toLowerCase() ?? 'n/a',
          action: data['action']?.toString().toLowerCase() ?? '-',
          time: formattedTime.toLowerCase(),
        );

        final String query = searchQuery.toLowerCase();

        final bool matchesSearch =
            query.isEmpty ||
            log.id.contains(query) ||
            log.user.contains(query) ||
            log.action.contains(query) ||
            log.time.contains(query);

        bool matchesDateRange = true;
        if (selectedDateRange != null) {
          final startDate = DateTime(
            selectedDateRange.start.year,
            selectedDateRange.start.month,
            selectedDateRange.start.day,
          );
          final endDate = DateTime(
            selectedDateRange.end.year,
            selectedDateRange.end.month,
            selectedDateRange.end.day,
            23,
            59,
            59,
            999,
          );

          matchesDateRange =
              logDate.isAfter(
                startDate.subtract(const Duration(milliseconds: 1)),
              ) &&
              logDate.isBefore(endDate.add(const Duration(milliseconds: 1)));
        }

        return matchesSearch && matchesDateRange;
      }).toList();

  // Sort logs by time (newest first)
  filtered.sort((a, b) {
    final aTime = (a.data() as Map<String, dynamic>)['time'] as Timestamp;
    final bTime = (b.data() as Map<String, dynamic>)['time'] as Timestamp;
    return bTime.compareTo(aTime);
  });

  // Pagination
  final totalItems = filtered.length;
  final totalPages =
      (totalItems / itemsPerPage).ceil().clamp(1, double.infinity).toInt();
  final safeCurrentPage = currentPage.clamp(1, totalPages);
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, totalItems);
  final currentPageLogs = filtered.sublist(startIndex, endIndex);

  return Column(
    children: [
      Expanded(
        child:
            currentPageLogs.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No logs match your search criteria.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      if (searchQuery.isNotEmpty || selectedDateRange != null)
                        const SizedBox(height: 8),
                      if (searchQuery.isNotEmpty || selectedDateRange != null)
                        Text(
                          'Try adjusting your filters or search terms.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                )
                : ListView.separated(
                  itemCount: currentPageLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = currentPageLogs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp timestamp = data['time'] ?? Timestamp.now();
                    final DateTime logDate = timestamp.toDate();
                    final String formattedTime = DateFormat(
                      "MMMM d, yyyy 'at' h:mm a",
                    ).format(logDate);

                    final log = Logs(
                      id: data['logId'] ?? 'N/A',
                      user: data['user'] ?? 'N/A',
                      action: data['action'] ?? '-',
                      time: formattedTime,
                    );

                    return _buildLogsRow(
                      context: context,
                      doc: doc,
                      logs: log,
                      messages: messages,
                    );
                  },
                ),
      ),

      if (totalItems > 0)
        buildPagination(
          currentPage: safeCurrentPage,
          totalPages: totalPages,
          totalItems: totalItems,
          itemsPerPage: itemsPerPage,
          onPageChanged: onPageChanged,
          onItemsPerPageChanged: onItemsPerPageChanged,
          item: 'activity logs',
        ),
    ],
  );
}

Widget _buildLogsRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required Logs logs,
  required List<Map<String, dynamic>> messages,
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[200]!),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: InkWell(
      onTap: () => showLogsInfoModal(context, doc, messages, false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User + Log ID
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  logs.user,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile && logs.id.isNotEmpty && logs.id != 'N/A')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "Log ID: $logs.id",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Action
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: getActionColor(logs.action),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  logs.action,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // Timestamp
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    logs.time,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isMobile && logs.id.isNotEmpty && logs.id != 'N/A')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "ID: $logs.id",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'delete') {
                showDeleteConfirmation(context, doc, DeleteConfigs.log, 'logs');
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
    ),
  );
}
