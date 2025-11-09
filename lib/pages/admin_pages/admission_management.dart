import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modal_pages/admission_info.dart';
import 'package:capstone_project/modal_pages/admission_edit.dart';




import 'package:capstone_project/pages/admin_pages/buttons/upload_document_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/admission_year_dropdown.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';

import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

import '../../crud/delete/delete.dart';

class AdmissionManagementPage extends StatefulWidget {
  const AdmissionManagementPage({super.key});

  @override
  State<AdmissionManagementPage> createState() =>
      _AdmissionManagementPageState();
}

class _AdmissionManagementPageState extends State<AdmissionManagementPage> {
  String selectedYear = 'All Year';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> allAdmissions = [];

  // Pagination variables
  int currentPage = 1;
  int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAdmissions();
  }

  void _loadAdmissions() {
    FirebaseFirestore.instance.collection('admissions').snapshots().listen((
      snapshot,
    ) {
      setState(() {
        allAdmissions = snapshot.docs;
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
      selectedYear = newYear;
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
      mobileBody: MobileAdmissionManagement(
        allAdmissions: allAdmissions,
        selectedYear: selectedYear,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
      tabletBody: TabletAdmissionManagement(
        allAdmissions: allAdmissions,
        selectedYear: selectedYear,
        onYearChanged: _onYearChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
      desktopBody: DesktopAdmissionManagement(
        allAdmissions: allAdmissions,
        selectedYear: selectedYear,
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

// Desktop Admission Management
class DesktopAdmissionManagement extends StatelessWidget {
  final List<DocumentSnapshot> allAdmissions;
  final String selectedYear;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const DesktopAdmissionManagement({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allAdmissions,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allAdmissions,
      context,
      selectedYear,
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

// Tablet Admission Management
class TabletAdmissionManagement extends StatelessWidget {
  final List<DocumentSnapshot> allAdmissions;
  final String selectedYear;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const TabletAdmissionManagement({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allAdmissions,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allAdmissions,
      context,
      selectedYear,
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

// Mobile Admission Management
class MobileAdmissionManagement extends StatelessWidget {
  final List<DocumentSnapshot> allAdmissions;
  final String selectedYear;
  final ValueChanged<String> onYearChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const MobileAdmissionManagement({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.allAdmissions,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      allAdmissions,
      context,
      selectedYear,
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
  List<DocumentSnapshot> allAdmissions,
  BuildContext context,
  final String selectedYear,
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
    body: SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            selectedYear,
            allAdmissions,
            onYearChanged,
            searchController,
          ),
          const SizedBox(height: 16),
          Container(
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
                  child: _buildAdmissionList(
                    allAdmissions: allAdmissions,
                    selectedYear: selectedYear,
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
        ],
      ),
    ),
  );
}

Widget _buildAdmissionList({
  required List<DocumentSnapshot> allAdmissions,
  required String selectedYear,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  // Filtering
  final filtered =
      allAdmissions.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString().toLowerCase().trim();
        final academicYear =
            (data['academicYear'] ?? '').toString().toLowerCase().trim();
        final query = searchQuery.toLowerCase().trim();
        final yearFilter = selectedYear.toLowerCase().trim();

        // Filter by selected year (if not "All Year")
        bool matchesYear =
            yearFilter == 'all year' ||
            yearFilter == 'all' ||
            academicYear == yearFilter;

        // Search filter (check if search matches title or academicYear)
        bool matchesSearch =
            query.isEmpty ||
            title.contains(query) ||
            academicYear.contains(query);

        return matchesYear && matchesSearch;
      }).toList();

  // Calculate pagination
  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  // Pagination
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageAdmissions = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      // Admission List
      Expanded(
        child:
            currentPageAdmissions.isEmpty
                ? const Center(
                  child: Text('No admissions match your criteria.'),
                )
                : ListView.separated(
                  itemCount: currentPageAdmissions.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = currentPageAdmissions[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final List<String> contacts =
                        (data['contact'] as List<dynamic>?)
                            ?.map((c) => c.toString())
                            .toList() ??
                        [];

                

                    return _buildAdmissionRow(
                      context: context,
                      doc: doc,
                      title: data['title'] ?? 'N/A',
                      source: data['source'] ?? 'N/A',
                      content: data['content'],
                      contacts: contacts,
                      academicYear: data['academicYear'] ?? '-',
                      
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
          item: 'admissions',
        ),
    ],
  );
}

// Helper to format month names

Widget _buildAdmissionRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String title,
  required String content,
  required String source,
  required String academicYear,

  required List<String>? contacts,
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
      onTap: () => showADInfoModal(context, doc),
      child: Row(
        children: [
          // Title + Source
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
                ),
                if (!isMobile && source.isNotEmpty)
                  Text(
                    source,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
                   if (!isMobile)
  Expanded(
    flex: 3,
    child: Text(
      content,
      style: const TextStyle(fontSize: 13),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
                          "No contacts",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
            ),
          ),

          // Academic Year
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                academicYear.isNotEmpty ? academicYear : "N/A",
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
                showEditADModal(context, doc);
              } else if (value == 'delete') {
                showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.admissions,
                  'admissions',
                  customDeleteHandler: handleComplexDocumentDelete,
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
  String selectedYear,
  List<DocumentSnapshot> allAdmissions,
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
                    'Admission Information',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage admission processes and procedures',
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
                  buildSearchField('title', searchController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AcademicYearDropdown(
                          allAdmissions: allAdmissions,
                          initialValue: selectedYear,
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
                    child: buildSearchField('title', searchController),
                  ),
                  const SizedBox(width: 16),
                  AcademicYearDropdown(
                    allAdmissions: allAdmissions,
                    initialValue: selectedYear,
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
                'Title',
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
                'Content',
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
                'Contacts',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
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
