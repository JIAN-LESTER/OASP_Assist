import 'dart:convert';

import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/pages/admin_pages/testAnnouncement.dart';
import 'package:capstone_project/services/fb_sync.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading announcements: $e')),
      );
    }
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

      print('📦 Sync result: $result');

      if (result['success'] == true) {
        await Future.delayed(Duration(milliseconds: 500));
        await loadAnnouncements();

        final count = result['count'] ?? 0;
        final failed = result['failed'] ?? 0;

        if (mounted) {
          _showSuccessSnackBar(
            '✅ Synced $count posts' + (failed > 0 ? ' ($failed failed)' : ''),
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
    bool isExchanging = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
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
                                'Facebook Integration',
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
                              // Instructions Section
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
                                      'SETUP INSTRUCTIONS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[500],
                                        letterSpacing: 0.5,
                                      ),
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
                                      'In the left sidebar, open “Use Cases” and select your created app and enable required permissions in Use Cases',
                                    ),
                                    const SizedBox(height: 12),

                                    _buildInstructionStep(
                                      '5',
                                      'Go to Tools → Graph API Explorer → Select your app and check the same permissions.',
                                    ),
                                    const SizedBox(height: 12),

                                    _buildInstructionStep(
                                      '6',
                                      'Generate and copy your Access Token',
                                    ),

                                    const SizedBox(height: 16),

                                    // Required Permissions
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle_outline,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Required Permissions',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'pages_read_engagement, pages_manage_posts, pages_show_list, pages_read_user_content, pages_manage_metadata',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Token Input Section
                              Text(
                                'ACCESS TOKEN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: tokenController,
                                maxLines: 3,
                                enabled: !isExchanging,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText:
                                      'Paste your Facebook access token here...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
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
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Paste Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      isExchanging
                                          ? null
                                          : () async {
                                            final data =
                                                await Clipboard.getData(
                                                  'text/plain',
                                                );
                                            if (data?.text != null) {
                                              tokenController.text =
                                                  data!.text!;
                                              _showSuccessSnackBar(
                                                '✅ Token pasted from clipboard',
                                              );
                                            }
                                          },
                                  icon: const Icon(
                                    Icons.content_paste_rounded,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Paste from Clipboard',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2E7D32),
                                    side: BorderSide(
                                      color:
                                          isExchanging
                                              ? Colors.grey.shade300
                                              : const Color(0xFF2E7D32),
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          isExchanging
                                              ? null
                                              : () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey[700],
                                        side: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          isExchanging
                                              ? null
                                              : () async {
                                                final token =
                                                    tokenController.text.trim();

                                                if (token.isEmpty) {
                                                  _showErrorSnackBar(
                                                    'Please enter a token',
                                                  );
                                                  return;
                                                }

                                                if (token.length < 50) {
                                                  _showErrorSnackBar(
                                                    'Token seems too short',
                                                  );
                                                  return;
                                                }

                                                setDialogState(
                                                  () => isExchanging = true,
                                                );

                                                try {
                                                  print(
                                                    '🔄 Exchanging token...',
                                                  );
                                                  final result =
                                                      await FacebookSyncService.exchangeToken(
                                                        token,
                                                      );

                                                  if (result['success'] ==
                                                          true ||
                                                      result['ok'] == true) {
                                                    final expiresIn =
                                                        result['expires_in'] ??
                                                        0;
                                                    final daysValid =
                                                        (expiresIn / 86400)
                                                            .round();

                                                    Navigator.pop(context);
                                                    _showSuccessSnackBar(
                                                      '✅ Token saved! Valid for ~$daysValid days.',
                                                    );
                                                    await _autoSyncAfterTokenSave();
                                                    return;
                                                  }

                                                  throw Exception(
                                                    result['message'] ??
                                                        result['error'],
                                                  );
                                                } catch (e) {
                                                  print('❌ Error: $e');
                                                  setDialogState(
                                                    () => isExchanging = false,
                                                  );
                                                  final errorMessage =
                                                      FacebookSyncService.parseErrorMessage(
                                                        e,
                                                      );
                                                  _showErrorSnackBar(
                                                    'Failed to save token: $errorMessage',
                                                  );
                                                }
                                              },
                                      icon:
                                          isExchanging
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                              : const Icon(
                                                Icons.check_circle,
                                                size: 22,
                                              ),
                                      label: Text(
                                        isExchanging
                                            ? 'Saving...'
                                            : 'Save & Connect',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2E7D32,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey.shade400,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[400]!, width: 2),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(String permission) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Text(
            permission,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final count = result['count'] ?? 0;
        final failed = result['failed'] ?? 0;

        print('✅ Auto-sync completed: $count posts synced');

        // Reload announcements
        await loadAnnouncements();

        // Show success message
        _showSuccessSnackBar(
          '✅ Successfully synced $count posts!' +
              (failed > 0 ? ' ($failed failed)' : ''),
        );
      } else {
        throw Exception(result['error'] ?? result['message'] ?? 'Sync failed');
      }
    } catch (e) {
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
              InfoBankTestWidget(),
            ],
          ),
    );
  }

  // Helper methods for snackbars
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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

  Widget _buildRefreshButton({required bool isDesktop}) {
    return Row(
      children: [
        // Test button
        SizedBox(width: 8),

        // Facebook Token Config Button
        Container(
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _showTokenInputModal,
              child: Tooltip(
                message: 'Configure Facebook Token (Auto-syncs after save)',
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  child: Icon(
                    Icons.vpn_key,
                    color: Colors.blue[700],
                    size: isDesktop ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
        ),
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
    stream: FirebaseFirestore.instance
        .collection('announcements')
        .where('deleted', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      // Loading state
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
      final displayedAnnouncements = _filterAnnouncementsFromDocs(allAnnouncements);

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

List<DocumentSnapshot> _filterAnnouncementsFromDocs(List<DocumentSnapshot> docs) {
  var filtered = docs.where((doc) {
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
                    FirebaseFirestore.instance
                        .collection('announcements')
                        .where('deleted', isEqualTo: false)
                        .orderBy('created_time', descending: true)
                        .limit(5)
                        .snapshots(),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.error,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Message cannot be empty'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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

                          Navigator.pop(context);
                          loadAnnouncements();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Announcement updated successfully',
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.error,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Error updating announcement: $e'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
  
  // ✅ FIXED: Properly extract images array with better type safety and validation
  List<String> images = [];
  
  // Check for new 'images' array field first
  if (data['images'] != null && data['images'] is List) {
    images = (data['images'] as List)
        .map((item) {
          if (item is String) return item;
          if (item is Map && item.containsKey('url')) return item['url'].toString();
          return '';
        })
        .where((url) => url.isNotEmpty && url.startsWith('http'))
        .toList();
  }
  
  // Fallback to single 'full_picture' for backward compatibility
  if (images.isEmpty && 
      data['full_picture'] != null && 
      (data['full_picture'] as String).isNotEmpty &&
      (data['full_picture'] as String).startsWith('http')) {
    images = [data['full_picture'] as String];
  }
  
  // ✅ Log for debugging
  print('📸 Post ${widget.announcement.id}: Found ${images.length} images');
  if (images.isNotEmpty) {
    print('   First image: ${images[0].substring(0, 100)}...');
    if (images.length > 1) {
      print('   Last image: ${images[images.length - 1].substring(0, 100)}...');
    }
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
        _buildHeader(category, createdTime, imageCount, hasOCR, ocrProcessedCount),
        if (deadline != null) _buildDeadline(deadline),
        if (message.isNotEmpty) _buildMessage(message),
        // ✅ Pass the properly extracted images list
        if (hasImages) _buildImageGallery(images),
        _buildActionButtons(data),
      ],
    ),
  );
}

  void _showFullScreenImage(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
  // ============================================================================
  // ✅ NEW: Image Gallery Widget with Carousel
  // ============================================================================
  
  Widget _buildImageGallery(List<String> images) {
  // Reset page controller if needed
  if (_pageController.hasClients && images.length == 1) {
    _currentImageIndex = 0;
  }
  
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

        
        // Main image display
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.isDesktop ? 400 : 300,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: images.length == 1
                ? _buildSingleImage(images[0])
                : _buildImageCarousel(images),
          ),
        ),

        // Thumbnail strip (only for multiple images)
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return _buildThumbnail(images[index], index, images);
              },
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildSingleImage(String imageUrl) {
  return GestureDetector(
    onTap: () => _showFullScreenImage(context, [imageUrl], 0),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImageError(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildImageLoading(loadingProgress);
            },
          ),
        ),
        // Fullscreen button
        Positioned(
          top: 12,
          left: 12,
          child: _buildFullscreenButton([imageUrl], 0),
        ),
      ],
    ),
  );
}


// Multiple images carousel
Widget _buildImageCarousel(List<String> images) {
  return Stack(
    children: [
      // PageView for swiping
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
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildImageError(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildImageLoading(loadingProgress);
              },
            ),
          );
        },
      ),

      // Navigation arrows
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

      // Image counter badge
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
                const Icon(Icons.photo_library, color: Colors.white, size: 16),
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

      // Fullscreen button
      Positioned(
        top: 12,
        left: 12,
        child: _buildFullscreenButton(images, _currentImageIndex),
      ),
    ],
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

// Updated thumbnail with proper images list reference
Widget _buildThumbnail(String imageUrl, int index, List<String> allImages) {
  final isActive = index == _currentImageIndex;
  
  return GestureDetector(
    onTap: () {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    },
    child: Container(
      width: 70,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.green[600]! : Colors.grey[300]!,
          width: isActive ? 3 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: Icon(Icons.image, color: Colors.grey[400], size: 24),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

 Widget _buildNavigationArrow({
  required AlignmentGeometry alignment,
  required IconData icon,
  required VoidCallback onTap,
  required bool enabled,
}) {
  if (!enabled) return SizedBox.shrink();

  return Align(
    alignment: alignment,
    child: Padding(
      padding: EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    ),
  );
}
  // ============================================================================
  // ✅ NEW: Full Screen Image Viewer
  // ============================================================================



  // ============================================================================
  // Helper Widgets
  // ============================================================================

 Widget _buildHeader(
  String category, 
  String createdTime, 
  int imageCount, 
  bool hasOCR,
  int ocrProcessedCount
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
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  
                
        
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
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
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
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
                SizedBox(height: 2),
                Text(
                  DateFormat('MMMM d, yyyy').format((deadline as Timestamp).toDate()),
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

  Widget _buildMessage(String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: widget.isDesktop ? 15 : 14,
          height: 1.7,
          color: Colors.grey[700],
        ),
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
          Icon(Icons.image_not_supported_outlined, color: Colors.grey[600], size: 48),
          SizedBox(height: 12),
          Text(
            'Unable to load image',
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
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
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
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
        borderRadius: BorderRadius.only(
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
          SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.edit_rounded,
            onTap: () => widget.onEdit(widget.announcement),
            color: Colors.blue,
          ),
          SizedBox(width: 8),
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
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(colors: [Colors.green[600]!, Colors.green[700]!])
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
              Icon(icon, size: 20, color: isPrimary ? Colors.white : Colors.grey[700]),
              SizedBox(width: 10),
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
          padding: EdgeInsets.all(12),
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
// ✅ NEW: Full Screen Image Gallery
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
                      return Icon(Icons.error, color: Colors.white, size: 64);
                    },
                  ),
                ),
              );
            },
          ),
          
          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
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
                  padding: EdgeInsets.all(16),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: TextStyle(
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
}