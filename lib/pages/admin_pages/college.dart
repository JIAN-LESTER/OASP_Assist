import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
import 'package:capstone_project/modal_pages/modal_widget/top_right_alert.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/pages/admin_pages/widgets/empty_state.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:flutter/material.dart';

class CollegeManagementPage extends StatefulWidget {
  const CollegeManagementPage({super.key});

  @override
  State<CollegeManagementPage> createState() => _CollegeManagementPageState();
}

class _CollegeManagementPageState extends State<CollegeManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  int currentPage = 1;
  int itemsPerPage = 10;
  bool isLoading = true;
  final StatDataManagement statData = StatDataManagement();
  ProgramData? program;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    loadStatData();
  }

  Future<void> loadStatData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final data = await statData.getProgramData();
      if (!mounted) return;
      setState(() {
        program = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading program data: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
      SnackbarUtil.showError(context, "Failed to load program data");
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() => currentPage = 1);
  void _goToPage(int page) => setState(() => currentPage = page);
  void _changeItemsPerPage(int newItemsPerPage) {
    setState(() {
      itemsPerPage = newItemsPerPage;
      currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ResponsiveLayout(
      mobileBody: MobileCollegeManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        program: program,
      ),
      tabletBody: TabletCollegeManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        program: program,
      ),
      desktopBody: DesktopCollegeManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        program: program,
      ),
    );
  }
}

class DesktopCollegeManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ProgramData? program;

  const DesktopCollegeManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.program,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      context,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      program,
    );
  }
}

class TabletCollegeManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ProgramData? program;

  const TabletCollegeManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.program,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      context,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      program,
    );
  }
}

class MobileCollegeManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ProgramData? program;

  const MobileCollegeManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.program,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMobileHeader(searchController, context, program),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(16),
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
                        stream: FirebaseFirestore.instance
                            .collection('colleges')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              SnackbarUtil.showError(
                                context,
                                'Error loading colleges: ${snapshot.error}',
                              );
                            });
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return buildEmptyState(false, false, "colleges");
                          }
                          return _buildCollegeList(
                            allColleges: snapshot.data!.docs,
                            searchQuery: searchController.text,
                            currentPage: currentPage,
                            itemsPerPage: itemsPerPage,
                            onPageChanged: onPageChanged,
                            onItemsPerPageChanged: onItemsPerPageChanged,
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
}

Widget mainContent(
  BuildContext context,
  TextEditingController searchController,
  int currentPage,
  int itemsPerPage,
  ValueChanged<int> onPageChanged,
  ValueChanged<int> onItemsPerPageChanged,
  double padding,
  ProgramData? program,
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(searchController, context, program),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
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
                      stream: FirebaseFirestore.instance
                          .collection('colleges')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            SnackbarUtil.showError(
                              context,
                              'Error loading colleges: ${snapshot.error}',
                            );
                          });
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return buildEmptyState(false, false, "colleges");
                        }
                        return _buildCollegeList(
                          allColleges: snapshot.data!.docs,
                          searchQuery: searchController.text,
                          currentPage: currentPage,
                          itemsPerPage: itemsPerPage,
                          onPageChanged: onPageChanged,
                          onItemsPerPageChanged: onItemsPerPageChanged,
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

Widget _buildMobileHeader(
  TextEditingController searchController,
  BuildContext context,
  ProgramData? program,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Colleges Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage academic colleges',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          AddCollegeButton(
            onPressed: () => showAddEditCollegeModal(context, null),
          ),
        ],
      ),
      const SizedBox(height: 16),
      buildSearchField('Search colleges by name', searchController),
    ],
  );
}

Widget _buildCollegeList({
  required List<DocumentSnapshot> allColleges,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  final filtered = allColleges.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString().toLowerCase();
    return searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());
  }).toList();

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageColleges = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child: currentPageColleges.isEmpty
            ? const Center(
                child: Text('No colleges match your search criteria.'),
              )
            : ListView.separated(
                itemCount: currentPageColleges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = currentPageColleges[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildCollegeRow(
                    context: context,
                    doc: doc,
                    name: data['name'] ?? 'N/A',
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
          item: 'colleges',
        ),
    ],
  );
}

Widget _buildCollegeRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String name,
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;
  bool isTablet = screenWidth >= 600 && screenWidth < 1100;

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[200]!),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap: () => showCollegeInfoModal(context, doc),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance,
              color: const Color(0xFF2E7D32),
              size: isMobile ? 20 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showAddEditCollegeModal(context, doc);
              } else if (value == 'delete') {
                showDeleteCollegeModal(context, doc);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
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

Widget _buildHeader(
  TextEditingController searchController,
  BuildContext context,
  ProgramData? program,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colleges Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage academic colleges',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              AddCollegeButton(
                onPressed: () => showAddEditCollegeModal(context, null),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: isMobile
                ? Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      buildStatCard(
                        'Total Colleges',
                        '${program?.totalProgram}',
                        Colors.blue,
                        Icons.account_balance,
                      ),
                      buildStatCard(
                        'College with Most Programs',
                        '${program?.dominantProgram}',
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: buildStatCard(
                          'Total Colleges',
                          '${program?.totalProgram}',
                          Colors.blue,
                          Icons.account_balance,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildStatCard(
                          'College with Most Programs',
                          '${program?.dominantProgram}',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
          ),
          buildSearchField('Search colleges by name', searchController),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'College Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 40),
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
            Icon(
              Icons.account_balance,
              color: Colors.grey[600],
              size: isMobile ? 20 : 24,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'College Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 60 : 80),
          ],
        ),
      );
    },
  );
}

// ==================== ADD COLLEGE BUTTON ====================
class AddCollegeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const AddCollegeButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        double height = isMobile ? 44 : (isTablet ? 46 : 48);
        double fontSize = isMobile ? 13 : (isTablet ? 14 : 15);
        double horizontalPadding = isMobile ? 16 : (isTablet ? 18 : 20);
        double iconSize = isMobile ? 18 : (isTablet ? 20 : 22);

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: isMobile ? 2 : 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: iconSize),
                    const SizedBox(width: 8),
                    Text(
                      isMobile ? 'Add' : 'Add College',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== COLLEGE INFO MODAL ====================
void showCollegeInfoModal(BuildContext context, DocumentSnapshot collegeDoc) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'College Info',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return CollegeInfoModal(collegeDoc: collegeDoc);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

class CollegeInfoModal extends StatelessWidget {
  final DocumentSnapshot collegeDoc;
  const CollegeInfoModal({super.key, required this.collegeDoc});

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final months = [
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
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • ${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final data = collegeDoc.data() as Map<String, dynamic>;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'College Details',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'College information',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.9),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 20 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionHeader(
                      'College Information',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      Icons.account_balance_outlined,
                      'College Name',
                      data['name'] ?? 'N/A',
                    ),
                    const SizedBox(height: 24),
                    buildSectionHeader('Metadata', Icons.access_time),
                    const SizedBox(height: 12),
                    if (data['createdAt'] != null)
                      _buildInfoItem(
                        Icons.calendar_today_outlined,
                        'Created',
                        _formatTimestamp(data['createdAt']),
                      ),
                    if (data['updatedAt'] != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoItem(
                        Icons.update_outlined,
                        'Last Updated',
                        _formatTimestamp(data['updatedAt']),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showDeleteCollegeModal(context, collegeDoc);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(
                            color: Color(0xFFDC2626),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showAddEditCollegeModal(
                            context,
                            collegeDoc,
                            previousModal: 'info',
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DELETE COLLEGE MODAL ====================
void showDeleteCollegeModal(BuildContext context, DocumentSnapshot collegeDoc) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Delete College',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return DeleteCollegeModal(collegeDoc: collegeDoc);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

class DeleteCollegeModal extends StatefulWidget {
  final DocumentSnapshot collegeDoc;
  const DeleteCollegeModal({super.key, required this.collegeDoc});

  @override
  State<DeleteCollegeModal> createState() => _DeleteCollegeModalState();
}

class _DeleteCollegeModalState extends State<DeleteCollegeModal> {
  bool _isDeleting = false;

  Future<void> _deleteCollege() async {
    setState(() => _isDeleting = true);
    final data = widget.collegeDoc.data() as Map<String, dynamic>;

    try {
      await FirebaseFirestore.instance
          .collection('colleges')
          .doc(widget.collegeDoc.id)
          .delete();

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          actorName = userData['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Deleted college: ${data['name']}',
        'time': Timestamp.now(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        SnackbarUtil.showSuccess(context, 'College deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        SnackbarUtil.showError(context, 'Failed to delete college: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.collegeDoc.data() as Map<String, dynamic>;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Delete College',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Are you sure you want to delete this college?',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'College:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['name'] ?? 'Unknown College',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: const Color(0xFF1F2937),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: isMobile ? 40 : 46,
                          child: OutlinedButton(
                            onPressed:
                                _isDeleting ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(
                                  color: Color(0xFFD1D5DB), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: isMobile ? 40 : 46,
                          child: ElevatedButton(
                            onPressed: _isDeleting ? null : _deleteCollege,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              disabledBackgroundColor: const Color(0xFFFCA5A5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isDeleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ADD/EDIT COLLEGE MODAL ====================
void showAddEditCollegeModal(
  BuildContext context,
  DocumentSnapshot? collegeDoc, {
  String? previousModal,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: collegeDoc == null ? 'Add College' : 'Edit College',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AddEditCollegeModal(
        collegeDoc: collegeDoc,
        previousModal: previousModal,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

class AddEditCollegeModal extends StatefulWidget {
  final DocumentSnapshot? collegeDoc;
  final String? previousModal;
  const AddEditCollegeModal({super.key, this.collegeDoc, this.previousModal});

  @override
  State<AddEditCollegeModal> createState() => _AddEditCollegeModalState();
}

class _AddEditCollegeModalState extends State<AddEditCollegeModal> {
  late TextEditingController _nameController;
  bool _isSubmitting = false;

  bool get isEditing => widget.collegeDoc != null;

  @override
  void initState() {
    super.initState();
    if (widget.collegeDoc != null) {
      final data = widget.collegeDoc!.data() as Map<String, dynamic>;
      _nameController = TextEditingController(text: data['name'] ?? '');
    } else {
      _nameController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCollege() async {
    if (_nameController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please enter a college name');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final collegeData = {
        'name': _nameController.text.trim(),
        'updatedAt': Timestamp.now(),
      };

      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('colleges')
            .doc(widget.collegeDoc!.id)
            .update(collegeData);
      } else {
        collegeData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('colleges').add(collegeData);
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          actorName = userData['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action':
            '${isEditing ? 'Updated' : 'Created'} college: ${_nameController.text.trim()}',
        'time': Timestamp.now(),
      });

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'College ${isEditing ? 'updated' : 'created'} successfully!',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        SnackbarUtil.showError(
          context,
          'Failed to ${isEditing ? 'update' : 'create'} college: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                child: Row(
                  children: [
                    if (widget.previousModal == 'info') ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                showCollegeInfoModal(
                                  context,
                                  widget.collegeDoc!,
                                );
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_document : Icons.add_circle_outline,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit College' : 'Add New College',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEditing
                                ? 'Update college information'
                                : 'Create a new college',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildSectionHeader(
                        'College Information',
                        Icons.account_balance_outlined,
                      ),
                      const SizedBox(height: 16),
                      buildTextField(
                        controller: _nameController,
                        label: 'College Name',
                        hint: 'e.g., College of Computer Studies',
                        icon: Icons.account_balance_outlined,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: isMobile ? 44 : 48,
                        child: OutlinedButton(
                          onPressed:
                              _isSubmitting ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(
                              color: Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: isMobile ? 44 : 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveCollege,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Saving...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEditing ? 'Save Changes' : 'Create College',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}