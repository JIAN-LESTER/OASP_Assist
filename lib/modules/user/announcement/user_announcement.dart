import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/modules/admin/announcement/announcement_card.dart';
import 'package:capstone_project/widgets/category_dropdown_button.dart';

import 'package:flutter/material.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserAnnouncementPage extends StatefulWidget {
  const UserAnnouncementPage({super.key});

  @override
  State<UserAnnouncementPage> createState() => _UserAnnouncementState();
}

class _UserAnnouncementState extends State<UserAnnouncementPage> {
  List<DocumentSnapshot> announcements = [];
  bool isLoading = true;
  String selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('announcements')
              .where('deleted', isEqualTo: false)
              .orderBy('created_time', descending: true)
              .get();

      setState(() {
        announcements = querySnapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading announcements: $e')),
      );
    }
  }

  List<DocumentSnapshot> get filteredAnnouncements {
    var filtered =
        announcements.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final message = data['message'] ?? '';
          final category = data['category'] ?? '';

          String normalizedSelectedCategory =
              selectedCategory.trim().toLowerCase();
          String normalizedDocCategory = category.trim().toLowerCase();

          bool categoryMatches =
              normalizedSelectedCategory == 'all categories'.toLowerCase() ||
              normalizedDocCategory == normalizedSelectedCategory ||
              normalizedDocCategory ==
                  _sentenceCase(normalizedSelectedCategory);

          if (!categoryMatches) {
            return false;
          }

          if (_searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase();
            final querySentence = _sentenceCase(query);
            return message.toLowerCase().contains(query) ||
                message.contains(querySentence);
          }

          return true;
        }).toList();

    return filtered;
  }

  String _sentenceCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildMobileLayout(),
      tabletBody: _buildTabletLayout(),
      desktopBody: _buildDesktopLayout(),
    );
  }

  // DESKTOP LAYOUT
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      body: Row(
        children: [
          // Main content area
          Expanded(
            child: Column(
              children: [
                // header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      // Search field
                      Expanded(child: _buildSearchField()),

                      const SizedBox(width: 16),

                      // Category dropdown
                      SizedBox(
                        width: 165,
                        child: CategoryDropdownButton(
                          initialValue: selectedCategory,
                          onChanged:
                              (value) =>
                                  setState(() => selectedCategory = value),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area - Takes remaining space
                Expanded(child: _buildMainContent(isDesktop: true)),
              ],
            ),
          ),
          // Right sidebar
          Container(
            width: 275,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: _buildSidebar(),
          ),
        ],
      ),
    );
  }

  // TABLET LAYOUT
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      body: Column(
        children: [
          // Fixed header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildSearchField()),
                const SizedBox(width: 12),
                Expanded(
                  child: CategoryDropdownButton(
                    initialValue: selectedCategory,
                    onChanged:
                        (value) => setState(() => selectedCategory = value),
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildMainContent(isDesktop: false),
            ),
          ),
        ],
      ),
    );
  }

  // MOBILE LAYOUT
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      body: Column(
        children: [
          // Fixed header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 12),
                CategoryDropdownButton(
                  initialValue: selectedCategory,
                  onChanged:
                      (value) => setState(() => selectedCategory = value),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMainContent(isDesktop: false),
            ),
          ),
        ],
      ),
    );
  }

  // SEARCH FIELD
  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {}),
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search announcements...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // MAIN CONTENT

  Widget _buildMainContent({required bool isDesktop}) {
    if (isLoading) {
      return _AnnouncementListSkeleton(isDesktop: isDesktop);
    }

    final displayedAnnouncements = filteredAnnouncements;

    if (displayedAnnouncements.isEmpty) {
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
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.announcement_outlined,
                  size: 64,
                  color: Colors.green[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No announcements found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Try adjusting your search or check back later for updates',
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        color: Colors.green[600],
        child: ListView.builder(
          padding:
              isDesktop
                  ? const EdgeInsets.fromLTRB(32, 0, 32, 32)
                  : const EdgeInsets.symmetric(horizontal: 20),
          itemCount: displayedAnnouncements.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: isDesktop ? 24 : 16),
              child: AnnouncementCard(
                announcement: displayedAnnouncements[index],
                index: index,
                isDesktop: isDesktop,
              ),
            );
          },
        ),
      ),
    );
  }

  // SIDEBAR
  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green[50]),
            child: Row(
              children: [
                Icon(
                  Icons.timeline_rounded,
                  color: Colors.green[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          // Sidebar content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('announcements')
                        .where('deleted', isEqualTo: false)
                        .orderBy('created_time', descending: true)
                        .limit(5)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _AnnouncementSidebarSkeleton();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timeline_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No recent activity',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final recentAnnouncements = snapshot.data!.docs;
                  return ScrollConfiguration(
                    behavior:
                        const MaterialScrollBehavior().copyWith(
                          scrollbars: false,
                        ),
                    child: ListView(
                      children:
                          recentAnnouncements
                              .map((doc) => _buildActivityItem(doc))
                              .toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final message = _truncateMessage(data['message'] ?? 'No message');
    final timeAgo = _formatTimeAgo(data['created_time']);
    final category = data['category'] ?? 'General';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: getCategoryColor(category).withOpacity(0.1),
            ),
            child: Icon(
              getCategoryIcon(category),
              size: 16,
              color: getCategoryColor(category),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _truncateMessage(String message, {int maxLength = 50}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    final dateTime =
        timestamp is Timestamp
            ? timestamp.toDate()
            : DateTime.parse(timestamp.toString());
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    }
    return DateFormat('MMM d').format(dateTime);
  }
}

class _AnnouncementListSkeleton extends StatelessWidget {
  final bool isDesktop;

  const _AnnouncementListSkeleton({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding:
          isDesktop
              ? const EdgeInsets.fromLTRB(32, 0, 32, 32)
              : const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: isDesktop ? 24 : 16),
      itemBuilder: (_, __) => const _AnnouncementSkeletonCard(),
    );
  }
}

class _AnnouncementSidebarSkeleton extends StatelessWidget {
  const _AnnouncementSidebarSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder:
          (_, __) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnnouncementSkeletonBox(width: double.infinity, height: 14),
              SizedBox(height: 8),
              _AnnouncementSkeletonBox(width: 130, height: 12),
            ],
          ),
    );
  }
}

class _AnnouncementSkeletonCard extends StatelessWidget {
  const _AnnouncementSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AnnouncementSkeletonBox(width: 42, height: 42, radius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnnouncementSkeletonBox(width: 160, height: 16),
                    SizedBox(height: 8),
                    _AnnouncementSkeletonBox(width: 110, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          _AnnouncementSkeletonBox(width: double.infinity, height: 14),
          SizedBox(height: 10),
          _AnnouncementSkeletonBox(width: double.infinity, height: 14),
          SizedBox(height: 10),
          _AnnouncementSkeletonBox(width: 220, height: 14),
        ],
      ),
    );
  }
}

class _AnnouncementSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _AnnouncementSkeletonBox({
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
