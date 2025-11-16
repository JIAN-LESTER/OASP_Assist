import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/statcard_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/pages/admin_pages/buttons/add_user_button.dart';
import 'package:capstone_project/modal_pages/edit_user_modal.dart';
import 'package:capstone_project/modal_pages/user_info.dart';

import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/role_dropdown_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class UserManagementPage extends StatefulWidget {
  final Function(int)? onNavigateToPage;

  const UserManagementPage({super.key, this.onNavigateToPage});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String selectedRole = 'All Roles';
  final TextEditingController _searchController = TextEditingController();
  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
  final StatDataManagement statData = StatDataManagement();

  UserData? user;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    loadStatData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadStatData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await statData.getUserData();

      if (!mounted) return;

      setState(() {
        user = data;
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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
        user: user,
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
        user: user,
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
        user: user,
      ),
    );
  }
}

class DesktopUserManagement extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Function(int)? onNavigateToPage;
  final UserData? user;

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
    this.user,
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
      user,
    );
  }
}

class TabletUserManagement extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Function(int)? onNavigateToPage;
  final UserData? user;

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
    this.user,
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
      user,
    );
  }
}

class MobileUserManagement extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;
  final Function(int)? onNavigateToPage;
  final UserData? user;

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
    this.user,
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
      user,
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
  final Function(int)? onNavigateToPage,
  final double padding,
  final UserData? user,
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            selectedRole,
            onRoleChanged,
            searchController,
            onNavigateToPage,
            user,
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
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('users')
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
                          onNavigateToPage: onNavigateToPage,
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
  final filtered =
      allUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final role = data['role'] ?? '';

        bool matchesRole =
            selectedRole == 'All Roles' ||
            (selectedRole == 'User' && role == 'user') ||
            (selectedRole == 'Staff' && role == 'staff') ||
            (selectedRole == 'Admin' && role == 'admin');

        bool matchesSearch =
            searchQuery.isEmpty ||
            name.contains(searchQuery.toLowerCase()) ||
            email.contains(searchQuery.toLowerCase());

        return matchesRole && matchesSearch;
      }).toList();

  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPageUsers = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      Expanded(
        child:
            currentPageUsers.isEmpty
                ? const Center(
                  child: Text('No users match your search criteria.'),
                )
                : ListView.builder(
                  shrinkWrap: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: currentPageUsers.length,
                  itemBuilder: (context, index) {
                    final doc = currentPageUsers[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildUserRow(
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
                        status:
                            data['isActive'] == true ? 'Active' : 'Inactive',
                        onNavigateToPage: onNavigateToPage,
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
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(year, style: const TextStyle(fontSize: 13)),
            ),
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Text(
                program,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          SizedBox(width: isTablet ? 60 : 80),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') {
                showEditUserModal(
                  context,
                  doc,
                  onNavigateToPage: onNavigateToPage,
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
  UserData? user,
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
                children: [AddUserButton(onNavigateToPage: onNavigateToPage)],
              ),
            ],
          ),

          // Stat Cards Section - Fixed for Mobile (2 per row)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child:
                isMobile
                    ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: buildStatCard(
                                'Total Users',
                                '${user?.totalUsers}',
                                Colors.blue,
                                Icons.message,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: buildStatCard(
                                'Active Users',
                                '${user?.activeUsers}',
                                Colors.green,
                                Icons.check_circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: buildStatCard(
                                'New Users (This Month)',
                                '${user?.newUsersThisMonth}',
                                Colors.red,
                                Icons.group,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: buildStatCard(
                                'Users Logged in Today',
                                '${user?.usersLoggedInToday}',
                                Colors.orange,
                                Icons.help_outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(
                          child: buildStatCard(
                            'Total Users',
                            '${user?.totalUsers}',
                            Colors.blue,
                            Icons.message,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildStatCard(
                            'Active Users',
                            '${user?.activeUsers}',
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildStatCard(
                            'New Users (This Month)',
                            '${user?.newUsersThisMonth}',
                            Colors.red,
                            Icons.group,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildStatCard(
                            'Users Logged in Today',
                            '${user?.usersLoggedInToday}',
                            Colors.orange,
                            Icons.help_outline,
                          ),
                        ),
                      ],
                    ),
          ),

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
            SizedBox(width: isTablet ? 60 : 80),
          ],
        ),
      );
    },
  );
}
