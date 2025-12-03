import 'package:capstone_project/icon_and_color.dart';

import 'package:capstone_project/services/fb_sync.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/pages/admin_pages/widgets/category_dropdown_button.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _cohere = CohereService();

  TokenStatus? _tokenStatus;
  bool _hasCheckedToken = false;

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
    _checkTokenStatus();
    _loadConfiguredApps(); // Add this line

      announcementStream = FirebaseFirestore.instance
      .collection('announcements')
      .where('deleted', isEqualTo: false)
      .orderBy('created_time', descending: true)
      .limit(10)
      .snapshots();

  }

  late final Stream<QuerySnapshot> announcementStream;

  Future<void> _loadConfiguredApps() async {
    setState(() => _isLoadingApps = true);

    try {
      // Use direct Firestore access instead of Cloud Functions
      final doc =
          await FirebaseFirestore.instance
              .collection('fb_app_credentials')
              .doc('apps')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        final apps = <Map<String, dynamic>>[];

        data.forEach((appId, config) {
          if (config is Map && config.containsKey('addedAt')) {
            apps.add({
              'appId': appId,
              'addedAt':
                  (config['addedAt'] as Timestamp?)?.toDate()?.toString() ??
                  'Unknown',
            });
          }
        });

        setState(() {
          _configuredApps = apps;
        });
      } else {
        setState(() {
          _configuredApps = [];
        });
      }
    } catch (e) {
      print('❌ Error loading apps: $e');
    } finally {
      setState(() => _isLoadingApps = false);
    }
  }

  List<Map<String, dynamic>> _configuredApps = [];
  bool _isLoadingApps = false;

  Future<void> loadAnnouncements() async {
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
      SnackbarUtil.showError(context, 'Error loading announcements: $e');
    }
  }

  Future<void> _checkTokenStatus() async {
    try {
      final status = await FacebookSyncService.getTokenStatus();

      if (!mounted) return;

      setState(() {
        _tokenStatus = status;
        _hasCheckedToken = true;
      });
    } catch (e) {
      print('❌ Error checking token status: $e');
    }
  }

  // ✅ NEW: Show token status tooltip with detailed info
  String _getTokenStatusTooltip() {
    if (_tokenStatus == null || !_tokenStatus!.configured) {
      return 'Configure Facebook Token\n(Click to setup)';
    }

    if (_tokenStatus!.expired) {
      return '⚠️ Token Expired!\nClick to renew now';
    }

    final daysLeft = _tokenStatus!.daysLeft ?? 0;

    if (daysLeft <= 7) {
      return '🔴 Token expires in $daysLeft days\nRenew urgently!';
    } else if (daysLeft <= 30) {
      return '🟠 Token expires in $daysLeft days\nConsider renewing soon';
    } else {
      return '✅ Token active ($daysLeft days left)\nClick to view/renew';
    }
  }

  // ✅ NEW: Get status color based on days left
  Color _getTokenStatusColor() {
    if (_tokenStatus == null || !_tokenStatus!.configured) {
      return Colors.grey[400]!;
    }

    if (_tokenStatus!.expired) {
      return Colors.red[700]!;
    }

    final daysLeft = _tokenStatus!.daysLeft ?? 0;

    if (daysLeft <= 7) {
      return Colors.red[700]!;
    } else if (daysLeft <= 30) {
      return Colors.orange[700]!;
    } else {
      return Colors.green[600]!;
    }
  }

  // ✅ NEW: Show detailed status dialog when clicking the indicator
// Add this constant on top (outside the function)
 Color fbBlue = Color(0xFF1877F2);

void _showTokenStatusDialog() {
  if (_tokenStatus == null || !_tokenStatus!.configured) {
    _showTokenInputModal();
    return;
  }

  final daysLeft = _tokenStatus!.daysLeft ?? 0;
  final isUrgent = daysLeft <= 30;
  final isExpired = _tokenStatus!.expired;

  // override the color with FB blue
  final Color statusColor = fbBlue;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // BLUE HEADER ICON BACKGROUND
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: fbBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isExpired
                    ? Icons.error_rounded
                    : isUrgent
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                color: fbBlue,
                size: 46,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              isExpired
                  ? "Token Expired"
                  : isUrgent
                      ? "Token Expiring Soon"
                      : "Token Active",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            Text(
              isExpired
                  ? "Your access token is no longer valid."
                  : "Here are your current token details.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            _buildMinimalStatusTile(
              icon: Icons.hourglass_bottom_rounded,
              label: "Days Remaining",
              value: isExpired ? "Expired" : "$daysLeft days",
              color: fbBlue,
              bold: true,
            ),

            const SizedBox(height: 12),

            _buildMinimalStatusTile(
              icon: Icons.calendar_month_rounded,
              label: "Expiration Date",
              value: _tokenStatus!.expiresAt != null
                  ? DateFormat('MMMM d, yyyy').format(
                      DateTime.fromMillisecondsSinceEpoch(
                        _tokenStatus!.expiresAt!,
                      ),
                    )
                  : "Unknown",
              color: Colors.grey[600]!,
            ),

            if (_tokenStatus!.pageId != null) ...[
              const SizedBox(height: 12),
              _buildMinimalStatusTile(
                icon: Icons.tag_rounded,
                label: "Page ID",
                value: _tokenStatus!.pageId!,
                color: Colors.grey[600]!,
              ),
            ],

            if (isExpired || isUrgent) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fbBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: fbBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired ? Icons.error_outline : Icons.info_outline,
                      color: fbBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isExpired
                            ? "Renew your token to continue system syncing."
                            : "You should renew the token soon to avoid interruption.",
                        style: TextStyle(
                          color: fbBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 26),

            Row(
              children: [
                if (!isExpired && !isUrgent)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                if (!isExpired && !isUrgent) const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showTokenInputModal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fbBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isExpired
                          ? Icons.vpn_key_rounded
                          : Icons.refresh_rounded,
                    ),
                    label: Text(
                      isExpired ? "Renew Now" : "Renew Token",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}


Widget _buildMinimalStatusTile({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
  bool bold = false,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}



  // Manual refresh button (keep as is for manual sync)
  Future<void> _refreshFromFacebook() async {
    if (isRefreshing) {
      print('⚠️ Sync already in progress');
      return;
    }

    setState(() => isRefreshing = true);

    try {
      print('🔄 Manual Facebook sync triggered...');

      final result = await FacebookSyncService.syncPosts();

      if (!mounted) return; // ADDED THIS LINE

      print('📦 Sync result: $result');

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
      print('❌ Sync error: $e');

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

  Future<void> _showTokenInputModal() async {
  final TextEditingController tokenController = TextEditingController();
  final TextEditingController pageIdController = TextEditingController();
  final TextEditingController appIdController = TextEditingController();
  bool isExchanging = false;

  // Load existing Page ID if available
  if (_tokenStatus?.pageId != null) {
    pageIdController.text = _tokenStatus!.pageId!;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ MODERN HEADER with gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1877F2), // Facebook blue
                        Color(0xFF0C63D4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Facebook icon
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.facebook,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Facebook Integration',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Connect your Facebook Page',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                              padding: EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),

                      // ✅ Status Banner (if configured)
                      if (_tokenStatus != null && _tokenStatus!.configured) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _tokenStatus!.expired
                                    ? Icons.error
                                    : _tokenStatus!.needsRenewal
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tokenStatus!.expired
                                          ? 'Token Expired'
                                          : _tokenStatus!.needsRenewal
                                              ? 'Token Expiring Soon'
                                              : 'Token Active',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      _tokenStatus!.expired
                                          ? 'Renew your token to continue syncing'
                                          : 'Expires in ${_tokenStatus!.daysLeft} days',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ✅ SCROLLABLE CONTENT
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ INSTRUCTIONS SECTION - Enhanced design
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade50,
                                Colors.blue.shade50,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade100,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'SETUP INSTRUCTIONS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInstructionStep(
                                '1',
                                'Visit developers.facebook.com and log in',
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionStep(
                                '2',
                                'Click "My Apps" → "Create App"',
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionStep(
                                '3',
                                'Choose "Manage everything on your Page" as the use case, and select "Business" as the App Type.',
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionStep(
                                '4',
                                'In the right sidebar, open "Use Cases" and select your created app and enable required permissions',
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionStep(
                                '5',
                                'Go to Tools → Graph API Explorer → Select your app and check the same permissions',
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionStep(
                                '6',
                                'Generate and copy your Access Token',
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionStep(
                                '7',
                                'Page ID: Go to your Facebook Page → About → Page transparency → Page ID. App ID: Find it in your Facebook App dashboard (optional but recommended).',
                              ),

                              const SizedBox(height: 16),

                              // ✅ Required Permissions - Enhanced
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          size: 18,
                                          color: Colors.green.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Required Permissions',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'pages_read_engagement, pages_manage_posts, pages_show_list, pages_read_user_content, pages_manage_metadata',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        height: 1.6,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ✅ APP ID INPUT - Enhanced
                        _buildInputLabel('Facebook App ID', Icons.apps, isOptional: true),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: appIdController,
                          hintText: 'Enter your Facebook App ID',
                          icon: Icons.apps,
                          enabled: !isExchanging,
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 20),

                        // ✅ PAGE ID INPUT - Enhanced
                        _buildInputLabel('Facebook Page ID', Icons.tag, isRequired: true),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: pageIdController,
                          hintText: 'e.g., 730995450096065',
                          icon: Icons.tag,
                          enabled: !isExchanging,
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 20),

                        // ✅ ACCESS TOKEN INPUT - Enhanced
                        _buildInputLabel('Access Token', Icons.key, isRequired: true),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: tokenController,
                          hintText: 'Paste your Facebook access token here...',
                          icon: Icons.key,
                          enabled: !isExchanging,
                          maxLines: 3,
                        ),

                        const SizedBox(height: 12),

                        // ✅ Paste Button - Enhanced
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isExchanging
                                ? null
                                : () async {
                                    final data = await Clipboard.getData('text/plain');
                                    if (data?.text != null) {
                                      tokenController.text = data!.text!;
                                      SnackbarUtil.showSuccess(
                                        context,
                                        '✅ Token pasted from clipboard',
                                      );
                                    }
                                  },
                            icon: Icon(Icons.content_paste_rounded, size: 20),
                            label: Text(
                              'Paste from Clipboard',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF1877F2),
                              side: BorderSide(
                                color: isExchanging
                                    ? Colors.grey.shade300
                                    : Color(0xFF1877F2),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ✅ ACTION BUTTONS - Enhanced
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isExchanging ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: isExchanging
                                    ? null
                                    : () async {
                                        final token = tokenController.text.trim();
                                        final pageId = pageIdController.text.trim();
                                        final appId = appIdController.text.trim();

                                        // Validation
                                        if (pageId.isEmpty) {
                                          SnackbarUtil.showError(
                                            context,
                                            'Please enter your Facebook Page ID',
                                          );
                                          return;
                                        }

                                        if (!RegExp(r'^\d+$').hasMatch(pageId)) {
                                          SnackbarUtil.showError(
                                            context,
                                            'Page ID should only contain numbers',
                                          );
                                          return;
                                        }

                                        if (appId.isNotEmpty && !RegExp(r'^\d+$').hasMatch(appId)) {
                                          SnackbarUtil.showError(
                                            context,
                                            'App ID should only contain numbers',
                                          );
                                          return;
                                        }

                                        if (token.isEmpty) {
                                          SnackbarUtil.showError(context, 'Please enter a token');
                                          return;
                                        }

                                        if (token.length < 50) {
                                          SnackbarUtil.showError(context, 'Token seems too short');
                                          return;
                                        }

                                        setDialogState(() => isExchanging = true);

                                        try {
                                          print('🔄 Exchanging token with Page ID: $pageId');
                                          if (appId.isNotEmpty) {
                                            print('📱 Using App ID: $appId');
                                          }

                                          final result = await FacebookSyncService.exchangeToken(
                                            token,
                                            pageId: pageId,
                                            appId: appId.isNotEmpty ? appId : null,
                                          );

                                          if (!context.mounted) return;

                                          if (result['success'] == true || result['ok'] == true) {
                                            final expiresIn = result['expires_in'] ?? 0;
                                            final daysValid = (expiresIn / 86400).round();
                                            final appUsed = result['appId'] ?? appId;

                                            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                                            Navigator.pop(context);

                                            String successMessage =
                                                'Token and Page ID saved! Valid for ~$daysValid days.';
                                            if (appUsed != null && appUsed.isNotEmpty) {
                                              successMessage += '\nUsing App ID: $appUsed';
                                            }

                                            SnackbarUtil.showSuccess(context, successMessage);
                                            await _checkTokenStatus();
                                            await _autoSyncAfterTokenSave();
                                            return;
                                          }

                                          throw Exception(result['message'] ?? result['error']);
                                        } catch (e) {
                                          print('❌ Error: $e');
                                          if (!context.mounted) return;
                                          setDialogState(() => isExchanging = false);
                                          final errorMessage =
                                              FacebookSyncService.parseErrorMessage(e);
                                          SnackbarUtil.showError(
                                            context,
                                            'Failed to save: $errorMessage',
                                          );
                                        }
                                      },
                                icon: isExchanging
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.check_circle, size: 22),
                                label: Text(
                                  isExchanging ? 'Saving...' : 'Save & Connect',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:  Colors.blue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade400,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ✅ HELPER: Enhanced instruction step
Widget _buildInstructionStep(String number, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade500, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ],
  );
}

// ✅ HELPER: Enhanced input label
Widget _buildInputLabel(String label, IconData icon, {bool isRequired = false, bool isOptional = false}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: Colors.grey[600]),
      SizedBox(width: 6),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
      if (isRequired) ...[
        SizedBox(width: 4),
        Text(
          '*',
          style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
      if (isOptional) ...[
        SizedBox(width: 6),
        Text(
          '(Optional)',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ],
  );
}

// ✅ HELPER: Enhanced text field
Widget _buildTextField({
  required TextEditingController controller,
  required String hintText,
  required IconData icon,
  required bool enabled,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.grey[900],
    ),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFF1877F2), width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
      ),
      filled: true,
      fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: maxLines > 1 ? 14 : 16,
      ),
    ),
  );
}
  
  // 🎯 NEW: Auto-sync after token is saved
  Future<void> _autoSyncAfterTokenSave() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Syncing Facebook posts...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      print('🔄 Starting auto-sync after token save...');

      final result = await FacebookSyncService.syncPosts();

      if (!mounted) return; // ADDED THIS LINE

      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final count = result['count'] ?? 0;
        final failed = result['failed'] ?? 0;

        print('✅ Auto-sync completed: $count posts synced');

        // Reload announcements
        await loadAnnouncements();

        // Show success message
        _showSuccessSnackBar(
          'Successfully synced $count posts!${failed > 0 ? ' ($failed failed)' : ''}',
        );
      } else {
        throw Exception(result['error'] ?? result['message'] ?? 'Sync failed');
      }
    } catch (e) {
      if (!mounted) return; // ADDED THIS LINE

      Navigator.pop(context); // Close loading dialog

      print('❌ Auto-sync failed: $e');

      final errorMessage = FacebookSyncService.parseErrorMessage(e);

      // Show error with retry option
      _showSyncErrorDialog(errorMessage);
    }
  }

  // Show error dialog with retry option
  void _showSyncErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red[700], size: 28),
                SizedBox(width: 12),
                Text('Sync Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage, style: TextStyle(fontSize: 15)),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can manually sync later using the refresh button',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _refreshFromFacebook(); // Trigger manual sync
                },
                icon: Icon(Icons.refresh),
                label: Text('Retry Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  // Helper methods for snackbars
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
            child: Stack(
              children: [
                Column(
                  children: [
                    // header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 1100),
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
                                      (value) => setState(
                                        () => selectedCategory = value,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Content area - Takes remaining space
                    Expanded(child: _buildMainContent(isDesktop: true)),
                  ],
                ),
                // Refresh button positioned at top right edge
                Positioned(
                  top: 24,
                  right: 32,
                  child: _buildRefreshButton(isDesktop: true),
                ),
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
                const SizedBox(width: 12),
                _buildRefreshButton(isDesktop: false),
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
                Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    const SizedBox(width: 12),
                    _buildRefreshButton(isDesktop: false),
                  ],
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

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.5 + (value * 0.5), // Pulse between 0.5 and 1.0
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Rebuild to restart animation
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // Replace the _buildRefreshButton method with this improved version:

  Widget _buildRefreshButton({required bool isDesktop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
                    onTap: _showAppCredentialsDialog,
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

            // Badge showing number of configured apps
            if (_configuredApps.isNotEmpty)
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
                      '${_configuredApps.length}',
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

        SizedBox(height: 12),

        // Token Status Indicator
        Stack(
          clipBehavior: Clip.none,
          children: [
            Tooltip(
              message: _getTokenStatusTooltip(),
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
                      if (_tokenStatus?.needsRenewal == true ||
                          _tokenStatus?.expired == true) {
                        _showTokenStatusDialog();
                      } else {
                        _showTokenInputModal();
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

            if (_hasCheckedToken && _tokenStatus?.configured == true)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: _showTokenStatusDialog,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _getTokenStatusColor(),
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
                        _tokenStatus!.daysLeft != null &&
                                _tokenStatus!.daysLeft! <= 7
                            ? _buildPulsingDot()
                            : null,
                  ),
                ),
              ),
          ],
        ),

        SizedBox(height: 12),

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

  // Also replace the _showAppCredentialsDialog method with this improved version:

  Future<void> _showAppCredentialsDialog() async {
  await _loadConfiguredApps();
  
  final TextEditingController appIdController = TextEditingController();
  final TextEditingController appSecretController = TextEditingController();
  
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FACEBOOK BLUE Gradient Header
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1877F2), Color(0xFF0C63D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF1877F2).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.apps_rounded, color: Colors.white, size: 32),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Facebook App Manager',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Configure multiple Facebook apps for seamless integration',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          padding: EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content with BLUE theme
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Banner (BLUE themed)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFE7F3FF), Color(0xFFD0E8FF).withOpacity(0.3)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFFB3D9FF), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1877F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.info_outline, color: Colors.white, size: 22),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Add multiple Facebook apps for token exchange. The system will automatically select the appropriate app for authentication.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0C4A8E),
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 28),
                        
                        // Add New App Section Header
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(0xFF1877F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ADD NEW APP',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        // App ID Input
                        TextField(
                          controller: appIdController,
                          decoration: InputDecoration(
                            labelText: 'App ID',
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            hintText: 'e.g., 776960582033609',
                            prefixIcon: Container(
                              margin: EdgeInsets.all(12),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFFE7F3FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.tag, color: Color(0xFF1877F2), size: 20),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Color(0xFF1877F2), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // App Secret Input
                        TextField(
                          controller: appSecretController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'App Secret',
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            hintText: 'Enter your app secret',
                            prefixIcon: Container(
                              margin: EdgeInsets.all(12),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFFE7F3FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.vpn_key, color: Color(0xFF1877F2), size: 20),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Color(0xFF1877F2), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // BLUE Add Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingApps ? null : () async {
                              final appId = appIdController.text.trim();
                              final appSecret = appSecretController.text.trim();
                              
                              if (appId.isEmpty || appSecret.isEmpty) {
                                SnackbarUtil.showError(context, 'Please enter both App ID and App Secret');
                                return;
                              }
                              
                              setDialogState(() => _isLoadingApps = true);
                              
                              try {
                                await FirebaseFirestore.instance
                                    .collection('fb_app_credentials')
                                    .doc('apps')
                                    .set({
                                  appId: {
                                    'appSecret': appSecret,
                                    'addedAt': FieldValue.serverTimestamp(),
                                  }
                                }, SetOptions(merge: true));
                                
                                appIdController.clear();
                                appSecretController.clear();
                                
                                await _loadConfiguredApps();
                                setDialogState(() {});
                                
                                SnackbarUtil.showSuccess(context, '✅ App added successfully!');
                              } catch (e) {
                                SnackbarUtil.showError(context, 'Error: $e');
                              } finally {
                                setDialogState(() => _isLoadingApps = false);
                              }
                            },
                            icon: _isLoadingApps 
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.add_circle_outline, size: 22),
                            label: Text(
                              _isLoadingApps ? 'Adding App...' : 'Add App',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1877F2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 32),
                        
                        // Configured Apps Section Header
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(0xFF1877F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.apps, color: Colors.white, size: 16),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'CONFIGURED APPS (${_configuredApps.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        if (_isLoadingApps)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
                              ),
                            ),
                          )
                        else if (_configuredApps.isEmpty)
                          Container(
                            padding: EdgeInsets.all(48),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!, width: 2),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.apps, size: 56, color: Colors.grey[400]),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No apps configured yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add your first Facebook app to get started',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._configuredApps.map((app) => Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.grey[50]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF1877F2), Color(0xFF0C63D4)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.apps, color: Colors.white, size: 24),
                              ),
                              title: Text(
                                app['appId'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                ),
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                    SizedBox(width: 6),
                                    Text(
                                      'Added: ${app['addedAt'] ?? 'Unknown'}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_rounded, color: Colors.red[600], size: 22),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red[50],
                                  padding: EdgeInsets.all(10),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(Icons.warning_rounded, color: Colors.orange[700]),
                                          SizedBox(width: 12),
                                          Text('Remove App'),
                                        ],
                                      ),
                                      content: Text('Are you sure you want to remove ${app['appId']}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('fb_app_credentials')
                                                  .doc('apps')
                                                  .update({
                                                app['appId']: FieldValue.delete(),
                                              });
                                              
                                              await _loadConfiguredApps();
                                              setDialogState(() {});
                                              
                                              SnackbarUtil.showSuccess(context, '✅ App removed successfully');
                                            } catch (e) {
                                              SnackbarUtil.showError(context, 'Error: $e');
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700],
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('announcements')
              .where('deleted', isEqualTo: false)
              .orderBy('created_time', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        // Loading state
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

        // Error state
        if (snapshot.hasError) {
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
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Error loading announcements',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Filter announcements based on search and category
        final allAnnouncements = snapshot.data?.docs ?? [];
        final displayedAnnouncements = _filterAnnouncementsFromDocs(
          allAnnouncements,
        );

        // Empty state
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

        // List view
        return RefreshIndicator(
          onRefresh: _refreshFromFacebook,
          color: Colors.green[600],
          child: ListView.builder(
            padding:
                isDesktop
                    ? const EdgeInsets.fromLTRB(32, 0, 32, 32)
                    : EdgeInsets.zero,
            itemCount: displayedAnnouncements.length,
            itemBuilder: (context, index) {
              return Center(
                child: Container(
                  constraints:
                      isDesktop ? const BoxConstraints(maxWidth: 1100) : null,
                  padding: EdgeInsets.only(bottom: isDesktop ? 24 : 16),
                  child: AnnouncementCard(
                    announcement: displayedAnnouncements[index],
                    index: index,
                    isDesktop: isDesktop,
                    onEdit: _editAnnouncement,
                    onDelete: _deleteAnnouncement,
                  ),
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
    var filtered =
        docs.where((doc) {
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
                   announcementStream,
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

  Future<void> _editAnnouncement(DocumentSnapshot announcement) async {
    final data = announcement.data() as Map<String, dynamic>;
    final messageController = TextEditingController(
      text: data['message'] ?? '',
    );
    final categoryController = TextEditingController(
      text: data['category'] ?? 'General',
    );
    final d = data['deadline'];
    String deadlineText = '';

    if (d is Timestamp) {
      deadlineText = DateFormat('yyyy-MM-dd').format(d.toDate());
    } else if (d is String) {
      deadlineText = d;
    }

    final deadlineController = TextEditingController(text: deadlineText);

    String selectedCategory = data['category'] ?? 'General';
    bool isLoading = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Announcement',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 600;
            final isTablet = screenWidth >= 600 && screenWidth < 1024;
            final isDesktop = screenWidth >= 1024;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 750,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.edit_document,
                                color: Colors.white,
                                size: isMobile ? 24 : 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Announcement',
                                    style: TextStyle(
                                      fontSize: isMobile ? 20 : 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update announcement information',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 20 : 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Message Section
                              buildSectionHeader(
                                'Message Content',
                                Icons.message_outlined,
                              ),
                              const SizedBox(height: 16),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 16,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Message *',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1E293B),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: messageController,
                                    maxLines: 5,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF334155),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter announcement message...',
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2E7D32),
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Category & Deadline Section
                              buildSectionHeader(
                                'Classification',
                                Icons.category_outlined,
                              ),
                              const SizedBox(height: 16),

                              // Category Dropdown
                              _buildDropdownField(
                                label: "Category",
                                value: selectedCategory,
                                items: [
                                  'General',
                                  'Admission',
                                  'Scholarship',
                                  'Placement',
                                  'Event',
                                ],
                                onChanged: (String? newValue) {
                                  setDialogState(() {
                                    selectedCategory = newValue ?? 'General';
                                    categoryController.text = selectedCategory;
                                  });
                                },
                                icon: Icons.label_outline,
                                isEnabled: true,
                              ),

                              const SizedBox(height: 16),

                              // Deadline Field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 16,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Deadline (optional)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1E293B),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: deadlineController,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF334155),
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'e.g., December 15, 2024 or Next Friday',
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2E7D32),
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Action Buttons
                              _buildActionButtons(
                                context,
                                isMobile,
                                isTablet,
                                isDesktop,
                                isLoading,
                                messageController,
                                selectedCategory,
                                deadlineController,
                                announcement,
                                setDialogState,
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
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    bool isLoading,
    TextEditingController messageController,
    String selectedCategory,
    TextEditingController deadlineController,
    DocumentSnapshot announcement,
    StateSetter setDialogState,
  ) {
    double buttonHeight =
        isMobile
            ? 40
            : isTablet
            ? 44
            : 46;
    double fontSize = isMobile ? 14 : 15;
    double borderRadius = 10;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton.icon(
              onPressed:
                  isLoading
                      ? null
                      : () async {
                        if (messageController.text.trim().isEmpty) {
                          SnackbarUtil.showError(
                            context,
                            'Message cannot be empty',
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        try {
                          await FirebaseFirestore.instance
                              .collection('announcements')
                              .doc(announcement.id)
                              .update({
                                'message': messageController.text.trim(),
                                'category': selectedCategory,
                                'deadline':
                                    deadlineController.text.trim().isEmpty
                                        ? null
                                        : Timestamp.fromDate(
                                          DateTime.parse(
                                            deadlineController.text.trim(),
                                          ),
                                        ),
                                'updated_at': FieldValue.serverTimestamp(),
                              });

                          if (!context.mounted) return; // ADDED THIS LINE

                          Navigator.pop(context);
                          await loadAnnouncements();

                          SnackbarUtil.showSuccess(
                            context,
                            'Announcement updated successfully',
                          );
                        } catch (e) {
                          if (!context.mounted) return; //  ADDED THIS LINE

                          setDialogState(() => isLoading = false);
                          SnackbarUtil.showError(
                            context,
                            'Error updating announcement: $e',
                          );
                        }
                      },
              icon:
                  isLoading
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                isLoading ? 'Saving...' : 'Save Changes',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required IconData icon,
    bool isEnabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isEnabled ? const Color(0xFF2E7D32) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isEnabled
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF9CA3AF),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: isEnabled ? onChanged : null,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color:
                isEnabled ? const Color(0xFF334155) : const Color(0xFF9CA3AF),
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
            filled: true,
            fillColor:
                isEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items:
              items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      Icon(
                        getCategoryIcon(value),
                        size: 16,
                        color: getColorForCategory(value),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isEnabled
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
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

class AnnouncementCard extends StatefulWidget {
  final DocumentSnapshot announcement;
  final int index;
  final bool isDesktop;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.index,
    required this.isDesktop,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _isMessageExpanded = false; // ✅ NEW: Track message expansion state

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

    List<String> images = [];

    if (data['images'] != null && data['images'] is List) {
      images =
          (data['images'] as List)
              .map((item) {
                if (item is String) return item;
                if (item is Map && item.containsKey('url'))
                  return item['url'].toString();
                return '';
              })
              .where((url) => url.isNotEmpty && url.startsWith('http'))
              .toList();
    }

    if (images.isEmpty &&
        data['full_picture'] != null &&
        (data['full_picture'] as String).isNotEmpty &&
        (data['full_picture'] as String).startsWith('http')) {
      images = [data['full_picture'] as String];
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
          if (message.isNotEmpty) _buildMessage(message),
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
                child: Image.network(
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
          Image.network(
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

  Widget _buildImageCarousel(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showFullScreenImage(context, images, index),
              child: Image.network(
                images[index],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain, // ✅ Changed from cover to contain
                errorBuilder:
                    (context, error, stackTrace) => _buildImageError(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImageLoading(loadingProgress);
                },
              ),
            );
          },
        ),

        if (images.length > 1) ...[
          _buildNavigationArrow(
            alignment: Alignment.centerLeft,
            icon: Icons.chevron_left,
            onTap: () {
              if (_currentImageIndex > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            enabled: _currentImageIndex > 0,
          ),
          _buildNavigationArrow(
            alignment: Alignment.centerRight,
            icon: Icons.chevron_right,
            onTap: () {
              if (_currentImageIndex < images.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            enabled: _currentImageIndex < images.length - 1,
          ),
        ],

        if (images.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_currentImageIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          top: 12,
          left: 12,
          child: _buildFullscreenButton(images, _currentImageIndex),
        ),
      ],
    );
  }

  Widget _buildNavigationArrow({
    required AlignmentGeometry alignment,
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    if (!enabled) return const SizedBox.shrink();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

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

  // ✅ NEW: Message widget with See More/Less functionality
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
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.edit_rounded,
            onTap: () => widget.onEdit(widget.announcement),
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.delete_rounded,
            onTap: () => widget.onDelete(widget.announcement),
            color: Colors.red,
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

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

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
// ✅ UPDATED: Full Screen Image Gallery with Navigation Arrows
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

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
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
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
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
                    widget.images[index],
                    fit: BoxFit.contain,
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

          // ✅ NEW: Navigation arrows in fullscreen
          if (widget.images.length > 1) ...[
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
                if (_currentIndex < widget.images.length - 1) {
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
          if (widget.images.length > 1)
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
                      '${_currentIndex + 1} / ${widget.images.length}',
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

  //  NEW: Navigation arrow for fullscreen mode
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
