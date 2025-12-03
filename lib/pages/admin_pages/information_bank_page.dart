import 'dart:async';

import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/pages/admin_pages/buttons/upload_document_button.dart';
import 'package:capstone_project/modal_pages/ib_edit.dart';
import 'package:capstone_project/modal_pages/ib_info.dart';
import 'package:capstone_project/pages/admin_pages/widgets/category_dropdown_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/modal_pages/modal_widget/top_right_alert.dart';
import 'package:flutter/material.dart';

class InformationBankPage extends StatefulWidget {
  const InformationBankPage({super.key});

  @override
  State<InformationBankPage> createState() => _InformationBankPageState();
}

// Replace the _InformationBankPageState class with this optimized version:

class _InformationBankPageState extends State<InformationBankPage> {
  String selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = false;


  final StatDataManagement statData = StatDataManagement();

  InformationBankData? ibData;

  int currentPage = 1;
  int itemsPerPage = 10;

  void _onCategoryChanged(String newCategory) {
    setState(() {
      selectedCategory = newCategory;
      currentPage = 1; // Reset to first page when category changes
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // ✅ Initialize the stream once

    // ✅ Load stats asynchronously without blocking UI
    _loadStatsAsync();
  }

  // ✅ Load stats in background without blocking
  Future<void> _loadStatsAsync() async {
    try {
      final data = await statData.getInformationBankData();
      if (mounted) {
        setState(() {
          ibData = data;
        });
      }
    } catch (e) {
      print("Error loading information bank data: $e");
    }
  }

  void _onSearchChanged() {

        setState(() {
          currentPage = 1;
    
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        // ✅ Pass the stream
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
        // ✅ Pass the stream
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
        // ✅ Pass the stream
      ),
    );
  }
}

// ✅ Update all layout classes to accept the stream

class DesktopInformationBank extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final InformationBankData? ib;

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
              child: _buildMobileHeader(
                selectedCategory,
                onCategoryChanged,
                searchController,
                ib,
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
                    _buildTableHeader(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('information_bank')
                                .orderBy('createdAt', descending: true)
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
                            return const Center(
                              child: Text('No documents found.'),
                            );
                          }

                          return _buildIBList(
                            context: context,
                            getAllDocuments: snapshot.data!.docs,
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

// ✅ Update mainContent to accept and use the stream
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
            ib,
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
                              .collection('information_bank')
                              .orderBy('createdAt', descending: true)
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
                          return const Center(
                            child: Text('No documents found.'),
                          );
                        }

                        return _buildIBList(
                          context: context,
                          getAllDocuments: snapshot.data!.docs,
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
  InformationBankData? ib,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Title
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
          // Title and Upload Button
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

          // Stat Cards Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: buildStatCard(
                    'Total Documents',
                    '${ib?.totalDocuments}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Most Frequent Category',
                    ib?.mostFrequentCategory.toUpperCase() ?? "Unknown",
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Latest Upload',
                    ib?.latestUpload ?? "Unknown",
                    Colors.red,
                    Icons.group,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Search and Filter Row
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
                flex: 3,
                child: Text(
                  'Document',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Text(
                  'Category',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 40), // space for actions
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
              flex: 3,
              child: Text(
                'Document',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
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
                  color: Colors.black87,
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
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 40 : 5),
            const SizedBox(width: 40), // Fixed space for action button
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
}) {
  final filtered =
      getAllDocuments.where((doc) {
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

                    return Padding(
                      key: ValueKey(doc.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildIBRow(
                        context: context,
                        doc: doc,
                        title: data['ib_title'] ?? 'N/A',
                        source: data['source'] ?? 'N/A',
                        category: data['category'] ?? 'General',
            content: cleanPdfContent(
  contentStr.length > 50 ? "${contentStr.substring(0, 50)}..." : contentStr,
),
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
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;
  bool isTablet = screenWidth >= 600 && screenWidth < 1100;

  final categoryStyle = getCategoryStyle(category);

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[200]!),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap: () => showIBInfoModal(context, doc),
      child: Row(
        children: [
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

          // Spacing before action button
          SizedBox(width: isTablet ? 40 : 5),

          // Action button - Fixed width 40
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
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
