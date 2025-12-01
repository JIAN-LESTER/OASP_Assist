import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:capstone_project/models/admissions.dart';
import 'package:url_launcher/url_launcher.dart';

class AdmissionInfo extends StatefulWidget {
  const AdmissionInfo({super.key});

  @override
  State<AdmissionInfo> createState() => _AdmissionInfoState();
}

class _AdmissionInfoState extends State<AdmissionInfo>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Admissions> _admissionsByType = [];
  String? _selectedType;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF4CAF50);
  final Color accentGreen = const Color(0xFF81C784);
  final Color successGreen = const Color(0xFF66BB6A);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchAdmissionProcesses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdmissionProcesses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final querySnapshot =
          await _firestore
              .collection('admissions')
              .orderBy('createdAt', descending: true)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final List<Admissions> admissions =
            querySnapshot.docs
                .map(
                  (doc) => Admissions.fromJson({...doc.data(), 'id': doc.id}),
                )
                .toList();

        // Group by type and keep the most recent one per type
        final Map<String, Admissions> typeMap = {};
        for (final admission in admissions) {
          final type = admission.type ?? 'General Admission';
          if (!typeMap.containsKey(type)) {
            typeMap[type] = admission;
          }
        }

        // Sort by type name
        final sortedAdmissions =
            typeMap.values.toList()..sort((a, b) {
              final aType = a.type ?? 'General Admission';
              final bType = b.type ?? 'General Admission';
              return aType.compareTo(bType);
            });

        setState(() {
          _admissionsByType = sortedAdmissions;
          if (_admissionsByType.isNotEmpty) {
            _selectedType = _admissionsByType.first.type ?? 'General Admission';
          }
          _isLoading = false;
        });

        _animationController.forward();
      } else {
        setState(() {
          _error = 'No admission information available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load admission information: $e';
        _isLoading = false;
      });
    }
  }

  Admissions? get _selectedAdmission {
    return _admissionsByType.firstWhere(
      (admission) => (admission.type ?? 'General Admission') == _selectedType,
      orElse: () => _admissionsByType.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading admission information...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null || _admissionsByType.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _fetchAdmissionProcesses,
      color: Colors.green[600],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildTypeSelector(),
                  _buildScheduleSection(),
                  _buildStepsAndRequirements(),
                  _buildHelpSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load admission information',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchAdmissionProcesses,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    if (_admissionsByType.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen.withOpacity(0.9), primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Admission Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _admissionsByType.map((admission) {
                  try {
                    final type = admission.type ?? 'General Admission';
                    final isSelected = type == _selectedType;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected
                                  ? LinearGradient(
                                    colors: [
                                      Colors.green[600]!,
                                      Colors.green[700]!,
                                    ],
                                  )
                                  : null,
                          color: isSelected ? null : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.green[700]!
                                    : Colors.grey[300]!,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: Colors.green[600]!.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    print('Error displaying admission type: $e');
                    return const SizedBox.shrink();
                  }
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final schedules = _selectedAdmission?.schedules;

    if (schedules == null || schedules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen.withOpacity(0.9), primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Exam Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...schedules.map((schedule) {
            final date = schedule['date']?.toString() ?? '';
            final dayOfWeek = schedule['dayOfWeek']?.toString() ?? '';
            final locations = schedule['locations'] as List<dynamic>? ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentGreen.withOpacity(0.1),
                    accentGreen.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentGreen.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                              ),
                            ),
                            if (dayOfWeek.isNotEmpty)
                              Text(
                                dayOfWeek,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (locations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Locations:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...locations.map((location) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 24,
                                bottom: 4,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: primaryGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      location.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStepsAndRequirements() {
    final steps = _selectedAdmission?.steps ?? [];
    final requirements = _selectedAdmission?.requirements ?? [];

    if (steps.isEmpty && requirements.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No admission information available',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please check back later or contact the admissions office',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Column(
            children: [
              if (steps.isNotEmpty) _buildStepsSection(steps),
              if (steps.isNotEmpty && requirements.isNotEmpty)
                const SizedBox(height: 24),
              if (requirements.isNotEmpty) _buildRequirementsCard(requirements),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (steps.isNotEmpty)
                Expanded(flex: 6, child: _buildStepsSection(steps)),
              if (steps.isNotEmpty && requirements.isNotEmpty)
                const SizedBox(width: 24),
              if (requirements.isNotEmpty)
                Expanded(flex: 4, child: _buildRequirementsCard(requirements)),
            ],
          );
        }
      },
    );
  }

  Widget _buildStepsSection(List<String> steps) {
    return Column(
      children:
          steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: _buildStepCard(index + 1, step),
            );
          }).toList(),
    );
  }

  Widget _buildRequirementsCard(List<String> requirements) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen.withOpacity(0.9), primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Requirements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...requirements.map((requirement) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      requirement,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStepCard(int stepNumber, String stepTitle) {
    final cleanedTitle = stepTitle.replaceFirst(
      RegExp(
        r'^(Step\s*\d+[:.\-\s]*)|(^\d+[.:-\s]*)|^\[\d+\]\s*',
        caseSensitive: false,
      ),
      '',
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen.withOpacity(0.9), primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  stepNumber.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Linkify(
                text: cleanedTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
                linkStyle: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
                onOpen: (link) async {
                  final uri = Uri.parse(link.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    final admission = _selectedAdmission;
    if (admission?.contact == null || admission!.contact!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: accentGreen.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen.withOpacity(0.9), primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentGreen.withOpacity(0.1),
                  accentGreen.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentGreen.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Admissions Office',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                ...admission.contact!.map((contact) {
                  bool isEmail = contact.toLowerCase().contains("email:");
                  bool isPhone = contact.toLowerCase().contains("phone:");
                  final cleaned =
                      contact
                          .replaceAll(
                            RegExp(
                              r'^(Email|Phone)\s*:\s*',
                              caseSensitive: false,
                            ),
                            '',
                          )
                          .trim();

                  final icon =
                      isEmail
                          ? Icons.email_rounded
                          : isPhone
                          ? Icons.phone_rounded
                          : Icons.contact_page_rounded;

                  return InkWell(
                    onTap: () async {
                      if (isEmail) {
                        final uri = Uri(scheme: 'mailto', path: cleaned);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      } else if (isPhone) {
                        final uri = Uri(scheme: 'tel', path: cleaned);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: primaryGreen),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cleaned,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


