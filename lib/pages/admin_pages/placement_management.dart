import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/modal_pages/pl_info.dart';


import 'package:capstone_project/modal_pages/placement_edit.dart';


import 'package:capstone_project/pages/admin_pages/buttons/upload_document_button.dart';

import 'package:capstone_project/pages/admin_pages/widgets/company_dropdown.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';

import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

import '../../crud/delete/delete.dart';

class PlacementManagementPage extends StatefulWidget {
  const PlacementManagementPage({super.key});

  @override
  State<PlacementManagementPage> createState() =>
      _PlacementManagementPageState();
}

class _PlacementManagementPageState extends State<PlacementManagementPage> {
  String selectedCompany = 'All Company';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> allPlacements = [];

  // Pagination variables
  int currentPage = 1;
  int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    loadPlacements();
  }

  void loadPlacements() {
    FirebaseFirestore.instance.collection('placements').snapshots().listen((
      snapshot,
    ) {
      setState(() {
        allPlacements = snapshot.docs;
      });
    });
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
    });
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
      mobileBody: MobilePlacementManagement(
        allPlacements: allPlacements,
        selectedCompany: selectedCompany,
        onCompanyChanged: _onCompanyChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
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
      ),
    );
  }
}

// Desktop Placement Management
class DesktopPlacementManagement extends StatelessWidget {
  final List<DocumentSnapshot> allPlacements;
  final String selectedCompany;
  final ValueChanged<String> onCompanyChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

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
    );
  }
}

// Tablet Placement Management
class TabletPlacementManagement extends StatelessWidget {
  final List<DocumentSnapshot> allPlacements;
  final String selectedCompany;
  final ValueChanged<String> onCompanyChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

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
    );
  }
}

// Mobile Placement Management
class MobilePlacementManagement extends StatelessWidget {
  final List<DocumentSnapshot> allPlacements;
  final String selectedCompany;
  final ValueChanged<String> onCompanyChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

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
      16.0,
    );
  }
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
) {
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
          ),
          const SizedBox(height: 16),
          Expanded(
          child:Container(
            height: MediaQuery.of(context).size.height - 200,
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
                  child: _buildPlacementList(
                    allPlacements: allPlacements,
                    selectedCompany: selectedCompany,
                    searchQuery: searchController.text,
                    currentPage: currentPage,
                    itemsPerPage: itemsPerPage,
                    onPageChanged: onPageChanged,
                    onItemsPerPageChanged: onItemsPerPageChanged,
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

Widget _buildPlacementList({
  required List<DocumentSnapshot> allPlacements,
  required String selectedCompany,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  // Filtering
final filtered = allPlacements.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  final company =
      (data['partnerCompany'] ?? '').toString().toLowerCase().trim();

  // Ensure positions is a List<String>
  final List<String> positionsList = (data['positions'] is List)
      ? List<String>.from(data['positions'].map((e) => e.toString()))
      : <String>[];

  final query = searchQuery.toLowerCase().trim();
  final companyFilter = selectedCompany.toLowerCase().trim();


  bool matchesCompany =
      companyFilter == 'all company' || 
      companyFilter == 'all' ||
      company == companyFilter;

  // Search filter → check if query matches company or ANY position
  bool matchesSearch = query.isEmpty ||
      company.contains(query) ||
      positionsList.any((pos) => pos.toLowerCase().contains(query));

  return matchesCompany && matchesSearch;
}).toList();


  // Calculate pagination
  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  // Pagination
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPagePlacements = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
 
      Expanded(
        child:
            currentPagePlacements.isEmpty
                ? const Center(
                  child: Text('No companies match your criteria.'),
                )
                : ListView.separated(
                  itemCount: currentPagePlacements.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
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


          
                    return _buildPlacementRow(
                      context: context,
                      doc: doc,
                      partnerCompany: data['partnerCompany'] ?? 'N/A',
                 
                      contacts: contacts,
                      positions: positions,
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
          item: 'placements',
        ),
    ],
  );
}

// Helper to format month names

Widget _buildPlacementRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String partnerCompany,

  required List<String>? contacts,
  required List<String>? positions,
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
    child: InkWell(
      onTap: () => showPLInfoModal(context, doc),
      child: Row(
        children: [
          // Title + Source
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerCompany,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  positions != null && positions.isNotEmpty
                      ? positions.map((c) {
                        String displayValue = c;

                        if (c.contains(":")) {
                          final parts = c.split(":");
                          // Join everything after the first colon → keeps full URL
                          final value = parts.sublist(1).join(":").trim();
                          displayValue = value;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayValue,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList()
                      : [
                        Text(
                          "No Vacancy",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
            ),
          ),

    
           Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  contacts != null && contacts.isNotEmpty
                      ? contacts.map((c) {
                        String displayValue = c;

                        if (c.contains(":")) {
                          final parts = c.split(":");
                          // Join everything after the first colon → keeps full URL
                          final value = parts.sublist(1).join(":").trim();
                          displayValue = value;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayValue,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList()
                      : [
                        Text(
                          "No Contacts",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
            ),
          ),

          // Actions
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showEditPlacementDialog(doc, context);
              } else if (value == 'delete') {
                showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.admissions,
                  'placements',
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
                        Icon(Icons.delete, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
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
  String selectedCompany,
  List<DocumentSnapshot> allPlacements,
  ValueChanged<String> onCompanyChanged,
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
          // Title and Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
              Row(children: [UploadDocumentButton()]),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Search and Filter Row
          isMobile
              ? Column(
                children: [
                  buildSearchField('positions', searchController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PlacementCompanyDropdown(
                          allPlacements: allPlacements,
                          initialValue: selectedCompany,
                          onChanged: onCompanyChanged,
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
                flex: 3,
                child: Text(
                  'Company',
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
                  'Positions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Contacts',
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
            Expanded(
              flex: 4, // match row
              child: Text(
                'Positions',
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
                'Contacts',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 60 : 80), // Actions space
          ],
        ),
      );
    },
  );
}
