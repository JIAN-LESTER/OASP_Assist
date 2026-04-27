import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/modal_pages/escalation_info.dart';

class HumanEscalation extends StatefulWidget {
  final String? initialEscalationId;
  final bool autoOpen;

  const HumanEscalation({
    super.key,
    this.initialEscalationId,
    this.autoOpen = false,
  });

  @override
  State<HumanEscalation> createState() => _HumanEscalationState();
}

class _HumanEscalationState extends State<HumanEscalation>
    with TickerProviderStateMixin {
  String _selectedFilter = 'all';
  String _selectedCategory = 'all';
  
  final List<String> _categoryOptions = [
    'all',
    'General',
    'Admission',
    'Scholarship',
    'Placement',
  ];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _refreshAnimationController;
  late Stream<QuerySnapshot> _escalationsStream;
  final List<String> _filterOptions = ['all', 'pending', 'resolved'];
  bool _hasAutoOpened = false;

  @override
  void initState() {
    super.initState();

    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _escalationsStream =
        FirebaseFirestore.instance
            .collection('escalations')
            .orderBy('createdAt', descending: true)
            .snapshots();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    if (!_hasAutoOpened &&
        widget.autoOpen == true &&
        widget.initialEscalationId != null &&
        widget.initialEscalationId!.isNotEmpty) {
      _hasAutoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openEscalationById(widget.initialEscalationId!);
      });
    }
  }

  @override
  void didUpdateWidget(HumanEscalation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialEscalationId != oldWidget.initialEscalationId &&
        widget.initialEscalationId != null) {
      _hasAutoOpened = false;
    }

    if (!_hasAutoOpened &&
        widget.autoOpen == true &&
        widget.initialEscalationId != null &&
        widget.initialEscalationId!.isNotEmpty &&
        widget.initialEscalationId != oldWidget.initialEscalationId) {
      _hasAutoOpened = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openEscalationById(widget.initialEscalationId!);
      });
    }
  }

  Future<void> _openEscalationById(String escalationId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('escalations')
              .doc(escalationId)
              .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Escalation not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => EscalationDetailModal(
                escalationId: doc.id,
                escalationData: doc.data() as Map<String, dynamic>,
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF2E7D32);
      case 'urgent':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'resolved':
        return Icons.check_circle;
      case 'urgent':
        return Icons.priority_high;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    
    // Month names
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    // Convert to 12-hour format
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    
    return '${months[date.month - 1]} ${date.day}, ${date.year} ${hour}:${minute} $period';
  }

  bool _matchesSearch(Map<String, dynamic> escalation) {
    if (_searchQuery.isEmpty) return true;

    final question = escalation['question']?.toString().toLowerCase() ?? '';
    final reason = escalation['reason']?.toString().toLowerCase() ?? '';
    final status = escalation['status']?.toString().toLowerCase() ?? '';

    return question.contains(_searchQuery) ||
        reason.contains(_searchQuery) ||
        status.contains(_searchQuery);
  }

  // ✅ Filter escalations by both status and category
  List<QueryDocumentSnapshot> _filterEscalations(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Status filter
      if (_selectedFilter != 'all') {
        if (data['status']?.toString().toLowerCase() != _selectedFilter) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != 'all') {
        final category = data['category']?.toString() ?? 'General';
        if (category != _selectedCategory) {
          return false;
        }
      }

      return _matchesSearch(data);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 900;

    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);
    final verticalPadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
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
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Escalations",
                                style: TextStyle(
                                  fontSize:
                                      isDesktop ? 26 : (isTablet ? 24 : 20),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              if (isTablet) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Manage and resolve user escalations",
                                  style: TextStyle(
                                    fontSize: isDesktop ? 15 : 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Status Filter Button
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
                                _selectedFilter = value;
                              });
                            },
                            itemBuilder: (BuildContext context) {
                              return _filterOptions.map((String option) {
                                return PopupMenuItem<String>(
                                  value: option,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: (option == 'all'
                                                    ? const Color(0xFF6B7280)
                                                    : _getStatusColor(option))
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            option == 'all'
                                                ? Icons.list_alt
                                                : _getStatusIcon(option),
                                            color:
                                                option == 'all'
                                                    ? const Color(0xFF6B7280)
                                                    : _getStatusColor(option),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          option == 'all'
                                              ? 'All Status'
                                              : option.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                _selectedFilter == option
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                            color:
                                                _selectedFilter == option
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 12 : 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.tune,
                                color: Colors.white,
                                size: isTablet ? 20 : 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Category Filter Button
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
                                _selectedCategory = value;
                              });
                            },
                            itemBuilder: (BuildContext context) {
                              return _categoryOptions.map((String option) {
                                return PopupMenuItem<String>(
                                  value: option,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF6366F1,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            option == 'all'
                                                ? Icons.category
                                                : Icons.label,
                                            color: const Color(0xFF0F172A),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          option == 'all'
                                              ? 'All Categories'
                                              : option,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                _selectedCategory == option
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                            color:
                                                _selectedCategory == option
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 12 : 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.category,
                                color: Colors.white,
                                size: isTablet ? 20 : 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 24 : 16),

                    // Search Bar
                    Container(
                      margin: EdgeInsets.only(bottom: isTablet ? 24 : 16),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search escalations...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(
                            Icons.search,
                            color: const Color(0xFF64748B),
                            size: isTablet ? 22 : 20,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: const Color(0xFF64748B),
                                      size: isTablet ? 22 : 20,
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
                            borderRadius: BorderRadius.circular(
                              isTablet ? 16 : 14,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 18 : 14,
                          ),
                        ),
                        style: TextStyle(fontSize: isTablet ? 15 : 14),
                      ),
                    ),

                    // ✅ Stats Row - Now filtered by category
                    StreamBuilder<QuerySnapshot>(
                      stream: _escalationsStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            height: isTablet ? 90 : 80,
                            margin: EdgeInsets.only(bottom: isTablet ? 24 : 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(
                                isTablet ? 16 : 12,
                              ),
                            ),
                          );
                        }

                        // ✅ Apply category filter to stats
                        final allDocs = snapshot.data!.docs;
                        final filteredDocs = _selectedCategory == 'all'
                            ? allDocs
                            : allDocs.where((doc) {
                                final category = (doc.data() as Map)['category']?.toString() ?? 'General';
                                return category == _selectedCategory;
                              }).toList();

                        final total = filteredDocs.length;
                        final pending =
                            filteredDocs
                                .where(
                                  (doc) =>
                                      (doc.data() as Map)['status'] ==
                                      'pending',
                                )
                                .length;
                        final resolved =
                            filteredDocs
                                .where(
                                  (doc) =>
                                      (doc.data() as Map)['status'] ==
                                      'resolved',
                                )
                                .length;

                        return Container(
                          margin: EdgeInsets.only(bottom: isTablet ? 24 : 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: "Total",
                                  value: total.toString(),
                                  color: const Color(0xFF6366F1),
                                  icon: Icons.inbox,
                                  isSelected: _selectedFilter == 'all',
                                  onTap:
                                      () => setState(
                                        () => _selectedFilter = 'all',
                                      ),
                                  isCompact: !isTablet,
                                ),
                              ),
                              SizedBox(width: isTablet ? 16 : 8),
                              Expanded(
                                child: _StatCard(
                                  title: "Pending",
                                  value: pending.toString(),
                                  color: const Color(0xFFF59E0B),
                                  icon: Icons.schedule,
                                  isSelected: _selectedFilter == 'pending',
                                  onTap:
                                      () => setState(
                                        () => _selectedFilter = 'pending',
                                      ),
                                  isCompact: !isTablet,
                                ),
                              ),
                              SizedBox(width: isTablet ? 16 : 8),
                              Expanded(
                                child: _StatCard(
                                  title: "Resolved",
                                  value: resolved.toString(),
                                  color: const Color(0xFF10B981),
                                  icon: Icons.check_circle,
                                  isSelected: _selectedFilter == 'resolved',
                                  onTap:
                                      () => setState(
                                        () => _selectedFilter = 'resolved',
                                      ),
                                  isCompact: !isTablet,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Enhanced List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _escalationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0F172A),
                        strokeWidth: 3,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _EmptyState(
                      icon: Icons.inbox_outlined,
                      title: "No escalations found",
                      subtitle: "All caught up! No escalations to review.",
                      isCompact: !isTablet,
                    );
                  }
                  
                  final escalations = _filterEscalations(snapshot.data!.docs);

                  if (escalations.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off,
                      title: "No matching escalations",
                      subtitle:
                          _searchQuery.isNotEmpty
                              ? "Try adjusting your search terms"
                              : "No $_selectedFilter escalations found",
                      isCompact: !isTablet,
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(horizontalPadding),
                    itemCount: escalations.length,
                    itemBuilder: (context, index) {
                      final doc = escalations[index];
                      final escalation = doc.data() as Map<String, dynamic>;
                      final status =
                          escalation['status']?.toString() ?? 'unknown';
                      final isResolved = status.toLowerCase() == 'resolved';

                      return Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            isTablet ? 16 : 12,
                          ),
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
                            borderRadius: BorderRadius.circular(
                              isTablet ? 16 : 12,
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (context) => EscalationDetailModal(
                                      escalationId: doc.id,
                                      escalationData: escalation,
                                    ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isTablet ? 20 : 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isTablet ? 10 : 8),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        isTablet ? 12 : 10,
                                      ),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: _getStatusColor(status),
                                      size: isTablet ? 22 : 18,
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 16 : 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          escalation['question'] ??
                                              'No question provided',
                                          style: TextStyle(
                                            fontSize: isTablet ? 16 : 15,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: isTablet ? 12 : 8),
                                        // ✅ Show creation date under the question
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isTablet ? 10 : 8,
                                                vertical: isTablet ? 5 : 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  status,
                                                ).withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: isTablet ? 11 : 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: _getStatusColor(
                                                    status,
                                                  ),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.access_time,
                                              size: isTablet ? 14 : 12,
                                              color: Colors.grey[500],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _formatDateTime(
                                                  escalation['createdAt']
                                                      as Timestamp?,
                                                ),
                                                style: TextStyle(
                                                  fontSize: isTablet ? 12 : 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (escalation['reason'] != null &&
                                            isTablet) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            escalation['reason'],
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
                                  // ✅ Right side - Show responder details for resolved escalations
                                  if (isResolved && escalation['respondedBy'] != null) ...[
                                    SizedBox(width: isTablet ? 12 : 8),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: isTablet ? 200 : 140,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Staff name
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person_outline,
                                                size: isTablet ? 14 : 12,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  escalation['respondedBy'],
                                                  style: TextStyle(
                                                    fontSize: isTablet ? 12 : 11,
                                                    color: const Color(0xFF2E7D32),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Responded date
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: isTablet ? 14 : 12,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  _formatDateTime(
                                                    escalation['respondedAt'] as Timestamp?,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: isTablet ? 11 : 10,
                                                    color: const Color(0xFF2E7D32),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    SizedBox(width: isTablet ? 12 : 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.grey[400],
                                      size: isTablet ? 16 : 14,
                                    ),
                                  ],
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey[600],
                  size: isCompact ? 16 : 20,
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: isCompact ? 6 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isCompact)
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.grey[600],
                    ),
                  ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? color : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompact;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isCompact ? 20 : 24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isCompact ? 40 : 48,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: isCompact ? 16 : 24),
            Text(
              title,
              style: TextStyle(
                fontSize: isCompact ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isCompact ? 13 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}