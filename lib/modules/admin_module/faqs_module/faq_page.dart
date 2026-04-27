import 'package:capstone_project/modules/admin_module/buttons/add_faq_button.dart';
import 'package:capstone_project/modules/admin_module/buttons/bulk.dart';
import 'package:capstone_project/modules/admin_module/faqs_module/faq_candidate_tab.dart';
import 'package:capstone_project/modules/admin_module/widgets/faq_category_dropdown_button.dart';
import 'package:capstone_project/modules/admin_module/widgets/pagination.dart';
import 'package:capstone_project/modules/admin_module/widgets/search_field.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/statcard_management.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/modules/admin_module/faqs_module/faq_edit.dart'
    show showEditFAQModal;
import 'package:capstone_project/modules/admin_module/faqs_module/faq_info.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';

import 'package:flutter/material.dart';


class FaqManagementPage extends StatefulWidget {
  const FaqManagementPage({super.key});

  @override
  State<FaqManagementPage> createState() => _FaqManagementPageState();
}

class _FaqManagementPageState extends State<FaqManagementPage>
    with BulkSelectionMixin, SingleTickerProviderStateMixin {
  // ── Tab controller ──────────────────────────────────────────────────────
  late final TabController _tabController;

  // ── FAQ list state ──────────────────────────────────────────────────────
  String selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;

  final StatDataManagement statData = StatDataManagement();
  FAQsData? faqData;

  int currentPage = 1;
  int itemsPerPage = 10;

  // ── Pending-candidate badge count ───────────────────────────────────────
  int _pendingCandidateCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    loadStatData();
    _listenToPendingCandidateCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ── Badge listener ──────────────────────────────────────────────────────
  void _listenToPendingCandidateCount() {
    FirebaseFirestore.instance
        .collection('faq_candidates')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() => _pendingCandidateCount = snap.docs.length);
      }
    });
  }

  // ── Data loading ────────────────────────────────────────────────────────
  Future<void> loadStatData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final data = await statData.getFAQsData();
      if (!mounted) return;
      setState(() {
        faqData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading FAQ data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      currentPage = 1;
      clearSelection();
    });
  }

  void _onCategoryChanged(String newCategory) {
    setState(() {
      selectedCategory = newCategory;
      currentPage = 1;
      clearSelection();
    });
  }

  void _goToPage(int page) => setState(() => currentPage = page);

  void _changeItemsPerPage(int n) =>
      setState(() {
        itemsPerPage = n;
        currentPage = 1;
      });

  Future<void> _loadStatsAsync() async {
    try {
      final data = await statData.getFAQsData();
      if (mounted) setState(() { faqData = data; isLoading = false; });
    } catch (e) {
      print('Error loading FAQ data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleBulkDelete() async {
    await handleBulkDelete(
      context: context,
      selectedIds: selectedIds,
      collection: 'faqs',
      itemType: 'faqs',
      onSuccess: () {
        clearSelection();
        _loadStatsAsync();
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
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

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab bar ──
          _buildTabBar(),
          // ── Tab views ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: FAQ list (existing content)
                _buildFaqListTab(),
                // Tab 1: FAQ Candidates
                _buildCandidatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF2E7D32),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF2E7D32),
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          const Tab(
            icon: Icon(Icons.quiz_outlined, size: 18),
            text: 'All FAQs',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('Candidates'),
                if (_pendingCandidateCount > 0) ...[
                  const SizedBox(width: 6),
                  _PendingBadge(count: _pendingCandidateCount),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FAQ list tab — wraps the existing responsive content ─────────────────
  Widget _buildFaqListTab() {
    return ResponsiveLayout(
      mobileBody: MobileFaqManagement(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        faq: faqData,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      tabletBody: TabletFaqManagement(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        faq: faqData,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
      ),
      desktopBody: DesktopFaqManagement(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        faq: faqData,
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

  // ── Candidates tab ────────────────────────────────────────────────────────
  Widget _buildCandidatesTab() {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final padding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAQ Candidates',
                    style: TextStyle(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Questions with 10+ occurrences awaiting review',
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Candidates list (fills remaining space)
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
              child: const FaqCandidatesTab(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Small badge widget shown next to "Candidates" tab label
// ============================================================================
class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// The rest of the file is UNCHANGED from the original faq_management.dart
// (DesktopFaqManagement, TabletFaqManagement, MobileFaqManagement,
//  mainContent, _buildHeader, _buildMobileHeader, _buildTableHeader,
//  _getFilteredFAQs, _buildFAQList, _buildFAQRow)
// ============================================================================

class DesktopFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final FAQsData? faq;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const DesktopFaqManagement({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.faq,
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
      selectedCategory, context, onCategoryChanged, searchController,
      currentPage, itemsPerPage, onPageChanged, onItemsPerPageChanged,
      24.0, faq, selectedIds, isSelectionMode, onToggleSelection,
      onToggleSelectAll, onClearSelection, onBulkDelete, isAllSelected,
    );
  }
}

class TabletFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final FAQsData? faq;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const TabletFaqManagement({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.faq,
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
      selectedCategory, context, onCategoryChanged, searchController,
      currentPage, itemsPerPage, onPageChanged, onItemsPerPageChanged,
      20.0, faq, selectedIds, isSelectionMode, onToggleSelection,
      onToggleSelectAll, onClearSelection, onBulkDelete, isAllSelected,
    );
  }
}

class MobileFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final FAQsData? faq;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

  const MobileFaqManagement({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.faq,
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
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('faqs')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final allDocs =
              snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
          final filtered =
              _getFilteredFAQs(allDocs, selectedCategory, searchController.text);
          final filteredIds = filtered.map((d) => d.id).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMobileHeader(
                    selectedCategory, onCategoryChanged, searchController, faq,
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
                      itemType: 'faqs',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
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
                          selectedIds.length == filtered.length &&
                              filtered.isNotEmpty,
                          () => onToggleSelectAll(filteredIds),
                          selectedIds,
                          filtered,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: allDocs.isEmpty
                              ? const Center(child: Text('No FAQs found.'))
                              : _buildFAQList(
                                  context: context,
                                  getAllFAQs: allDocs,
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
}

Widget mainContent(
  final String selectedCategory,
  BuildContext context,
  final ValueChanged<String> onCategoryChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final FAQsData? faq,
  final Set<String> selectedIds,
  final bool isSelectionMode,
  final Function(String) onToggleSelection,
  final Function(List<String>) onToggleSelectAll,
  final VoidCallback onClearSelection,
  final VoidCallback onBulkDelete,
  final Function(List<String>) isAllSelected,
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('faqs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final allDocs =
            snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
        final filtered =
            _getFilteredFAQs(allDocs, selectedCategory, searchController.text);
        final filteredIds = filtered.map((d) => d.id).toList();

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                selectedCategory, onCategoryChanged, searchController, faq,
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
                    itemType: 'faqs',
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
                        selectedIds.length == filtered.length &&
                            filtered.isNotEmpty,
                        () => onToggleSelectAll(filteredIds),
                        selectedIds,
                        filtered,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: allDocs.isEmpty
                            ? const Center(child: Text('No FAQs found.'))
                            : _buildFAQList(
                                context: context,
                                getAllFAQs: allDocs,
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

Widget _buildMobileHeader(
  String selectedCategory,
  ValueChanged<String> onCategoryChanged,
  TextEditingController searchController,
  FAQsData? faq,
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
                'FAQ Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage questions, answers, and categories',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const AddFaqButton(),
        ],
      ),
    ],
  );
}

Widget _buildHeader(
  String selectedCategory,
  ValueChanged<String> onCategoryChanged,
  TextEditingController searchController,
  FAQsData? faq,
) {
  return LayoutBuilder(builder: (context, constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

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
                  'FAQ Management',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage questions, answers, and categories',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const AddFaqButton(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: buildStatCard('Total FAQs', '${faq?.totalFAQs}',
                    Colors.blue, Icons.message),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildStatCard(
                    'Most Frequent Category',
                    faq?.mostFrequentCategory ?? 'Unknown',
                    Colors.green,
                    Icons.check_circle),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildStatCard(
                    'Most Asked Question',
                    faq?.mostAskedQuestion ?? 'Unknown',
                    Colors.purple,
                    Icons.group),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildStatCard('Latest FAQ', faq?.latestFAQ ?? 'Unknown',
                    Colors.orange, Icons.help_outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: buildSearchField('questions or category', searchController),
            ),
            const SizedBox(width: 16),
            FaqCategoryDropdownButton(
              initialValue: selectedCategory,
              onChanged: onCategoryChanged,
            ),
          ],
        ),
      ],
    );
  });
}

Widget _buildTableHeader(
  bool isAllSelected,
  VoidCallback onSelectAll,
  Set<String> selectedIds,
  List<DocumentSnapshot> filteredDocs,
) {
  return LayoutBuilder(builder: (context, constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

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
                    color: isAllSelected
                        ? const Color(0xFF2E7D32)
                        : Colors.white,
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
              child: Text('Question',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.black87)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              flex: 3,
              child: Text('Answer',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.black87)),
            ),
            const SizedBox(width: 5),
            const SizedBox(width: 40),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isTablet ? 14 : 16, horizontal: 12),
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
                  color:
                      isAllSelected ? const Color(0xFF2E7D32) : Colors.white,
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
            flex: 4,
            child: Text('Question',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 13 : 14,
                    color: Colors.black87)),
          ),
          Expanded(
            flex: 3,
            child: Text('Answer',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 13 : 14,
                    color: Colors.black87)),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 3,
            child: Text('Category',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 13 : 14,
                    color: Colors.black87)),
          ),
          SizedBox(width: isTablet ? 40 : 5),
          const SizedBox(width: 40),
        ],
      ),
    );
  });
}

List<DocumentSnapshot> _getFilteredFAQs(
  List<DocumentSnapshot> docs,
  String selectedCategory,
  String searchQuery,
) {
  return docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final question = (data['question'] ?? '').toString().toLowerCase();
    final answer = (data['answer'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? '').toString().toLowerCase();

    final matchesCategory = selectedCategory == 'All Categories' ||
        category == selectedCategory.toLowerCase();
    final matchesSearch = searchQuery.isEmpty ||
        question.contains(searchQuery.toLowerCase()) ||
        answer.contains(searchQuery.toLowerCase()) ||
        category.contains(searchQuery.toLowerCase());

    return matchesCategory && matchesSearch;
  }).toList();
}

Widget _buildFAQList({
  required BuildContext context,
  required List<DocumentSnapshot> getAllFAQs,
  required String selectedCategory,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required Set<String> selectedIds,
  required Function(String) onToggleSelection,
}) {
  final filtered = _getFilteredFAQs(getAllFAQs, selectedCategory, searchQuery);
  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageFAQs = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child: currentPageFAQs.isEmpty
            ? const Center(
                child: Text('No FAQs match your search criteria.'))
            : ListView.builder(
                shrinkWrap: false,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: currentPageFAQs.length,
                itemBuilder: (context, index) {
                  final doc = currentPageFAQs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return Padding(
                    key: ValueKey(doc.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildFAQRow(
                      context: context,
                      doc: doc,
                      question: data['question'] ?? 'N/A',
                      answer: data['answer'] ?? 'N/A',
                      category: data['category'] ?? 'General',
                      isSelected: selectedIds.contains(doc.id),
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
          item: 'FAQs',
        ),
    ],
  );
}

Widget _buildFAQRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String question,
  required String answer,
  required String category,
  required bool isSelected,
  required VoidCallback onToggleSelection,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1100;
  final categoryStyle = getCategoryStyle(category);

  return Container(
    key: ValueKey(doc.id),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[200]!, width: 1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap: () => showFAQInfoModal(context, doc),
      child: Row(
        children: [
          InkWell(
            onTap: onToggleSelection,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF2E7D32) : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              question,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (isMobile) const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(answer,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          if (!isMobile) const SizedBox(width: 40),
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    categoryStyle.displayName,
                    style: TextStyle(
                        fontSize: 12,
                        color: categoryStyle.textColor,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          SizedBox(width: isTablet ? 40 : 5),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon:
                  Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onSelected: (value) {
                if (value == 'edit') {
                  showEditFAQModal(context, doc);
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                      context, doc, DeleteConfigs.faqs, 'faqs');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF6B7280)),
                      SizedBox(width: 8),
                      Text('Edit',
                          style: TextStyle(color: Color(0xFF1F2937))),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: Color(0xFFEF4444))),
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
