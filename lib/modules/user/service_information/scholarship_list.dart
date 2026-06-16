import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';

class ScholarshipList extends StatefulWidget {
  const ScholarshipList({super.key});

  @override
  State<ScholarshipList> createState() => _ScholarshipListState();
}

class _ScholarshipListState extends State<ScholarshipList>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedProvider = 'all';
  String _sortBy = 'deadline';
  int _currentPage = 0;
  static const int _itemsPerPage = 12;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF4CAF50);
  final Color accentGreen = const Color(0xFF81C784);
  final Color successGreen = const Color(0xFF66BB6A);
  final Color deadlineYellow = const Color(0xFFF59E0B);
  final Color lightYellow = const Color(0xFFFFF7D6);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(int? daysLeft) {
    if (daysLeft == null) return const Color(0xFF6B7280);
    if (daysLeft < 0) return const Color(0xFFEF4444);
    if (daysLeft <= 7) return const Color(0xFFF59E0B);
    return const Color(0xFF2E7D32);
  }

  IconData _getStatusIcon(int? daysLeft) {
    if (daysLeft == null) return Icons.event_note;
    if (daysLeft < 0) return Icons.event_busy;
    if (daysLeft <= 7) return Icons.priority_high;
    return Icons.event_available;
  }

  String _formatDeadline(Timestamp? timestamp) {
    if (timestamp == null) return 'No deadline';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < 0) {
      return 'Expired';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference <= 7) {
      return '$difference days left';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  bool _matchesSearch(Map<String, dynamic> scholarship) {
    if (_searchQuery.isEmpty) return true;

    final name = scholarship['name']?.toString().toLowerCase() ?? '';
    final provider =
        scholarship['scholarshipProvider']?.toString().toLowerCase() ?? '';
    final description =
        scholarship['description']?.toString().toLowerCase() ?? '';

    return name.contains(_searchQuery) ||
        provider.contains(_searchQuery) ||
        description.contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and actions
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Scholarships",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              "Explore available scholarship opportunities",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Filter button
                        // Replace the PopupMenuButton section in ScholarshipList with this:
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: PopupMenuButton<String>(
                            offset: const Offset(0, 50),
                            onSelected: (String value) {
                              setState(() {
                                if (value.startsWith('sort_')) {
                                  _sortBy = value.replaceFirst('sort_', '');
                                } else {
                                  _selectedProvider = value;
                                }
                                _currentPage = 0;
                              });
                            },
                            itemBuilder: (BuildContext context) {
                              return [
                                const PopupMenuItem<String>(
                                  enabled: false,
                                  child: Text(
                                    'FILTER BY PROVIDER',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                ..._getProviderOptions().map((option) {
                                  return PopupMenuItem<String>(
                                    value: option,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            option == 'all'
                                                ? Icons.list_alt
                                                : Icons.business,
                                            color:
                                                _selectedProvider == option
                                                    ? primaryGreen
                                                    : const Color(0xFF64748B),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            option == 'all'
                                                ? 'All Providers'
                                                : option,
                                            style: TextStyle(
                                              fontWeight:
                                                  _selectedProvider == option
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                              color:
                                                  _selectedProvider == option
                                                      ? const Color(0xFF0F172A)
                                                      : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                const PopupMenuDivider(),
                                const PopupMenuItem<String>(
                                  enabled: false,
                                  child: Text(
                                    'SORT BY',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'sort_deadline',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.event,
                                        color:
                                            _sortBy == 'deadline'
                                                ? primaryGreen
                                                : const Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Deadline',
                                        style: TextStyle(
                                          fontWeight:
                                              _sortBy == 'deadline'
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'sort_name',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.sort_by_alpha,
                                        color:
                                            _sortBy == 'name'
                                                ? primaryGreen
                                                : const Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Name',
                                        style: TextStyle(
                                          fontWeight:
                                              _sortBy == 'name'
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'sort_newest',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.new_releases,
                                        color:
                                            _sortBy == 'newest'
                                                ? primaryGreen
                                                : const Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Newest',
                                        style: TextStyle(
                                          fontWeight:
                                              _sortBy == 'newest'
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.tune,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search Bar
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            spreadRadius: 0,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase().trim();
                            _currentPage = 0;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search scholarships...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF64748B),
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Color(0xFF64748B),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 0;
                                      });
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('scholarships').snapshots(),
                builder: (context, snapshot) {
                  //   Show loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryGreen,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Loading Scholarships',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please wait a moment',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _EmptyState(
                      icon: Icons.card_giftcard_outlined,
                      title: "No scholarships found",
                      subtitle: "Check back later for new opportunities",
                    );
                  }

                  final scholarships = _processScholarships(
                    snapshot.data!.docs,
                  );

                  if (scholarships.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off,
                      title: "No matching scholarships",
                      subtitle:
                          _searchQuery.isNotEmpty
                              ? "Try adjusting your search terms"
                              : "No scholarships from ${_selectedProvider} found",
                    );
                  }

                  final totalPages =
                      (scholarships.length / _itemsPerPage).ceil();
                  final currentPage =
                      _currentPage >= totalPages ? totalPages - 1 : _currentPage;
                  final start = currentPage * _itemsPerPage;
                  final end =
                      (start + _itemsPerPage) > scholarships.length
                          ? scholarships.length
                          : start + _itemsPerPage;
                  final pageScholarships = scholarships.sublist(start, end);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final useCards = constraints.maxWidth >= 900;

                      if (useCards) {
                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(24),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.82,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final scholarship =
                                      pageScholarships[index].data()
                                          as Map<String, dynamic>;
                                  return _buildDesktopScholarshipCard(
                                    scholarship,
                                  );
                                }, childCount: pageScholarships.length),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _buildPaginationControls(
                                totalPages,
                                currentPage,
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageScholarships.length + 1,
                        itemBuilder: (context, index) {
                          if (index == pageScholarships.length) {
                            return _buildPaginationControls(
                              totalPages,
                              currentPage,
                            );
                          }

                          final scholarship =
                              pageScholarships[index].data()
                                  as Map<String, dynamic>;
                          return _buildMobileScholarshipTile(scholarship);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopScholarshipCard(Map<String, dynamic> scholarship) {
    final deadline = scholarship['deadline'] as Timestamp?;
    final deadlineText = _deadlineDateText(deadline);
    final eligibilityItems = _normalizedEligibilityItems(
      scholarship['eligibilityRequirements'],
    );
    final benefitItems = _stringListFrom(scholarship['privileges']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showScholarshipDetails(scholarship),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: deadlineYellow, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: lightYellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  color: deadlineYellow,
                  size: 22,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                scholarship['name'] ?? 'Unnamed Scholarship',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scholarship['scholarshipProvider'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildCardSummarySection(
                        'Eligibility',
                        eligibilityItems,
                      ),
                      if (eligibilityItems.isNotEmpty &&
                          benefitItems.isNotEmpty)
                        const SizedBox(height: 8),
                      _buildCardSummarySection('Benefits', benefitItems),
                    ],
                  ),
                ),
              ),
              if (deadlineText != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: _buildDeadlineText(deadlineText),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScholarshipTile(Map<String, dynamic> scholarship) {
    final deadline = scholarship['deadline'] as Timestamp?;
    final deadlineText = _deadlineDateText(deadline);
    final eligibilityItems = _normalizedEligibilityItems(
      scholarship['eligibilityRequirements'],
    );
    final benefitItems = _stringListFrom(scholarship['privileges']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showScholarshipDetails(scholarship),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFD54F), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scholarship['name'] ?? 'Unnamed Scholarship',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                scholarship['scholarshipProvider'] ??
                                    'Unknown',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (eligibilityItems.isNotEmpty ||
                            benefitItems.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildCardSummarySection(
                            'Eligibility',
                            eligibilityItems,
                          ),
                          if (eligibilityItems.isNotEmpty &&
                              benefitItems.isNotEmpty)
                            const SizedBox(height: 8),
                          _buildCardSummarySection('Benefits', benefitItems),
                        ],
                        if (deadlineText != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: _buildDeadlineText(deadlineText),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlineText(String deadlineText) {
    return Text(
      'Deadline: $deadlineText',
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF92400E),
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.right,
    );
  }

  Widget _buildCardSummarySection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final visibleItems = items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF92400E),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ...visibleItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '- ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        if (items.length > 3)
          const Text(
            '...',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
      ],
    );
  }

  List<String> _stringListFrom(dynamic value) {
    if (value is! List) return [];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _normalizedEligibilityItems(dynamic value) {
    final items = _stringListFrom(value);
    if (items.isEmpty) return [];

    final combined = items.join(' ').toLowerCase();
    final isGenericMissingEligibility =
        combined.contains('not explicitly mentioned') ||
        combined.contains('provided text or image') ||
        combined.contains('further details') ||
        combined.contains('official ched channels');

    if (isGenericMissingEligibility) {
      return ['N/A, please refer to OASP.'];
    }

    return items;
  }

  String? _deadlineDateText(Timestamp? timestamp) {
    if (timestamp == null) return null;
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }

  Widget _buildPaginationControls(int totalPages, int currentPage) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 24, 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed:
                    currentPage == 0
                        ? null
                        : () {
                          setState(() {
                            _currentPage = currentPage - 1;
                          });
                        },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${currentPage + 1} of $totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              IconButton(
                onPressed:
                    currentPage >= totalPages - 1
                        ? null
                        : () {
                          setState(() {
                            _currentPage = currentPage + 1;
                          });
                        },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getProviderOptions() {
    // This should be populated from Firestore in real implementation
    return ['all'];
  }

  List<QueryDocumentSnapshot> _processScholarships(
    List<QueryDocumentSnapshot> docs,
  ) {
    var scholarships = docs;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      scholarships =
          scholarships.where((doc) {
            return _matchesSearch(doc.data() as Map<String, dynamic>);
          }).toList();
    }

    // Apply provider filter
    if (_selectedProvider != 'all') {
      scholarships =
          scholarships.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var provider = data['scholarshipProvider']?.toString() ?? '';
            return provider == _selectedProvider;
          }).toList();
    }

    // Apply sorting
    scholarships.sort((a, b) {
      var dataA = a.data() as Map<String, dynamic>;
      var dataB = b.data() as Map<String, dynamic>;

      switch (_sortBy) {
        case 'deadline':
          var deadlineA = dataA['deadline'] as Timestamp?;
          var deadlineB = dataB['deadline'] as Timestamp?;
          if (deadlineA != null && deadlineB != null) {
            return deadlineA.compareTo(deadlineB);
          }
          return 0;
        case 'name':
          return (dataA['name']?.toString() ?? '').compareTo(
            dataB['name']?.toString() ?? '',
          );
        case 'newest':
          var createdA = dataA['createdAt'] as Timestamp?;
          var createdB = dataB['createdAt'] as Timestamp?;
          if (createdA != null && createdB != null) {
            return createdB.compareTo(createdA);
          }
          return 0;
        default:
          return 0;
      }
    });

    return scholarships;
  }

  void _showScholarshipDetails(Map<String, dynamic> data) {
    final deadline = data['deadline'] as Timestamp?;
    final eligibilityItems = _normalizedEligibilityItems(
      data['eligibilityRequirements'],
    );
    final benefitItems = _stringListFrom(data['privileges']);
    final daysLeft =
        deadline != null
            ? deadline.toDate().difference(DateTime.now()).inDays
            : null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Scholarship Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[600],
                          ),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Scholarship Name Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCHOLARSHIP NAME',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2E7D32),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    data['name'] ?? 'Unnamed Scholarship',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[900],
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    data['scholarshipProvider'] ??
                                        'Unknown Provider',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (daysLeft != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              daysLeft >= 0
                                                  ? primaryGreen.withOpacity(
                                                    0.1,
                                                  )
                                                  : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          daysLeft >= 0 ? 'Active' : 'Expired',
                                          style: TextStyle(
                                            color:
                                                daysLeft >= 0
                                                    ? primaryGreen
                                                    : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Deadline & Duration Section
                          if (deadline != null || data['duration'] != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (deadline != null) ...[
                                    Text(
                                      'APPLICATION DEADLINE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            DateFormat(
                                              'MMMM d, yyyy',
                                            ).format(deadline.toDate()),
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey[800],
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (deadline != null &&
                                      data['duration'] != null)
                                    const SizedBox(height: 16),
                                  if (data['duration'] != null) ...[
                                    Text(
                                      'DURATION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            data['duration'].toString(),
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey[800],
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          // Eligibility Requirements
                          if (eligibilityItems.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ELIGIBILITY REQUIREMENTS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...eligibilityItems.map((requirement) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              requirement,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.5,
                                                color: Colors.grey[800],
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
                            ),
                          ],

                          // Privileges
                          if (benefitItems.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PRIVILEGES & BENEFITS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...benefitItems.map((privilege) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              privilege,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.5,
                                                color: Colors.grey[800],
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
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Apply Now Button
                          if (data['applicationLink'] != null &&
                              data['applicationLink']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Handle application link opening
                                  // You can use url_launcher package here
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Apply Now',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Close Button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
