import 'package:capstone_project/pages/data/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/crud/delete/delete.dart';

import 'package:capstone_project/pages/admin_pages/widgets/pagination.dart';
import 'package:capstone_project/pages/admin_pages/widgets/search_field.dart';
import 'package:capstone_project/pages/admin_pages/widgets/empty_state.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

// Import the AddEditProgramDialog from the manage programs modal
// Assuming it's in the same file or import path
// If it's in a separate file, adjust the import accordingly

class ProgramManagementPage extends StatefulWidget {
  const ProgramManagementPage({super.key});

  @override
  State<ProgramManagementPage> createState() => _ProgramManagementPageState();
}

class _ProgramManagementPageState extends State<ProgramManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  // Pagination variables
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
      mobileBody: MobileProgramManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
      tabletBody: TabletProgramManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
      desktopBody: DesktopProgramManagement(
        searchController: _searchController,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage,
        onPageChanged: _goToPage,
        onItemsPerPageChanged: _changeItemsPerPage,
      ),
    );
  }
}

// Desktop Program Management
class DesktopProgramManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const DesktopProgramManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
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
    );
  }
}

// Tablet Program Management
class TabletProgramManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const TabletProgramManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
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
    );
  }
}

// Mobile Program Management
class MobileProgramManagement extends StatelessWidget {
  final TextEditingController searchController;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const MobileProgramManagement({
    super.key,
    required this.searchController,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
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
      16.0,
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
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(searchController, context),
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
                    stream: FirebaseFirestore.instance
                        .collection('programs')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return buildEmptyState(false, false, "programs");
                      }

                      return _buildProgramList(
                        allPrograms: snapshot.data!.docs,
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

Widget _buildProgramList({
  required List<DocumentSnapshot> allPrograms,
  required String searchQuery,
  required int currentPage,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
}) {
  // Filtering
  final filtered = allPrograms.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString().toLowerCase();

    // Search filter
    bool matchesSearch = searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());

    return matchesSearch;
  }).toList();

  // Calculate pagination
  final totalItems = filtered.length;
  final totalPages = totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  final safeCurrentPage = currentPage.clamp(1, totalPages);

  // Pagination
  final startIndex = (safeCurrentPage - 1) * itemsPerPage;
  final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
  final currentPagePrograms = filtered.sublist(
    startIndex >= filtered.length ? 0 : startIndex,
    startIndex >= filtered.length ? 0 : endIndex,
  );

  return Column(
    children: [
      // Program List
      Expanded(
        child: currentPagePrograms.isEmpty
            ? const Center(
                child: Text('No programs match your search criteria.'),
              )
            : ListView.separated(
                itemCount: currentPagePrograms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = currentPagePrograms[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return _buildProgramRow(
                    context: context,
                    doc: doc,
                    name: data['name'] ?? 'N/A',
                    description: data['description'] ?? '-',
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
          item: 'programs',
        ),
    ],
  );
}

Widget _buildProgramRow({
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
        // Icon
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
        // Program Info
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
        // Actions
        SizedBox(width: isTablet ? 60 : 80),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            if (value == 'edit') {
              showDialog(
                context: context,
                builder: (context) => AddEditProgramDialog(
                  program: doc,
                  onSaved: () {},
                ),
              );
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, doc);
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

void _showDeleteConfirmation(BuildContext context, DocumentSnapshot program) {
  final data = program.data() as Map<String, dynamic>;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Icon(Icons.warning, color: const Color(0xFFDC2626), size: 24),
          const SizedBox(width: 12),
          const Text(
            'Delete Program',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete "${data['name']}"?\n\nThis action cannot be undone.',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              Navigator.of(context).pop(); // Close confirmation dialog

              await FirebaseFirestore.instance
                  .collection('programs')
                  .doc(program.id)
                  .delete();

              // Log the action
              final currentUser = FirebaseAuth.instance.currentUser;
              String actorName = 'Unknown';

              if (currentUser != null) {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get();

                if (userDoc.exists) {
                  final userData = userDoc.data() as Map<String, dynamic>;
                  actorName = userData['name'] ?? currentUser.email ?? 'Unknown';
                }
              }

              final logRef = FirebaseFirestore.instance.collection('logs').doc();
              await logRef.set({
                'logId': logRef.id,
                'user': actorName,
                'action': 'Deleted program: ${data['name']}',
                'time': Timestamp.now(),
              });

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Program deleted successfully')),
                );
              }
            } catch (e) {
              // Show error message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete program: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

Widget _buildHeader(
  TextEditingController searchController,
  BuildContext context,
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
                    'Programs Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage academic programs',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddEditProgramDialog(
                      onSaved: () {},
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(isMobile ? 'Add' : 'Add Program'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: isMobile
                ? Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      buildStatCard('Total Messages', '59', Colors.blue, Icons.message),
                      buildStatCard('Answered Messages', '58', Colors.green, Icons.check_circle),
                      buildStatCard('Total Users', '26', Colors.red, Icons.group),
                      buildStatCard('Most Frequent Category', 'General', Colors.orange, Icons.help_outline),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: buildStatCard(
                          'Total Messages',
                          '59',
                          Colors.blue,
                          Icons.message,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildStatCard(
                          'Answered Messages',
                          '58',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildStatCard(
                          'Total Users',
                          '26',
                          Colors.red,
                          Icons.group,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildStatCard(
                          'Most Frequent Category',
                          'General',
                          Colors.orange,
                          Icons.help_outline,
                        ),
                      ),
                    ],
                  ),
          ),

          // Search Row
          buildSearchField('Search programs by name', searchController),
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
                'Program Name',
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

// AddEditProgramDialog class - copied from manage_programs modal
class AddEditProgramDialog extends StatelessWidget {
  final DocumentSnapshot? program;
  final VoidCallback onSaved;

  const AddEditProgramDialog({Key? key, this.program, required this.onSaved})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildModal(context, true, false, false),
      tabletBody: _buildModal(context, false, true, false),
      desktopBody: _buildModal(context, false, false, true),
    );
  }

  Widget _buildModal(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    double modalWidth;
    double modalHeight;
    EdgeInsets modalPadding;

    if (isMobile) {
      modalWidth = screenWidth * 0.95;
      modalHeight = screenHeight * 0.65;
      modalPadding = const EdgeInsets.all(16);
    } else if (isTablet) {
      modalWidth = screenWidth * 0.70;
      modalHeight = screenHeight * 0.60;
      modalPadding = const EdgeInsets.all(24);
    } else {
      modalWidth = 500;
      modalHeight = screenHeight * 0.55;
      modalPadding = const EdgeInsets.all(32);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: modalPadding,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            child: AddEditProgramContent(
              program: program,
              onSaved: onSaved,
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
            ),
          ),
        ),
      ),
    );
  }
}

class AddEditProgramContent extends StatefulWidget {
  final DocumentSnapshot? program;
  final VoidCallback onSaved;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  const AddEditProgramContent({
    Key? key,
    this.program,
    required this.onSaved,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<AddEditProgramContent> createState() => _AddEditProgramContentState();
}

class _AddEditProgramContentState extends State<AddEditProgramContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.program != null) {
      final data = widget.program!.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _descriptionController.text = data['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.program != null;

  Future<void> _saveProgram() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a program name')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final programData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'updatedAt': Timestamp.now(),
      };

      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('programs')
            .doc(widget.program!.id)
            .update(programData);
      } else {
        programData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('programs').add(programData);
      }

      // Log the action
      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          actorName = userData['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action':
            '${isEditing ? 'Updated' : 'Created'} program: ${_nameController.text.trim()}',
        'time': Timestamp.now(),
      });

      widget.onSaved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Program ${isEditing ? 'updated' : 'created'} successfully!'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${isEditing ? 'update' : 'create'} program: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E7D32), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit : Icons.add_circle_outline,
                    color: Colors.white,
                    size: widget.isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Program' : 'Add New Program',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEditing
                            ? 'Update program details'
                            : 'Create a new academic program',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 14 : 16,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 20 : 28,
                vertical: widget.isMobile ? 20 : 28,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Program Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Program Name',
                        hintText: 'e.g., Bachelor of Science in Information Technology',
                        prefixIcon: const Icon(Icons.school_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a program name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Program Description Field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter a brief description of the program...',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _isSubmitting ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _saveProgram,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              disabledBackgroundColor: const Color(0xFFE5E7EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSubmitting
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Saving...',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    isEditing ? 'Update Program' : 'Create Program',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}