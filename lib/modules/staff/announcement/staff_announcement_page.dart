import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/modules/admin/announcement/fb_sync.dart';
import 'package:capstone_project/widgets/category_dropdown_button.dart';
import 'package:flutter/material.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum AlertType { success, error, warning, info }

String? _normalizeAnnouncementImageUrl(dynamic value) {
  if (value == null) return null;

  String rawUrl = '';

  if (value is String) {
    rawUrl = value;
  } else if (value is Map && value['url'] != null) {
    rawUrl = value['url'].toString();
  }

  if (rawUrl.isEmpty) return null;

  final sanitizedUrl = rawUrl.trim().replaceAll('&amp;', '&');
  final uri = Uri.tryParse(sanitizedUrl);

  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  return uri.toString();
}

bool _isFirebaseAnnouncementImageUrl(String url) {
  return url.contains('firebasestorage.googleapis.com');
}

List<String> _selectAnnouncementImageUrls(Iterable<dynamic> values) {
  final normalized =
      values.map(_normalizeAnnouncementImageUrl).whereType<String>().toList();

  if (normalized.isEmpty) return const [];

  final firebaseUrls =
      normalized.where(_isFirebaseAnnouncementImageUrl).toList();

  return firebaseUrls.isNotEmpty ? firebaseUrls : normalized;
}

class StaffAnnouncementPage extends StatefulWidget {
  const StaffAnnouncementPage({super.key});

  @override
  State<StaffAnnouncementPage> createState() => _StaffAnnouncementState();
}

class _StaffAnnouncementState extends State<StaffAnnouncementPage> {
  List<DocumentSnapshot> announcements = [];
  bool isLoading = true;
  bool isRefreshing = false;
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
      _showErrorSnackBar('Error loading announcements: $e');
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

  // Manual refresh button (keep as is for manual sync)
  Future<void> _refreshFromFacebook() async {
    if (isRefreshing) {
      print(' Sync already in progress');
      return;
    }

    setState(() => isRefreshing = true);

    try {
      print(' Manual Facebook sync triggered...');

      final result = await FacebookSyncService.syncPosts();

      print(' Sync result: $result');

      if (result['success'] == true) {
        await Future.delayed(Duration(milliseconds: 500));
        await _loadAnnouncements();

        final count = result['count'] ?? 0;
        final failed = result['failed'] ?? 0;

        if (mounted) {
          _showSuccessSnackBar(
            'Synced $count posts${failed > 0 ? ' ($failed failed)' : ''}',
          );
        }
      } else {
        final errorMsg = result['error'] ?? result['message'] ?? 'Sync failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print(' Sync error: $e');

      if (mounted) {
        final errorMessage = FacebookSyncService.parseErrorMessage(e);
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  // void _showSyncErrorDialog(String errorMessage) {
  //   showDialog(
  //     context: context,
  //     builder:
  //         (context) => AlertDialog(
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(16),
  //           ),
  //           title: Row(
  //             children: [
  //               Icon(Icons.error, color: Colors.red[700], size: 28),
  //               SizedBox(width: 12),
  //               Text('Sync Failed'),
  //             ],
  //           ),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(errorMessage, style: TextStyle(fontSize: 15)),
  //               SizedBox(height: 16),
  //               Container(
  //                 padding: EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey[100],
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Icon(
  //                       Icons.info_outline,
  //                       size: 16,
  //                       color: Colors.grey[700],
  //                     ),
  //                     SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         'You can manually sync later using the refresh button',
  //                         style: TextStyle(
  //                           fontSize: 12,
  //                           color: Colors.grey[700],
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: Text('Cancel'),
  //             ),
  //             ElevatedButton.icon(
  //               onPressed: () {
  //                 Navigator.pop(context);
  //                 _refreshFromFacebook(); // Trigger manual sync
  //               },
  //               icon: Icon(Icons.refresh),
  //               label: Text('Retry Sync'),
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: Colors.blue[700],
  //                 foregroundColor: Colors.white,
  //               ),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
            type: AlertType.success,
            onDismiss: () => overlayEntry.remove(),
            isMobile: isMobile,
            isTablet: isTablet,
            duration: const Duration(seconds: 4),
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
            type: AlertType.error,
            onDismiss: () => overlayEntry.remove(),
            isMobile: isMobile,
            isTablet: isTablet,
            duration: const Duration(seconds: 5),
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  // Update your refresh button row to include the test button:
  Widget _buildRefreshButton({required bool isDesktop}) {
    return Row(
      children: [
        // Test button
        SizedBox(width: 8),

        // Facebook Token Config Button
        SizedBox(width: 8),

        // Manual Sync Button
        Container(
          decoration: BoxDecoration(
            color: isRefreshing ? Colors.grey[100] : Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isRefreshing ? Colors.grey[300]! : Colors.green[200]!,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: isRefreshing ? null : _refreshFromFacebook,
              child: Tooltip(
                message: 'Manual Sync Facebook Posts',
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  child:
                      isRefreshing
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey[600]!,
                              ),
                            ),
                          )
                          : Icon(
                            Icons.sync_rounded,
                            color: Colors.green[700],
                            size: isDesktop ? 24 : 20,
                          ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
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
                      _buildRefreshButton(isDesktop: true),
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

                //  Row for dropdown + refresh button
                Row(
                  children: [
                    // Dropdown takes most space
                    Expanded(
                      child: CategoryDropdownButton(
                        initialValue: selectedCategory,
                        onChanged:
                            (value) => setState(() => selectedCategory = value),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Refresh button fixed width
                    _buildRefreshButton(isDesktop: false),
                  ],
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

    return RefreshIndicator(
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
                  return ListView(
                    children:
                        recentAnnouncements
                            .map((doc) => _buildActivityItem(doc))
                            .toList(),
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

class AnnouncementCard extends StatefulWidget {
  final DocumentSnapshot announcement;
  final int index;
  final bool isDesktop;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.index,
    required this.isDesktop,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  // int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _isMessageExpanded = false; //   Track message expansion state

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.announcement.data() as Map<String, dynamic>;
    final message = data['message'] ?? "";
    final category = data['category'] ?? 'General';
    final deadline = data['deadline'];

    List<String> images = _selectAnnouncementImageUrls(
      (data['images'] as List?) ?? const [],
    );

    if (images.isEmpty) {
      images = _selectAnnouncementImageUrls([data['full_picture']]);
    }

    if (images.isEmpty && data['original_image_urls'] is List) {
      images = _selectAnnouncementImageUrls(
        data['original_image_urls'] as List,
      );
    }

    final hasImages = images.isNotEmpty;
    final imageCount = data['image_count'] ?? images.length;
    final createdTime = _formatDate(data['created_time']);
    final hasOCR = data['has_image_text'] == true;
    final ocrProcessedCount = data['ocr_processed_count'] ?? 0;

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
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            category,
            createdTime,
            imageCount,
            hasOCR,
            ocrProcessedCount,
          ),
          if (deadline != null) _buildDeadline(deadline),
          if (message.isNotEmpty)
            _buildMessage(message), //  Updated with See More/Less
          if (hasImages) _buildImageGallery(images),
          _buildActionButtons(data),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child:
          images.length == 1
              ? _buildSingleImage(images[0])
              : _buildImageCollage(images),
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, [imageUrl], 0),
        child: Container(
          height: widget.isDesktop ? 400 : 300,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildAnnouncementImage(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => _buildImageError(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildImageLoading(loadingProgress);
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _buildFullscreenButton([imageUrl], 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCollage(List<String> images) {
    final imageCount = images.length;

    // Different layouts based on number of images
    if (imageCount == 2) {
      return _buildTwoImageLayout(images);
    } else if (imageCount == 3) {
      return _buildThreeImageLayout(images);
    } else if (imageCount == 4) {
      return _buildFourImageLayout(images);
    } else {
      // 5 or more images
      return _buildMultiImageLayout(images);
    }
  }

  // Layout for 2 images (side by side)
  Widget _buildTwoImageLayout(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Row(
          children: [
            Expanded(child: _buildCollageImage(images[0], 0, images)),
            const SizedBox(width: 4),
            Expanded(child: _buildCollageImage(images[1], 1, images)),
          ],
        ),
      ),
    );
  }

  // Layout for 3 images (1 large on left, 2 stacked on right)
  Widget _buildThreeImageLayout(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Row(
          children: [
            Expanded(flex: 2, child: _buildCollageImage(images[0], 0, images)),
            const SizedBox(width: 4),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _buildCollageImage(images[1], 1, images)),
                  const SizedBox(height: 4),
                  Expanded(child: _buildCollageImage(images[2], 2, images)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Layout for 4 images (2x2 grid)
  Widget _buildFourImageLayout(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCollageImage(images[0], 0, images)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildCollageImage(images[1], 1, images)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCollageImage(images[2], 2, images)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildCollageImage(images[3], 3, images)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Layout for 5+ images (2x2 grid with "+N" overlay on last image)
  Widget _buildMultiImageLayout(List<String> images) {
    final displayImages = images.take(4).toList();
    final remainingCount = images.length - 4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCollageImage(displayImages[0], 0, images),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildCollageImage(displayImages[1], 1, images),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCollageImage(displayImages[2], 2, images),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildCollageImage(
                      displayImages[3],
                      3,
                      images,
                      showOverlay: true,
                      overlayText: '+$remainingCount',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollageImage(
    String imageUrl,
    int index,
    List<String> allImages, {
    bool showOverlay = false,
    String? overlayText,
  }) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, allImages, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildAnnouncementImage(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.image, color: Colors.grey[400], size: 32),
                ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[100],
                child: Center(
                  child: CircularProgressIndicator(
                    value:
                        loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green[600]!,
                    ),
                  ),
                ),
              );
            },
          ),
          if (showOverlay && overlayText != null)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Text(
                  overlayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Fullscreen button on hover
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenButton(List<String> images, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFullScreenImage(context, images, index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageGallery(
              images: images,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  // Widget _buildImageCarousel(List<String> images) {
  //   return Stack(
  //     children: [
  //       PageView.builder(
  //         controller: _pageController,
  //         itemCount: images.length,
  //         onPageChanged: (index) {
  //           setState(() {
  //             _currentImageIndex = index;
  //           });
  //         },
  //         itemBuilder: (context, index) {
  //           return GestureDetector(
  //             onTap: () => _showFullScreenImage(context, images, index),
  //             child: Image.network(
  //               images[index],
  //               width: double.infinity,
  //               height: double.infinity,
  //               fit: BoxFit.contain, //  Changed from cover to contain
  //               errorBuilder:
  //                   (context, error, stackTrace) => _buildImageError(),
  //               loadingBuilder: (context, child, loadingProgress) {
  //                 if (loadingProgress == null) return child;
  //                 return _buildImageLoading(loadingProgress);
  //               },
  //             ),
  //           );
  //         },
  //       ),

  //       if (images.length > 1) ...[
  //         _buildNavigationArrow(
  //           alignment: Alignment.centerLeft,
  //           icon: Icons.chevron_left,
  //           onTap: () {
  //             if (_currentImageIndex > 0) {
  //               _pageController.previousPage(
  //                 duration: const Duration(milliseconds: 300),
  //                 curve: Curves.easeInOut,
  //               );
  //             }
  //           },
  //           enabled: _currentImageIndex > 0,
  //         ),
  //         _buildNavigationArrow(
  //           alignment: Alignment.centerRight,
  //           icon: Icons.chevron_right,
  //           onTap: () {
  //             if (_currentImageIndex < images.length - 1) {
  //               _pageController.nextPage(
  //                 duration: const Duration(milliseconds: 300),
  //                 curve: Curves.easeInOut,
  //               );
  //             }
  //           },
  //           enabled: _currentImageIndex < images.length - 1,
  //         ),
  //       ],

  //       if (images.length > 1)
  //         Positioned(
  //           top: 12,
  //           right: 12,
  //           child: Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //             decoration: BoxDecoration(
  //               color: Colors.black.withOpacity(0.7),
  //               borderRadius: BorderRadius.circular(20),
  //             ),
  //             child: Row(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 const Icon(
  //                   Icons.photo_library,
  //                   color: Colors.white,
  //                   size: 16,
  //                 ),
  //                 const SizedBox(width: 6),
  //                 Text(
  //                   '${_currentImageIndex + 1}/${images.length}',
  //                   style: const TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 13,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),

  //       Positioned(
  //         top: 12,
  //         left: 12,
  //         child: _buildFullscreenButton(images, _currentImageIndex),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildNavigationArrow({
  //   required AlignmentGeometry alignment,
  //   required IconData icon,
  //   required VoidCallback onTap,
  //   required bool enabled,
  // }) {
  //   if (!enabled) return const SizedBox.shrink();

  //   return Align(
  //     alignment: alignment,
  //     child: Padding(
  //       padding: const EdgeInsets.all(8),
  //       child: Material(
  //         color: Colors.transparent,
  //         child: InkWell(
  //           onTap: onTap,
  //           borderRadius: BorderRadius.circular(24),
  //           child: Container(
  //             padding: const EdgeInsets.all(8),
  //             decoration: BoxDecoration(
  //               color: Colors.black.withOpacity(0.6),
  //               shape: BoxShape.circle,
  //             ),
  //             child: Icon(icon, color: Colors.white, size: 28),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildHeader(
    String category,
    String createdTime,
    int imageCount,
    bool hasOCR,
    int ocrProcessedCount,
  ) {
    return Padding(
      padding: EdgeInsets.all(widget.isDesktop ? 24 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  getColorForCategory(category).withOpacity(0.9),
                  getColorForCategory(category),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              getCategoryIcon(category),
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            getColorForCategory(category).withOpacity(0.15),
                            getColorForCategory(category).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: getColorForCategory(category),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdTime,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadline(dynamic deadline) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEADLINE',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat(
                    'MMMM d, yyyy',
                  ).format((deadline as Timestamp).toDate()),
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //   Message widget with See More/Less functionality
  Widget _buildMessage(String message) {
    // Count the number of lines
    final textPainter = TextPainter(
      text: TextSpan(
        text: message,
        style: TextStyle(
          fontSize: widget.isDesktop ? 15 : 14,
          height: 1.7,
          color: Colors.grey[700],
        ),
      ),
      maxLines: null,
      textDirection: Directionality.of(context),
    )..layout(
      maxWidth:
          MediaQuery.of(context).size.width - (widget.isDesktop ? 48 : 40),
    );

    final lineCount = textPainter.computeLineMetrics().length;
    final needsExpansion = lineCount > 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: widget.isDesktop ? 15 : 14,
              height: 1.7,
              color: Colors.grey[700],
            ),
            maxLines: needsExpansion && !_isMessageExpanded ? 3 : null,
            overflow:
                needsExpansion && !_isMessageExpanded
                    ? TextOverflow.ellipsis
                    : null,
          ),
          if (needsExpansion) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _isMessageExpanded = !_isMessageExpanded;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isMessageExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isMessageExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.green[700],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.grey[200]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load image',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageLoading(ImageChunkEvent loadingProgress) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: CircularProgressIndicator(
          value:
              loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
        ),
      ),
    );
  }

  Widget _buildAnnouncementImage(
    String imageUrl, {
    required BoxFit fit,
    ImageErrorWidgetBuilder? errorBuilder,
    ImageLoadingBuilder? loadingBuilder,
  }) {
    final normalizedUrl = _normalizeAnnouncementImageUrl(imageUrl);

    if (normalizedUrl == null) {
      return errorBuilder?.call(
            context,
            StateError('Invalid image URL'),
            null,
          ) ??
          _buildImageError();
    }

    return Image.network(
      normalizedUrl,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(widget.isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: _buildActionButton(
              icon: Icons.open_in_new_rounded,
              label: 'View on Facebook',
              onTap: () => _launchUrl(data['permalink_url']),
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            gradient:
                isPrimary
                    ? LinearGradient(
                      colors: [Colors.green[600]!, Colors.green[700]!],
                    )
                    : null,
            color: isPrimary ? null : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary ? Colors.green[700]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isPrimary ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : Colors.grey[700],
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildIconButton({
  //   required IconData icon,
  //   required VoidCallback onTap,
  //   required Color color,
  // }) {
  //   return Material(
  //     color: Colors.transparent,
  //     child: InkWell(
  //       onTap: onTap,
  //       borderRadius: BorderRadius.circular(8),
  //       child: Container(
  //         padding: const EdgeInsets.all(12),
  //         decoration: BoxDecoration(
  //           color: color.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(8),
  //           border: Border.all(color: color.withOpacity(0.3)),
  //         ),
  //         child: Icon(icon, size: 18, color: color),
  //       ),
  //     ),
  //   );
  // }

  void _launchUrl(String? url) {
    if (url != null) {
      launchUrl(Uri.parse(url));
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }
}

// ============================================================================
//   Full Screen Image Gallery with Navigation Arrows
// ============================================================================

class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
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

class TopRightAlert extends StatefulWidget {
  final String message;
  final AlertType type;
  final VoidCallback onDismiss;
  final bool isMobile;
  final bool isTablet;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Duration duration;

  const TopRightAlert({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.isMobile = false,
    this.isTablet = false,
    this.actionLabel,
    this.onActionPressed,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<TopRightAlert> createState() => _TopRightAlertState();
}

class _TopRightAlertState extends State<TopRightAlert>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Progress animation for the underline
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _progressController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF1E3A32);
      case AlertType.error:
        return const Color(0xFF3A2327);
      case AlertType.warning:
        return const Color(0xFF3A3227);
      case AlertType.info:
        return const Color(0xFF2D2D2D);
    }
  }

  LinearGradient _getProgressGradient() {
    switch (widget.type) {
      case AlertType.success:
        return const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case AlertType.error:
        return const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case AlertType.warning:
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case AlertType.info:
        return const LinearGradient(
          colors: [Color(0xFF4B5563), Color(0xFF6B7280)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }

  Color _getIconBackgroundColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF10B981);
      case AlertType.error:
        return const Color(0xFFEF4444);
      case AlertType.warning:
        return const Color(0xFFF59E0B);
      case AlertType.info:
        return const Color(0xFF6B7280);
    }
  }

  Color _getActionButtonColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF059669);
      case AlertType.error:
        return const Color(0xFF991B1B);
      case AlertType.warning:
        return const Color(0xFF92400E);
      case AlertType.info:
        return const Color(0xFF4B5563);
    }
  }

  Color _getActionTextColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF6EE7B7);
      case AlertType.error:
        return const Color(0xFFFCA5A5);
      case AlertType.warning:
        return const Color(0xFFFCD34D);
      case AlertType.info:
        return Colors.white70;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning_amber_rounded;
      case AlertType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double alertWidth;
    double topPosition;
    double rightPosition;

    if (widget.isMobile) {
      alertWidth = screenWidth - 32;
      topPosition = 16;
      rightPosition = 16;
    } else if (widget.isTablet) {
      alertWidth = 420;
      topPosition = 24;
      rightPosition = 24;
    } else {
      alertWidth = 460;
      topPosition = 24;
      rightPosition = 24;
    }

    return Positioned(
      top: topPosition,
      right: rightPosition,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: alertWidth,
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Content
                  Padding(
                    padding: EdgeInsets.all(widget.isMobile ? 16 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getIconBackgroundColor(),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                _getIcon(),
                                color: Colors.white,
                                size: widget.isMobile ? 20 : 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: widget.isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _dismiss,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white.withOpacity(0.7),
                                    size: widget.isMobile ? 18 : 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Action Buttons
                        if (widget.actionLabel != null ||
                            widget.onActionPressed != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (widget.actionLabel != null &&
                                  widget.onActionPressed != null)
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onActionPressed,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getActionButtonColor(),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          widget.actionLabel!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _getActionTextColor(),
                                            fontSize: widget.isMobile ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _dismiss,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'Dismiss',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: widget.isMobile ? 14 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Progress indicator at bottom
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: SizedBox(
                      height: 4,
                      child: Stack(
                        children: [
                          // Background
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ),
                          // Progress bar with gradient
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: _getProgressGradient(),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late final List<String> _images;

  @override
  void initState() {
    super.initState();
    _images =
        widget.images
            .map(_normalizeAnnouncementImageUrl)
            .whereType<String>()
            .toList();
    _currentIndex =
        _images.isEmpty ? 0 : widget.initialIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_images.isEmpty)
            const Center(
              child: Icon(Icons.error, color: Colors.white, size: 64),
            )
          else
            PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      _images[index],
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 64,
                        );
                      },
                    ),
                  ),
                );
              },
            ),

          //   Navigation arrows in fullscreen
          if (_images.length > 1) ...[
            _buildFullscreenNavigationArrow(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left,
              onTap: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              enabled: _currentIndex > 0,
            ),
            _buildFullscreenNavigationArrow(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right,
              onTap: () {
                if (_currentIndex < _images.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              enabled: _currentIndex < widget.images.length - 1,
            ),
          ],

          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Image counter
          if (_images.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  //   Navigation arrow for fullscreen mode
  Widget _buildFullscreenNavigationArrow({
    required AlignmentGeometry alignment,
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    if (!enabled) return const SizedBox.shrink();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
