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
  List<Admissions> _admissionYears = [];
  String? _selectedAcademicYear;
  bool _isLoading = true;
  String? _error;
  int _currentStepIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Color scheme
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
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
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

      final querySnapshot = await _firestore
          .collection('admissions')
          .orderBy('createdAt', descending: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final List<Admissions> admissions = querySnapshot.docs
            .map((doc) => Admissions.fromJson({...doc.data(), 'id': doc.id}))
            .toList();

        // Group by academic year and get unique years
        final Map<String, Admissions> yearMap = {};
        for (final admission in admissions) {
          final year = admission.academicYear ?? 'Unknown Year';
          if (!yearMap.containsKey(year)) {
            yearMap[year] = admission;
          }
        }

        setState(() {
          _admissionYears = yearMap.values.toList();
          if (_admissionYears.isNotEmpty) {
            _selectedAcademicYear = _admissionYears.first.academicYear;
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
    return _admissionYears.firstWhere(
      (admission) => admission.academicYear == _selectedAcademicYear,
      orElse: () => _admissionYears.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
    
          SliverToBoxAdapter(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }



  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        height: 500,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading admission information...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _admissionYears.isEmpty) {
      return _buildErrorState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildAcademicYearSelector(),

       _buildStepsOverview(),
          _buildHelpSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unable to load admission information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _fetchAdmissionProcesses,
            icon: const Icon(Icons.refresh),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicYearSelector() {
    if (_admissionYears.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryGreen.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Academic Year',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _admissionYears.map((admission) {
                  final isSelected = admission.academicYear == _selectedAcademicYear;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAcademicYear = admission.academicYear;
                        _currentStepIndex = 0;
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
                        color: isSelected ? primaryGreen : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? primaryGreen : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        admission.academicYear ?? 'Unknown',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
 

Widget _buildStepsOverview() {
  final steps = _selectedAdmission?.steps ?? [];
  if (steps.isEmpty) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No admission steps available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check back later or contact the admissions office.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;

      

        return _buildStepCard(
          index + 1,
          step,
   
        );
      }).toList(),
    ),
  );
}
Widget _buildStepCard(int stepNumber, String stepTitle) {
  Color cardColor = Colors.grey[50]!;
  Color iconColor = Color(0xFF2E7D32);
  Color textColor = Colors.grey[600]!;

  // Remove leading numbers like "1. ", "2. ", etc.
// Remove prefixes like "1. ", "Step 1: ", "Step 2 - ", etc.
final cleanedTitle = stepTitle.replaceFirst(
  RegExp(r'^(Step\s*\d+[:.\-\s]*)|(^\d+[.:-\s]*)', caseSensitive: false),
  '',
);


  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // ✅ Circle with step number
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

  
          Expanded(
            child: Linkify(
              text: cleanedTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              linkStyle: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.none,
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
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: accentGreen.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentGreen.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.help_outline,
                      color: primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Admissions Office',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                   ...admission.contact!.map((contact) {
  // Detect type
  bool isEmail = contact.toLowerCase().contains("email:");
  bool isPhone = contact.toLowerCase().contains("phone:");

  // Clean prefix
  final cleaned = contact.replaceAll(
    RegExp(r'^(Email|Phone)\s*:\s*', caseSensitive: false),
    '',
  ).trim();

  // Choose icon
  final icon = isEmail
      ? Icons.email
      : isPhone
          ? Icons.phone
          : Icons.contact_page;

  // Build clickable row
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
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cleaned,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.blue, // highlight clickable
                decoration: TextDecoration.none
               
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
              const SizedBox(height: 16),
              // SizedBox(
              //   width: double.infinity,
              //   child: ElevatedButton.icon(
              //     onPressed: () {
              //       // Add contact functionality here
              //     },
              //     icon: const Icon(Icons.contact_support),
              //     label: const Text('Get Support'),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: primaryGreen,
              //       foregroundColor: Colors.white,
              //       padding: const EdgeInsets.symmetric(vertical: 16),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}