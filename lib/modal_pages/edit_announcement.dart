import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/modal_pages/programs.modal.dart';
import 'package:capstone_project/pages/admin_pages/program_management.dart';
import 'package:capstone_project/modal_pages/user_info.dart';

void showEditAnnouncementModal(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit User',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setState) {
          return EditUserModal(userDoc: userDoc, previousModal: previousModal);
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

class EditUserModal extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final String? previousModal;

  const EditUserModal({super.key, required this.userDoc, this.previousModal});

  @override
  State<EditUserModal> createState() => _EditUserModalState();
}

class _EditUserModalState extends State<EditUserModal> {
  List<String> programs = ['N/A'];
  bool isLoadingPrograms = true;
  bool hasFetchedPrograms = false;
  final List<String> roles = ['admin', 'user', 'staff'];
  final List<String> years = [
    'N/A',
    'Incoming',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Graduate',
  ];

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;

  late String selectedRole;
  late String selectedYear;
  late String selectedProgram;
  late bool isActive;

  bool get isYearEnabled => selectedRole == 'user';
  bool get isProgramEnabled =>
      selectedRole == 'user' &&
      selectedYear != 'N/A' &&
      selectedYear != 'Incoming' &&
      selectedYear != 'Graduate';

  @override
  void initState() {
    super.initState();
    final userData = widget.userDoc.data() as Map<String, dynamic>;

    final fullName = userData['name']?.toString().split(' ') ?? [''];
    firstNameController = TextEditingController(
      text: fullName.isNotEmpty ? fullName.first : '',
    );
    lastNameController = TextEditingController(
      text: fullName.length > 1 ? fullName.sublist(1).join(' ') : '',
    );
    emailController = TextEditingController(text: userData['email'] ?? '');

    selectedRole = userData['role'] ?? 'user';
    selectedYear = userData['year'] ?? '1st Year';
    selectedProgram = userData['program'] ?? 'N/A';
    isActive = userData['isActive'] ?? true;

    _fetchPrograms();
  }

  Future<void> _fetchPrograms() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('programs')
              .orderBy('name')
              .get();

      final fetchedPrograms = ['N/A'];
      fetchedPrograms.addAll(snapshot.docs.map((doc) => doc['name'] as String));

      setState(() {
        programs = fetchedPrograms;
        isLoadingPrograms = false;

        // ✅ Ensure selectedProgram exists, otherwise default to 'N/A'
        if (!programs.contains(selectedProgram)) {
          selectedProgram = 'N/A';
        }
      });
    } catch (e) {
      setState(() {
        isLoadingPrograms = false;
      });
      print('Error fetching programs: $e');
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  String getDisplayRole(String role) =>
      role[0].toUpperCase() + role.substring(1);

  String getOriginalRole(String displayRole) => displayRole.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient (updated to match FAQ edit modal)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                child: Row(
                  children: [
                    // Show back button only if previousModal is provided
                    if (widget.previousModal == 'info') ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(context).pop();
                            // Add delay before showing previous modal
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                showUserInfoModal(
                                  context,
                                  widget.userDoc,
                                  fromEdit: true,
                                );
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_document,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit User',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 4),
                          Text(
                            'Update user information',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
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
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      buildSectionHeader(
                        'Personal Information',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 16),

                      isMobile
                          ? Column(
                            children: [
                              buildTextField(
                                isMobile: false,
                                controller: firstNameController,
                                label: "First Name",
                                hint: "Enter first name",
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              buildTextField(
                                isMobile: false,
                                controller: lastNameController,
                                label: "Last Name",
                                hint: "Enter last name",
                                icon: Icons.person_outline,
                              ),
                            ],
                          )
                          : Row(
                            children: [
                              Expanded(
                                child: buildTextField(
                                  isMobile: false,
                                  controller: firstNameController,
                                  label: "First Name",
                                  hint: "Enter first name",
                                  icon: Icons.person_outline,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: buildTextField(
                                  isMobile: false,
                                  controller: lastNameController,
                                  label: "Last Name",
                                  hint: "Enter last name",
                                  icon: Icons.person_outline,
                                ),
                              ),
                            ],
                          ),

                      const SizedBox(height: 16),
                      buildTextField(
                        controller: emailController,
                        isMobile: false,
                        label: "Email Address",
                        hint: "Enter email address",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 32),

                      // Account Information Section
                      buildSectionHeader(
                        'Account Information',
                        Icons.settings_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildDropdownField(
                        label: "Role",
                        value: getDisplayRole(selectedRole),
                        items: roles.map(getDisplayRole).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedRole = getOriginalRole(val!);
                            if (selectedRole != 'user') {
                              selectedYear = 'N/A';
                              selectedProgram = 'N/A';
                            } else {
                              if (selectedYear == 'N/A')
                                selectedYear = '1st Year';
                              if (selectedProgram == 'N/A')
                                selectedProgram = 'BSIT';
                            }
                          });
                        },
                        icon: Icons.admin_panel_settings_outlined,
                        isEnabled: true,
                      ),

                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: "Year Level",
                        value: selectedYear,
                        items: years,
                        onChanged:
                            isYearEnabled
                                ? (val) {
                                  setState(() {
                                    selectedYear = val!;
                                    if (selectedYear == 'N/A' ||
                                        selectedYear == 'Incoming' ||
                                        selectedYear == 'Graduate') {
                                      selectedProgram = 'N/A';
                                    } else if (selectedProgram == 'N/A') {
                                      selectedProgram = 'BSIT';
                                    }
                                  });
                                }
                                : null,
                        icon: Icons.school_outlined,
                        isEnabled: isYearEnabled,
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child:
                                isLoadingPrograms
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    ) // Loader
                                    : _buildDropdownField(
                                      label: 'Program',
                                      // ✅ Ensure value is always valid
                                      value:
                                          programs.contains(selectedProgram)
                                              ? selectedProgram
                                              : 'N/A',
                                      items: programs,
                                      onChanged:
                                          isProgramEnabled
                                              ? (value) => setState(
                                                () => selectedProgram = value!,
                                              )
                                              : null,
                                      icon: Icons.book_outlined,
                                      isEnabled: isProgramEnabled,
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.only(top: 24),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder:
                                      (context) => const ManageProgramsDialog(),
                                );
                                // ✅ Re-fetch programs after managing
                                await _fetchPrograms();
                              },
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Manage'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
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

                      const SizedBox(height: 24),

                      // Status Section
                      buildSectionHeader('Status', Icons.toggle_on_outlined),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle_outlined,
                              size: 18,
                              color:
                                  isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Account Status',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Switch(
                              value: isActive,
                              activeColor: const Color(0xFF2E7D32),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              onChanged:
                                  (val) => setState(() => isActive = val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      _buildActionButtons(
                        context,
                        isMobile,
                        isTablet,
                        isDesktop,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    double buttonHeight =
        isMobile
            ? 40
            : isTablet
            ? 44
            : 46;
    double fontSize = isMobile ? 14 : 15;
    double borderRadius = 10;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
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
            child: ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Please enter a first name'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userDoc.id)
          .update({
            'name':
                '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
            'email': emailController.text.trim(),
            'role': selectedRole.toLowerCase(),
            'year': selectedYear,
            'program': selectedProgram,
            'isActive': isActive,
            'updatedAt': Timestamp.now(),
          });

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          actorName = data['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final userData = widget.userDoc.data() as Map<String, dynamic>;
      final originalName = userData['name'] ?? 'Unknown';

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      final logData = {
        'logId': logRef.id,
        'user': actorName,
        'action':
            'Updated User: $originalName to ${firstNameController.text.trim()} ${lastNameController.text.trim()}',
        'time': Timestamp.now(),
      };
      await logRef.set(logData);

      // Close loading and modal, then navigate back if needed
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close edit modal

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('User updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Failed to update: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }


  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required IconData icon,
    bool isEnabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isEnabled ? const Color(0xFF2E7D32) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isEnabled
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF9CA3AF),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: isEnabled ? onChanged : null,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color:
                isEnabled ? const Color(0xFF334155) : const Color(0xFF9CA3AF),
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
            filled: true,
            fillColor:
                isEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items:
              items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isEnabled
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}
