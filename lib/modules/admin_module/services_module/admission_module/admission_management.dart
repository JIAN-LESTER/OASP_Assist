import 'package:capstone_project/modules/admin_module/services_module/admission_module/add_edit_admission.dart';
import 'package:capstone_project/modules/admin_module/buttons/bulk.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/statcard_management.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/modules/admin_module/services_module/admission_module/admission_info.dart';

import 'package:capstone_project/modules/admin_module/buttons/upload_document_button.dart';
import 'package:capstone_project/modules/admin_module/widgets/admission_year_dropdown.dart';
import 'package:capstone_project/modules/admin_module/widgets/pagination.dart';
import 'package:capstone_project/modules/admin_module/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import '../../../../crud/delete/delete.dart';

class AdmissionManagementPage extends StatefulWidget {
  const AdmissionManagementPage({super.key});

  @override
  State<AdmissionManagementPage> createState() =>
      _AdmissionManagementPageState();
}

class _AdmissionManagementPageState extends State<AdmissionManagementPage>
    with BulkSelectionMixin {
  String selectedYear = 'All Year';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> allAdmissions = [];

  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
  final StatDataManagement statData = StatDataManagement();

  AdmissionData? ad;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAdmissions();
    loadStatData();
  }

  Future<void> loadStatData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await statData.getAdmissionData();

      if (!mounted) return;

      setState(() {
        ad = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading admission data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      SnackbarUtil.showError(context, "Failed to load admission data");
    }
  }

  void _loadAdmissions() {
    FirebaseFirestore.instance
        .collection('admissions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                allAdmissions = snapshot.docs;
              });
            }
          },
          onError: (error) {
            print("Error loading admissions: $error");
            if (mounted) {
              SnackbarUtil.showError(
                context,
                "Failed to load admissions: $error",
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onYearChanged(String newYear) {
    setState(() {
      selectedYear = newYear;
      currentPage = 1;
      clearSelection();
    });
  }

  void _onSearchChanged() {
    setState(() {
      currentPage = 1;
      clearSelection();
    });
  }

  void _goToPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  void _changeItemsPerPage(int newItemsPerPage) {
    setState(() {
      itemsPerPage = newItemsPerPage;
      currentPage = 1;
    });
  }

  Future<void> _loadStatsAsync() async {
    try {
      final data = await statData.getAdmissionData();
      if (mounted) {
        setState(() {
          ad = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading admission data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _handleBulkDelete() async {
    await handleBulkDelete(
      context: context,
      selectedIds: selectedIds,
      collection: 'admissions',
      itemType: 'admissions',
      onSuccess: () {
        clearSelection();
        _loadStatsAsync();
      },
      customDeleteHandler: handleAdmissionDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2E7D32),
          ),
        ),
      );
    }
    return ResponsiveLayout(
      mobileBody: MobileAdmissionManagement(
        allAdmissions: allAdmissions,
        selectedYear: selectedYear,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        ad: ad,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      tabletBody: TabletAdmissionManagement(
        allAdmissions: allAdmissions,
        selectedYear: selectedYear,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        ad: ad,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      desktopBody: DesktopAdmissionManagement(
        allAdmissions: allAdmissions,
        selectedYear: selectedYear,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        ad: ad,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
    );
  }
}

String _formatAcademicYear(dynamic academicYear) {
  if (academicYear == null) return 'N/A';

  if (academicYear is Map) {
    final start = academicYear['start'];
    final end = academicYear['end'];

    if (start != null && end != null) {
      return '$start-$end';
    } else if (start != null) {
      return '$start';
    }
  } else if (academicYear is String) {
    return academicYear;
  }

  return 'N/A';
}

class DesktopAdmissionManagement extends StatelessWidget {
  final List<DocumentSnapshot> allAdmissions;
  final String selectedYear;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final AdmissionData? ad;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const DesktopAdmissionManagement({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allAdmissions,
    this.ad,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.isAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allAdmissions,
      context,
      selectedYear,
      onYearChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      ad,
      selectedIds,
      isSelectionMode,
      onToggleSelection,
      onToggleSelectAll,
      onClearSelection,
      onBulkDelete,
      isAllSelected,
    );
  }
}

class TabletAdmissionManagement extends StatelessWidget {
  final List<DocumentSnapshot> allAdmissions;
  final String selectedYear;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final AdmissionData? ad;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const TabletAdmissionManagement({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allAdmissions,
    this.ad,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.isAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allAdmissions,
      context,
      selectedYear,
      onYearChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      ad,
      selectedIds,
      isSelectionMode,
      onToggleSelection,
      onToggleSelectAll,
      onClearSelection,
      onBulkDelete,
      isAllSelected,
    );
  }
}

class MobileAdmissionManagement extends StatelessWidget {
  final List<DocumentSnapshot> allAdmissions;
  final String selectedYear;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final AdmissionData? ad;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const MobileAdmissionManagement({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allAdmissions,
    this.ad,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.isAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredAdmissions(
      allAdmissions,
      selectedYear,
      searchController.text,
    );
    final filteredIds = filtered.map((d) => d.id).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMobileHeader(
                selectedYear,
                allAdmissions,
                onYearChanged,
                searchController,
                ad,
              ),
            ),
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: BulkDeleteBar(
                  selectedCount: selectedIds.length,
                  onToggleSelectAll: () => onToggleSelectAll(filteredIds),
                  onBulkDelete: onBulkDelete,
                  isAllSelected: isAllSelected(filteredIds),
                  itemType: 'admissions',
                ),
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
                    _buildTableHeader(
                      selectedIds.length == filtered.length && filtered.isNotEmpty,
                      () => onToggleSelectAll(filteredIds),
                      selectedIds,
                      filtered,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildAdmissionList(
                        allAdmissions: allAdmissions,
                        selectedYear: selectedYear,
                        searchQuery: searchController.text,
                        currentPage: currentPage,
                        itemsPerPage: itemsPerPage,
                        onPageChanged: onPageChanged,
                        onItemsPerPageChanged: onItemsPerPageChanged,
                        selectedIds: selectedIds,
                        onToggleSelection: onToggleSelection,
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

Widget _buildMobileHeader(
  String selectedYear,
  List<DocumentSnapshot> allAdmissions,
  ValueChanged<String> onYearChanged,
  TextEditingController searchController,
  AdmissionData? ad,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admission Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage admission processes and procedures',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          UploadDocumentButton(formType: 'admission'),
        ],
      ),
      const SizedBox(height: 16),
      buildSearchField('title', searchController),
      const SizedBox(height: 12),
      AcademicYearDropdown(
        allAdmissions: allAdmissions,
        initialValue: selectedYear,
        onChanged: onYearChanged,
      ),
    ],
  );
}

Widget mainContent(
  List<DocumentSnapshot> allAdmissions,
  BuildContext context,
  final String selectedYear,
  final ValueChanged<String> onYearChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final AdmissionData? ad,
  final Set<String> selectedIds,
  final bool isSelectionMode,
  final Function(String) onToggleSelection,
  final Function(List<String>) onToggleSelectAll,
  final VoidCallback onClearSelection,
  final VoidCallback onBulkDelete,
  final Function(List<String>) isAllSelected,
) {
  final filtered = _getFilteredAdmissions(
    allAdmissions,
    selectedYear,
    searchController.text,
  );
  final filteredIds = filtered.map((d) => d.id).toList();

  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            selectedYear,
            allAdmissions,
            onYearChanged,
            searchController,
            ad,
          ),
          const SizedBox(height: 16),
          if (isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BulkDeleteBar(
                selectedCount: selectedIds.length,
                onToggleSelectAll: () => onToggleSelectAll(filteredIds),
                onBulkDelete: onBulkDelete,
                isAllSelected: isAllSelected(filteredIds),
                itemType: 'admissions',
              ),
            ),
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
                  _buildTableHeader(
                    selectedIds.length == filtered.length && filtered.isNotEmpty,
                    () => onToggleSelectAll(filteredIds),
                    selectedIds,
                    filtered,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildAdmissionList(
                      allAdmissions: allAdmissions,
                      selectedYear: selectedYear,
                      searchQuery: searchController.text,
                      currentPage: currentPage,
                      itemsPerPage: itemsPerPage,
                      onPageChanged: onPageChanged,
                      onItemsPerPageChanged: onItemsPerPageChanged,
                      selectedIds: selectedIds,
                      onToggleSelection: onToggleSelection,
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

List<DocumentSnapshot> _getFilteredAdmissions(
  List<DocumentSnapshot> docs,
  String selectedYear,
  String searchQuery,
) {
  return docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] ?? '').toString().toLowerCase().trim();
    final academicYearData = data['academicYear'];
    final academicYear =
        _formatAcademicYear(academicYearData).toLowerCase().trim();
    final query = searchQuery.toLowerCase().trim();
    final yearFilter = selectedYear.toLowerCase().trim();

    bool matchesYear =
        yearFilter == 'all year' ||
        yearFilter == 'all' ||
        academicYear == yearFilter;

    bool matchesSearch =
        query.isEmpty ||
        title.contains(query) ||
        academicYear.contains(query);

    return matchesYear && matchesSearch;
  }).toList();
}

Widget _buildAdmissionList({
  required List<DocumentSnapshot> allAdmissions,
  required String selectedYear,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required Set<String> selectedIds,
  required Function(String) onToggleSelection,
}) {
  final filtered = _getFilteredAdmissions(
    allAdmissions,
    selectedYear,
    searchQuery,
  );

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageAdmissions = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child: currentPageAdmissions.isEmpty
            ? const Center(
                child: Text('No admissions match your criteria.'),
              )
            : ListView.separated(
                itemCount: currentPageAdmissions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = currentPageAdmissions[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final List<String> contacts =
                      (data['contact'] as List<dynamic>?)
                          ?.map((c) => c.toString())
                          .toList() ??
                      [];
                  final isSelected = selectedIds.contains(doc.id);

                  return _buildAdmissionRow(
                    context: context,
                    doc: doc,
                    title: data['title'] ?? 'N/A',
                    source: data['source'] ?? 'N/A',
                    content: data['content'] ?? '',
                    contacts: contacts,
                    academicYear: _formatAcademicYear(data['academicYear']),
                    isSelected: isSelected,
                    onToggleSelection: () => onToggleSelection(doc.id),
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
          item: 'admissions',
        ),
    ],
  );
}

Widget _buildAdmissionRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String title,
  required String content,
  required String source,
  required String academicYear,
  required List<String>? contacts,
  required bool isSelected,
  required VoidCallback onToggleSelection,
}) {
  return _AdmissionRowWidget(
    context: context,
    doc: doc,
    title: title,
    content: content,
    source: source,
    academicYear: academicYear,
    contacts: contacts,
    isSelected: isSelected,
    onToggleSelection: onToggleSelection,
  );
}

Widget _buildHeader(
  String selectedYear,
  List<DocumentSnapshot> allAdmissions,
  ValueChanged<String> onYearChanged,
  TextEditingController searchController,
  AdmissionData? ad,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admission Information',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage admission processes and procedures',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              UploadDocumentButton(formType: 'admission'),
            ],
          ),
          const SizedBox(height: 40),
          isMobile
              ? Column(
                  children: [
                    buildSearchField('title', searchController),
                    const SizedBox(height: 12),
                    AcademicYearDropdown(
                      allAdmissions: allAdmissions,
                      initialValue: selectedYear,
                      onChanged: onYearChanged,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: buildSearchField('title', searchController),
                    ),
                    const SizedBox(width: 16),
                    AcademicYearDropdown(
                      allAdmissions: allAdmissions,
                      initialValue: selectedYear,
                      onChanged: onYearChanged,
                    ),
                  ],
                ),
        ],
      );
    },
  );
}

Widget _buildTableHeader(
  bool isAllSelected,
  VoidCallback onSelectAll,
  Set<String> selectedIds,
  List<DocumentSnapshot> filteredDocs,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      if (isMobile) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: filteredDocs.isEmpty ? null : onSelectAll,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isAllSelected ? const Color(0xFF2E7D32) : Colors.white,
                      border: Border.all(
                        color: isAllSelected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD1D5DB),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isAllSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                flex: 4,
                child: Text(
                  'Title',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                flex: 5,
                child: Text(
                  'Steps',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 48),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 14 : 16,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: filteredDocs.isEmpty ? null : onSelectAll,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isAllSelected ? const Color(0xFF2E7D32) : Colors.white,
                    border: Border.all(
                      color: isAllSelected
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isAllSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                'Title',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                'Steps',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                'Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                'Contacts',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(width: 48),
          ],
        ),
      );
    },
  );
}

Widget _buildExpandableList({
  required List<String> items,
  required String emptyText,
  bool isExpanded = false,
  required Function(bool) onToggle,
}) {
  if (items.isEmpty) {
    return Text(
      emptyText,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border.all(color: Colors.blue[200]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          items[0],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue[900],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (isExpanded && items.length > 1)
        ...items
            .skip(1)
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      if (items.length > 1)
        InkWell(
          onTap: () => onToggle(!isExpanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? 'Show less' : '+${items.length - 1} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _AdmissionRowWidget extends StatefulWidget {
  final BuildContext context;
  final DocumentSnapshot doc;
  final String title;
  final String content;
  final String source;
  final String academicYear;
  final List<String>? contacts;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _AdmissionRowWidget({
    required this.context,
    required this.doc,
    required this.title,
    required this.content,
    required this.source,
    required this.academicYear,
    required this.contacts,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  State<_AdmissionRowWidget> createState() => _AdmissionRowWidgetState();
}

class _AdmissionRowWidgetState extends State<_AdmissionRowWidget> {
  bool stepsExpanded = false;
  bool requirementsExpanded = false;
  bool contactsExpanded = false;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1100;

    final data = widget.doc.data() as Map<String, dynamic>;
    final List<String> steps =
        (data['steps'] as List<dynamic>?)?.map((s) => s.toString()).toList() ??
        [];
    final List<String> requirements =
        (data['requirements'] as List<dynamic>?)
            ?.map((r) => r.toString())
            .toList() ??
        [];

    final List<String> processedContacts =
        widget.contacts?.map((c) {
          if (c.contains(":")) {
            final parts = c.split(":");
            return parts.sublist(1).join(":").trim();
          }
          return c;
        }).toList() ??
        [];

    if (isMobile) {
      return Container(
        key: ValueKey(widget.doc.id),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Checkbox with cursor hand on hover
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggleSelection,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.isSelected ? const Color(0xFF2E7D32) : Colors.white,
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD1D5DB),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: widget.isSelected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Rest of the content - wrapped in Expanded and GestureDetector
            Expanded(
              child: GestureDetector(
                onTap: () => showADInfoModal(context, widget.doc),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Column
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.academicYear.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                widget.academicYear,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Steps Column
                    Expanded(
                      flex: 5,
                      child: _buildExpandableList(
                        items: steps,
                        emptyText: 'No steps',
                        isExpanded: stepsExpanded,
                        onToggle: (value) => setState(() => stepsExpanded = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (context) => AdmissionFormDialog(
                      doc: widget.doc,
                      isEdit: true,
                    ),
                  );
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                    context,
                    widget.doc,
                    DeleteConfigs.admissions,
                    'admissions',
                    customDeleteHandler: handleAdmissionDelete,
                  );
                }
              },
              itemBuilder: (context) => [
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
      );
    }

    // Tablet & Desktop View
    return Container(
      key: ValueKey(widget.doc.id),
      padding: EdgeInsets.all(isTablet ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom Checkbox with cursor hand on hover
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onToggleSelection,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.isSelected ? const Color(0xFF2E7D32) : Colors.white,
                    border: Border.all(
                      color: widget.isSelected
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: widget.isSelected
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Rest of content wrapped in Expanded and GestureDetector
          Expanded(
            child: GestureDetector(
              onTap: () => showADInfoModal(context, widget.doc),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Steps
                  Expanded(
                    flex: 3,
                    child: _buildExpandableList(
                      items: steps,
                      emptyText: 'No steps',
                      isExpanded: stepsExpanded,
                      onToggle: (value) => setState(() => stepsExpanded = value),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Requirements
                  Expanded(
                    flex: 3,
                    child: _buildExpandableList(
                      items: requirements,
                      emptyText: 'No requirements',
                      isExpanded: requirementsExpanded,
                      onToggle: (value) => setState(() => requirementsExpanded = value),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Contacts
                  Expanded(
                    flex: 3,
                    child: _buildExpandableList(
                      items: processedContacts,
                      emptyText: 'No contacts',
                      isExpanded: contactsExpanded,
                      onToggle: (value) => setState(() => contactsExpanded = value),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showDialog(
                  context: context,
                  builder: (context) =>
                      AdmissionFormDialog(doc: widget.doc, isEdit: true),
                );
              } else if (value == 'delete') {
                showDeleteConfirmation(
                  context,
                  widget.doc,
                  DeleteConfigs.admissions,
                  'admissions',
                  customDeleteHandler: handleAdmissionDelete,
                );
              }
            },
            itemBuilder: (context) => [
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
    );
  }
}
