import 'package:capstone_project/models/admissions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class AdmissionInfo extends StatefulWidget {
  const AdmissionInfo({super.key});

  @override
  State<AdmissionInfo> createState() => _AdmissionInfoState();
}

class _AdmissionInfoState extends State<AdmissionInfo>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Admissions> _admissions = [];
  String? _selectedType;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color accentGreen = const Color(0xFF81C784);

  static const List<String> _examTypes = ['GSAT', 'CMUCAT', 'ULHSAT'];
  static const Map<String, String> _examNames = {
    'GSAT': 'Graduate School Admission Test',
    'CMUCAT': 'Central Mindanao University College Admission Test',
    'ULHSAT': 'University Laboratory High School Admission Test',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
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

      final admissions =
          querySnapshot.docs
              .map((doc) => Admissions.fromJson({...doc.data(), 'id': doc.id}))
              .where((admission) {
                final type = _normalizeType(admission.type);
                return _examTypes.contains(type);
              })
              .toList()
            ..sort(_sortAdmissions);

      if (!mounted) return;

      setState(() {
        _admissions
          ..clear()
          ..addAll(admissions);
        _selectedType =
            _examTypes.firstWhere(
              (type) => _admissions.any((item) => _normalizeType(item.type) == type),
              orElse: () => _examTypes.first,
            );
        _isLoading = false;
        _error = admissions.isEmpty ? 'No admission information available' : null;
      });

      _animationController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load admission information: $e';
        _isLoading = false;
      });
    }
  }

  int _sortAdmissions(Admissions a, Admissions b) {
    final typeCompare = _examTypes
        .indexOf(_normalizeType(a.type))
        .compareTo(_examTypes.indexOf(_normalizeType(b.type)));
    if (typeCompare != 0) return typeCompare;

    final bYear = b.academicYear?['start'] ?? 0;
    final aYear = a.academicYear?['start'] ?? 0;
    if (bYear != aYear) return bYear.compareTo(aYear);
    return b.createdAt.compareTo(a.createdAt);
  }

  String _normalizeType(String? type) => (type ?? '').trim().toUpperCase();

  List<Admissions> get _selectedAdmissions {
    return _admissions
        .where((admission) => _normalizeType(admission.type) == _selectedType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null || _admissions.isEmpty) return _buildErrorState();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return RefreshIndicator(
      onRefresh: _fetchAdmissionProcesses,
      color: primaryGreen,
      child: SingleChildScrollView(
        padding: _pagePadding(context),
        child: SizedBox(
          width: double.infinity,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExamCards(),
                if (!isMobile) ...[
                  const SizedBox(height: 20),
                  _buildSelectedExamHeader(),
                  const SizedBox(height: 14),
                  _buildAdmissionVersions(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) return const EdgeInsets.fromLTRB(10, 10, 10, 20);
    if (width < 1024) return const EdgeInsets.fromLTRB(14, 14, 14, 24);
    return const EdgeInsets.fromLTRB(12, 12, 12, 24);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Admission Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Container(
        margin: EdgeInsets.all(isMobile ? 12 : 16),
        padding: EdgeInsets.all(isMobile ? 22 : 32),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Unable to load admission information',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchAdmissionProcesses,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 980;

        return GridView.count(
          crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 3),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: isMobile ? 10 : 12,
          crossAxisSpacing: isMobile ? 10 : 12,
          childAspectRatio: isMobile ? 2.35 : (isTablet ? 2.15 : 2.45),
          children:
              _examTypes.map((type) {
                final versions =
                    _admissions
                        .where((item) => _normalizeType(item.type) == type)
                        .toList();
                final isSelected =
                    !isMobile && _selectedType == type;
                final hasData = versions.isNotEmpty;
                final latestYear =
                    hasData ? _formatAcademicYear(versions.first.academicYear) : 'No version';

                return InkWell(
                  onTap: () => _selectExamType(type, isMobile),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(isMobile ? 16 : 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primaryGreen : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isSelected ? 0.12 : 0.06),
                          blurRadius: isSelected ? 20 : 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isMobile ? 8 : 10),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? primaryGreen
                                        : primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.school_outlined,
                                color: isSelected ? Colors.white : primaryGreen,
                                size: isMobile ? 20 : 22,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${versions.length}',
                              style: TextStyle(
                                color: hasData ? primaryGreen : Colors.grey[500],
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 15 : 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _examNames[type]!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                height: 1.3,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Latest: $latestYear',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                fontWeight: FontWeight.w600,
                                color: hasData ? primaryGreen : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  void _selectExamType(String type, bool isMobile) {
    setState(() => _selectedType = type);
    if (!isMobile) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: const Color.fromARGB(255, 245, 245, 245),
              appBar: AppBar(
                title: Text(type),
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: SingleChildScrollView(
                padding: _pagePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSelectedExamHeader(),
                    const SizedBox(height: 14),
                    _buildAdmissionVersions(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSelectedExamHeader() {
    final type = _selectedType ?? _examTypes.first;
    final count = _selectedAdmissions.length;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_examNames[type]} - $count version${count == 1 ? '' : 's'} available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isMobile ? 13 : 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdmissionVersions() {
    final admissions = _selectedAdmissions;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (admissions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        decoration: _cardDecoration(),
        child: Text(
          'No ${_selectedType ?? ''} admission information available.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return Column(
      children:
          admissions.map((admission) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: _cardDecoration(),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  initiallyExpanded: admissions.length == 1,
                  tilePadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 22,
                    vertical: isMobile ? 6 : 8,
                  ),
                  childrenPadding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 22,
                    0,
                    isMobile ? 16 : 22,
                    isMobile ? 16 : 22,
                  ),
                  iconColor: primaryGreen,
                  collapsedIconColor: primaryGreen,
                  title: Text(
                    _formatAcademicYear(admission.academicYear),
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      admission.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  children: [_buildAdmissionDetails(admission)],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildAdmissionDetails(Admissions admission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScheduleSection(admission.schedules ?? []),
        _buildListSection('Steps', Icons.list_alt_outlined, admission.steps, numbered: true),
        _buildListSection(
          'Requirements',
          Icons.checklist_outlined,
          admission.requirements ?? [],
        ),
        _buildLinksSection(admission.links ?? []),
        _buildContactSection(admission.contact ?? []),
      ],
    );
  }

  Widget _buildScheduleSection(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) return const SizedBox.shrink();

    return _buildSectionShell(
      'Exam Schedule',
      Icons.event_note_rounded,
      Column(
        children:
            schedules.map((schedule) {
              final date = schedule['date']?.toString() ?? '';
              final dayOfWeek = schedule['dayOfWeek']?.toString() ?? '';
              final locations = schedule['locations'] as List<dynamic>? ?? [];

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentGreen.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.isEmpty ? 'Schedule date not specified' : date,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    if (dayOfWeek.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(dayOfWeek, style: TextStyle(color: Colors.grey[600])),
                    ],
                    if (locations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...locations.map(
                        (location) => _buildBulletText(location.toString()),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildListSection(
    String title,
    IconData icon,
    List<String> items, {
    bool numbered = false,
  }) {
    final cleanItems =
        items.map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (cleanItems.isEmpty) return const SizedBox.shrink();

    return _buildSectionShell(
      title,
      icon,
      Column(
        children:
            cleanItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item =
                  numbered
                      ? entry.value.replaceFirst(
                        RegExp(
                          r'^(Step\s*\d+[:.\-\s]*)|(^\d+[.:-\s]*)|^\[\d+\]\s*',
                          caseSensitive: false,
                        ),
                        '',
                      )
                      : entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: numbered ? 28 : 8,
                      height: numbered ? 28 : 8,
                      margin: EdgeInsets.only(top: numbered ? 0 : 8),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: numbered ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius:
                            numbered ? BorderRadius.circular(14) : null,
                      ),
                      child:
                          numbered
                              ? Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Linkify(
                        text: item,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        linkStyle: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        onOpen: _openLink,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildLinksSection(List<String> links) {
    final cleanLinks =
        links.map((link) => link.trim()).where((link) => link.isNotEmpty).toList();
    if (cleanLinks.isEmpty) return const SizedBox.shrink();

    return _buildSectionShell(
      'Related Links',
      Icons.link_outlined,
      Column(
        children:
            cleanLinks.map((link) {
              return InkWell(
                onTap: () => _launchUrl(link),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, size: 16, color: primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          link,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildContactSection(List<String> contacts) {
    final cleanContacts =
        contacts
            .map((contact) => contact.trim())
            .where((contact) => contact.isNotEmpty)
            .toList();
    if (cleanContacts.isEmpty) return const SizedBox.shrink();

    return _buildSectionShell(
      'Contact',
      Icons.contact_phone_outlined,
      Column(
        children:
            cleanContacts.map((contact) {
              final isEmail = contact.toLowerCase().contains('email:');
              final isPhone = contact.toLowerCase().contains('phone:');
              final cleaned =
                  contact
                      .replaceAll(
                        RegExp(r'^(Email|Phone)\s*:\s*', caseSensitive: false),
                        '',
                      )
                      .trim();

              return InkWell(
                onTap: () async {
                  if (isEmail) {
                    await launchUrl(Uri(scheme: 'mailto', path: cleaned));
                  } else if (isPhone) {
                    await launchUrl(Uri(scheme: 'tel', path: cleaned));
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        isEmail
                            ? Icons.email_rounded
                            : isPhone
                                ? Icons.phone_rounded
                                : Icons.contact_page_rounded,
                        size: 18,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cleaned,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSectionShell(String title, IconData icon, Widget child) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: primaryGreen),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[900],
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletText(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[300]!),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  String _formatAcademicYear(Map<String, int>? academicYear) {
    if (academicYear == null || academicYear.isEmpty) return 'Year not specified';

    final start = academicYear['start'];
    final end = academicYear['end'];
    if (start != null && end != null) return '$start-$end';
    if (start != null) return '$start';
    return 'Year not specified';
  }

  Future<void> _openLink(LinkableElement link) async {
    await _launchUrl(link.url);
  }

  Future<void> _launchUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;

    final target =
        uri.hasScheme ? uri : Uri.tryParse('https://$value');
    if (target == null) return;

    if (await canLaunchUrl(target)) {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    }
  }
}
