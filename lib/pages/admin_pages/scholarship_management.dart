import 'package:capstone_project/modal_pages/add_edit_scholarship.dart';
import 'package:capstone_project/pages/data/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modal_pages/scholarship_edit.dart';
import 'package:capstone_project/modal_pages/scholarship_info.dart';




import 'package:capstone_project/pages/admin_pages/buttons/upload_document_button.dart';

import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/provider_dropdown.dart';

import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

import '../../crud/delete/delete.dart';

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

  // Pagination variables
  int currentPage = 1;
  int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadScholarships();
  }

  void _loadScholarships() {
    FirebaseFirestore.instance.collection('scholarships').snapshots().listen((
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
      ),
    );
  }
}

// Desktop Scholarship Management
class DesktopScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

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
    );
  }
}

// Tablet Scholarship Management
class TabletScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

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
    );
  }
}

// Mobile Scholarship Management
class MobileScholarshipManagement extends StatelessWidget {
  final List<DocumentSnapshot> allScholarships;
  final String selectedProvider;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

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
      16.0,
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

Widget _buildScholarshipList({
  required List<DocumentSnapshot> allScholarships,
  required String selectedProvider,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  // Filtering
  final filtered = allScholarships.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final scholarshipName = (data['name'] ?? '').toString().toLowerCase().trim();
    final scholarshipProvider = (data['scholarshipProvider'] ?? '').toString().toLowerCase().trim();
    final query = searchQuery.toLowerCase().trim();
    final providerFilter = selectedProvider.toLowerCase().trim();

    bool matchesProvider = providerFilter == 'all' ||
        providerFilter == 'all providers' ||
        scholarshipProvider == providerFilter;

    bool matchesSearch =
        query.isEmpty || scholarshipName.contains(query) || scholarshipProvider.contains(query);

    return matchesProvider && matchesSearch;
  }).toList();

  // Pagination
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
      // Scholarship List
      Expanded(
        child: currentPageScholarships.isEmpty
            ? const Center(child: Text('No scholarships match your criteria.'))
            : ListView.separated(
                itemCount: currentPageScholarships.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = currentPageScholarships[index];
                  final data = doc.data() as Map<String, dynamic>;

                  // Combine eligibility + requirements
                  List<String> eligibilityRequirements = [];

                  // if (data['eligibility'] != null && data['eligibility'].toString().trim().isNotEmpty) {
                  //   eligibilityRequirements.add(data['eligibility'].toString().trim());
                  // }

                  if (data['eligibilityRequirements'] != null) {
                    final reqs = (data['eligibilityRequirements'] as List<dynamic>?)
                            ?.map((c) => c.toString().trim())
                            .where((c) => c.isNotEmpty)
                            .toList() ??
                        [];
                    eligibilityRequirements.addAll(reqs);
                  }

                  final List<String> privileges = (data['privileges'] as List<dynamic>?)
                          ?.map((c) => c.toString())
                          .toList() ??
                      [];


                  String deadline = '-';
                  if (data['deadline'] != null) {
                    if (data['deadline'] is Timestamp) {
                      deadline = DateFormat("MMMM d, yyyy").format((data['deadline'] as Timestamp).toDate());
                    } else {
                      deadline = data['deadline'].toString();
                    }
                  }

                  return _buildScholarshipRow(
                    context: context,
                    doc: doc,
                    name: data['name'] ?? 'N/A',
                    description: data['description'] ?? 'N/A',
                    eligibilityRequirements: eligibilityRequirements,
                    scholarshipProvider: data['scholarshipProvider'] ?? 'N/A',
                    privileges: privileges,
                    deadline: deadline,
        
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
  required List<String>? eligibilityRequirements, // combined field
  required String deadline,
  required List<String>? privileges,

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
      onTap: () => showSCInfoModal(context, doc),
      child: Row(
        children: [
          // Title + Provider
          Expanded(
            flex: 3,
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
                if (!isMobile && scholarshipProvider.isNotEmpty)
                  Text(
                    scholarshipProvider,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Eligibility & Requirements combined
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: eligibilityRequirements != null &&
                      eligibilityRequirements.isNotEmpty
                  ? eligibilityRequirements.map((c) {
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
                          c,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList()
                  : [
                      Text(
                        "No eligibility/requirements",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
            ),
          ),

          // Privileges
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: privileges != null && privileges.isNotEmpty
                  ? privileges.map((c) {
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
                          c,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList()
                  : [
                      Text(
                        "No privileges",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
            ),
          ),

          // Deadline
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Text(
                deadline.isNotEmpty ? deadline : "N/A",
                style: const TextStyle(fontSize: 13),
              ),
            ),

          // Created At
         
          // Actions
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
      showDialog(
        context: context,
        builder: (context) => ScholarshipFormDialog(
          doc: doc,
          isEdit: true,
        ),
      );
    }else if (value == 'delete') {
                showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.scholarships,
                  'scholarships',
                  customDeleteHandler: handleComplexDocumentDelete,
                );
              }
            },
            itemBuilder: (context) => [
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
  String selectedProvider,
  List<DocumentSnapshot> allScholarships,
  ValueChanged<String> onYearChanged,
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
                    'Scholarship List',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage scholarship list and its contents',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
             Row(children: [
  UploadDocumentButton(
    formType: 'scholarship',
   
  )
]),
            ],
          ),

                 Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: isMobile
                ? Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      buildStatCard('Total Scholarships', '59', Colors.blue, Icons.message),
                    
                      buildStatCard('Approaching Deadline', '58', Colors.green, Icons.check_circle),
    
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: buildStatCard(
                          'Total Scholarshipss',
                          '59',
                          Colors.blue,
                          Icons.message,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildStatCard(
                          'New Scholarship',
                          '58',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      Expanded(
                        child: buildStatCard(
                          'Approaching Deadline',
                          '58',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
               
                    ],
                  ),
          ),

          // Search and Filter Row
          isMobile
              ? Column(
                children: [
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
              )
              : Row(
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
                  'Title',
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
                  'Contact',
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
                  'A.Y. Year',
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
                'Scholarship',
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
                'Eligibility/Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              flex: 3, // match row
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
              flex: 3,
              child: Text(
                'Deadline',
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
