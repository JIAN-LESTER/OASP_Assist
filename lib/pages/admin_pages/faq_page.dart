import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/colors.dart';
import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/pages/admin_pages/buttons/add_faq_button.dart';
import 'package:capstone_project/modal_pages/faq_edit.dart'
    show showEditFAQModal;
import 'package:capstone_project/modal_pages/faq_info.dart';
import 'package:capstone_project/pages/admin_pages/widgets/faq_category_dropdown_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
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

  void _onCategoryChanged(String newCategory) {
    setState(() {
      selectedCategory = newCategory;
    });
  }

  // Pagination variables
  int currentPage = 1;
  int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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
    return ResponsiveLayout(
      mobileBody: MobileFaqManagement(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
      tabletBody: TabletFaqManagement(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
      desktopBody: DesktopFaqManagement(
        selectedCategory: selectedCategory,
        onCategoryChanged: _onCategoryChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
    );
  }
}

// Desktop FAQ Management
class DesktopFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;

  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const DesktopFaqManagement({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
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
    );
  }
}

// Tablet FAQ Management
class TabletFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;

  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const TabletFaqManagement({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
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
    );
  }
}

// Mobile FAQ Management
class MobileFaqManagement extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;

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
      16.0,
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
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(selectedCategory, onCategoryChanged, searchController),
          const SizedBox(height: 16),

          // Main container
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

                  // FAQ list area
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('faqs')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('No FAQs found.'));
                        }

                        return _buildFAQList(
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


Widget _buildHeader(
  String selectedCategory,
  ValueChanged<String> onCategoryChanged,
  TextEditingController searchController,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Upload Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAQ Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage questions, answers, and categories',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              AddFaqButton(),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Search and Filter Row
          isMobile
              ? Column(
                children: [
                  buildSearchField('questions or category', searchController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FaqCategoryDropdownButton(
                          initialValue: selectedCategory,
                          onChanged: onCategoryChanged,
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              SizedBox(width: 40), // Actions space
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
            
          ],
        ),
      );
    },
  );
}

Widget _buildFAQList({
  required List<DocumentSnapshot> getAllFAQs,
  required String selectedCategory,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  // Filtering with corrected logic
  final filtered =
      getAllFAQs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final question = (data['question'] ?? '').toString().toLowerCase();
        final category = (data['category'] ?? '').toString().toLowerCase();

        // Fixed category filter - exact matching instead of contains
        bool matchesCategory =
            selectedCategory == 'All Categories' ||
            category == selectedCategory.toLowerCase();

        // Search filter - search across multiple fields
        bool matchesSearch =
            searchQuery.isEmpty ||
            question.contains(searchQuery.toLowerCase()) ||
            category.contains(searchQuery.toLowerCase());

        return matchesCategory && matchesSearch;
      }).toList();

  // Rest of the pagination logic remains the same...
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
                : ListView.separated(
                  itemCount: currentPageFAQs.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = currentPageFAQs[index];
                    final data = doc.data() as Map<String, dynamic>;
                   

                    return _buildIBRow(
                      context: context,
                      doc: doc,
                      question: data['question'] ?? 'N/A',
                      answer: data['answer'] ?? 'N/A',
                      category: data['category'] ?? 'General',
                     
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
          item: 'FAQs',
        ),
    ],
  );
}

Widget _buildIBRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String question,
  required String answer,
  required String category,

}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;

  // Normalize category for consistent display
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
          // Question
          Expanded(
            flex: 4,
            child: Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              softWrap: true,
              maxLines: 2,
               textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(width: 12),

          // Answer
          Expanded(
            flex: 3,
            child: Text(
              answer,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              softWrap: true,
              maxLines: 2,
               textAlign: TextAlign.justify,
               overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // Category
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(width: 12),

         

          const SizedBox(width: 12),

          // Actions
          PopupMenuButton<String>(
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
        ],
      ),
    ),
  );
}
