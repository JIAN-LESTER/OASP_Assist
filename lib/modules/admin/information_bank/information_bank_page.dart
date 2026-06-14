import 'dart:async';

import 'package:capstone_project/buttons/bulk.dart';
import 'package:capstone_project/buttons/upload_document_button.dart' show UploadDocumentButton;
import 'package:capstone_project/modules/admin/dashboard_and_reports/statcard_management.dart';
import 'package:capstone_project/modules/admin/information_bank/ib_format.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:capstone_project/widgets/category_dropdown_button.dart';
import 'package:capstone_project/widgets/pagination.dart';
import 'package:capstone_project/widgets/search_field.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/modules/admin/information_bank/ib_edit.dart';
import 'package:capstone_project/modules/admin/information_bank/ib_info.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InformationBankPage extends StatefulWidget {
  const InformationBankPage({super.key});

  @override
  State<InformationBankPage> createState() => _InformationBankPageState();
}

class _InformationBankPageState extends State<InformationBankPage>
    with BulkSelectionMixin {
  String selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  final StatDataManagement statData = StatDataManagement();

  InformationBankData? ibData;

  int currentPage = 1;
  int itemsPerPage = 10;

  void _onCategoryChanged(String newCategory) {
    setState(() {
      selectedCategory = newCategory;
      currentPage = 1;
      clearSelection();
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadStatsAsync();
  }

  Future<void> _loadStatsAsync() async {
    try {
      final data = await statData.getInformationBankData();
      if (mounted) {
        setState(() {
          ibData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading information bank data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      currentPage = 1;
      clearSelection();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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

  void _handleBulkDelete() async {
    await handleBulkDelete(
      context: context,
      selectedIds: selectedIds,
      collection: 'information_bank',
      itemType: 'documents',
      onSuccess: () {
        clearSelection();
        _loadStatsAsync();
      },
      customDeleteHandler: handleInformationBankDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    return ResponsiveLayout(
      mobileBody: MobileInformationBank(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        ib: ibData,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      tabletBody: TabletInformationBank(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        ib: ibData,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      desktopBody: DesktopInformationBank(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        ib: ibData,
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

class DesktopInformationBank extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final InformationBankData? ib;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const DesktopInformationBank({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.ib,
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
      selectedCategory,
      onCategoryChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      ib,
      context,
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

class TabletInformationBank extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final InformationBankData? ib;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const TabletInformationBank({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.ib,
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
      selectedCategory,
      onCategoryChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      ib,
      context,
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

class MobileInformationBank extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final InformationBankData? ib;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const MobileInformationBank({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.ib,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('information_bank')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          // Show loading only on first load
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs =
              snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
          final filtered = _getFilteredDocs(
            allDocs,
            selectedCategory,
            searchController.text,
          );
          final filteredIds = filtered.map((d) => d.id).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMobileHeader(
                    selectedCategory,
                    onCategoryChanged,
                    searchController,
                    ib,
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
                      itemType: 'documents',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        buildTableHeader(
                          selectedIds.length == filtered.length &&
                              filtered.isNotEmpty,
                          () => onToggleSelectAll(filteredIds),
                          selectedIds,
                          filtered,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child:
                              allDocs.isEmpty
                                  ? const Center(
                                    child: Text('No documents found.'),
                                  )
                                  : _buildIBList(
                                    context: context,
                                    getAllDocuments: allDocs,
                                    selectedCategory: selectedCategory,
                                    searchQuery: searchController.text,
                                    currentPage: currentPage,
                                    itemsPerPage: itemsPerPage,
                                    onPageChanged: onPageChanged,
                                    onItemsPerPageChanged:
                                        onItemsPerPageChanged,
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
          );
        },
      ),
    );
  }
}

Widget mainContent(
  final String selectedCategory,
  final ValueChanged<String> onCategoryChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final InformationBankData? ib,
  final BuildContext context,
  final Set<String> selectedIds,
  final bool isSelectionMode,
  final Function(String) onToggleSelection,
  final Function(List<String>) onToggleSelectAll,
  final VoidCallback onClearSelection,
  final VoidCallback onBulkDelete,
  final Function(List<String>) isAllSelected,
) {
  return Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    body: StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('information_bank')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        // Show loading only on first load
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs =
            snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
        final filtered = _getFilteredDocs(
          allDocs,
          selectedCategory,
          searchController.text,
        );
        final filteredIds = filtered.map((d) => d.id).toList();

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                selectedCategory,
                onCategoryChanged,
                searchController,
                ib,
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
                    itemType: 'documents',
                  ),
                ),
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
                      buildTableHeader(
                        selectedIds.length == filtered.length &&
                            filtered.isNotEmpty,
                        () => onToggleSelectAll(filteredIds),
                        selectedIds,
                        filtered,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child:
                            allDocs.isEmpty
                                ? const Center(
                                  child: Text('No documents found.'),
                                )
                                : _buildIBList(
                                  context: context,
                                  getAllDocuments: allDocs,
                                  selectedCategory: selectedCategory,
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
        );
      },
    ),
  );
}

// Keep existing helper functions unchanged
Widget _buildMobileHeader(
  String selectedCategory,
  ValueChanged<String> onCategoryChanged,
  TextEditingController searchController,
  InformationBankData? ib,
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
              Text(
                'Information Bank',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Centralized document repository',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          UploadDocumentButton(),
        ],
      ),
    ],
  );
}

Widget _buildHeader(
  String selectedCategory,
  ValueChanged<String> onCategoryChanged,
  TextEditingController searchController,
  InformationBankData? ib,
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
                    'Information Bank',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Centralized document repository for quick reference',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              UploadDocumentButton(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: buildCompactStatCard(
                    'Total Documents',
                    '${ib?.totalDocuments}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
                    'Most Frequent Category',
                    ib?.mostFrequentCategory.toUpperCase() ?? "Unknown",
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
                    'Latest Upload',
                    ib?.latestUpload ?? "Unknown",
                    Colors.red,
                    Icons.group,
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
                child: buildSearchField(
                  'documents, source or category',
                  searchController,
                ),
              ),
              const SizedBox(width: 16),
              CategoryDropdownButton(
                initialValue: selectedCategory,
                onChanged: onCategoryChanged,
              ),
            ],
          ),
        ],
      );
    },
  );
}

List<DocumentSnapshot> _getFilteredDocs(
  List<DocumentSnapshot> docs,
  String selectedCategory,
  String searchQuery,
) {
  return docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['ib_title'] ?? '').toString().toLowerCase();
    final source = (data['source'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? '').toString().toLowerCase();

    bool matchesCategory =
        selectedCategory == 'All Categories' ||
        category == selectedCategory.toLowerCase();

    bool matchesSearch =
        searchQuery.isEmpty ||
        title.contains(searchQuery.toLowerCase()) ||
        source.contains(searchQuery.toLowerCase()) ||
        category.contains(searchQuery.toLowerCase());

    return matchesCategory && matchesSearch;
  }).toList();
}

Widget buildTableHeader(
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
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
                      color: isAllSelected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: isAllSelected ? Colors.white : Colors.white70,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:
                        isAllSelected
                            ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Color(0xFF2E7D32),
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Document',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 9 : 10,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
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
                    color: isAllSelected ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: isAllSelected ? Colors.white : Colors.white70,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      isAllSelected
                          ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          )
                          : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                'Document',
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
                'Content',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 100),
            Expanded(
              flex: 3,
              child: Text(
                'Category',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 40 : 5),
            const SizedBox(width: 40),
          ],
        ),
      );
    },
  );
}

Widget _buildIBList({
  required BuildContext context,
  required List<DocumentSnapshot> getAllDocuments,
  required String selectedCategory,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required Set<String> selectedIds,
  required Function(String) onToggleSelection,
}) {
  final filtered = _getFilteredDocs(
    getAllDocuments,
    selectedCategory,
    searchQuery,
  );

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageIB = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child:
            currentPageIB.isEmpty
                ? const Center(
                  child: Text('No documents match your search criteria.'),
                )
                : ListView.builder(
                  shrinkWrap: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: currentPageIB.length,
                  itemBuilder: (context, index) {
                    final doc = currentPageIB[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp timeStamp =
                        data['createdAt'] ?? Timestamp.now();
                    final DateTime date = timeStamp.toDate();
                    final String formattedDate = DateFormat(
                      "MMMM d, yyyy 'at' hh:mm a",
                    ).format(date);

                    final contentStr = data['content'] as String;
                    final source = data['source'] ?? 'Unknown';

                    final preview = ContentFormatter.getPreviewText(
                      contentStr,
                      source,
                      maxLength: 50,
                    );

                    return Padding(
                      key: ValueKey(doc.id),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildIBRow(
                        context: context,
                        doc: doc,
                        title: data['ib_title'] ?? 'N/A',
                        source: source,
                        category: data['category'] ?? 'General',
                        content: preview,
                        isSelected: selectedIds.contains(doc.id),
                        onToggleSelection: () => onToggleSelection(doc.id),
                        index: index,
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
          item: 'documents',
        ),
    ],
  );
}

Widget _buildIBRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String title,
  required String category,
  required String source,
  required String content,
  required bool isSelected,
  required VoidCallback onToggleSelection,
  required int index,
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;
  bool isTablet = screenWidth >= 600 && screenWidth < 1100;

  final categoryStyle = getCategoryStyle(category);

  if (isMobile) {
    return Container(
      key: ValueKey(doc.id),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => showIBInfoModal(context, doc),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggleSelection,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      isSelected
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: categoryStyle.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        categoryStyle.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: categoryStyle.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    showEditIBModal(context, doc);
                  } else if (value == 'delete') {
                    showDeleteConfirmation(
                      context,
                      doc,
                      DeleteConfigs.document,
                      'information_bank',
                      customDeleteHandler: handleInformationBankDelete,
                    );
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: TextStyle(color: Color(0xFF1F2937)),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFEF4444)),
                            ),
                          ],
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

  return Container(
    key: ValueKey(doc.id),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
      border: Border.all(color: Colors.grey[200]!, width: 1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap: () => showIBInfoModal(context, doc),
      child: Row(
        children: [
          // Custom Checkbox
          InkWell(
            onTap: onToggleSelection,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Document Title - flex: 3
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (isMobile) ...[const SizedBox(width: 20)],

          // Content - flex: 4 (only on tablet/desktop)
          if (!isMobile)
            Expanded(
              flex: 4,
              child: Text(
                content,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Spacing to match header
          if (!isMobile) const SizedBox(width: 100),

          // Category - flex: 3
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryStyle.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  categoryStyle.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: categoryStyle.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Spacing before action button
          SizedBox(width: isTablet ? 40 : 5),

          // Action button - Fixed width 40
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  showEditIBModal(context, doc);
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                    context,
                    doc,
                    DeleteConfigs.document,
                    'information_bank',
                    customDeleteHandler: handleInformationBankDelete,
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(color: Color(0xFF1F2937)),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ],
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
