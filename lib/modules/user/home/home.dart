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
                  SliverToBoxAdapter(child: _buildMessageLimitSection()),

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
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (!hasConversation)
              _buildNoMessagesYet(isMobile)
            else
              _buildRealChatMessages(_cachedMessages!, isMobile),
            const SizedBox(height: 12),
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

  Widget _buildMessageLimitSection() {
    final isMobile = _isMobile(context);

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final used = chatProvider.userDailyMessageCount;
        final limit = ChatProvider.MAX_DAILY_MESSAGES;
        final remaining = (limit - used).clamp(0, limit);
        final isLimitReached = remaining == 0;

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
                  color:
                      isLimitReached
                          ? const Color(0xFFFFF1F2)
                          : const Color(0xFF2E7D32).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isLimitReached
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF2E7D32).withOpacity(0.18),
                  ),
                ),
                child: Icon(
                  Icons.message_outlined,
                  color:
                      isLimitReached
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2E7D32),
                  size: isMobile ? 22 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message Limit',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLimitReached
                          ? 'Daily limit reached. Resets at 8:00 AM.'
                          : '$remaining messages remaining today.',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$used/$limit',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color:
                      isLimitReached
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildNoMessagesYet(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: isMobile ? 40 : 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: isMobile ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a conversation with OASP Assist!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade600,
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
    final displayMessages = messages.take(3).toList();

    return Column(
      children:
          displayMessages.reversed.map((message) {
            final isUser = message['sender'] == 'user';
            final content = message['content']?.toString() ?? '';

            if (content.trim().isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildChatBubble(content, isUser, isMobile),
            );
          }).toList(),
    );
  }

  Widget _buildChatBubble(String message, bool isUser, bool isMobile) {
    final displayMessage =
        message.length > 100 ? '${message.substring(0, 100)}...' : message;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
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
          color: isUser ? null : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isUser
                      ? const Color(0xFF2E7D32).withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: MarkdownBody(
          data: displayMessage,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: isUser ? Colors.white : Colors.black87,
              fontSize: isMobile ? 13 : 14,
              height: 1.4,
            ),
            strong: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUser ? Colors.white : Colors.black87,
            ),
          ),
        ),
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
