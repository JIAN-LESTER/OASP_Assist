import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/models/placement.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
  int _currentPage = 0;

  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF4CAF50);
  final Color accentGreen = const Color(0xFF81C784);
  final Color successGreen = const Color(0xFF66BB6A);
  final Color placementViolet = const Color(0xFF7C3AED);

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

  String _formatFullDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
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
                              "Job Placements",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              "Explore available job opportunities",
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
                                _currentPage = 0;
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
                            _currentPage = 0;
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
                                        _currentPage = 0;
                                        _searchQuery = '';
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

            Expanded(
              child:
                  isLoading
                      ? Center(
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
                              'Loading Job Placements',
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

                          return ResponsiveLayout(
                            mobileBody: _buildPlacementResults(
                              filteredPlacements,
                              isMobile: true,
                            ),
                            tabletBody: _buildPlacementResults(
                              filteredPlacements,
                              isMobile: false,
                            ),
                            desktopBody: _buildPlacementResults(
                              filteredPlacements,
                              isMobile: false,
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacementResults(
    List<Placement> filteredPlacements, {
    required bool isMobile,
  }) {
    final itemsPerPage = isMobile ? 6 : 8;
    final totalPages = (filteredPlacements.length / itemsPerPage).ceil();
    final effectivePage =
        totalPages == 0
            ? 0
            : _currentPage.clamp(0, totalPages - 1).toInt();
    final startIndex = effectivePage * itemsPerPage;
    final endIndex =
        (startIndex + itemsPerPage).clamp(0, filteredPlacements.length).toInt();
    final pagePlacements = filteredPlacements.sublist(startIndex, endIndex);

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pagePlacements.length + 1,
        itemBuilder: (context, index) {
          if (index == pagePlacements.length) {
            return _buildPaginationControls(effectivePage, totalPages);
          }

          return _buildMobilePlacementTile(pagePlacements[index]);
        },
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDesktopPlacementCard(
                pagePlacements[index],
              ),
              childCount: pagePlacements.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildPaginationControls(effectivePage, totalPages),
        ),
      ],
    );
  }

  Widget _buildDesktopPlacementCard(Placement placement) {
    final daysAgo = DateTime.now().difference(placement.createdAt).inDays;
    final deadlineText = _formatDeadline(placement.deadline);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPlacementDetails(placement),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: placementViolet, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: placementViolet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.business, color: placementViolet, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      placement.partnerCompany,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(daysAgo).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDate(placement.createdAt).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(daysAgo),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildPositionBadges(placement.positions)),
              if (deadlineText != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.bottomRight,
                  child: _buildDeadlineBadge(deadlineText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePlacementTile(Placement placement) {
    final daysAgo = DateTime.now().difference(placement.createdAt).inDays;
    final deadlineText = _formatDeadline(placement.deadline);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showPlacementDetails(placement),
          child: Container(
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [placementViolet, const Color(0xFFA78BFA)],
                      ),
                      borderRadius: const BorderRadius.only(
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  placement.partnerCompany,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (deadlineText != null) ...[
                                const SizedBox(width: 8),
                                _buildDeadlineBadge(deadlineText),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(daysAgo).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDate(placement.createdAt).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(daysAgo),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPositionBadges(placement.positions),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionBadges(List<String> positions) {
    if (positions.isEmpty) return const SizedBox.shrink();

    final visible = positions.take(5).toList();
    final hiddenCount = positions.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visible.map(
          (position) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Text(
              position,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: placementViolet,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (hiddenCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              '+$hiddenCount more',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeadlineBadge(String deadlineText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        deadlineText,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildPaginationControls(int effectivePage, int totalPages) {
    if (totalPages <= 1) return const SizedBox(height: 12);

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
                    effectivePage == 0
                        ? null
                        : () =>
                            setState(() => _currentPage = effectivePage - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${effectivePage + 1} of $totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              IconButton(
                onPressed:
                    effectivePage >= totalPages - 1
                        ? null
                        : () =>
                            setState(() => _currentPage = effectivePage + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatDeadline(DateTime? deadline) {
    if (deadline == null) return null;

    final dateText = DateFormat('MMM d, yyyy').format(deadline);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final deadlineOnly = DateTime(deadline.year, deadline.month, deadline.day);

    if (deadlineOnly.isBefore(todayOnly)) {
      return 'Expired $dateText';
    }
    return 'Deadline $dateText';
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
                          // Company Name Section (KEEP WITH LEFT PADDING)
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
                                  'COMPANY NAME',
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
                                    placement.partnerCompany,
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
                                    'Posted on ${_formatFullDate(placement.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
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

                          // Available Positions (WITH BULLETS)
                          if (placement.positions.isNotEmpty) ...[
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
                                    'AVAILABLE POSITIONS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...placement.positions.map((position) {
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
                                              position,
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

                          // Contact Information (WITH BULLETS)
                          if (placement.contacts.isNotEmpty) ...[
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
                                    'CONTACT INFORMATION',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...placement.contacts.map((contact) {
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
                                            child: SelectableText(
                                              contact,
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
