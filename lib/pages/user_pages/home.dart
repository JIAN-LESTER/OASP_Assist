import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/pages/user_pages/user_main_page.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({Key? key}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Stream controllers for real-time data
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  Stream<QuerySnapshot>? _admissionsStream;
  Stream<QuerySnapshot>? _scholarshipsStream;
  Stream<QuerySnapshot>? _placementsStream;
  Stream<QuerySnapshot>? _announcementsStream;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _initializeStreams();
  }

  void _initializeStreams() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Get latest conversation and its messages
      _messagesStream = FirebaseFirestore.instance
          .collection('conversations')
          .where('userID', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .limit(1)
          .snapshots()
          .asyncMap((conversationSnapshot) async {
            if (conversationSnapshot.docs.isEmpty) {
              return <Map<String, dynamic>>[];
            }

            final conversationId = conversationSnapshot.docs.first.id;
            final messagesSnapshot =
                await FirebaseFirestore.instance
                    .collection('messages')
                    .where('conversationID', isEqualTo: conversationId)
                    .orderBy('sent_at', descending: true)
                    .limit(2)
                    .get();

            return messagesSnapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          });
    }

    // Get latest admissions
    _admissionsStream =
        FirebaseFirestore.instance
            .collection('admissions')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots();

    // Get latest scholarships
    _scholarshipsStream =
        FirebaseFirestore.instance
            .collection('scholarships')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .snapshots();

    // Get latest placements
    _placementsStream =
        FirebaseFirestore.instance
            .collection('placements')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .snapshots();

    // Get latest announcements
    _announcementsStream =
        FirebaseFirestore.instance
            .collection('announcements')
            .where('deleted', isEqualTo: false)
            .orderBy('created_time', descending: true)
            .limit(3)
            .snapshots();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Responsive helper methods
  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1024;
  }

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1980;

  double _getMaxWidth(BuildContext context) {
    if (_isDesktop(context)) return 1400;
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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

                  // AI Chat Assistant - Large Preview at Top
                  SliverToBoxAdapter(child: _buildChatPreviewSection()),

                  // Service Grid (Admission, Scholarship, Placement, Announcements)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile(context) ? 16 : 20,
                      vertical: 8,
                    ),
                    sliver: _buildServicesGrid(),
                  ),

                  // Quick Actions
                  SliverToBoxAdapter(child: _buildQuickActions()),

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
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildHeaderUI('User');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final name = userData['name'] ?? 'User';

        return _buildHeaderUI(name);
      },
    );
  }

  Widget _buildHeaderUI(String name) {
    final isMobile = _isMobile(context);
    final isDesktop = _isDesktop(context);

    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 20),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.white, size: isMobile ? 28 : 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OASP Assist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : (isDesktop ? 28 : 24),
                    fontWeight: FontWeight.bold,
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Welcome, $name!',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 16 : (isDesktop ? 20 : 18),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Access all your academic services in one place',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        return GestureDetector(
          onTap: () => _navigateToTab(context, 1),
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: 8,
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.15),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        color: const Color(0xFF2E7D32),
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
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Text(
                    'Error loading messages',
                    style: TextStyle(fontSize: isMobile ? 12 : 13),
                  )
                else if (!snapshot.hasData || snapshot.data!.isEmpty)
                  _buildNoMessagesYet(isMobile)
                else
                  _buildRealChatMessages(snapshot.data!, isMobile),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _navigateToTab(context, 1),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Open Chat'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoMessagesYet(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No messages yet — start a conversation with OASP Assist!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildRealChatMessages(
    List<Map<String, dynamic>> messages,
    bool isMobile,
  ) {
    return Column(
      children:
          messages.reversed.map((message) {
            final isUser = message['sender'] == 'user';
            final content = message['content'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildChatBubble(content, isUser, isMobile),
            );
          }).toList(),
    );
  }

  Widget _buildChatBubble(String message, bool isUser, bool isMobile) {
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
          color: isUser ? const Color(0xFF2E7D32) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: isMobile ? 13 : 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // Services Grid
  Widget _buildServicesGrid() {
    final isMobile = _isMobile(context);

    return SliverList(
      delegate: SliverChildListDelegate([
        // Row of 3 cards: Admission, Scholarship, Placement
!isMobile
    ? IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // 🔑 makes heights equal
          children: [
            Expanded(child: _buildAdmissionCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildScholarshipCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildPlacementCard()),
          ],
        ),
      )
    : Column(
        children: [
          _buildAdmissionCard(),
          const SizedBox(height: 12),
          _buildScholarshipCard(),
          const SizedBox(height: 12),
          _buildPlacementCard(),
        ],
      ),
        const SizedBox(height: 16),
        // Announcements full width (like chat)
        _buildAnnouncementCard(),
      ]),
    );
  }

  // Admission Card
  Widget _buildAdmissionCard() {
    final isMobile = _isMobile(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _admissionsStream,
      builder: (context, snapshot) {
        List<String> steps = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          steps =
              (data['steps'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .take(6)
                  .toList() ??
              [];
        }

        // Default steps if no data
        if (steps.isEmpty) {
          steps = [
            'Create Account',
            'Fill Personal Information',
            'Upload Documents',
            'Submit Application',
            'Pay Application Fee',
          ];
        }

        return GestureDetector(
          onTap: () => _navigateToTab(context, 3),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withOpacity(0.15),
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
                        color: const Color(0xFF43A047).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.school,
                        color: const Color(0xFF43A047),
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Admission Info',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Application Steps:',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ...steps.map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF43A047),
                            size: isMobile ? 14 : 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _navigateToTab(context, 3),
                    child: const Text('See more →'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF43A047),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Scholarship Card
  Widget _buildScholarshipCard() {
    final isMobile = _isMobile(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _scholarshipsStream,
      builder: (context, snapshot) {
        List<Map<String, dynamic>> scholarships = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          scholarships =
              snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'name': data['name'] ?? 'Unnamed Scholarship',
                  'provider': data['scholarshipProvider'] ?? 'Unknown',
                };
              }).toList();
        }

        // Default scholarships if no data
        if (scholarships.isEmpty) {
          scholarships = [
            {'name': 'Merit-Based Scholarship', 'provider': 'University'},
            {'name': 'Need-Based Financial Aid', 'provider': 'Foundation'},
            {'name': 'Athletic Scholarship', 'provider': 'Sports Dept'},
          ];
        }

        return GestureDetector(
          onTap: () => _navigateToTab(context, 4),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
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
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.card_giftcard,
                        color: const Color(0xFF4CAF50),
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Scholarships',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Available Scholarships:',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ...scholarships.map((scholarship) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: isMobile ? 16 : 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scholarship['name']!,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  scholarship['provider']!,
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 11,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _navigateToTab(context, 4),
                    child: const Text('See more →'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Placement Card
  Widget _buildPlacementCard() {
    final isMobile = _isMobile(context);

    return GestureDetector(
      onTap: () => _navigateToTab(context, 5),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF66BB6A).withOpacity(0.15),
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
                    color: const Color(0xFF66BB6A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.work,
                    color: const Color(0xFF66BB6A),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Placement Assistance',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Upcoming Companies:',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildPlacementItems(isMobile),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _navigateToTab(context, 5),
                child: const Text('See more →'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF66BB6A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlacementItems(bool isMobile) {
    final companies = [
      {'name': 'TechCorp Ltd.', 'positions': '5 positions'},
      {'name': 'InnovateSoft Inc.', 'positions': '3 positions'},
      {'name': 'DataSolutions Co.', 'positions': '7 positions'},
    ];

    return companies.map((company) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF66BB6A).withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.business,
              color: const Color(0xFF66BB6A),
              size: isMobile ? 16 : 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company['name']!,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    company['positions']!,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Announcement Card - Full Width like Chat
  Widget _buildAnnouncementCard() {
    final isMobile = _isMobile(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        List<Map<String, dynamic>> announcements = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          announcements =
              snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                // Get category and determine priority
                String category = data['category']?.toString() ?? 'General';
                String priority = 'low';
                if (category.toLowerCase().contains('urgent') ||
                    category.toLowerCase().contains('important')) {
                  priority = 'high';
                } else if (category.toLowerCase().contains('announcement')) {
                  priority = 'medium';
                }

                // Format date
                String date = 'Recent';
                if (data['created_time'] != null) {
                  try {
                    DateTime createdTime;
                    if (data['created_time'] is Timestamp) {
                      createdTime =
                          (data['created_time'] as Timestamp).toDate();
                    } else if (data['created_time'] is String) {
                      createdTime = DateTime.parse(data['created_time']);
                    } else {
                      createdTime = DateTime.now();
                    }
                    date =
                        '${createdTime.month}/${createdTime.day}/${createdTime.year}';
                  } catch (e) {
                    date = 'Recent';
                  }
                }

                // Get message and truncate for description
                String message =
                    data['message']?.toString() ?? 'No description';
                String title =
                    message.length > 50 ? message.substring(0, 50) : message;
                String description =
                    message.length > 100
                        ? message.substring(0, 100) + '...'
                        : message;

                return {
                  'title': title,
                  'description': description,
                  'date': date,
                  'priority': priority,
                };
              }).toList();
        }

        // Default announcements if no data
        if (announcements.isEmpty) {
          announcements = [
            {
              'title': 'Semester Registration Open',
              'description':
                  'Register for next semester courses. Deadline: March 15',
              'date': 'March 1, 2025',
              'priority': 'high',
            },
            {
              'title': 'Career Fair Next Week',
              'description':
                  'Top companies hiring. Bring your resume and dress professionally.',
              'date': 'March 5, 2025',
              'priority': 'medium',
            },
            {
              'title': 'Library Hours Extended',
              'description': 'Library now open until 11 PM during exam week.',
              'date': 'March 3, 2025',
              'priority': 'low',
            },
          ];
        }

        return GestureDetector(
          onTap: () => _navigateToTab(context, 2),
          child: Container(
            margin: EdgeInsets.only(top: 0, bottom: 0),
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF388E3C).withOpacity(0.15),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF388E3C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.campaign,
                        color: const Color(0xFF388E3C),
                        size: isMobile ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const SizedBox(width: 6),
                          Text(
                            '${announcements.length} new updates',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else
                  ...announcements.map((announcement) {
                    Color priorityColor =
                        announcement['priority'] == 'high'
                            ? Colors.red
                            : announcement['priority'] == 'medium'
                            ? Colors.orange
                            : Colors.blue;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: priorityColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: priorityColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  announcement['title']!,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 15,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                announcement['date']!,
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              announcement['description']!,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _navigateToTab(context, 2),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF388E3C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final isMobile = _isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact & Support',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Contact Us',
                  Icons.phone,
                  const Color(0xFF2E7D32),
                  () => _showContactInfo(context),
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isMobile,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 6 : 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => UserMainPage(initialTabIndex: tabIndex),
      ),
    );
  }

 void _showContactInfo(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: const Color(0xFF2E7D32), size: 26),
            const SizedBox(width: 10),
            Text(
              'Contact Information',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactRow(Icons.access_time, 'Office Hours', '9:00 AM - 5:00 PM'),
            const SizedBox(height: 10),
            _buildContactRow(Icons.phone, 'Phone', '+1-555-0100'),
            const SizedBox(height: 10),
            _buildContactRow(Icons.email_outlined, 'Email', 'info@oasp.edu'),
            const SizedBox(height: 10),
            _buildContactRow(Icons.location_on_outlined, 'Address', '123 Education St, Campus City'),
          ],
        ),
        actionsPadding: const EdgeInsets.only(bottom: 12, right: 16),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildContactRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFF2E7D32), size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

}
