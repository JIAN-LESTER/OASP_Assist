import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/modal_pages/add_edit_affiliation.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/pages/admin_pages/widgets/empty_state.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class AffiliationManagementPage extends StatefulWidget {
  const AffiliationManagementPage({super.key});

  @override
  State<AffiliationManagementPage> createState() =>
      _AffiliationManagementPageState();
}

class _AffiliationManagementPageState extends State<AffiliationManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;

  final StatDataManagement statData = StatDataManagement();
  AffiliationData? affiliation;

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
      final data = await statData.getAffiliationData();

      if (!mounted) return;

      setState(() {
        affiliation = data;
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
      mobileBody: MobileAffiliationManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        affiliation: affiliation,
      ),
      tabletBody: TabletAffiliationManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        affiliation: affiliation,
      ),
      desktopBody: DesktopAffiliationManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        affiliation: affiliation,
      ),
    );
  }
}

class DesktopAffiliationManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final AffiliationData? affiliation;

  const DesktopAffiliationManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.affiliation,
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
      affiliation,
    );
  }
}

class TabletAffiliationManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final AffiliationData? affiliation;

  const TabletAffiliationManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.affiliation,
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
      affiliation,
    );
  }
}

class MobileAffiliationManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final AffiliationData? affiliation;

  const MobileAffiliationManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.affiliation,
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
                searchController,
                context,
                affiliation,
              ),
            ),
            // Table section with fixed height
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
                            .collection('affiliations')
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
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return buildEmptyState(false, false, "affiliations");
                          }

                          return _buildAffiliationList(
                            allAffiliations: snapshot.data!.docs,
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
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final AffiliationData? affiliation,
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(searchController, context, affiliation),
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
                              .collection('affiliations')
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
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return buildEmptyState(false, false, "affiliations");
                        }

                        return _buildAffiliationList(
                          allAffiliations: snapshot.data!.docs,
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
  AffiliationData? affiliation,
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
                    'Affiliations Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage academic affiliations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              _buildAddButton(context, false, true),
            ],
          ),

     
      const SizedBox(height: 16),
      // Search field
      buildSearchField('Search affiliations by name', searchController),
    ],
  );
}

Widget _buildAffiliationList({
  required List<DocumentSnapshot> allAffiliations,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  final filtered =
      allAffiliations.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();

        bool matchesSearch =
            searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());

        return matchesSearch;
      }).toList();

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageAffiliations = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child:
            currentPageAffiliations.isEmpty
                ? const Center(
                  child: Text('No affiliations match your search criteria.'),
                )
                : ListView.builder(
                  shrinkWrap: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: currentPageAffiliations.length,
                  itemBuilder: (context, index) {
                    final doc = currentPageAffiliations[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAffiliationRow(
                        context: context,
                        doc: doc,
                        name: data['name'] ?? 'N/A',
                        description: data['description'] ?? '-',
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
          item: 'affiliations',
        ),
    ],
  );
}

Widget _buildAffiliationRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String name,
  required String description,
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
              if (!isMobile && description.isNotEmpty && description != '-')
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
            ],
          ),
        ),
        SizedBox(width: isTablet ? 60 : 80),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            if (value == 'edit') {
              showDialog(
                context: context,
                builder:
                    (context) => AddEditaffiliationDialog(
                      affiliation: doc,
                      onSaved: () {},
                    ),
              );
            } else if (value == 'delete') {
              showDeleteConfirmation(
                context,
                doc,
                DeleteConfigs.affiliations,
                'affiliations',
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
  );
}

Widget _buildHeader(
  TextEditingController searchController,
  BuildContext context,
  AffiliationData? affiliation,
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
                    'Affiliations Management',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage academic affiliations',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              _buildAddButton(context, true, isTablet),
            ],
          ),

          // Stat Cards Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: buildStatCard(
                    'Total Affiliations',
                    '${affiliation?.totalAffiliations}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Affiliation where most students are affiliated',
                    '${affiliation?.dominantAffiliation}',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
          ),

     

          buildSearchField('Search affiliations by name', searchController),
        ],
      );
    },
  );
}

Widget _buildAddButton(BuildContext context, bool isMobile, bool isTablet) {
  double height = isMobile ? 44 : (isTablet ? 46 : 48);
  double fontSize = isMobile ? 13 : (isTablet ? 14 : 15);
  double horizontalPadding = isMobile ? 16 : (isTablet ? 18 : 20);
  double iconSize = isMobile ? 18 : (isTablet ? 20 : 22);
  double borderRadius = 8;

  return Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFF2E7D32),
      borderRadius: BorderRadius.circular(borderRadius),
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
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AddEditaffiliationDialog(onSaved: () {}),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: iconSize),
              const SizedBox(width: 8),
              Text(
                isMobile ? 'Add' : 'Add',
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
}

Widget _buildTableHeader() {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

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
              Icons.school,
              color: Colors.grey[600],
              size: isMobile ? 20 : 24,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Affiliation Name',
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