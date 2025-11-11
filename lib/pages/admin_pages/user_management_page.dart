import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/pages/admin_pages/buttons/add_user_button.dart';
import 'package:capstone_project/modal_pages/edit_user_modal.dart';
import 'package:capstone_project/modal_pages/user_info.dart';
import 'package:capstone_project/pages/admin_pages/buttons/affiliation.dart';
import 'package:capstone_project/pages/admin_pages/buttons/program.dart';
import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/role_dropdown_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class UserManagementPage extends StatefulWidget {
  final Function(int)? onNavigateToPage; // ✅ Add this parameter

  const UserManagementPage({super.key, this.onNavigateToPage});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String selectedRole = 'All Roles';
  final TextEditingController _searchController = TextEditingController();
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

  void _onRoleChanged(String newRole) {
    setState(() {
      selectedRole = newRole;
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
      mobileBody: MobileUserManagement(
        selectedRole: selectedRole,
        onRoleChanged: _onRoleChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        onNavigateToPage: widget.onNavigateToPage,
      ),
      tabletBody: TabletUserManagement(
        selectedRole: selectedRole,
        onRoleChanged: _onRoleChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        onNavigateToPage: widget.onNavigateToPage,
      ),
      desktopBody: DesktopUserManagement(
        selectedRole: selectedRole,
        onRoleChanged: _onRoleChanged,
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
        onNavigateToPage: widget.onNavigateToPage,
      ),
    );
  }
}

// Desktop User Management
class DesktopUserManagement extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Function(int)? onNavigateToPage;

  const DesktopUserManagement({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      context,
      selectedRole,
      onRoleChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      onNavigateToPage,
      24.0,
    );
  }
}

// Tablet User Management
class TabletUserManagement extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Function(int)? onNavigateToPage;

  const TabletUserManagement({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      context,
      selectedRole,
      onRoleChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      onNavigateToPage,
      20.0,
    );
  }
}

// Mobile User Management
class MobileUserManagement extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Function(int)? onNavigateToPage;

  const MobileUserManagement({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return mainContent(
      context,
      selectedRole,
      onRoleChanged,
      searchController,
      currentPage,
      itemsPerPage,
      onPageChanged,
      onItemsPerPageChanged,
      onNavigateToPage,
      16.0,
    );
  }
}

Widget mainContent(
  BuildContext context,
  final String selectedRole,
  final ValueChanged<String> onRoleChanged,
  final TextEditingController searchController,
  final int currentPage,
  final int itemsPerPage,
  final ValueChanged<int> onPageChanged,
  final ValueChanged<int> onItemsPerPageChanged,
  final Function(int)? onNavigateToPage, // ✅ Add this parameter
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
            selectedRole,
            onRoleChanged,
            searchController,
            onNavigateToPage, // ✅ Pass it to header
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      return _buildUserList(
                        allUsers: snapshot.data!.docs,
                        selectedRole: selectedRole,
                        searchQuery: searchController.text,
                        currentPage: currentPage,
                        itemsPerPage: itemsPerPage,
                        onPageChanged: onPageChanged,
                        onItemsPerPageChanged: onItemsPerPageChanged,
                        onNavigateToPage:
                            onNavigateToPage, // ✅ Pass it to user list
                      );
                    },
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

Widget _buildUserList({
  required List<DocumentSnapshot> allUsers,
  required String selectedRole,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required Function(int)? onNavigateToPage,
}) {
  // Filtering
  final filtered =
      allUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final role = data['role'] ?? '';

        // Role filter
        bool matchesRole =
            selectedRole == 'All Roles' ||
            (selectedRole == 'User' && role == 'user') ||
            (selectedRole == 'Staff' && role == 'staff') ||
            (selectedRole == 'Admin' && role == 'admin');

        // Search filter
        bool matchesSearch =
            searchQuery.isEmpty ||
            name.contains(searchQuery.toLowerCase()) ||
            email.contains(searchQuery.toLowerCase());

        return matchesRole && matchesSearch;
      }).toList();

  // Calculate pagination
  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  // Pagination
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageUsers = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      // User List
      Expanded(
        child:
            currentPageUsers.isEmpty
                ? const Center(
                  child: Text('No users match your search criteria.'),
                )
                : ListView.separated(
                  itemCount: currentPageUsers.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = currentPageUsers[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildUserRow(
                      context: context,
                      doc: doc,
                      name: data['name'] ?? 'N/A',
                      email: data['email'] ?? 'N/A',
                      role:
                          data['role'] == 'user'
                              ? 'User'
                              : data['role'] == 'admin'
                              ? 'Admin'
                              : data['role'] == 'staff'
                              ? 'Staff'
                              : (data['role'] ?? 'N/A'),
                      year: data['year']?.toString() ?? '-',
                      program: data['program'] ?? '-',
                      status: data['isActive'] == true ? 'Active' : 'Inactive',
                      onNavigateToPage: onNavigateToPage,
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
          item: 'users',
        ),
    ],
  );
}

Widget _buildUserRow({
  required BuildContext context,
  required DocumentSnapshot doc,
  required String name,
  required String email,
  required String role,
  required String year,
  required String program,
  required String status,
  required Function(int)? onNavigateToPage,
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
      onTap: () => showUserInfoModal(context, doc),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: 20,
              color: Colors.grey[700],
            ),
          ),

          const SizedBox(width: 12),
          // User Info (Name/Email)
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
                if (!isMobile && email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Role
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      role == 'Admin'
                          ? Colors.red[700]
                          : role == 'Staff'
                          ? Colors.orange[700]
                          : Colors.blue[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        role == 'Admin'
                            ? Colors.red[50]
                            : role == 'Staff'
                            ? Colors.orange[50]
                            : Colors.blue[50],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          // Year (hidden on mobile)
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(year, style: const TextStyle(fontSize: 13)),
            ),
          // Program (hidden on mobile)
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Text(
                program,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      status == 'Active' ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        status == 'Active'
                            ? Colors.green[700]
                            : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          // Actions
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showEditUserModal(
                  context,
                  doc,
                  onNavigateToPage: onNavigateToPage, // Pass it through
                );
              } else if (value == 'delete') {
                showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.users,
                  'users',
                  customDeleteHandler: handleUserDelete,
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

Widget _buildHeader(
  String selectedRole,
  ValueChanged<String> onRoleChanged,
  TextEditingController searchController,
  Function(int)? onNavigateToPage,
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
                    'Users Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage accounts and user roles',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  AddUserButton(
                    onNavigateToPage:
                        onNavigateToPage, // ✅ Pass it to AddUserButton
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Search and Filter Row
          isMobile
              ? Column(
                children: [
                  buildSearchField('name, email or role', searchController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RoleDropdownButton(
                          initialValue: selectedRole,
                          onChanged: onRoleChanged,
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
                      'name, email or role',
                      searchController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  RoleDropdownButton(
                    initialValue: selectedRole,
                    onChanged: onRoleChanged,
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
                  'User',
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
                  'Role',
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
                  'Status',
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
                'User',
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
                'Role',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.black87,
                ),
              ),
            ),
            if (!isMobile)
              Expanded(
                flex: 2,
                child: Text(
                  'Year',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 13 : 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            if (!isMobile)
              Expanded(
                flex: 3,
                child: Text(
                  'Program',
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
                'Status',
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
