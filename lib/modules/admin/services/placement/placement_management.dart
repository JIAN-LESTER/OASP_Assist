import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modules/admin/services/placement/add_edit_placement.dart';
import 'package:capstone_project/modules/admin/buttons/bulk.dart';
import 'package:capstone_project/modules/admin/buttons/upload_document_button.dart';
import 'package:capstone_project/modules/admin/widgets/company_dropdown.dart';
import 'package:capstone_project/modules/admin/widgets/pagination.dart';
import 'package:capstone_project/modules/admin/widgets/search_field.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/statcard_management.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:capstone_project/modules/admin/services/placement/pl_info.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlacementManagementPage extends StatefulWidget {
  const PlacementManagementPage({super.key});

  @override
  State<PlacementManagementPage> createState() =>
      _PlacementManagementPageState();
}

class _PlacementManagementPageState extends State<PlacementManagementPage>
    with BulkSelectionMixin {
  String selectedCompany = 'All Company';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> allPlacements = [];

  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
  bool _isCleaningDuplicates = false;
  final StatDataManagement statData = StatDataManagement();
  PlacementData? pl;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    loadPlacements();
    loadStatData();
  }

  Future<void> loadStatData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await statData.getPlacementData();

      if (!mounted) return;

      setState(() {
        pl = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading placement data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void loadPlacements() {
    FirebaseFirestore.instance
        .collection('placements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _cleanupDuplicatePlacements(snapshot.docs);
      if (mounted) {
        setState(() {
          allPlacements = snapshot.docs;
        });
      }
    });
  }

  String _placementDuplicateKey(Map<String, dynamic> data) {
    final company = (data['partnerCompany'] ?? '').toString().trim().toLowerCase();
    final positions = (data['positions'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    return '$company|${positions.join(",")}';
  }

  Future<void> _cleanupDuplicatePlacements(List<DocumentSnapshot> docs) async {
    if (_isCleaningDuplicates) {
      return;
    }

    final duplicates = <DocumentReference>[];
    final seenKeys = <String>{};

    for (final doc in docs) {
      final key = _placementDuplicateKey(doc.data() as Map<String, dynamic>);
      if (key == '|') {
        continue;
      }
      if (!seenKeys.add(key)) {
        duplicates.add(doc.reference);
      }
    }

    if (duplicates.isEmpty) {
      return;
    }

    _isCleaningDuplicates = true;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final ref in duplicates) {
        batch.delete(ref);
      }
      await batch.commit();
    } finally {
      _isCleaningDuplicates = false;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onCompanyChanged(String newCompany) {
    setState(() {
      selectedCompany = newCompany;
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
      final data = await statData.getPlacementData();
      if (mounted) {
        setState(() {
          pl = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading placement data: $e");
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
      collection: 'placements',
      itemType: 'placements',
      onSuccess: () {
        clearSelection();
        _loadStatsAsync();
      },
      customDeleteHandler: handlePlacementDelete,
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
      mobileBody: MobilePlacementManagement(
        allPlacements: allPlacements,
        selectedCompany: selectedCompany,
        onCompanyChanged: _onCompanyChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        pl: pl,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      tabletBody: TabletPlacementManagement(
        allPlacements: allPlacements,
        selectedCompany: selectedCompany,
        onCompanyChanged: _onCompanyChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        pl: pl,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      desktopBody: DesktopPlacementManagement(
        allPlacements: allPlacements,
        selectedCompany: selectedCompany,
        onCompanyChanged: _onCompanyChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        pl: pl,
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

class DesktopPlacementManagement extends StatelessWidget {
  final List<DocumentSnapshot> allPlacements;
  final String selectedCompany;
  final ValueChanged<String> onCompanyChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final PlacementData? pl;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const DesktopPlacementManagement({
    super.key,
    required this.selectedCompany,
    required this.onCompanyChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allPlacements,
    this.pl,
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
      allPlacements,
      context,
      selectedCompany,
      onCompanyChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      pl,
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

class TabletPlacementManagement extends StatelessWidget {
  final List<DocumentSnapshot> allPlacements;
  final String selectedCompany;
  final ValueChanged<String> onCompanyChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final PlacementData? pl;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const TabletPlacementManagement({
    super.key,
    required this.selectedCompany,
    required this.onCompanyChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allPlacements,
    this.pl,
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
      allPlacements,
      context,
      selectedCompany,
      onCompanyChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      pl,
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

class MobilePlacementManagement extends StatelessWidget {
  final List<DocumentSnapshot> allPlacements;
  final String selectedCompany;
  final ValueChanged<String> onCompanyChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final PlacementData? pl;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const MobilePlacementManagement({
    super.key,
    required this.selectedCompany,
    required this.onCompanyChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allPlacements,
    this.pl,
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
    final filtered = _getFilteredPlacements(
      allPlacements,
      selectedCompany,
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
                selectedCompany,
                allPlacements,
                onCompanyChanged,
                searchController,
                pl,
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
                  itemType: 'placements',
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
                    const SizedBox(height: 6),
                    Expanded(
                      child: _buildPlacementList(
                        allPlacements: allPlacements,
                        selectedCompany: selectedCompany,
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
  String selectedCompany,
  List<DocumentSnapshot> allPlacements,
  ValueChanged<String> onCompanyChanged,
  TextEditingController searchController,
  PlacementData? pl,
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
                  'Placement Companies',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage companies and job vacancies',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          UploadDocumentButton(formType: 'placement'),
        ],
      ),
      const SizedBox(height: 16),
      buildSearchField('positions', searchController),
      const SizedBox(height: 12),
      PlacementCompanyDropdown(
        allPlacements: allPlacements,
        initialValue: selectedCompany,
        onChanged: onCompanyChanged,
      ),
    ],
  );
}

Widget mainContent(
  List<DocumentSnapshot> allPlacements,
  BuildContext context,
  final String selectedCompany,
  final ValueChanged<String> onCompanyChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final PlacementData? pl,
  final Set<String> selectedIds,
  final bool isSelectionMode,
  final Function(String) onToggleSelection,
  final Function(List<String>) onToggleSelectAll,
  final VoidCallback onClearSelection,
  final VoidCallback onBulkDelete,
  final Function(List<String>) isAllSelected,
) {
  final filtered = _getFilteredPlacements(
    allPlacements,
    selectedCompany,
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
            selectedCompany,
            allPlacements,
            onCompanyChanged,
            searchController,
            pl,
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
                itemType: 'placements',
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
                  const SizedBox(height: 6),
                  Expanded(
                    child: _buildPlacementList(
                      allPlacements: allPlacements,
                      selectedCompany: selectedCompany,
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

List<DocumentSnapshot> _getFilteredPlacements(
  List<DocumentSnapshot> docs,
  String selectedCompany,
  String searchQuery,
) {
  final filtered = docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final company = (data['partnerCompany'] ?? '').toString().toLowerCase().trim();
    final List<String> positionsList =
        (data['positions'] is List)
            ? List<String>.from(data['positions'].map((e) => e.toString()))
            : <String>[];
    final query = searchQuery.toLowerCase().trim();
    final companyFilter = selectedCompany.toLowerCase().trim();

    bool matchesCompany =
        companyFilter == 'all company' ||
        companyFilter == 'all' ||
        company == companyFilter;

    bool matchesSearch =
        query.isEmpty ||
        company.contains(query) ||
        positionsList.any((pos) => pos.toLowerCase().contains(query));

    return matchesCompany && matchesSearch;
  }).toList();

  final seenKeys = <String>{};
  final deduplicated = <DocumentSnapshot>[];
  for (final doc in filtered) {
    final data = doc.data() as Map<String, dynamic>;
    final company = (data['partnerCompany'] ?? '').toString().trim().toLowerCase();
    final positions = (data['positions'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    final dedupeKey = '$company|${positions.join(",")}';

    if (dedupeKey == '|' || seenKeys.contains(dedupeKey)) {
      continue;
    }

    seenKeys.add(dedupeKey);
    deduplicated.add(doc);
  }

  return deduplicated;
}
// Part 2 - Widget builders and components

Widget _buildPlacementList({
  required List<DocumentSnapshot> allPlacements,
  required String selectedCompany,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required Set<String> selectedIds,
  required Function(String) onToggleSelection,
}) {
  final filtered = _getFilteredPlacements(
    allPlacements,
    selectedCompany,
    searchQuery,
  );

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPagePlacements = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child: currentPagePlacements.isEmpty
            ? const Center(child: Text('No companies match your criteria.'))
            : ListView.builder(
                shrinkWrap: false,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: currentPagePlacements.length,
                itemBuilder: (context, index) {
                  final doc = currentPagePlacements[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final List<String> contacts =
                      (data['contacts'] as List<dynamic>?)
                          ?.map((c) => c.toString())
                          .toList() ??
                      [];

                  final List<String> positions =
                      (data['positions'] as List<dynamic>?)
                          ?.map((c) => c.toString())
                          .toList() ??
                      [];

                  String deadline = '-';
                  if (data['deadline'] != null) {
                    if (data['deadline'] is Timestamp) {
                      deadline = DateFormat("MMMM d, yyyy")
                          .format((data['deadline'] as Timestamp).toDate());
                    } else {
                      deadline = data['deadline'].toString();
                    }
                  }

                  final isSelected = selectedIds.contains(doc.id);

                  return Padding(
                    key: ValueKey(doc.id),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildPlacementRow(
                      context: context,
                      doc: doc,
                      partnerCompany: data['partnerCompany'] ?? 'N/A',
                      contacts: contacts,
                      positions: positions,
                      deadline: deadline,
                      isSelected: isSelected,
                      onToggleSelection: () => onToggleSelection(doc.id),
                    ),
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
          item: 'placements',
        ),
    ],
  );
}

Widget _buildPlacementRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String partnerCompany,
  required List<String>? contacts,
  required List<String>? positions,
  required String deadline,
  required bool isSelected,
  required VoidCallback onToggleSelection,
}) {
  return _PlacementRowWidget(
    context: context,
    doc: doc,
    partnerCompany: partnerCompany,
    contacts: contacts,
    positions: positions,
    deadline: deadline,
    isSelected: isSelected,
    onToggleSelection: onToggleSelection,
  );
}

Widget _buildHeader(
  String selectedCompany,
  List<DocumentSnapshot> allPlacements,
  ValueChanged<String> onCompanyChanged,
  TextEditingController searchController,
  PlacementData? pl,
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
                      'Placement Companies',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage companies and job vacancies',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              UploadDocumentButton(formType: 'placement'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: isMobile
                ? Column(
                    children: [
                      buildCompactStatCard(
                        'Total Companies',
                        '${pl?.totalCompanies ?? 0}',
                        Colors.blue,
                        Icons.message,
                      ),
                      const SizedBox(height: 12),
                      buildCompactStatCard(
                        'Companies Looking for Vacancy',
                        '${pl?.vacantCompanies ?? 0}',
                        Colors.green,
                        Icons.check_circle,
                      ),
                      const SizedBox(height: 12),
                      buildCompactStatCard(
                        'Approaching Deadline',
                        pl?.approachingDeadline ?? 'Unknown',
                        Colors.red,
                        Icons.group,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: buildCompactStatCard(
                          'Total Companies',
                          '${pl?.totalCompanies ?? 0}',
                          Colors.blue,
                          Icons.message,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildCompactStatCard(
                          'Companies Looking for Vacancy',
                          '${pl?.vacantCompanies ?? 0}',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildCompactStatCard(
                          'Approaching Deadline',
                          pl?.approachingDeadline ?? 'Unknown',
                          Colors.red,
                          Icons.group,
                        ),
                      ),
                    ],
                  ),
          ),
          isMobile
              ? Column(
                  children: [
                    buildSearchField('positions', searchController),
                    const SizedBox(height: 12),
                    PlacementCompanyDropdown(
                      allPlacements: allPlacements,
                      initialValue: selectedCompany,
                      onChanged: onCompanyChanged,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: buildSearchField('positions', searchController),
                    ),
                    const SizedBox(width: 16),
                    PlacementCompanyDropdown(
                      allPlacements: allPlacements,
                      initialValue: selectedCompany,
                      onChanged: onCompanyChanged,
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                    width: 18,
                    height: 18,
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
                  'Company',
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
                  'Positions',
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
          vertical: isTablet ? 9 : 10,
          horizontal: 12,
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
                  width: 18,
                  height: 18,
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
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                'Company',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Text(
                'Positions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Text(
                'Contacts',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Text(
                'Deadline',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 20),
            const SizedBox(width: 48),
          ],
        ),
      );
    },
  );
}

Widget _buildExpandableListYellow({
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

  final processedItems = items.map((c) {
    String displayValue = c;
    if (c.contains(":")) {
      final parts = c.split(":");
      displayValue = parts.sublist(1).join(":").trim();
    }
    return displayValue;
  }).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          border: Border.all(color: Colors.amber[300]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          processedItems[0],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.amber[900],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (isExpanded && processedItems.length > 1)
        ...processedItems
            .skip(1)
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(color: Colors.amber[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.amber[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      if (processedItems.length > 1)
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
                  color: Colors.amber[800],
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? 'Show less' : '+${processedItems.length - 1} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber[800],
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

class _PlacementRowWidget extends StatefulWidget {
  final BuildContext context;
  final DocumentSnapshot doc;
  final String partnerCompany;
  final List<String>? contacts;
  final List<String>? positions;
  final String deadline;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _PlacementRowWidget({
    required this.context,
    required this.doc,
    required this.partnerCompany,
    required this.contacts,
    required this.positions,
    required this.deadline,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  State<_PlacementRowWidget> createState() => _PlacementRowWidgetState();
}

class _PlacementRowWidgetState extends State<_PlacementRowWidget> {
  bool positionsExpanded = false;
  bool contactsExpanded = false;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1100;

    return Container(
      key: ValueKey(widget.doc.id),
      padding: EdgeInsets.all(isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () => showPLInfoModal(context, widget.doc),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Checkbox
            InkWell(
              onTap: widget.onToggleSelection,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 18,
                  height: 18,
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
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              flex: isMobile ? 4 : 3,
              child: Text(
                widget.partnerCompany,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              flex: isMobile ? 5 : 4,
              child: _buildExpandableListYellow(
                items: widget.positions ?? [],
                emptyText: 'No Vacancy',
                isExpanded: positionsExpanded,
                onToggle: (value) => setState(() => positionsExpanded = value),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildExpandableListYellow(
                  items: widget.contacts ?? [],
                  emptyText: 'No Contacts',
                  isExpanded: contactsExpanded,
                  onToggle: (value) => setState(() => contactsExpanded = value),
                ),
              ),
            ],
            if (!isMobile) ...[
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Text(
                  widget.deadline,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            SizedBox(width: isMobile ? 8 : (isTablet ? 16 : 20)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        PlacementFormDialog(doc: widget.doc, isEdit: true),
                  );
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                    context,
                    widget.doc,
                    DeleteConfigs.placements,
                    'placements',
                    customDeleteHandler: handlePlacementDelete,
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
      ),
    );
  }
}


