import 'package:capstone_project/buttons/add_user_button.dart';
import 'package:capstone_project/buttons/bulk.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/statcard_management.dart';
import 'package:capstone_project/widgets/empty_state.dart';
import 'package:capstone_project/widgets/pagination.dart';
import 'package:capstone_project/widgets/role_dropdown_button.dart';
import 'package:capstone_project/widgets/search_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/modules/admin/user_management/edit_user_modal.dart';
import 'package:capstone_project/modules/admin/user_management/user_info.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class UserManagementPage extends StatefulWidget {
  final Function(int)? onNavigateToPage;

  const UserManagementPage({super.key, this.onNavigateToPage});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with BulkSelectionMixin {
  String selectedRole = 'All Roles';
  final TextEditingController _searchController = TextEditingController();
  int currentPage = 1;
  int itemsPerPage = 10;

  bool isLoading = true;
  final StatDataManagement statData = StatDataManagement();

  late final Stream<QuerySnapshot> _usersStream;

  UserData? user;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _usersStream =
        FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots();
    loadStatData();
  }

  void _handleBulkDelete() async {
    await handleBulkDelete(
      context: context,
      selectedIds: selectedIds,
      collection: 'users',
      itemType: 'users',
      onSuccess: () {
        clearSelection();
        _loadStatsAsync();
      },
    );
  }

  Future<void> _loadStatsAsync() async {
    try {
      final data = await statData.getUserData();
      if (mounted) {
        setState(() {
          user = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
      print("Error loading user data: $e");
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
    return buildSmoothManagementTransition(
      isLoading: isLoading,
      loading: buildManagementTableSkeleton(statCardCount: 4),
      child: ResponsiveLayout(
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
        usersStream: _usersStream,

        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
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
        usersStream: _usersStream,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
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
        usersStream: _usersStream,
        selectedIds: selectedIds,
        isSelectionMode: isSelectionMode,
        onToggleSelection: toggleSelection,
        onToggleSelectAll: toggleSelectAll,
        onClearSelection: clearSelection,
        onBulkDelete: _handleBulkDelete,
        isAllSelected: isAllSelected,
        ),
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
  final Stream<QuerySnapshot> usersStream;

  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

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
    required this.usersStream,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.isAllSelected,
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
      usersStream,

      selectedIds,
      isSelectionMode,
      onToggleSelection,
      onToggleSelectAll,
      onClearSelection,
      onBulkDelete,
      isAllSelected,
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
  final Stream<QuerySnapshot> usersStream;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

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
    required this.usersStream,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.isAllSelected,
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
      usersStream,
      selectedIds,
      isSelectionMode,
      onToggleSelection,
      onToggleSelectAll,
      onClearSelection,
      onBulkDelete,
      isAllSelected,
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
  final Stream<QuerySnapshot> usersStream;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(List<String>) onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final Function(List<String>) isAllSelected;

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
    required this.usersStream,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.isAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersStream,
        builder: (context, snapshot) {
          // Show loading only on first load
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs =
              snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
          final filtered = _getFilteredUsers(
            allDocs,
            selectedRole,
            searchController.text,
          );
          final filteredIds = filtered.map((d) => d.id).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMobileHeader(
                    selectedRole,
                    onRoleChanged,
                    searchController,
                    onNavigateToPage,
                    user,
                  ),
                ),
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: BulkDeleteBar(
                      selectedCount: selectedIds.length,
                      onToggleSelectAll: () => onToggleSelectAll(filteredIds),
                      onBulkDelete: onBulkDelete,
                      isAllSelected: isAllSelected(filteredIds),
                      itemType: 'users',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader(
                          selectedIds.length == filtered.length &&
                              filtered.isNotEmpty,
                          () => onToggleSelectAll(filteredIds),
                          selectedIds,
                          filtered,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child:
                              allDocs.isEmpty
                                  ? buildManagementEmptyState(
                                    hasFilters: false,
                                    isMobileOrTablet:
                                        MediaQuery.of(context).size.width < 900,
                                    item: 'Users',
                                  )
                                  : _buildUserList(
                                    allUsers: allDocs,
                                    selectedRole: selectedRole,
                                    searchQuery: searchController.text,
                                    currentPage: currentPage,
                                    itemsPerPage: itemsPerPage,
                                    onPageChanged: onPageChanged,
                                    onItemsPerPageChanged:
                                        onItemsPerPageChanged,
                                    onNavigateToPage: onNavigateToPage,
                                    selectedIds: selectedIds,
                                    isSelectionMode: isSelectionMode,
                                    onToggleSelection: onToggleSelection,
                                    context: context
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
  final Stream<QuerySnapshot> usersStream,

  final Set<String> selectedIds,
  final bool isSelectionMode,
  final Function(String) onToggleSelection,
  final Function(List<String>) onToggleSelectAll,
  final VoidCallback onClearSelection,
  final VoidCallback onBulkDelete,
  final Function(List<String>) isAllSelected,
) {
  return Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    body: StreamBuilder<QuerySnapshot>(
      stream: usersStream,
      builder: (context, snapshot) {
        // Show loading only on first load
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs =
            snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
        final filtered = _getFilteredUsers(
          allDocs,
          selectedRole,
          searchController.text,
        );
        final filteredIds = filtered.map((d) => d.id).toList();

        return Padding(
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
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BulkDeleteBar(
                    selectedCount: selectedIds.length,
                    onToggleSelectAll: () => onToggleSelectAll(filteredIds),
                    onBulkDelete: onBulkDelete,
                    isAllSelected: isAllSelected(filteredIds),
                    itemType: 'users',
                  ),
                ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        spreadRadius: 0,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTableHeader(
                        selectedIds.length == filtered.length &&
                            filtered.isNotEmpty,
                        () => onToggleSelectAll(filteredIds),
                        selectedIds,
                        filtered,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child:
                            allDocs.isEmpty
                                ? buildManagementEmptyState(
                                  hasFilters: false,
                                  isMobileOrTablet:
                                      MediaQuery.of(context).size.width < 900,
                                  item: 'Users',
                                )
                                : _buildUserList(
                                  allUsers: allDocs,
                                  selectedRole: selectedRole,
                                  searchQuery: searchController.text,
                                  currentPage: currentPage,
                                  itemsPerPage: itemsPerPage,
                                  onPageChanged: onPageChanged,
                                  onItemsPerPageChanged: onItemsPerPageChanged,
                                  onNavigateToPage: onNavigateToPage,
                                  selectedIds: selectedIds,
                                  isSelectionMode: isSelectionMode,
                                  onToggleSelection: onToggleSelection,
                                  context: context
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

List<DocumentSnapshot> _getFilteredUsers(
  List<DocumentSnapshot> docs,
  String selectedRole,
  String searchQuery,
) {
  return docs.where((doc) {
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
}

Widget _buildMobileHeader(
  String selectedRole,
  ValueChanged<String> onRoleChanged,
  TextEditingController searchController,
  Function(int)? onNavigateToPage,
  UserData? user,
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
              Text(
                'Users Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage accounts and user roles',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          Row(children: [AddUserButton(onNavigateToPage: onNavigateToPage)]),
        ],
      ),
    ],
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
  required Set<String> selectedIds,
  required bool isSelectionMode,
  required Function(String) onToggleSelection,
  required BuildContext context,
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
                ? buildManagementEmptyState(
                  hasFilters:
                      searchQuery.isNotEmpty || selectedRole != 'All Roles',
                  isMobileOrTablet: MediaQuery.of(context).size.width < 900,
                  item: 'Users',
                )
                : ListView.builder(
                  shrinkWrap: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: currentPageUsers.length,
                  itemBuilder: (context, index) {
                    final doc = currentPageUsers[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = selectedIds.contains(doc.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildUserRow(
                        context: context,
                        doc: doc,
                        index: index,
                        name: data['name'] ?? 'N/A',
                        email: data['email'] ?? 'N/A',
                        role:
                            data['role'] == 'user'
                                ? data['affiliation'] ?? 'N/A'
                                : data['role'] == 'admin'
                                ? 'OASP Admin'
                                : data['role'] == 'staff'
                                ? 'OASP Staff'
                                : (data['role'] ?? 'N/A'),
                        year: data['year']?.toString() ?? 'N/A',
                        program: data['program'] ?? 'N/A',
                        status:
                            data['isActive'] == true ? 'Active' : 'Inactive',
                        onNavigateToPage: onNavigateToPage,
                        isSelectionMode: isSelectionMode,
                        isSelected: isSelected,
                        onToggleSelection: () => onToggleSelection(doc.id),
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
  required int index,
  required String name,
  required String email,
  required String role,
  required String year,
  required String program,
  required String status,
  required Function(int)? onNavigateToPage,
  required bool isSelectionMode,
  required bool isSelected,
  required VoidCallback onToggleSelection,
}) {
  double screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 600;
  bool isTablet = screenWidth >= 600 && screenWidth < 1100;

  if (isMobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap:
            isSelectionMode
                ? onToggleSelection
                : () => showUserInfoModal(context, doc),
        onLongPress: onToggleSelection,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggleSelection,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                          : null,
                ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildUserChip(
                        role,
                        role == 'OASP Admin'
                            ? Colors.red
                            : role == 'OASP Staff'
                            ? Colors.orange
                            : Colors.blue,
                      ),
                      _buildUserChip(
                        status,
                        status == 'Active' ? Colors.green : Colors.orange,
                        soft: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              padding: EdgeInsets.zero,
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

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
      border: Border.all(color: Colors.grey[200]!, width: 1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: InkWell(
      onTap:
          isSelectionMode
              ? onToggleSelection
              : () => showUserInfoModal(context, doc),
      onLongPress: onToggleSelection,
      child: Row(
        children: [
          // Checkbox for selection mode
          InkWell(
            onTap: onToggleSelection,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User (Name & Email) - flex: 3
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile && email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Role - flex: 3
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color:
                      role == 'OASP Admin'
                          ? Colors.red[700]
                          : role == 'OASP Staff'
                          ? Colors.orange[700]
                          : Colors.blue[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        role == 'OASP Admin'
                            ? Colors.red[50]
                            : role == 'OASP Staff'
                            ? Colors.orange[50]
                            : Colors.blue[50],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // Year - flex: 3 (desktop only)
          if (!isMobile) ...[
            Expanded(
              flex: 3,
              child: Text(
                year,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Expanded(
              flex: 4,
              child: Text(
                program,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Status - flex: 2
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // Menu button spacing
          SizedBox(width: isTablet ? 60 : 60),

          // Popup menu
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

Widget _buildUserChip(String label, MaterialColor color, {bool soft = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: soft ? color[50] : color[700],
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: soft ? color[700] : color[50],
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
                      fontSize: isTablet ? 22 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage accounts and user roles',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              Row(
                children: [AddUserButton(onNavigateToPage: onNavigateToPage)],
              ),
            ],
          ),

          // Stat Cards Section
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: buildCompactStatCard(
                    'Total Users',
                    '${user?.totalUsers}',
                    Colors.blue,
                    Icons.message,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
                    'Active Users',
                    '${user?.activeUsers}',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
                    'New Users (This Month)',
                    '${user?.newUsersThisMonth}',
                    Colors.red,
                    Icons.group,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCompactStatCard(
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
          Row(
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

Widget _buildTableHeader(
  bool isAllSelected,
  VoidCallback onSelectAll,
  Set<String> selectedIds,
  List<DocumentSnapshot> filteredDocs,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      if (isMobile) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: filteredDocs.isEmpty ? null : onSelectAll,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isAllSelected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: isAllSelected ? Colors.white : Colors.white70,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:
                        isAllSelected
                            ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Color(0xFF2E7D32),
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'User',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 9 : 10,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: filteredDocs.isEmpty ? null : onSelectAll,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isAllSelected ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: isAllSelected ? Colors.white : Colors.white70,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      isAllSelected
                          ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          )
                          : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                'User',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Role',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Year',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                'Program',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 14,
                  color: Colors.white,
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
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 60),
            const SizedBox(width: 48),
          ],
        ),
      );
    },
  );
}
