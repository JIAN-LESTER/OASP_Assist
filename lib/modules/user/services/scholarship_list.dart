import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              "Explore available scholarship opportunities",
                              style: TextStyle(
                                fontSize: 14,
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(height: 24),

                    // Search Bar
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase().trim();
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
                                      });
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
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
                  // ✅ NEW: Show loading state
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

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: scholarships.length,
                    itemBuilder: (context, index) {
                      final doc = scholarships[index];
                      final scholarship = doc.data() as Map<String, dynamic>;
                      final deadline = scholarship['deadline'] as Timestamp?;
                      final daysLeft =
                          deadline != null
                              ? deadline
                                  .toDate()
                                  .difference(DateTime.now())
                                  .inDays
                              : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showScholarshipDetails(scholarship),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Status indicator
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        daysLeft,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(daysLeft),
                                      color: _getStatusColor(daysLeft),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Scholarship name
                                        Text(
                                          scholarship['name'] ??
                                              'Unnamed Scholarship',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),

                                        // Meta info
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  daysLeft,
                                                ).withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _formatDeadline(
                                                  deadline,
                                                ).toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: _getStatusColor(
                                                    daysLeft,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.business,
                                              size: 14,
                                              color: Colors.grey[500],
                                            ),
                                            const SizedBox(width: 4),
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

                                        if (scholarship['description'] !=
                                                null &&
                                            scholarship['description']
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            scholarship['description'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Arrow
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCHOLARSHIP NAME',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[500],
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
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
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
                                        color: Colors.grey[500],
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
                                        color: Colors.grey[500],
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

                          // Description
                          if (data['description'] != null &&
                              data['description']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DESCRIPTION',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
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
                                          data['description'],
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
                                ],
                              ),
                            ),
                          ],

                          // Eligibility Requirements
                          if (data['eligibilityRequirements'] != null &&
                              data['eligibilityRequirements'] is List &&
                              (data['eligibilityRequirements'] as List)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ELIGIBILITY REQUIREMENTS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...List<String>.from(
                                    data['eligibilityRequirements'],
                                  ).map((requirement) {
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
                          if (data['privileges'] != null &&
                              data['privileges'] is List &&
                              (data['privileges'] as List).isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PRIVILEGES & BENEFITS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...List<String>.from(data['privileges']).map((
                                    privilege,
                                  ) {
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
                                foregroundColor: Colors.grey[700],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
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
