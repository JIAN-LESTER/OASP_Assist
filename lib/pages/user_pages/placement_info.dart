import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/models/placement.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';

class PlacementInfo extends StatefulWidget {
  const PlacementInfo({super.key});

  @override
  State<PlacementInfo> createState() => _PlacementInfoState();
}

class _PlacementInfoState extends State<PlacementInfo>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedProvider = 'all';
  String _sortBy = 'newest';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool isLoading = true;
  List<Placement> placements = [];

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
    _loadPlacements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPlacements() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('placements')
              .orderBy('createdAt', descending: true)
              .get();

      final List<Placement> loadedPlacements =
          snapshot.docs
              .map(
                (doc) => Placement.fromJson({
                  'placementID': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                }),
              )
              .toList();

      setState(() {
        placements = loadedPlacements;
        isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading placements: $e')));
      }
    }
  }

  Future<void> _launchContact(String contact) async {
    Uri uri;
    if (contact.contains('@')) {
      uri = Uri.parse('mailto:$contact');
    } else if (contact.startsWith('+') || contact.length >= 10) {
      uri = Uri.parse('tel:$contact');
    } else {
      uri = Uri.parse(
        contact.startsWith('http') ? contact : 'https://$contact',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $contact')));
      }
    }
  }

  Color _getStatusColor(int daysAgo) {
    if (daysAgo <= 3) return const Color(0xFF2563EB); // Blue for new
    if (daysAgo <= 14) return const Color(0xFF2E7D32); // Green for recent
    return const Color(0xFF6B7280); // Gray for old
  }

  IconData _getStatusIcon(int daysAgo) {
    if (daysAgo <= 3) return Icons.fiber_new;
    if (daysAgo <= 14) return Icons.work;
    return Icons.business;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
  }

  bool _matchesSearch(Placement placement) {
    if (_searchQuery.isEmpty) return true;

    final company = placement.partnerCompany.toLowerCase();
    final positions = placement.positions.map((p) => p.toLowerCase()).join(' ');

    return company.contains(_searchQuery) || positions.contains(_searchQuery);
  }

  List<String> _getProviderOptions() {
    Set<String> providers = {'all'};
    for (var placement in placements) {
      if (placement.partnerCompany.isNotEmpty) {
        providers.add(placement.partnerCompany);
      }
    }
    return providers.toList();
  }

  List<Placement> _processPlacement() {
    var filtered = placements;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((placement) => _matchesSearch(placement)).toList();
    }

    // Apply provider filter
    if (_selectedProvider != 'all') {
      filtered =
          filtered.where((placement) {
            return placement.partnerCompany == _selectedProvider;
          }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.partnerCompany.compareTo(b.partnerCompany);
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
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
                              "Job Placements",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              "Explore available job opportunities",
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
                                    'FILTER BY COMPANY',
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
                                                ? 'All Companies'
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
                                  value: 'sort_oldest',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        color:
                                            _sortBy == 'oldest'
                                                ? primaryGreen
                                                : const Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Oldest',
                                        style: TextStyle(
                                          fontWeight:
                                              _sortBy == 'oldest'
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
                          hintText: 'Search companies or positions...',
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
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0F172A),
                          strokeWidth: 3,
                        ),
                      )
                      : Builder(
                        builder: (context) {
                          if (placements.isEmpty) {
                            return _EmptyState(
                              icon: Icons.work_off_outlined,
                              title: "No placements found",
                              subtitle:
                                  "Check back later for new opportunities",
                            );
                          }

                          final filteredPlacements = _processPlacement();

                          if (filteredPlacements.isEmpty) {
                            return _EmptyState(
                              icon: Icons.search_off,
                              title: "No matching placements",
                              subtitle:
                                  _searchQuery.isNotEmpty
                                      ? "Try adjusting your search terms"
                                      : "No placements from $_selectedProvider found",
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: filteredPlacements.length,
                            itemBuilder: (context, index) {
                              final placement = filteredPlacements[index];
                              final daysAgo =
                                  DateTime.now()
                                      .difference(placement.createdAt)
                                      .inDays;

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
                                    onTap:
                                        () => _showPlacementDetails(placement),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          // Status indicator
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                daysAgo,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _getStatusIcon(daysAgo),
                                              color: _getStatusColor(daysAgo),
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
                                                // Company name
                                                Text(
                                                  placement.partnerCompany,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A),
                                                    height: 1.4,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                          daysAgo,
                                                        ).withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _formatDate(
                                                          placement.createdAt,
                                                        ).toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              _getStatusColor(
                                                                daysAgo,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.work_outline,
                                                      size: 14,
                                                      color: Colors.grey[500],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        '${placement.positions.length} position${placement.positions.length == 1 ? '' : 's'}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                if (placement
                                                    .positions
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    placement.positions.first,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                      height: 1.3,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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

  void _showPlacementDetails(Placement placement) {
    final daysAgo = DateTime.now().difference(placement.createdAt).inDays;

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
                            'Placement Details',
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
                          // Company Name Section
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
                                  'PARTNER COMPANY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[500],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  placement.partnerCompany,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(placement.createdAt),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (daysAgo <= 3) ...[
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
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'New',
                                          style: TextStyle(
                                            color: Colors.blue[700],
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

                          // Available Positions
                          if (placement.positions.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'AVAILABLE POSITIONS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...placement.positions.map((position) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 7),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        position,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],

                          // Contact Information
                          if (placement.contacts.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'CONTACT INFORMATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...placement.contacts.map((contact) {
                              IconData iconData;
                              if (contact.contains('@')) {
                                iconData = Icons.email_rounded;
                              } else if (contact.startsWith('+') ||
                                  contact.length >= 10) {
                                iconData = Icons.phone_rounded;
                              } else {
                                iconData = Icons.link_rounded;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 7),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.purple[600],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _launchContact(contact),
                                        child: Text(
                                          contact,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: primaryGreen,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],

                          const SizedBox(height: 24),

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
