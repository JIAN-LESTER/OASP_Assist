import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/modules/admin/announcement/announcement_card.dart';
import 'package:capstone_project/modules/admin/announcement/fb_storage.dart';

import 'package:capstone_project/modules/admin/announcement/token_input.dart';
import 'package:capstone_project/modules/admin/announcement/fb_sync.dart';
import 'package:capstone_project/widgets/category_dropdown_button.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  List<DocumentSnapshot> announcements = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _announcementScrollController = ScrollController();
  final Map<String, GlobalKey> _announcementKeys = {};
  late final Stream<QuerySnapshot> announcementStream;

  // Facebook Integration Helper
  final fbHelper = FacebookIntegrationHelper();

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
    _initializeFacebookIntegration();

    announcementStream =
        FirebaseFirestore.instance
            .collection('announcements')
            .where('deleted', isEqualTo: false)
            .orderBy('created_time', descending: true)
            .limit(10)
            .snapshots();
  }

  Future<void> _initializeFacebookIntegration() async {
    await fbHelper.checkTokenStatus();
    await fbHelper.loadConfiguredApps();
    if (mounted) setState(() {});
  }

  Future<void> loadAnnouncements() async {
    // Your existing loadAnnouncements implementation
    setState(() => isLoading = false);
  }

  // Manual refresh button
  Future<void> _refreshFromFacebook() async {
    if (isRefreshing) {
      print(' Sync already in progress');
      return;
    }

    setState(() => isRefreshing = true);

    try {
      print(' Manual Facebook sync triggered...');
      final result = await FacebookSyncService.syncPosts();

      if (!mounted) return;

      print(' Sync result: $result');

      if (result['success'] == true) {
        await Future.delayed(Duration(milliseconds: 500));
        await loadAnnouncements();

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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    SnackbarUtil.showSuccess(context, message);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    SnackbarUtil.showError(context, message);
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
  void dispose() {
    _searchController.dispose();
    _announcementScrollController.dispose();
    super.dispose();
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
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSearchField()),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 165,
                        child: CategoryDropdownButton(
                          initialValue: selectedCategory,
                          onChanged: (value) {
                            setState(() => selectedCategory = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildActionButtons(isDesktop: true),
                    ],
                  ),
                ),
                Expanded(child: _buildMainContent(isDesktop: true)),
              ],
            ),
          ),
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
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              children: [
                Row(
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActionButtons(isDesktop: false),
                ),
              ],
            ),
          ),
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

  void _showSyncSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[600]!, Colors.orange[700]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_suggest_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Auto-create documents & Vision OCR',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.document_scanner_rounded,
                                  color: Colors.orange[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'When enabled, synced Facebook posts with images will use '
                                    'Google Vision OCR to extract text, then automatically '
                                    'create structured Admission, Scholarship, or Placement documents.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[900],
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AnnouncementSyncSettings(),
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

  // MOBILE LAYOUT
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      body: Column(
        children: [
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildActionButtons(isDesktop: false),
                ),
                const SizedBox(height: 12),
                CategoryDropdownButton(
                  initialValue: selectedCategory,
                  onChanged:
                      (value) => setState(() => selectedCategory = value),
                ),
              ],
            ),
          ),
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

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.5 + (value * 0.5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildActionButtons({required bool isDesktop}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        // App Credentials Button
        Stack(
          clipBehavior: Clip.none,
          children: [
            Tooltip(
              message: 'Manage Facebook App Credentials',
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap:
                        () => showAppCredentialsDialog(
                          context,
                          fbHelper,
                          () => setState(() {}),
                        ),
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 14 : 12),
                      child: Icon(
                        Icons.apps_rounded,
                        color: Colors.white,
                        size: isDesktop ? 24 : 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (fbHelper.configuredApps.isNotEmpty)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[500]!, Colors.green[700]!],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      '${fbHelper.configuredApps.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Token Status Indicator
        Stack(
          clipBehavior: Clip.none,
          children: [
            Tooltip(
              message: fbHelper.getTokenStatusTooltip(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[600]!, Colors.indigo[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (fbHelper.tokenStatus?.needsRenewal == true ||
                          fbHelper.tokenStatus?.expired == true) {
                        showTokenStatusDialog(
                          context,
                          fbHelper,
                          () => setState(() {}),
                        );
                      } else {
                        showTokenInputModal(
                          context,
                          fbHelper,
                          () => setState(() {}),
                        );
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 14 : 12),
                      child: Icon(
                        Icons.vpn_key_rounded,
                        color: Colors.white,
                        size: isDesktop ? 24 : 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (fbHelper.hasCheckedToken &&
                fbHelper.tokenStatus?.configured == true)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap:
                      () => showTokenStatusDialog(
                        context,
                        fbHelper,
                        () => setState(() {}),
                      ),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: fbHelper.getTokenStatusColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child:
                        fbHelper.tokenStatus!.daysLeft != null &&
                                fbHelper.tokenStatus!.daysLeft! <= 7
                            ? _buildPulsingDot()
                            : null,
                  ),
                ),
              ),
          ],
        ),
        // Sync Settings Button
        Tooltip(
          message: 'Sync Settings (Auto-create & Vision OCR)',
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[600]!, Colors.orange[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showSyncSettingsDialog(context),
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 14 : 12),
                  child: Icon(
                    Icons.settings_suggest_rounded,
                    color: Colors.white,
                    size: isDesktop ? 24 : 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Manual Sync Button
        Tooltip(
          message: 'Manual Sync Facebook Posts',
          child: Container(
            decoration: BoxDecoration(
              gradient:
                  isRefreshing
                      ? LinearGradient(
                        colors: [Colors.grey[400]!, Colors.grey[500]!],
                      )
                      : LinearGradient(
                        colors: [Colors.green[600]!, Colors.green[700]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isRefreshing ? Colors.grey : Colors.green)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isRefreshing ? null : _refreshFromFacebook,
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 14 : 12),
                  child:
                      isRefreshing
                          ? SizedBox(
                            width: isDesktop ? 24 : 22,
                            height: isDesktop ? 24 : 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(
                            Icons.sync_rounded,
                            color: Colors.white,
                            size: isDesktop ? 24 : 22,
                          ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildMainContent({required bool isDesktop}) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('announcements')
              .where('deleted', isEqualTo: false)
              .orderBy('created_time', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading announcements...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allAnnouncements = snapshot.data?.docs ?? [];
        final displayedAnnouncements = _filterAnnouncementsFromDocs(
          allAnnouncements,
        );
        final visibleIds = displayedAnnouncements.map((doc) => doc.id).toSet();
        _announcementKeys.removeWhere((id, _) => !visibleIds.contains(id));

        if (displayedAnnouncements.isEmpty) {
          return Center(child: Text('No announcements found'));
        }

        return RefreshIndicator(
          onRefresh: _refreshFromFacebook,
          color: Colors.green[600],
          child: ListView.builder(
            controller: _announcementScrollController,
            padding:
                isDesktop
                    ? const EdgeInsets.fromLTRB(32, 0, 32, 32)
                    : const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayedAnnouncements.length,
            itemBuilder: (context, index) {
              final announcement = displayedAnnouncements[index];
              final announcementKey = _announcementKeys.putIfAbsent(
                announcement.id,
                () => GlobalKey(),
              );
              return Padding(
                key: announcementKey,
                padding: EdgeInsets.only(bottom: isDesktop ? 24 : 16),
                child: AnnouncementCard(
                  announcement: announcement,
                  index: index,
                  isDesktop: isDesktop,
                  onEdit: _editAnnouncement,
                  onDelete: _deleteAnnouncement,
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<DocumentSnapshot> _filterAnnouncementsFromDocs(
    List<DocumentSnapshot> docs,
  ) {
    // Your existing filter logic
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final message = data['message'] ?? '';
      final category = data['category'] ?? '';

      String normalizedSelectedCategory = selectedCategory.trim().toLowerCase();
      String normalizedDocCategory = category.trim().toLowerCase();

      bool categoryMatches =
          normalizedSelectedCategory == 'all categories'.toLowerCase() ||
          normalizedDocCategory == normalizedSelectedCategory;

      if (!categoryMatches) return false;

      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        return message.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<QuerySnapshot>(
                stream: announcementStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
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

  Future<void> _scrollToAnnouncement(DocumentSnapshot doc) async {
    final key = _announcementKeys[doc.id];
    if (key?.currentContext == null) {
      _showErrorSnackBar('Announcement is not visible in the current list');
      return;
    }

    await Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  Widget _buildActivityItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final message = _truncateMessage(data['message'] ?? 'No message');
    final timeAgo = _formatTimeAgo(data['created_time']);
    final category = data['category'] ?? 'General';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _scrollToAnnouncement(doc),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
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
        ),
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
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w ago';
    return DateFormat('MMM d').format(dateTime);
  }

  Future<void> _editAnnouncement(DocumentSnapshot announcement) async {
    // Your existing edit implementation
  }

  Future<void> _deleteAnnouncement(DocumentSnapshot announcement) async {
    showDeleteConfirmation(
      context,
      announcement,
      DeleteConfigs.announcement,
      'announcements',
    );
  }
}

class AnnouncementSyncSettings extends StatefulWidget {
  const AnnouncementSyncSettings({super.key});

  @override
  State<AnnouncementSyncSettings> createState() =>
      _AnnouncementSyncSettingsState();
}

class _AnnouncementSyncSettingsState extends State<AnnouncementSyncSettings> {
  bool _masterEnabled = true;
  bool _admissionEnabled = true;
  bool _scholarshipEnabled = true;
  bool _placementEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  final _doc = FirebaseFirestore.instance
      .collection('settings')
      .doc('announcement_sync');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final snap = await _doc.get();
      if (snap.exists) {
        final data = snap.data()!;
        setState(() {
          _masterEnabled = data['autoCreateDocuments'] != false;
          _admissionEnabled = data['categories']?['admission'] != false;
          _scholarshipEnabled = data['categories']?['scholarship'] != false;
          _placementEnabled = data['categories']?['placement'] != false;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _doc.set({
        'autoCreateDocuments': _masterEnabled,
        'categories': {
          'admission': _admissionEnabled,
          'scholarship': _scholarshipEnabled,
          'placement': _placementEnabled,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsTile(
          title: 'Auto-create documents from announcements',
          subtitle:
              'When a post is synced, automatically create the matching '
              'admission, scholarship, or placement document.',
          value: _masterEnabled,
          onChanged: (v) => setState(() => _masterEnabled = v),
        ),
        AnimatedOpacity(
          opacity: _masterEnabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_masterEnabled,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  _SettingsTile(
                    title: 'Admissions',
                    subtitle:
                        'CMUCAT, GSAT, ULHSAT schedules and requirements.',
                    value: _admissionEnabled,
                    onChanged: (v) => setState(() => _admissionEnabled = v),
                    isSubItem: true,
                  ),
                  _SettingsTile(
                    title: 'Scholarships',
                    subtitle: 'Eligibility, privileges, and deadlines.',
                    value: _scholarshipEnabled,
                    onChanged: (v) => setState(() => _scholarshipEnabled = v),
                    isSubItem: true,
                  ),
                  _SettingsTile(
                    title: 'Placements',
                    subtitle: 'Partner companies and open positions.',
                    value: _placementEnabled,
                    onChanged: (v) => setState(() => _placementEnabled = v),
                    isSubItem: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveSettings,
            child:
                _isSaving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Save settings'),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isSubItem;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isSubItem = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left:
              isSubItem
                  ? BorderSide(color: Theme.of(context).dividerColor, width: 2)
                  : BorderSide.none,
        ),
        borderRadius: isSubItem ? BorderRadius.zero : BorderRadius.circular(12),
        boxShadow:
            isSubItem
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
