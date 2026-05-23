import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modules/admin/services/scholarship/add_edit_scholarship.dart';
import 'package:capstone_project/modules/admin/buttons/bulk.dart';
import 'package:capstone_project/modules/admin/buttons/upload_document_button.dart';
import 'package:capstone_project/modules/admin/widgets/pagination.dart';
import 'package:capstone_project/modules/admin/widgets/provider_dropdown.dart';
import 'package:capstone_project/modules/admin/widgets/search_field.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/statcard_management.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';

import 'package:capstone_project/modules/admin/services/scholarship/scholarship_info.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';

import 'package:flutter/material.dart';

class ScholarshipManagementPage extends StatefulWidget {
  const ScholarshipManagementPage({super.key});

  @override
  State<ScholarshipManagementPage> createState() =>
      _ScholarshipManagementPageState();
}

class _ScholarshipManagementPageState extends State<ScholarshipManagementPage>
    with BulkSelectionMixin {
  String selectedProvider = 'All Providers';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> allScholarships = [];

  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
  bool _isCleaningDuplicates = false;
  final StatDataManagement statData = StatDataManagement();
  ScholarshipData? sc;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadScholarships();
    loadStatData();
  }

  Future<void> loadStatData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await statData.getScholarshipData();

      if (!mounted) return;

      setState(() {
        sc = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading scholarship data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _loadScholarships() {
    FirebaseFirestore.instance
        .collection('scholarships')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _cleanupDuplicateScholarships(snapshot.docs);
      if (mounted) {
        setState(() {
          allScholarships = snapshot.docs;
        });
      }
    });
  }

  String _scholarshipDuplicateKey(Map<String, dynamic> data) {
    final scholarshipName = (data['name'] ?? '').toString().trim().toLowerCase();
    final scholarshipProvider =
        (data['scholarshipProvider'] ?? '').toString().trim().toLowerCase();
    return '$scholarshipName|$scholarshipProvider';
  }

  Future<void> _cleanupDuplicateScholarships(
    List<DocumentSnapshot> docs,
  ) async {
    if (_isCleaningDuplicates) {
      return;
    }

    final duplicates = <DocumentReference>[];
    final seenKeys = <String>{};

    for (final doc in docs) {
      final key = _scholarshipDuplicateKey(doc.data() as Map<String, dynamic>);
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

  void _onProviderChanged(String newProvider) {
    setState(() {
      selectedProvider = newProvider;
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
      final data = await statData.getScholarshipData();
      if (mounted) {
        setState(() {
          sc = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading scholarship data: $e");
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
      collection: 'scholarships',
      itemType: 'scholarships',
      onSuccess: () {
        clearSelection();
        _loadStatsAsync();
      },
      customDeleteHandler: handleScholarshipDelete,
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
      mobileBody: MobileScholarshipManagement(
        allScholarships: allScholarships,
        selectedProvider: selectedProvider,
        onProviderChanged: _onProviderChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        sc: sc,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      tabletBody: TabletScholarshipManagement(
        allScholarships: allScholarships,
        selectedProvider: selectedProvider,
        onProviderChanged: _onProviderChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        sc: sc,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      desktopBody: DesktopScholarshipManagement(
        allScholarships: allScholarships,
        selectedProvider: selectedProvider,
        onProviderChanged: _onProviderChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        sc: sc,
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

class DesktopScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onProviderChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ScholarshipData? sc;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const DesktopScholarshipManagement({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allScholarships,
    this.sc,
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
      allScholarships,
      context,
      selectedProvider,
      onProviderChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      sc,
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

class TabletScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onProviderChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ScholarshipData? sc;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const TabletScholarshipManagement({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allScholarships,
    this.sc,
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
      allScholarships,
      context,
      selectedProvider,
      onProviderChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      sc,
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

class MobileScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onProviderChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ScholarshipData? sc;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const MobileScholarshipManagement({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allScholarships,
    this.sc,
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
    final filtered = _getFilteredScholarships(
      allScholarships,
      selectedProvider,
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
                selectedProvider,
                allScholarships,
                onProviderChanged,
                searchController,
                sc,
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
                  itemType: 'scholarships',
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
                      child: _buildScholarshipList(
                        allScholarships: allScholarships,
                        selectedProvider: selectedProvider,
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

Widget mainContent(
  List<DocumentSnapshot> allScholarships,
  BuildContext context,
  final String selectedProvider,
  final ValueChanged<String> onProviderChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final ScholarshipData? sc,
  final Set<String> selectedIds,
  final bool isSelectionMode,
  final Function(String) onToggleSelection,
  final Function(List<String>) onToggleSelectAll,
  final VoidCallback onClearSelection,
  final VoidCallback onBulkDelete,
  final Function(List<String>) isAllSelected,
) {
  final filtered = _getFilteredScholarships(
    allScholarships,
    selectedProvider,
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
            selectedProvider,
            allScholarships,
            onProviderChanged,
            searchController,
            sc,
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
                itemType: 'scholarships',
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
                    child: _buildScholarshipList(
                      allScholarships: allScholarships,
                      selectedProvider: selectedProvider,
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

Widget _buildMobileHeader(
  String selectedProvider,
  List<DocumentSnapshot> allScholarships,
  ValueChanged<String> onProviderChanged,
  TextEditingController searchController,
  ScholarshipData? sc,
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
                'Scholarship List',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage scholarship list and its contents',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          UploadDocumentButton(formType: 'scholarship'),
        ],
      ),
      const SizedBox(height: 16),
      buildSearchField('scholarship name', searchController),
      const SizedBox(height: 12),
      ScholarshipProviderDropdown(
        allScholarships: allScholarships,
        initialValue: selectedProvider,
        onChanged: onProviderChanged,
      ),
    ],
  );
}

List<DocumentSnapshot> _getFilteredScholarships(
  List<DocumentSnapshot> docs,
  String selectedProvider,
  String searchQuery,
) {
  final filtered = docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final scholarshipName =
        (data['name'] ?? '').toString().toLowerCase().trim();
    final scholarshipProvider =
        (data['scholarshipProvider'] ?? '').toString().toLowerCase().trim();
    final query = searchQuery.toLowerCase().trim();
    final providerFilter = selectedProvider.toLowerCase().trim();

    bool matchesProvider =
        providerFilter == 'all' ||
        providerFilter == 'all providers' ||
        scholarshipProvider == providerFilter;

    bool matchesSearch =
        query.isEmpty ||
        scholarshipName.contains(query) ||
        scholarshipProvider.contains(query);

    return matchesProvider && matchesSearch;
  }).toList();

  final seenKeys = <String>{};
  final deduplicated = <DocumentSnapshot>[];
  for (final doc in filtered) {
    final data = doc.data() as Map<String, dynamic>;
    final scholarshipName = (data['name'] ?? '').toString().trim().toLowerCase();
    final scholarshipProvider =
        (data['scholarshipProvider'] ?? '').toString().trim().toLowerCase();
    final dedupeKey = '$scholarshipName|$scholarshipProvider';

    if (dedupeKey == '|' || seenKeys.contains(dedupeKey)) {
      continue;
    }

    seenKeys.add(dedupeKey);
    deduplicated.add(doc);
  }

  return deduplicated;
}

Widget _buildScholarshipList({
  required List<DocumentSnapshot> allScholarships,
  required String selectedProvider,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required Set<String> selectedIds,
  required Function(String) onToggleSelection,
}) {
  final filtered = _getFilteredScholarships(
    allScholarships,
    selectedProvider,
    searchQuery,
  );

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageScholarships = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child: currentPageScholarships.isEmpty
            ? const Center(
                child: Text('No scholarships match your criteria.'),
              )
            : ListView.builder(
                shrinkWrap: false,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: currentPageScholarships.length,
                itemBuilder: (context, index) {
                  final doc = currentPageScholarships[index];
                  final data = doc.data() as Map<String, dynamic>;

                  List<String> eligibilityRequirements = [];
                  if (data['eligibilityRequirements'] != null) {
                    final reqs =
                        (data['eligibilityRequirements'] as List<dynamic>?)
                            ?.map((c) => c.toString().trim())
                            .where((c) => c.isNotEmpty)
                            .toList() ??
                        [];
                    eligibilityRequirements.addAll(reqs);
                  }

                  final List<String> privileges =
                      (data['privileges'] as List<dynamic>?)
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
                    child: _buildScholarshipRow(
                      context: context,
                      doc: doc,
                      name: data['name'] ?? 'N/A',
                      description: data['description'] ?? 'N/A',
                      eligibilityRequirements: eligibilityRequirements,
                      scholarshipProvider: data['scholarshipProvider'] ?? 'N/A',
                      privileges: privileges,
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
          item: 'scholarships',
        ),
    ],
  );
}

Widget _buildScholarshipRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String name,
  required String scholarshipProvider,
  required String description,
  required List<String>? eligibilityRequirements,
  required String deadline,
  required List<String>? privileges,
  required bool isSelected,
  required VoidCallback onToggleSelection,
}) {
  return _ScholarshipRowWidget(
    context: context,
    doc: doc,
    name: name,
    scholarshipProvider: scholarshipProvider,
    description: description,
    eligibilityRequirements: eligibilityRequirements,
    deadline: deadline,
    privileges: privileges,
    isSelected: isSelected,
    onToggleSelection: onToggleSelection,
  );
}

Widget _buildHeader(
  String selectedProvider,
  List<DocumentSnapshot> allScholarships,
  ValueChanged<String> onProviderChanged,
  TextEditingController searchController,
  ScholarshipData? sc,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
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
                    'Scholarship List',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage scholarship list and its contents',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              UploadDocumentButton(formType: 'scholarship'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: buildCompactStatCard(
                    'Total Scholarships',
                    '${sc?.totalScholarship}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
                    'New Scholarship',
                    sc?.newScholarship ?? "Unknown",
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
                    'Approaching Deadline',
                    sc?.approachingDeadline ?? "Unknown",
                    const Color.fromARGB(255, 245, 118, 0),
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: buildSearchField('scholarship name', searchController),
              ),
              const SizedBox(width: 16),
              ScholarshipProviderDropdown(
                allScholarships: allScholarships,
                initialValue: selectedProvider,
                onChanged: onProviderChanged,
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
                flex: 3,
                child: Text(
                  'Scholarship',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                flex: 3,
                child: Text(
                  'Eligibility/Requirements',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
          horizontal: isTablet ? 10 : 12,
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
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                'Scholarship',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              flex: 4,
              child: Text(
                'Eligibility/Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 85),
            Expanded(
              flex: 5,
              child: Text(
                'Benefits',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Text(
                'Deadline',
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
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple[50],
          border: Border.all(color: Colors.purple[200]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          items[0],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.purple[900],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (isExpanded && items.length > 1)
        ...items
            .skip(1)
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  border: Border.all(color: Colors.purple[200]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.purple[900],
                  ),
                  maxLines: 1,
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
                  color: Colors.purple[700],
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? 'Show less' : '+${items.length - 1} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple[700],
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

class _ScholarshipRowWidget extends StatefulWidget {
  final BuildContext context;
  final DocumentSnapshot doc;
  final String name;
  final String scholarshipProvider;
  final String description;
  final List<String>? eligibilityRequirements;
  final String deadline;
  final List<String>? privileges;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _ScholarshipRowWidget({
    required this.context,
    required this.doc,
    required this.name,
    required this.scholarshipProvider,
    required this.description,
    required this.eligibilityRequirements,
    required this.deadline,
    required this.privileges,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  State<_ScholarshipRowWidget> createState() => _ScholarshipRowWidgetState();
}

class _ScholarshipRowWidgetState extends State<_ScholarshipRowWidget> {
  bool eligibilityExpanded = false;
  bool benefitsExpanded = false;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1100;

    if (isMobile) {
      return Container(
        key: ValueKey(widget.doc.id),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: InkWell(
          onTap: () => showSCInfoModal(context, widget.doc),
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
              const SizedBox(width: 12),
              // Scholarship Name Column
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.scholarshipProvider.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.scholarshipProvider,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Eligibility Column
              Expanded(
                flex: 3,
                child: _buildExpandableList(
                  items: widget.eligibilityRequirements ?? [],
                  emptyText: 'No eligibility',
                  isExpanded: eligibilityExpanded,
                  onToggle: (value) => setState(() => eligibilityExpanded = value),
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
                      builder: (context) => ScholarshipFormDialog(
                        doc: widget.doc,
                        isEdit: true,
                      ),
                    );
                  } else if (value == 'delete') {
                    showDeleteConfirmation(
                      context,
                      widget.doc,
                      DeleteConfigs.scholarships,
                      'scholarships',
                      customDeleteHandler: handleScholarshipDelete,
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

    // Tablet & Desktop View
    return Container(
      key: ValueKey(widget.doc.id),
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 9 : 10,
        horizontal: isTablet ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () => showSCInfoModal(context, widget.doc),
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
            const SizedBox(width: 12),
            // Scholarship Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.scholarshipProvider.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.scholarshipProvider,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 40),
            // Eligibility/Requirements
            Expanded(
              flex: 4,
              child: _buildExpandableList(
                items: widget.eligibilityRequirements ?? [],
                emptyText: 'No eligibility/requirements',
                isExpanded: eligibilityExpanded,
                onToggle: (value) => setState(() => eligibilityExpanded = value),
              ),
            ),
            const SizedBox(width: 85),
            // Benefits/Privileges
            Expanded(
              flex: 5,
              child: _buildExpandableList(
                items: widget.privileges ?? [],
                emptyText: 'No benefits',
                isExpanded: benefitsExpanded,
                onToggle: (value) => setState(() => benefitsExpanded = value),
              ),
            ),
            const SizedBox(width: 16),
            // Deadline
            Expanded(
              flex: 5,
              child: Text(
                widget.deadline.isNotEmpty ? widget.deadline : "N/A",
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                    builder: (context) => ScholarshipFormDialog(
                      doc: widget.doc,
                      isEdit: true,
                    ),
                  );
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                    context,
                    widget.doc,
                    DeleteConfigs.scholarships,
                    'scholarships',
                    customDeleteHandler: handleScholarshipDelete,
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


