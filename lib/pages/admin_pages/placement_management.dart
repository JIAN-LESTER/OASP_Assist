import 'package:capstone_project/modal_pages/add_edit_placement.dart';
import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
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

  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
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
      print("Error loading information bank data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      pl,
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
  final PlacementData? pl,
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
            pl,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
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
  final filtered =
      allPlacements.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final company =
            (data['partnerCompany'] ?? '').toString().toLowerCase().trim();

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
        child:
            currentPagePlacements.isEmpty
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildPlacementRow(
                        context: context,
                        doc: doc,
                        partnerCompany: data['partnerCompany'] ?? 'N/A',
                        contacts: contacts,
                        positions: positions,
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
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showDialog(
                  context: context,
                  builder:
                      (context) => PlacementFormDialog(doc: doc, isEdit: true),
                );
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
              Row(children: [UploadDocumentButton(formType: 'placement')]),
            ],
          ),

          // Stat Cards Section - Fixed for Mobile (1 per row)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child:
                isMobile
                    ? Column(
                      children: [
                        buildStatCard(
                          'Total Companies',
                          '${pl?.totalCompanies ?? 0}',
                          Colors.blue,
                          Icons.message,
                        ),
                        const SizedBox(height: 12),
                        buildStatCard(
                          'Companies Looking for Vacancy',
                          '${pl?.vacantCompanies ?? 0}',
                          Colors.green,
                          Icons.check_circle,
                        ),
                        const SizedBox(height: 12),
                        buildStatCard(
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
                          child: buildStatCard(
                            'Total Companies',
                            '${pl?.totalCompanies ?? 0}',
                            Colors.blue,
                            Icons.message,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildStatCard(
                            'Companies Looking for Vacancy',
                            '${pl?.vacantCompanies ?? 0}',
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildStatCard(
                            'Approaching Deadline',
                            pl?.approachingDeadline ?? 'Unknown',
                            Colors.red,
                            Icons.group,
                          ),
                        ),
                      ],
                    ),
          ),

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
              SizedBox(width: 40),
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
            SizedBox(width: isTablet ? 60 : 80),
          ],
        ),
      );
    },
  );
}
