
import 'package:capstone_project/widgets/date_range_filter.dart';
import 'package:capstone_project/widgets/empty_state.dart';
import 'package:capstone_project/widgets/pagination.dart';
import 'package:capstone_project/widgets/search_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/models/message_logs.dart';
import 'package:capstone_project/modules/admin/logs/log_info.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class AdminMessageLogsPage extends StatefulWidget {
  const AdminMessageLogsPage({super.key});

  @override
  State<AdminMessageLogsPage> createState() => _AdminMessageLogsPageState();
}

class _AdminMessageLogsPageState extends State<AdminMessageLogsPage> {
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
            content: const Text('Message logs refreshed'),
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
      mobileBody: MobileAdminMessageLogsPage(
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
      tabletBody: TabletAdminMessageLogsPage(
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
      desktopBody: DesktopAdminMessageLogsPage(
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

class DesktopAdminMessageLogsPage extends StatefulWidget {
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

  const DesktopAdminMessageLogsPage({
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
  State<DesktopAdminMessageLogsPage> createState() =>
      _DesktopAdminMessageLogsPageState();
}

class _DesktopAdminMessageLogsPageState
    extends State<DesktopAdminMessageLogsPage> {
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

class TabletAdminMessageLogsPage extends StatefulWidget {
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

  const TabletAdminMessageLogsPage({
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
  State<TabletAdminMessageLogsPage> createState() =>
      _TabletAdminMessageLogsPageState();
}

class _TabletAdminMessageLogsPageState
    extends State<TabletAdminMessageLogsPage> {
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

class MobileAdminMessageLogsPage extends StatefulWidget {
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

  const MobileAdminMessageLogsPage({
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
  State<MobileAdminMessageLogsPage> createState() =>
      _MobileAdminMessageLogsPageState();
}

class _MobileAdminMessageLogsPageState
    extends State<MobileAdminMessageLogsPage> {
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
                    'Message Logs',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track user messages to the system',
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
                    'user or message',
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
                      'user or message',
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

/// Reusable MainContent widget builder (stateless)
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
    backgroundColor: const Color(0xFFF0F4F8),
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
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    spreadRadius: 0,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTableHeader(),
                  const SizedBox(height: 6),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('message_logs')
                              .orderBy('time', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return buildEmptyState(
                            isLoading,
                            true,
                            'Message Logs',
                          );
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

Widget _buildTableHeader() {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      if (isMobile) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
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
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Message',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
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
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 48),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 9 : 10,
          horizontal: isTablet ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'User',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Message',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
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
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 48),
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
  // Fixed filtering logic
  final filtered =
      allLogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        final Timestamp timestamp = data['time'] ?? Timestamp.now();
        final DateTime logDate = timestamp.toDate();
        final String formattedTime = DateFormat(
          'yyyy-MM-dd hh:mm a',
        ).format(logDate);

        final log = MessageLogs(
          id: data['logId']?.toString().toLowerCase() ?? 'n/a',
          user: data['user']?.toString().toLowerCase() ?? 'n/a',
          message: data['message']?.toString().toLowerCase() ?? '-',
          reply: data['reply']?.toString().toLowerCase() ?? '-',
          time: formattedTime.toLowerCase(),
        );

        // Fixed search filter - search across all relevant fields
        final String query = searchQuery.toLowerCase();

        final bool matchesSearch =
            query.isEmpty ||
            log.id.contains(query) ||
            log.user.contains(query) ||
            log.message.contains(query) ||
            log.time.contains(query);
        // Fixed date range filter
        bool matchesDateRange = true;
        if (selectedDateRange != null) {
          // Normalize dates to compare only the date part (ignore time)
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
            999, // End of day
          );
          final logDateNormalized = DateTime(
            logDate.year,
            logDate.month,
            logDate.day,
            logDate.hour,
            logDate.minute,
            logDate.second,
            logDate.millisecond,
          );

          matchesDateRange =
              logDateNormalized.isAfter(
                startDate.subtract(Duration(milliseconds: 1)),
              ) &&
              logDateNormalized.isBefore(
                endDate.add(Duration(milliseconds: 1)),
              );
        }

        return matchesSearch && matchesDateRange;
      }).toList();

  // Sort by time (newest first)
  filtered.sort((a, b) {
    final aTime = (a.data() as Map<String, dynamic>)['time'] as Timestamp;
    final bTime = (b.data() as Map<String, dynamic>)['time'] as Timestamp;
    return bTime.compareTo(aTime);
  });

  // Calculate pagination
  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  // Pagination
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageLogs = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      // Logs List
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
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final doc = currentPageLogs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp timestamp = data['time'] ?? Timestamp.now();
                    final DateTime logDate = timestamp.toDate();
                    final String formattedTime = DateFormat(
                      "MMMM d, yyyy 'at' h:mm a",
                    ).format(logDate);

                    final msglogs = MessageLogs(
                      id: data['logId'] ?? 'N/A',
                      user: data['user'] ?? 'N/A',
                      message: data['message'] ?? '-',
                      reply: data['reply'] ?? '-',
                      time: formattedTime,
                    );

                    return _buildLogsRow(
                      context: context,
                      doc: doc,
                      index: index,
                      msglogs: msglogs,
                      messages: messages,
                    );
                  },
                ),
      ),

      // Pagination
      if (totalItems > 0)
        buildPagination(
          currentPage: safeCurrentPage,
          totalPages: totalPages,
          totalItems: totalItems,
          itemsPerPage: itemsPerPage,
          onPageChanged: onPageChanged,
          onItemsPerPageChanged: onItemsPerPageChanged,
          item: 'message logs',
        ),
    ],
  );
}

Widget _buildLogsRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required int index,
  required MessageLogs msglogs,
  required List<Map<String, dynamic>> messages,
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
      border: Border.all(color: Colors.grey[200]!),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap:
          () => showLogsInfoModal(
            context,
            doc,
            messages,
            true,
            showDeleteButton: true,
          ),
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
                  msglogs.user,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (!isMobile && msglogs.id.isNotEmpty && msglogs.id != 'N/A')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "Log ID: $msglogs.id",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
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
                  color: getActionColor(msglogs.message),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Sent a message: ${msglogs.message}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Timestamp
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msglogs.time,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
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
                showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.msgLog,
                  'message_logs',
                );
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
