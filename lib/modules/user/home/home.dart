import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/modules/user/user_main_page.dart';
import 'package:capstone_project/provider/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../../authentication/app_distribution_qr_button.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({Key? key}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Cached data for faster subsequent loads
  Map<String, dynamic>? _cachedUserData;
  List<Map<String, dynamic>>? _cachedMessages;

  // Loading states for progressive rendering
  bool _userDataLoaded = false;
  bool _messagesLoaded = false;

  String? _currentConversationId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Start batch loading immediately
    _batchLoadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadUserMessageCount();
      chatProvider.listenToUserMessageCount();
    });
  }

  Future<void> _batchLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _loadCriticalData(user);
  }

  // Load critical data first (user info + chat)
  Future<void> _loadCriticalData(User user) async {
    try {
      // Load user data and messages in parallel
      await Future.wait([_loadUserData(user.uid), _loadMessages(user.uid)]);
    } catch (e) {
      debugPrint('Error loading critical data: $e');
    }
  }

  // Load user data
  Future<void> _loadUserData(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (mounted) {
        setState(() {
          _cachedUserData = doc.exists ? doc.data() : null;
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _userDataLoaded = true);
    }
  }

  // Load messages
  Future<void> _loadMessages(String uid) async {
    try {
      final conversationSnapshot =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (conversationSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _cachedMessages = [];
            _messagesLoaded = true;
          });
        }
        return;
      }

      final conversationId = conversationSnapshot.docs.first.id;
      _currentConversationId = conversationId;

      final messagesSnapshot =
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .orderBy('sent_at', descending: true)
              .limit(4)
              .get();

      if (mounted) {
        setState(() {
          _cachedMessages =
              messagesSnapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
          _messagesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _cachedMessages = [];
          _messagesLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Responsive helper methods
  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1980;
  double _getMaxWidth(BuildContext context) {
    if (_isDesktop(context)) return 1400;
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF0F7),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(context)),
              child: CustomScrollView(
                slivers: [
                  // Welcome Header
                  SliverToBoxAdapter(child: _buildWelcomeHeader()),
                  SliverToBoxAdapter(child: _buildDownloadMobileAppSection()),

                  // AI Chat Assistant
                  SliverToBoxAdapter(child: _buildChatPreviewSection()),
                  SliverToBoxAdapter(child: _buildAnnouncementsPreviewSection()),

                  // Bottom spacing
                  SliverToBoxAdapter(
                    child: SizedBox(height: _isMobile(context) ? 20 : 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    if (!_userDataLoaded) {
      return _buildHeaderLoadingSkeleton();
    }

    final name = _cachedUserData?['name'] ?? 'User';
    return _buildHeaderUI(name);
  }

  Widget _buildDownloadMobileAppSection() {
    final isMobile = _isMobile(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: 8,
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E7D32).withOpacity(0.18),
              ),
            ),
            child: Icon(
              Icons.phone_android,
              color: const Color(0xFF2E7D32),
              size: isMobile ? 22 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Mobile App',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Install the mobile application.',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const AppDistributionQrButton(
            positioned: false,
            requireLoginForEmail: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLoadingSkeleton() {
    final isMobile = _isMobile(context);
    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 20),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.white, size: isMobile ? 28 : 32),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Container(
            height: 20,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderUI(String name) {
    final isMobile = _isMobile(context);
    final isDesktop = _isDesktop(context);

    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 20),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.40),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Icon(
                  Icons.school,
                  color: Colors.white,
                  size: isMobile ? 24 : 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OASP Assist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : (isDesktop ? 28 : 24),
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF69F0AE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 18),
          Divider(color: Colors.white.withOpacity(0.20), height: 1),
          SizedBox(height: isMobile ? 14 : 18),
          Text(
            'Welcome back, $name!',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 17 : (isDesktop ? 21 : 19),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Text(
            'Access all your academic services in one place.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: isMobile ? 13 : (isDesktop ? 15 : 14),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreviewSection() {
    final isMobile = _isMobile(context);

    if (!_messagesLoaded) {
      return _buildChatLoadingSkeleton(isMobile);
    }

    final hasConversation =
        _cachedMessages != null && _cachedMessages!.isNotEmpty;

    return GestureDetector(
      onTap: () => _navigateToChatTab(context, hasConversation),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: 10,
        ),
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Chat Assistant',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildMessageLimitSummary(isMobile),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            _buildChatMessagesPreview(
              hasConversation: hasConversation,
              isMobile: isMobile,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _navigateToChatTab(context, hasConversation),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(hasConversation ? 'Continue Chat' : 'Start Chat'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageLimitSummary(bool isMobile) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final used = chatProvider.userDailyMessageCount;
        final limit = ChatProvider.MAX_DAILY_MESSAGES;
        final remaining = (limit - used).clamp(0, limit);
        final isLimitReached = remaining == 0;
        final progress =
            limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0).toDouble();

        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color:
                isLimitReached
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isLimitReached
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFBBF7D0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.message_outlined,
                    color:
                        isLimitReached
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2E7D32),
                    size: isMobile ? 18 : 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLimitReached
                          ? 'Daily message limit reached'
                          : '$remaining messages remaining today',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isLimitReached
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                      ),
                    ),
                  ),
                  Text(
                    '$used/$limit',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color:
                          isLimitReached
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.85),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isLimitReached
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isLimitReached
                    ? 'Your limit resets at 8:00 AM.'
                    : 'Limit resets daily at 8:00 AM.',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color:
                      isLimitReached
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsPreviewSection() {
    final isMobile = _isMobile(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 8),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.campaign_outlined,
            title: 'Latest Announcements',
            subtitle: 'Recent updates from OASP.',
            color: const Color(0xFF2563EB),
            isMobile: isMobile,
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('announcements')
                    .where('deleted', isEqualTo: false)
                    .orderBy('created_time', descending: true)
                    .limit(3)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildAnnouncementsSkeleton(isMobile);
              }

              final announcements = snapshot.data?.docs ?? [];
              if (announcements.isEmpty) {
                return _buildNoAnnouncementsYet(isMobile);
              }

              return Column(
                children:
                    announcements
                        .map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildAnnouncementPreviewItem(
                              doc,
                              isMobile,
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
          const SizedBox(height: 6),
          _buildCardAction(
            label: 'View Announcements',
            color: const Color(0xFF2563EB),
            onPressed: () => _navigateToTab(context, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildChatLoadingSkeleton(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 8),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          _buildSkeletonLine(width: double.infinity, height: 44),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _buildSkeletonLine(
              width: isMobile ? 170 : 220,
              height: 44,
            ),
          ),
          const SizedBox(height: 8),
          _buildSkeletonLine(width: isMobile ? 140 : 180, height: 34),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildAnnouncementsSkeleton(bool isMobile) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8),
          child: Row(
            children: [
              _buildSkeletonLine(width: isMobile ? 36 : 40, height: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonLine(width: double.infinity, height: 14),
                    const SizedBox(height: 6),
                    _buildSkeletonLine(
                      width: isMobile ? 130 : 180,
                      height: 12,
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

  Widget _buildNoAnnouncementsYet(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 18 : 20,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: isMobile ? 34 : 40,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            'No announcements yet',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementPreviewItem(DocumentSnapshot doc, bool isMobile) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final category = data['category']?.toString() ?? 'General';
    final message = data['message']?.toString() ?? 'No message';
    final timeText =
        data['created_time'] is Timestamp
            ? formatTime(data['created_time'] as Timestamp)
            : '';
    final categoryColor = getCategoryColor(category);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _navigateToTab(context, 2),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 36 : 40,
              height: isMobile ? 36 : 40,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                getCategoryIcon(category),
                color: categoryColor,
                size: isMobile ? 18 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: categoryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (timeText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessagesPreview({
    required bool hasConversation,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasConversation ? 'Recent conversation' : 'Start a chat',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              if (hasConversation)
                Text(
                  '${_cachedMessages!.length.clamp(0, 4)} shown',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasConversation)
            _buildNoMessagesYet(isMobile)
          else
            _buildRealChatMessages(_cachedMessages!, isMobile),
        ],
      ),
    );
  }

  Widget _buildNoMessagesYet(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 18 : 20,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: isMobile ? 44 : 50,
            height: isMobile ? 44 : 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: isMobile ? 24 : 28,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ask OASP Assist anything',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your latest messages will appear here once you start a conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              height: 1.35,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealChatMessages(
    List<Map<String, dynamic>> messages,
    bool isMobile,
  ) {
    final displayMessages =
        messages
            .where((message) {
              final content = message['content']?.toString() ?? '';
              return content.trim().isNotEmpty;
            })
            .take(4)
            .toList();

    return Column(
      children:
          displayMessages.reversed.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
            final isUser = _isUserMessage(message);
            final content = message['content']?.toString() ?? '';

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == displayMessages.length - 1 ? 0 : 10,
              ),
              child: _buildChatBubble(content, isUser, isMobile),
            );
          }).toList(),
    );
  }

  bool _isUserMessage(Map<String, dynamic> message) {
    final sender = message['sender']?.toString().toLowerCase() ?? '';
    return sender == 'user' || sender == 'student';
  }

  Widget _buildChatBubble(String message, bool isUser, bool isMobile) {
    final cleanedMessage = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    final maxLength = isMobile ? 120 : 170;
    final displayMessage =
        cleanedMessage.length > maxLength
            ? '${cleanedMessage.substring(0, maxLength)}...'
            : cleanedMessage;

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          _buildMessageAvatar(isUser, isMobile),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: isMobile ? 280 : 520),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 14,
              vertical: isMobile ? 10 : 12,
            ),
            decoration: BoxDecoration(
              gradient:
                  isUser
                      ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                      )
                      : null,
              color: isUser ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 5),
                bottomRight: Radius.circular(isUser ? 5 : 16),
              ),
              border:
                  isUser
                      ? null
                      : Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color:
                      isUser
                          ? const Color(0xFF2E7D32).withOpacity(0.18)
                          : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'OASP Assist',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    color:
                        isUser
                            ? Colors.white.withOpacity(0.78)
                            : const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                MarkdownBody(
                  data: displayMessage,
                  selectable: false,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                      fontSize: isMobile ? 12 : 13,
                      height: 1.35,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUser ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          _buildMessageAvatar(isUser, isMobile),
        ],
      ],
    );
  }

  Widget _buildMessageAvatar(bool isUser, bool isMobile) {
    return Container(
      width: isMobile ? 28 : 32,
      height: isMobile ? 28 : 32,
      decoration: BoxDecoration(
        color:
            isUser
                ? const Color(0xFF2E7D32).withOpacity(0.12)
                : const Color(0xFFEFF6FF),
        shape: BoxShape.circle,
        border: Border.all(
          color:
              isUser
                  ? const Color(0xFF2E7D32).withOpacity(0.24)
                  : const Color(0xFFBFDBFE),
        ),
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.smart_toy_outlined,
        size: isMobile ? 15 : 17,
        color:
            isUser
                ? const Color(0xFF2E7D32)
                : const Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildHomeCard({
    required Widget child,
    required Color accentColor,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(color: accentColor.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isMobile,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Icon(icon, color: color, size: isMobile ? 22 : 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: const Color(0xFF64748B),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 28 : 30,
            height: isMobile ? 28 : 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isMobile ? 16 : 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAction({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: color,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCardSkeleton(bool isMobile, String title, IconData icon) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.grey[400],
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 16,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                UserMainPage(initialTabIndex: tabIndex),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _navigateToChatTab(BuildContext context, bool hasConversation) {
    if (hasConversation && _currentConversationId != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) => UserMainPage(
                initialTabIndex: 1,
                conversationId: _currentConversationId,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  UserMainPage(initialTabIndex: 1),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }
}
