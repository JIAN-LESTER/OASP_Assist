import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';

import 'modal_widget/top_right_alert.dart';

class ManageProgramsDialog extends StatelessWidget {
  final VoidCallback? onProgramsUpdated;

  const ManageProgramsDialog({Key? key, this.onProgramsUpdated})
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
      modalHeight = screenHeight * 0.85;
      modalPadding = const EdgeInsets.all(16);
    } else if (isTablet) {
      modalWidth = screenWidth * 0.80;
      modalHeight = screenHeight * 0.80;
      modalPadding = const EdgeInsets.all(24);
    } else {
      modalWidth = 700;
      modalHeight = screenHeight * 0.76;
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
            child: ManageProgramsContent(
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
              onProgramsUpdated: onProgramsUpdated,
            ),
          ),
        ),
      ),
    );
  }
}

class ManageProgramsContent extends StatefulWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final VoidCallback? onProgramsUpdated;

  const ManageProgramsContent({
    Key? key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    this.onProgramsUpdated,
  }) : super(key: key);

  @override
  State<ManageProgramsContent> createState() => _ManageProgramsContentState();
}

class _ManageProgramsContentState extends State<ManageProgramsContent> {
  List<DocumentSnapshot> programs = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPrograms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrograms() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('programs')
              .orderBy('name')
              .get();

      setState(() {
        programs = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showTopRightAlert('Failed to load programs: $e', AlertType.error);
    }
  }

  List<DocumentSnapshot> get filteredPrograms {
    if (searchQuery.isEmpty) return programs;
    return programs.where((program) {
      final data = program.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      return name.contains(searchQuery.toLowerCase());
    }).toList();
  }

  void _showTopRightAlert(String message, AlertType type) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
            type: type,
            onDismiss: () => overlayEntry.remove(),
            isMobile: widget.isMobile,
            isTablet: widget.isTablet,
          ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
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
                    Icons.school_outlined,
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
                        'Manage Programs',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add, edit, or delete academic programs',
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

          // Search and Add Section
          Container(
            padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search Programs',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged:
                              (value) => setState(() => searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search programs by name...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _showAddProgramDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(widget.isMobile ? 'Add' : 'Add Program'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isMobile ? 12 : 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Programs List
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredPrograms.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
                      itemCount: filteredPrograms.length,
                      itemBuilder: (context, index) {
                        final program = filteredPrograms[index];
                        final data = program.data() as Map<String, dynamic>;
                        return _buildProgramCard(program, data);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(widget.isMobile ? 40 : 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.school_outlined,
                size: widget.isMobile ? 48 : 64,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              searchQuery.isEmpty
                  ? 'No programs found'
                  : 'No programs match your search',
              style: TextStyle(
                fontSize: widget.isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty
                  ? 'Add your first program to get started'
                  : 'Try adjusting your search terms',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showAddProgramDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Your First Program'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCard(
    DocumentSnapshot program,
    Map<String, dynamic> data,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.school,
                color: const Color(0xFF2E7D32),
                size: widget.isMobile ? 20 : 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? 'Unknown Program',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: widget.isMobile ? 15 : 16,
                      color: const Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (data['description'] != null &&
                      data['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      data['description'],
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showEditProgramDialog(program),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit,
                        color: const Color(0xFF3B82F6),
                        size: widget.isMobile ? 18 : 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showDeleteConfirmation(program),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete,
                        color: const Color(0xFFDC2626),
                        size: widget.isMobile ? 18 : 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProgramDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Program',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddEditProgramDialog(
          onSaved: () {
            _fetchPrograms();
            widget.onProgramsUpdated?.call();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  void _showEditProgramDialog(DocumentSnapshot program) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Program',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddEditProgramDialog(
          program: program,
          onSaved: () {
            _fetchPrograms();
            widget.onProgramsUpdated?.call();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(DocumentSnapshot program) {
    final data = program.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                onPressed: () => _deleteProgram(program),
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

  Future<void> _deleteProgram(DocumentSnapshot program) async {
    try {
      Navigator.of(context).pop(); // Close confirmation dialog
      final programName = (program.data() as Map<String, dynamic>)['name'];

      unawaited(() async {
        try {
          await FirebaseFirestore.instance
              .collection('programs')
              .doc(program.id)
              .delete();

          // Log the action
          final currentUser = FirebaseAuth.instance.currentUser;
          String actorName = 'Unknown';

          if (currentUser != null) {
            final userDoc =
                await FirebaseFirestore.instance
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
            'action': 'Deleted program: $programName',
            'time': Timestamp.now(),
          });

          _fetchPrograms();
          widget.onProgramsUpdated?.call();

          _showTopRightAlert('Program deleted successfully', AlertType.success);
        } catch (e) {
          _showTopRightAlert('Program deletion failed: $e', AlertType.error);
        }
      }());

      _showTopRightAlert(
        'Program deleted successfully',
        AlertType.info,
      );
    } catch (e) {
      _showTopRightAlert('Program deletion failed: $e', AlertType.error);
    }
  }
}

// Add/Edit Program Dialog
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

  void _showTopRightAlert(String message, AlertType type) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
            type: type,
            onDismiss: () => overlayEntry.remove(),
            isMobile: widget.isMobile,
            isTablet: widget.isTablet,
          ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _saveProgram() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nameController.text.trim().isEmpty) {
      _showTopRightAlert('Please enter a program name', AlertType.warning);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final programData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'updatedAt': Timestamp.now(),
      };

      final programName = _nameController.text.trim();

      unawaited(() async {
        try {
          if (isEditing) {
            await FirebaseFirestore.instance
                .collection('programs')
                .doc(widget.program!.id)
                .update(programData);
          } else {
            programData['createdAt'] = Timestamp.now();
            await FirebaseFirestore.instance
                .collection('programs')
                .add(programData);
          }

          final currentUser = FirebaseAuth.instance.currentUser;
          String actorName = 'Unknown';

          if (currentUser != null) {
            final userDoc =
                await FirebaseFirestore.instance
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
                '${isEditing ? 'Updated' : 'Created'} program: $programName',
            'time': Timestamp.now(),
          });
        } catch (e) {
          print('Program save failed: $e');
        }
      }());

      widget.onSaved();

      _showTopRightAlert(
        'Program ${isEditing ? 'updated' : 'created'} successfully',
        AlertType.info,
      );

      Navigator.of(context).pop();
    } catch (e) {
      _showTopRightAlert(
        'Program ${isEditing ? 'update' : 'creation'} failed: $e',
        AlertType.error,
      );
    } finally {
      setState(() => _isSubmitting = false);
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
                    // Program Details Section
                    _buildSectionHeader('Program Details', Icons.info_outlined),
                    const SizedBox(height: 16),

                    // Program Name Field
                    buildTextField(
                       isMobile: false,
                      controller: _nameController,
                      label: 'Program Name',
                      hint:
                          'e.g., Bachelor of Science in Information Technology',
                      icon: Icons.school_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a program name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Program Description Field
                    buildTextField(
                       isMobile: false,
                      controller: _descriptionController,
                      label: 'Description (Optional)',
                      hint: 'Enter a brief description of the program...',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    _buildActionButtons(),

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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  
  Widget _buildActionButtons() {
    double buttonHeight =
        widget.isMobile
            ? 40
            : widget.isTablet
            ? 44
            : 46;
    double fontSize = widget.isMobile ? 14 : 15;
    double borderRadius = 10;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 20,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveProgram,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 20,
                ),
              ),
              child:
                  _isSubmitting
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditing ? 'Updating...' : 'Creating...',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                      : Text(
                        isEditing ? 'Update Program' : 'Create Program',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
