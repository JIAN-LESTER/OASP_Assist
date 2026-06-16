
import 'package:capstone_project/widgets/empty_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modal_pages/add_edit_affiliation.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';

import 'modal_widget/top_right_alert.dart';

class ManageAffiliationDialog extends StatelessWidget {
  final VoidCallback? onAffiliationsUpdated;

  const ManageAffiliationDialog({super.key, this.onAffiliationsUpdated});

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
            child: ManageAffiliationContent(
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
              onAffiliationsUpdated: onAffiliationsUpdated,
            ),
          ),
        ),
      ),
    );
  }
}

class ManageAffiliationContent extends StatefulWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final VoidCallback? onAffiliationsUpdated;

  const ManageAffiliationContent({
    Key? key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    this.onAffiliationsUpdated,
  }) : super(key: key);

  @override
  State<ManageAffiliationContent> createState() => _ManageAffiliationContentState();
}

class _ManageAffiliationContentState extends State<ManageAffiliationContent> {
  List<DocumentSnapshot> affiliations = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAffiliations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAffiliations() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('affiliations')
              .orderBy('name')
              .get();

      setState(() {
        affiliations = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showTopRightAlert('Failed to load affiliations: $e', AlertType.error);
    }
  }

  List<DocumentSnapshot> get filteredAffiliations {
    if (searchQuery.isEmpty) return affiliations;
    return affiliations.where((affiliation) {
      final data = affiliation.data() as Map<String, dynamic>;
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
                colors: [Color(0xFF2E7D32), Color(0xFF2E7D32),],
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
                        'Manage affiliations',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add, edit, or delete academic affiliations',
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
                      'Search affiliations',
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
                            hintText: 'Search affiliations by name...',
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
                        onPressed: _showAddAffiliationDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(widget.isMobile ? 'Add' : 'Add affiliation'),
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

          // affiliations List
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredAffiliations.isEmpty
                    ? buildEmptyState(isLoading, false, "affiliations")
                    : ListView.builder(
                      padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
                      itemCount: filteredAffiliations.length,
                      itemBuilder: (context, index) {
                        final affiliation = filteredAffiliations[index];
                        final data = affiliation.data() as Map<String, dynamic>;
                        return _buildAffiliationCard(affiliation, data);
                      },
                    ),
          ),
        ],
      ),
    );
  }

 
  Widget _buildAffiliationCard(
    DocumentSnapshot affiliation,
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
                    data['name'] ?? 'Unknown Affiliation',
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
                    onTap: () => _showEditAffiliationDialog(affiliation),
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
                    onTap: () => _showDeleteConfirmation(affiliation),
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

  void _showAddAffiliationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add affiliation',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddEditaffiliationDialog(
          onSaved: () {
            _fetchAffiliations();
            widget.onAffiliationsUpdated?.call();
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

  void _showEditAffiliationDialog(DocumentSnapshot affiliation) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit affiliation',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddEditaffiliationDialog(
          affiliation: affiliation,
          onSaved: () {
            _fetchAffiliations();
            widget.onAffiliationsUpdated?.call();
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

  void _showDeleteConfirmation(DocumentSnapshot affiliation) {
    final data = affiliation.data() as Map<String, dynamic>;

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
                  'Delete Affiliation',
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
                onPressed: () => showDeleteConfirmation(context, affiliation, DeleteConfigs.affiliations, 'affiliations'),
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
}

