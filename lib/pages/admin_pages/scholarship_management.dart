import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modal_pages/add_edit_scholarship.dart';
import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modal_pages/scholarship_edit.dart';
import 'package:capstone_project/modal_pages/scholarship_info.dart';
import 'package:capstone_project/pages/admin_pages/buttons/upload_document_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/provider_dropdown.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:flutter/material.dart';

class ScholarshipManagementPage extends StatefulWidget {
  const ScholarshipManagementPage({super.key});

  @override
  State<ScholarshipManagementPage> createState() =>
      _ScholarshipManagementPageState();
}

class _ScholarshipManagementPageState extends State<ScholarshipManagementPage> {
  String selectedProvider = 'All Providers';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> allScholarships = [];

  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
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
      print("Error loading information bank data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _loadScholarships() {
    FirebaseFirestore.instance.collection('scholarships').orderBy('createdAt', descending: true).snapshots().listen((
      snapshot,
    ) {
      setState(() {
        allScholarships = snapshot.docs;
      });
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onYearChanged(String newYear) {
    setState(() {
      selectedProvider = newYear;
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
      mobileBody: MobileScholarshipManagement(
        allScholarships: allScholarships,
        selectedProvider: selectedProvider,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        sc: sc,
      ),
      tabletBody: TabletScholarshipManagement(
        allScholarships: allScholarships,
        selectedProvider: selectedProvider,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        sc: sc,
      ),
      desktopBody: DesktopScholarshipManagement(
        allScholarships: allScholarships,
        selectedProvider: selectedProvider,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        sc: sc,
      ),
    );
  }
}

class DesktopScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ScholarshipData? sc;

  const DesktopScholarshipManagement({
    super.key,
    required this.selectedProvider,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allScholarships,
    this.sc,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allScholarships,
      context,
      selectedProvider,
      onYearChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      24.0,
      sc,
    );
  }
}

class TabletScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ScholarshipData? sc;

  const TabletScholarshipManagement({
    super.key,
    required this.selectedProvider,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allScholarships,
    this.sc,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allScholarships,
      context,
      selectedProvider,
      onYearChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      20.0,
      sc,
    );
  }
}

class MobileScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final ScholarshipData? sc;

  const MobileScholarshipManagement({
    super.key,
    required this.selectedProvider,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allScholarships,
    this.sc,
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
                selectedProvider,
                allScholarships,
                onYearChanged,
                searchController,
                sc,
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
                      child: _buildScholarshipList(
                        allScholarships: allScholarships,
                        selectedProvider: selectedProvider,
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

Widget mainContent(
  List<DocumentSnapshot> allScholarships,
  BuildContext context,
  final String selectedProvider,
  final ValueChanged<String> onYearChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final double padding,
  final ScholarshipData? sc,
) {
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
            onYearChanged,
            searchController,
            sc,
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
                    child: _buildScholarshipList(
                      allScholarships: allScholarships,
                      selectedProvider: selectedProvider,
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

Widget _buildMobileHeader(
  String selectedProvider,
  List<DocumentSnapshot> allScholarships,
  ValueChanged<String> onYearChanged,
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
          Row(children: [UploadDocumentButton(formType: 'scholarship')]),
        ],
      ),
      const SizedBox(height: 16),
      buildSearchField('scholarship name', searchController),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: ScholarshipProviderDropdown(
              allScholarships: allScholarships,
              initialValue: selectedProvider,
              onChanged: onYearChanged,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildScholarshipList({
  required List<DocumentSnapshot> allScholarships,
  required String selectedProvider,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  final filtered =
      allScholarships.where((doc) {
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
        child:
            currentPageScholarships.isEmpty
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
                        deadline = DateFormat(
                          "MMMM d, yyyy",
                        ).format((data['deadline'] as Timestamp).toDate());
                      } else {
                        deadline = data['deadline'].toString();
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildScholarshipRow(
                        context: context,
                        doc: doc,
                        name: data['name'] ?? 'N/A',
                        description: data['description'] ?? 'N/A',
                        eligibilityRequirements: eligibilityRequirements,
                        scholarshipProvider:
                            data['scholarshipProvider'] ?? 'N/A',
                        privileges: privileges,
                        deadline: deadline,
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
  );
}

Widget _buildHeader(
  String selectedProvider,
  List<DocumentSnapshot> allScholarships,
  ValueChanged<String> onYearChanged,
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
              Row(children: [UploadDocumentButton(formType: 'scholarship')]),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: buildStatCard(
                    'Total Scholarships',
                    '${sc?.totalScholarship}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'New Scholarship',
                    sc?.newScholarship ?? "Unknown",
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildStatCard(
                    'Approaching Deadline',
                    sc?.approachingDeadline ?? "Unknown",
                    const Color.fromARGB(255, 245, 118, 0),
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                onChanged: onYearChanged,
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
                  'Scholarship',
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
                  'Eligibility/Requirements',
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
                'Scholarship',
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
                'Eligibility/Requirements',
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
                'Benefits',
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
                'Deadline',
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (isExpanded && items.length > 1)
        ...items
            .skip(1)
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
                  maxLines: 2,
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

  const _ScholarshipRowWidget({
    required this.context,
    required this.doc,
    required this.name,
    required this.scholarshipProvider,
    required this.description,
    required this.eligibilityRequirements,
    required this.deadline,
    required this.privileges,
  });

  @override
  State<_ScholarshipRowWidget> createState() => _ScholarshipRowWidgetState();
}

class _ScholarshipRowWidgetState extends State<_ScholarshipRowWidget> {
  bool eligibilityExpanded = false;
  bool benefitsExpanded = false;

  @override
  Widget build(BuildContext context) {
    DocumentSnapshot doc = widget.doc;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1100;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
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
                  onToggle:
                      (value) => setState(() => eligibilityExpanded = value),
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
                      builder:
                          (context) => ScholarshipFormDialog(
                            doc: widget.doc,
                            isEdit: true,
                          ),
                    );
                  } else if (value == 'delete') {
                    showDeleteConfirmation(
                      context,
                      doc,
                      DeleteConfigs.scholarships,
                      'scholarships',
                      customDeleteHandler: handleScholarshipDelete,
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

    // Tablet & Desktop View
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 14 : 16,
        horizontal: isTablet ? 12 : 16,
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
                onToggle:
                    (value) => setState(() => eligibilityExpanded = value),
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
                    builder:
                        (context) => ScholarshipFormDialog(
                          doc: widget.doc,
                          isEdit: true,
                        ),
                  );
                } else if (value == 'delete') {
                  showDeleteConfirmation(
                    context,
                    doc,
                    DeleteConfigs.scholarships,
                    'scholarships',
                    customDeleteHandler: handleScholarshipDelete,
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
