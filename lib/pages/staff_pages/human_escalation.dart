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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _refreshAnimationController;
  
  final List<String> _filterOptions = [
    'all',
    'pending',
    'resolved',
  ];

 @override
void initState() {
  super.initState();
  
  _refreshAnimationController = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  
  _searchController.addListener(() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  });
  
  // ✅ ADD THIS: Auto-open escalation if specified
  if (widget.autoOpen && widget.initialEscalationId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openEscalationById(widget.initialEscalationId!);
    });
  }
}

// ✅ ADD THIS METHOD:
Future<void> _openEscalationById(String escalationId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('escalations')
        .doc(escalationId)
        .get();
    
    if (doc.exists && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => EscalationDetailModal(
          escalationId: doc.id,
          escalationData: doc.data() as Map<String, dynamic>,
        ),
      );
    }
  } catch (e) {
    print('❌ Error opening escalation: $e');
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header with gradient
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
                    // Enhanced title and actions
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Escalations",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                      
                              ),
                            ),
                            Text(
                              "Manage and resolve user escalations",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Enhanced action buttons
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
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: (option == 'all'
                                                ? const Color(0xFF6B7280)
                                                : _getStatusColor(option)).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            option == 'all'
                                                ? Icons.list_alt
                                                : _getStatusIcon(option),
                                            color: option == 'all'
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
                                            fontWeight: _selectedFilter == option
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: _selectedFilter == option
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
                    
                    // Search Bar - Always visible
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
                        decoration: InputDecoration(
                          hintText: 'Search escalations...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                      ),
                    ),                    // Active filters with improved design
                        // Enhanced Stats Row
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('escalations').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            height: 90,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        final total = docs.length;
                        final pending = docs.where((doc) => (doc.data() as Map)['status'] == 'pending').length;
                        final resolved = docs.where((doc) => (doc.data() as Map)['status'] == 'resolved').length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: "Total",
                                  value: total.toString(),
                                  color: const Color(0xFF6366F1),
                                  icon: Icons.inbox,
                                  isSelected: _selectedFilter == 'all',
                                  onTap: () => setState(() => _selectedFilter = 'all'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  title: "Pending",
                                  value: pending.toString(),
                                  color: const Color(0xFFF59E0B),
                                  icon: Icons.schedule,
                                  isSelected: _selectedFilter == 'pending',
                                  onTap: () => setState(() => _selectedFilter = 'pending'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  title: "Resolved",
                                  value: resolved.toString(),
                                  color: const Color(0xFF10B981),
                                  icon: Icons.check_circle,
                                  isSelected: _selectedFilter == 'resolved',
                                  onTap: () => setState(() => _selectedFilter = 'resolved'),
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
                stream: FirebaseFirestore.instance
                    .collection('escalations')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
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
                    );
                  }

                  final escalations = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    if (_selectedFilter != 'all') {
                      if (data['status']?.toString().toLowerCase() != _selectedFilter) {
                        return false;
                      }
                    }
                    
                    return _matchesSearch(data);
                  }).toList();

                  if (escalations.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off,
                      title: "No matching escalations",
                      subtitle: _searchQuery.isNotEmpty 
                          ? "Try adjusting your search terms"
                          : "No ${_selectedFilter} escalations found",
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: escalations.length,
                    itemBuilder: (context, index) {
                      final doc = escalations[index];
                      final escalation = doc.data() as Map<String, dynamic>;
                      final status = escalation['status']?.toString() ?? 'unknown';

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
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => EscalationDetailModal(
                                  escalationId: doc.id,
                                  escalationData: escalation,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Enhanced status indicator
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: _getStatusColor(status),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Enhanced content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Question
                                        Text(
                                          escalation['question'] ?? 'No question provided',
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
                                        
                                        // Enhanced meta info
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: _getStatusColor(status),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.schedule,
                                              size: 14,
                                              color: Colors.grey[500],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDate(escalation['createdAt'] as Timestamp?),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        if (escalation['reason'] != null) ...[
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
                                  
                                  // Enhanced arrow
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
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
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey[600],
                  size: 20,
                ),
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
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: color,
              ),
            ),
          ),
        ],
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
            child: Icon(
              icon,
              size: 48,
              color: Colors.grey[400],
            ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}