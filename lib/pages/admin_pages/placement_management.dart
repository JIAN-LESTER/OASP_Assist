import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modal_pages/add_edit_placement.dart';
import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/modal_pages/pl_info.dart';
import 'package:capstone_project/modal_pages/placement_edit.dart';
import 'package:capstone_project/pages/admin_pages/buttons/upload_document_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/company_dropdown.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/pages/admin_pages/widgets/empty_state.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/modal_pages/modal_widget/top_right_alert.dart';
import 'package:flutter/material.dart';

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
  return _PlacementRowWidget(
    context: context,
    doc: doc,
    partnerCompany: partnerCompany,
    contacts: contacts,
    positions: positions,
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
                  'Company',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
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
              SizedBox(width: 50),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 14 : 16,
          horizontal: 16,
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
            SizedBox(width: isTablet ? 70 : 80),
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

  final processedItems =
      items.map((c) {
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (isExpanded && processedItems.length > 1)
        ...processedItems
            .skip(1)
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
                  maxLines: 2,
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
                  isExpanded
                      ? 'Show less'
                      : '+${processedItems.length - 1} more',
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

  const _PlacementRowWidget({
    required this.context,
    required this.doc,
    required this.partnerCompany,
    required this.contacts,
    required this.positions,
  });

  @override
  State<_PlacementRowWidget> createState() => _PlacementRowWidgetState();
}

class _PlacementRowWidgetState extends State<_PlacementRowWidget> {
  bool positionsExpanded = false;
  bool contactsExpanded = false;

  @override
  Widget build(BuildContext context) {
    DocumentSnapshot doc = widget.doc;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1100;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
            SizedBox(width: isMobile ? 8 : (isTablet ? 16 : 20)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder:
                        (context) =>
                            PlacementFormDialog(doc: widget.doc, isEdit: true),
                  );
                } else if (value == 'delete') {
              showDeleteConfirmation(
  context,
  doc,
  DeleteConfigs.placements,
  'placements',
  customDeleteHandler: handlePlacementDelete,
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
}
