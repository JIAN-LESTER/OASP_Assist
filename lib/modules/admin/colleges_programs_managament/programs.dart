import 'package:capstone_project/modules/admin/dashboard_and_reports/statcard_management.dart';

import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:capstone_project/widgets/empty_state.dart';
import 'package:capstone_project/widgets/pagination.dart';
import 'package:capstone_project/widgets/search_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:flutter/material.dart';

class ProgramManagementPage extends StatefulWidget {
  const ProgramManagementPage({super.key});

  @override
  State<ProgramManagementPage> createState() => _ProgramManagementPageState();
}

class _ProgramManagementPageState extends State<ProgramManagementPage> {
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
      mobileBody: MobileProgramManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        program: program,
      ),
      tabletBody: TabletProgramManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        program: program,
      ),
      desktopBody: DesktopProgramManagement(
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

class DesktopProgramManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ProgramData? program;

  const DesktopProgramManagement({
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

class TabletProgramManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ProgramData? program;

  const TabletProgramManagement({
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

class MobileProgramManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ProgramData? program;

  const MobileProgramManagement({
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
      backgroundColor: const Color(0xFFF0F4F8),
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
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('programs')
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
                                'Error loading programs: ${snapshot.error}',
                              );
                            });
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return buildEmptyState(false, false, "programs");
                          }
                          return _buildProgramList(
                            allPrograms: snapshot.data!.docs,
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
    backgroundColor: const Color(0xFFF0F4F8),
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
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('programs')
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
                              'Error loading programs: ${snapshot.error}',
                            );
                          });
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return buildEmptyState(false, false, "programs");
                        }
                        return _buildProgramList(
                          allPrograms: snapshot.data!.docs,
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
                'Programs Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage academic programs',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          AddProgramButton(
            onPressed: () => showAddEditProgramModal(context, null),
          ),
        ],
      ),
      const SizedBox(height: 16),
      buildSearchField('Search programs by name', searchController),
    ],
  );
}

Widget _buildProgramList({
  required List<DocumentSnapshot> allPrograms,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  final filtered =
      allPrograms.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        return searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());
      }).toList();

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPagePrograms = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child:
            currentPagePrograms.isEmpty
                ? const Center(
                  child: Text('No programs match your search criteria.'),
                )
                : ListView.separated(
                  itemCount: currentPagePrograms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = currentPagePrograms[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildProgramRow(
                      context: context,
                      doc: doc,
                      index: index,
                      name: data['name'] ?? 'N/A',
                      collegeId: data['collegeId'] ?? '',
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
          item: 'programs',
        ),
    ],
  );
}

Widget _buildProgramRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required int index,
  required String name,
  required String collegeId,
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;
  bool isTablet = screenWidth >= 600 && screenWidth < 1100;

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
      border: Border.all(color: Colors.grey[200]!),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap: () => showProgramInfoModal(context, doc),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.school,
              color: const Color(0xFF2E7D32),
              size: isMobile ? 20 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile && collegeId.isNotEmpty)
                  FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('colleges')
                            .doc(collegeId)
                            .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final collegeData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return Text(
                          collegeData['name'] ?? 'Unknown College',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showAddEditProgramModal(context, doc);
              } else if (value == 'delete') {
                showDeleteProgramModal(context, doc);
              }
            },
            itemBuilder:
                (_) => [
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
                    'Programs Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage academic programs',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              AddProgramButton(
                onPressed: () => showAddEditProgramModal(context, null),
              ),
            ],
          ),
          const SizedBox(height: 40),
          buildSearchField('Search programs by name', searchController),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Program Name',
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
          vertical: isTablet ? 14 : 16,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.school, color: Colors.white, size: isMobile ? 20 : 24),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Program Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 60 : 80),
            const SizedBox(width: 48),
          ],
        ),
      );
    },
  );
}

// ==================== ADD PROGRAM BUTTON ====================
class AddProgramButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const AddProgramButton({Key? key, this.onPressed}) : super(key: key);

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
                      isMobile ? 'Add' : 'Add Program',
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

// ==================== PROGRAM INFO MODAL ====================
void showProgramInfoModal(BuildContext context, DocumentSnapshot programDoc) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Program Info',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return ProgramInfoModal(programDoc: programDoc);
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

class ProgramInfoModal extends StatelessWidget {
  final DocumentSnapshot programDoc;
  const ProgramInfoModal({super.key, required this.programDoc});

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
    final data = programDoc.data() as Map<String, dynamic>;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final collegeId = data['collegeId'] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
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
                      Icons.school,
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
                          'Program Details',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Program information',
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
                      'Program Information',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      Icons.school_outlined,
                      'Program Name',
                      data['name'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),

                    if (collegeId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('colleges')
                                .doc(collegeId)
                                .get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final collegeData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            return _buildInfoItem(
                              Icons.account_balance_outlined,
                              'College',
                              collegeData['name'] ?? 'Unknown College',
                            );
                          }
                          return _buildInfoItem(
                            Icons.account_balance_outlined,
                            'College',
                            'Unknown College',
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    buildSectionHeader('Metadata', Icons.access_time),
                    const SizedBox(height: 12),
                    if (data['created_at'] != null)
                      _buildInfoItem(
                        Icons.calendar_today_outlined,
                        'Created',
                        _formatTimestamp(data['created_at']),
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
                        onPressed: () async {
                          final confirmed = await showDeleteProgramModal(
                            context,
                            programDoc,
                          );
                          if (confirmed == true && context.mounted) {
                            Navigator.of(
                              context,
                            ).pop(); // Only close details modal if deleted
                          }
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
                          showAddEditProgramModal(
                            context,
                            programDoc,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DELETE PROGRAM MODAL ====================
Future<bool?> showDeleteProgramModal(
  BuildContext context,
  DocumentSnapshot programDoc,
) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Delete Program',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return DeleteProgramModal(programDoc: programDoc);
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

class DeleteProgramModal extends StatefulWidget {
  final DocumentSnapshot programDoc;
  const DeleteProgramModal({super.key, required this.programDoc});

  @override
  State<DeleteProgramModal> createState() => _DeleteProgramModalState();
}

class _DeleteProgramModalState extends State<DeleteProgramModal> {
  bool _isDeleting = false;

  Future<void> _deleteProgram(BuildContext dialogContext) async {
    setState(() => _isDeleting = true);
    final data = widget.programDoc.data() as Map<String, dynamic>;

    try {
      await FirebaseFirestore.instance
          .collection('programs')
          .doc(widget.programDoc.id)
          .delete();

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';
      if (currentUser != null) {
        final userDoc =
            await FirebaseFirestore.instance
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
        'action': 'Deleted program: ${data['name']}',
        'time': Timestamp.now(),
      });

      if (mounted) {
        Navigator.of(
          dialogContext,
        ).pop(true); // Return true to indicate success
        SnackbarUtil.showSuccess(context, 'Program deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        SnackbarUtil.showError(context, 'Failed to delete program: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.programDoc.data() as Map<String, dynamic>;
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
                    'Delete Program',
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
                    'Are you sure you want to delete this program?',
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
                          'Program:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['name'] ?? 'Unknown Program',
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
                                _isDeleting
                                    ? null
                                    : () => Navigator.of(context).pop(),
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
                            onPressed:
                                _isDeleting
                                    ? null
                                    : () => _deleteProgram(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              disabledBackgroundColor: const Color(0xFFFCA5A5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child:
                                _isDeleting
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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

// ==================== ADD/EDIT PROGRAM MODAL ====================
void showAddEditProgramModal(
  BuildContext context,
  DocumentSnapshot? programDoc, {
  String? previousModal,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: programDoc == null ? 'Add Program' : 'Edit Program',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AddEditProgramModal(
        programDoc: programDoc,
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

class AddEditProgramModal extends StatefulWidget {
  final DocumentSnapshot? programDoc;
  final String? previousModal;
  const AddEditProgramModal({super.key, this.programDoc, this.previousModal});

  @override
  State<AddEditProgramModal> createState() => _AddEditProgramModalState();
}

// ==================== MODIFIED ADD/EDIT PROGRAM MODAL STATE ====================
// ==================== MODIFIED ADD/EDIT PROGRAM MODAL STATE ====================
class _AddEditProgramModalState extends State<AddEditProgramModal> {
  late TextEditingController _nameController;
  bool _isSubmitting = false;
  String? _selectedCollegeId;
  String? _selectedCategory; // NEW: Category field
  List<DocumentSnapshot> _colleges = [];
  bool _loadingColleges = true;
  String? _nameError;
  String? _categoryError;
  String? _collegeError;

  bool get isEditing => widget.programDoc != null;

  @override
  void initState() {
    super.initState();

    // Initialize controller immediately
    _nameController = TextEditingController();

    if (widget.programDoc != null) {
      final data = widget.programDoc!.data() as Map<String, dynamic>;
      final fullName = data['name'] ?? '';
      _selectedCategory = data['category']; // NEW: Load existing category
      _selectedCollegeId = data['collegeId'];

      // Load colleges first, then strip prefix
      _loadColleges().then((_) {
        if (!mounted) return;

        // NEW: Strip the prefix when editing to show only the user input part
        String nameWithoutPrefix = fullName;

        // Check if we should strip the prefix based on college
        bool shouldStripPrefix = true;
        if (_selectedCategory == 'Bachelor' &&
            _selectedCollegeId != null &&
            _selectedCollegeId!.isNotEmpty) {
          try {
            final college = _colleges.firstWhere(
              (c) => c.id == _selectedCollegeId,
            );
            final collegeData = college.data() as Map<String, dynamic>;
            final collegeName = collegeData['name'] ?? '';

            // Don't strip prefix for "Others" or "Veterinary Medicine"
            if (collegeName == 'Others' ||
                collegeName == 'College of Veterinary Medicine') {
              shouldStripPrefix = false;
            }
          } catch (e) {
            // If college not found, strip prefix by default
            shouldStripPrefix = true;
          }
        }

        if (shouldStripPrefix) {
          if (_selectedCategory == 'Bachelor' &&
              fullName.startsWith('Bachelor ')) {
            nameWithoutPrefix = fullName.substring('Bachelor '.length);
          } else if (_selectedCategory == 'Masteral' &&
              fullName.startsWith('Master of ')) {
            nameWithoutPrefix = fullName.substring('Master of '.length);
          }
        }

        setState(() {
          _nameController.text = nameWithoutPrefix;
        });
      });
    } else {
      _loadColleges();
    }
  }

  Future<void> _loadColleges() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('colleges')
              .orderBy('name')
              .get();
      if (mounted) {
        setState(() {
          _colleges = snapshot.docs;
          _loadingColleges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingColleges = false);
        SnackbarUtil.showError(context, 'Failed to load colleges');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // NEW: Helper method to format program name based on category
  String _formatProgramName(String input) {
    // Check if college is "Others" or "Veterinary Medicine" - don't add prefix
    if (_selectedCategory == 'Bachelor' && _selectedCollegeId != null) {
      // Check the college name
      try {
        final college = _colleges.firstWhere((c) => c.id == _selectedCollegeId);
        final collegeData = college.data() as Map<String, dynamic>;
        final collegeName = collegeData['name'] ?? '';

        // If college is "Others" or "Veterinary Medicine", return input as-is
        if (collegeName == 'Others' || collegeName == 'Veterinary Medicine') {
          return input;
        }

        // Otherwise, add "Bachelor " prefix
        return 'Bachelor $input';
      } catch (e) {
        // If college not found, add prefix by default
        return 'Bachelor $input';
      }
    } else if (_selectedCategory == 'Masteral') {
      return 'Master of $input';
    }
    return input;
  }

  Future<void> _saveProgram() async {
    setState(() {
      _nameError = null;
      _categoryError = null;
      _collegeError = null;
    });

    bool hasError = false;

    // Validate category first
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      setState(() {
        _categoryError = 'Please select a program category';
      });
      hasError = true;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Please enter a program name';
      });
      hasError = true;
    }

    // Only validate college for Bachelor programs
    if (_selectedCategory == 'Bachelor') {
      if (_selectedCollegeId == null || _selectedCollegeId!.isEmpty) {
        setState(() {
          _collegeError = 'Please select a college';
        });
        hasError = true;
      }
    }

    if (hasError) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // NEW: Format the program name based on category
      final formattedName = _formatProgramName(_nameController.text.trim());

      final programData = {
        'name': formattedName,
        'category': _selectedCategory, // NEW: Save category
        'updatedAt': Timestamp.now(),
      };

      // NEW: Only add collegeId for Bachelor programs
      if (_selectedCategory == 'Bachelor') {
        programData['collegeId'] = _selectedCollegeId;
      } else {
        // For Masteral programs, explicitly set collegeId to empty string or remove it
        programData['collegeId'] = '';
      }

      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('programs')
            .doc(widget.programDoc!.id)
            .update(programData);
      } else {
        programData['created_at'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('programs')
            .add(programData);
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';
      if (currentUser != null) {
        final userDoc =
            await FirebaseFirestore.instance
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
            '${isEditing ? 'Updated' : 'Created'} program: $formattedName',
        'time': Timestamp.now(),
      });

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'Program ${isEditing ? 'updated' : 'created'} successfully!',
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
          'Failed to ${isEditing ? 'update' : 'create'} program: $e',
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
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 650,
        ), // Increased height
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
              // Header (same as before)
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
                                showProgramInfoModal(
                                  context,
                                  widget.programDoc!,
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
                        isEditing
                            ? Icons.edit_document
                            : Icons.add_circle_outline,
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
                            isEditing ? 'Edit Program' : 'Add New Program',
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
                                ? 'Update program information'
                                : 'Create a new academic program',
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
              // Content - MODIFIED ORDER
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildSectionHeader(
                        'Program Information',
                        Icons.school_outlined,
                      ),
                      const SizedBox(height: 16),
                      // NEW: Category dropdown at the top
                      _buildCategoryDropdown(isMobile),
                      const SizedBox(height: 16),
                      // NEW: Only show college dropdown for Bachelor programs
                      if (_selectedCategory == 'Bachelor') ...[
                        _buildCollegeDropdown(isMobile),
                        const SizedBox(height: 16),
                      ],
                      // MODIFIED: Show prefix hint based on selected category
                      _buildProgramNameField(isMobile),
                    ],
                  ),
                ),
              ),
              // Actions (same as before)
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
                              _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
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
                          onPressed: _isSubmitting ? null : _saveProgram,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child:
                              _isSubmitting
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
                                        isEditing
                                            ? 'Save Changes'
                                            : 'Create Program',
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

  // NEW: Category radio buttons widget
  Widget _buildCategoryDropdown(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'Bachelor';
                    // Don't clear collegeId when switching to Bachelor
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _selectedCategory == 'Bachelor'
                            ? const Color(0xFF2E7D32).withOpacity(0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _categoryError != null
                              ? Colors.red
                              : _selectedCategory == 'Bachelor'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE5E7EB),
                      width:
                          _categoryError != null ||
                                  _selectedCategory == 'Bachelor'
                              ? 2
                              : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: 'Bachelor',
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _categoryError = null;
                          });
                        },
                        activeColor: const Color(0xFF2E7D32),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bachelor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                _selectedCategory == 'Bachelor'
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            color:
                                _selectedCategory == 'Bachelor'
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'Masteral';
                    // Clear collegeId when switching to Masteral
                    _selectedCollegeId = null;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _selectedCategory == 'Masteral'
                            ? const Color(0xFF2E7D32).withOpacity(0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _categoryError != null
                              ? Colors.red
                              : _selectedCategory == 'Masteral'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE5E7EB),
                      width:
                          _categoryError != null ||
                                  _selectedCategory == 'Masteral'
                              ? 2
                              : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: 'Masteral',
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _selectedCollegeId = null;
                            _categoryError = null;
                          });
                        },
                        activeColor: const Color(0xFF2E7D32),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Masteral',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                _selectedCategory == 'Masteral'
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            color:
                                _selectedCategory == 'Masteral'
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_categoryError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _categoryError!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // NEW: Modified program name field with dynamic hint
  Widget _buildProgramNameField(bool isMobile) {
    String prefix = '';
    String example = '';
    bool showPrefix = true;

    // Check if college is "Others" or "Veterinary Medicine"
    if (_selectedCategory == 'Bachelor' &&
        _selectedCollegeId != null &&
        _colleges.isNotEmpty) {
      try {
        final college = _colleges.firstWhere((c) => c.id == _selectedCollegeId);
        final collegeData = college.data() as Map<String, dynamic>;
        final collegeName = collegeData['name'] ?? '';

        if (collegeName == 'Others' || collegeName == 'Veterinary Medicine') {
          showPrefix = false;
          example = 'Bachelor of Science in Information Technology';
        } else {
          showPrefix = true;
          prefix = 'Bachelor ';
          example = 'of Science in Information Technology';
        }
      } catch (e) {
        // Default to showing prefix if college not found
        showPrefix = true;
        prefix = 'Bachelor ';
        example = 'of Science in Information Technology';
      }
    } else if (_selectedCategory == 'Bachelor') {
      // Bachelor selected but no college yet
      showPrefix = true;
      prefix = 'Bachelor ';
      example = 'of Science in Information Technology';
    } else if (_selectedCategory == 'Masteral') {
      showPrefix = true;
      prefix = 'Master of ';
      example = 'Business Administration';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Program Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _nameError != null ? Colors.red : const Color(0xFFE5E7EB),
              width: _nameError != null ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _nameController,
            enabled: _selectedCategory != null,
            onChanged: (value) {
              if (_nameError != null && value.trim().isNotEmpty) {
                setState(() {
                  _nameError = null;
                });
              }
            },
            decoration: InputDecoration(
              hintText:
                  _selectedCategory != null
                      ? 'e.g., $example'
                      : 'Select a category first',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: const Icon(
                Icons.school_outlined,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
              prefixText:
                  (_selectedCategory != null && showPrefix) ? prefix : null,
              prefixStyle: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          ),
        ),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 8),
          Text(
            showPrefix
                ? 'Will be saved as: $prefix${_nameController.text.isNotEmpty ? _nameController.text : example}'
                : 'Will be saved as: ${_nameController.text.isNotEmpty ? _nameController.text : example}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (_nameError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _nameError!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCollegeDropdown(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'College',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _collegeError != null ? Colors.red : const Color(0xFFE5E7EB),
              width: _collegeError != null ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child:
              _loadingColleges
                  ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                  : DropdownButtonFormField<String>(
                    value: _selectedCollegeId,
                    decoration: InputDecoration(
                      hintText: 'Select a college',
                      hintStyle: TextStyle(
                        color:
                            _collegeError != null
                                ? Colors.red.shade300
                                : Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.account_balance_outlined,
                        color:
                            _collegeError != null
                                ? Colors.red
                                : const Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      errorText: _collegeError,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items:
                        _colleges.map((college) {
                          final data = college.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: college.id,
                            child: Text(
                              data['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCollegeId = value;
                        _collegeError = null;
                      });
                    },
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
        ),
      ],
    );
  }
}

// ==================== MODIFIED PROGRAM INFO MODAL ====================
// Add category display in the ProgramInfoModal build method's content section:

// Inside ProgramInfoModal's build method, add after the Program Name info item:
/*
const SizedBox(height: 8),
_buildInfoItem(
  Icons.category_outlined,
  'Category',
  data['category'] ?? 'N/A',
),
*/
