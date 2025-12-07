import 'package:capstone_project/modules/admin_module/buttons/add_faq_button.dart';
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

class _FaqManagementPageState extends State<FaqManagementPage> {
  String selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;

  final StatDataManagement statData = StatDataManagement();

  FAQsData? faqData;

  void _onCategoryChanged(String newCategory) {
    setState(() {
      selectedCategory = newCategory;
    });
  }

  int currentPage = 1;
  int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    loadStatData();
  }

  Future<void> loadStatData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await statData.getFAQsData();

      if (!mounted) return;

      setState(() {
        faqData = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading information bank data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      currentPage = 1;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
      ),
    );
  }
}

class DesktopFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final FAQsData? faq;

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
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      selectedCategory,
      context,
      onCategoryChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      faq,
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
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      selectedCategory,
      context,
      onCategoryChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      faq,
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
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMobileHeader(
                selectedCategory,
                onCategoryChanged,
                searchController,
                faq,
              ),
            ),
            // Table section with fixed height
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
                    _buildTableHeader(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('faqs')
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

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('No FAQs found.'));
                          }

                          return _buildFAQList(
                            context: context,
                            getAllFAQs: snapshot.data!.docs,
                            selectedCategory: selectedCategory,
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
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            selectedCategory,
            onCategoryChanged,
            searchController,
            faq,
          ),
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
                      stream:
                          FirebaseFirestore.instance
                              .collection('faqs')
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
                          return const Center(child: Text('No FAQs found.'));
                        }

                        return _buildFAQList(
                          context: context,
                          getAllFAQs: snapshot.data!.docs,
                          selectedCategory: selectedCategory,
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
              Text(
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
          AddFaqButton(),
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
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Add FAQ Button
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
              AddFaqButton(),
            ],
          ),

          // Stat Cards Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: buildStatCard(
                    'Total FAQs',
                    '${faq?.totalFAQs}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Most Frequent Category',
                    faq?.mostFrequentCategory ?? "Unknown",
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Most Asked Question',
                    faq?.mostAskedQuestion ?? 'Unknown',
                    Colors.purple,
                    Icons.group,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Latest FAQ',
                    faq?.latestFAQ ?? "Unknown",
                    Colors.orange,
                    Icons.help_outline,
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: buildSearchField(
                  'questions or category',
                  searchController,
                ),
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
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Question',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  'Answer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 60), // Space for popup menu
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
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'Question',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                'Answer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              flex: 3,
              child: Text(
                'Category',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 60),
          ],
        ),
      );
    },
  );
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
}) {
  final filtered =
      getAllFAQs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final question = (data['question'] ?? '').toString().toLowerCase();
        final category = (data['category'] ?? '').toString().toLowerCase();

        bool matchesCategory =
            selectedCategory == 'All Categories' ||
            category == selectedCategory.toLowerCase();

        bool matchesSearch =
            searchQuery.isEmpty ||
            question.contains(searchQuery.toLowerCase()) ||
            category.contains(searchQuery.toLowerCase());

        return matchesCategory && matchesSearch;
      }).toList();

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
        child:
            currentPageFAQs.isEmpty
                ? const Center(
                  child: Text('No FAQs match your search criteria.'),
                )
                : ListView.builder(
                  shrinkWrap: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: currentPageFAQs.length,
                  itemBuilder: (context, index) {
                    final doc = currentPageFAQs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildFAQRow(
                        context: context,
                        doc: doc,
                        question: data['question'] ?? 'N/A',
                        answer: data['answer'] ?? 'N/A',
                        category: data['category'] ?? 'General',
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
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;

  final categoryStyle = getCategoryStyle(category);

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[200]!),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap: () => showFAQInfoModal(context, doc),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.left,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              answer,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              softWrap: true,
              maxLines: 2,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 40),
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
          SizedBox(width: isMobile ? 12 : 12),
          SizedBox(
            width: 48, // Fixed width for popup menu
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'edit') {
                  showEditFAQModal(context, doc);
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                    context,
                    doc,
                    DeleteConfigs.faqs,
                    'faqs',
                  );
                }
              },
              itemBuilder:
                  (context) => [
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
          ),
        ],
      ),
    ),
  );
}
