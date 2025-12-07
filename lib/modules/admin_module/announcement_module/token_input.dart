// ============================================================================
// FILE 1: lib/modules/admin_module/announcement_module/fb_integration_helpers.dart
// ============================================================================

import 'package:capstone_project/modules/admin_module/announcement_module/fb_sync.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Manages Facebook integration state and operations
class FacebookIntegrationHelper {
  TokenStatus? tokenStatus;
  List<Map<String, dynamic>> configuredApps = [];
  bool isLoadingApps = false;
  bool hasCheckedToken = false;

  // Color constant
  static const Color fbBlue = Color(0xFF1877F2);

  /// Check token status
  Future<void> checkTokenStatus() async {
    try {
      tokenStatus = await FacebookSyncService.getTokenStatus();
      hasCheckedToken = true;
    } catch (e) {
      print('❌ Error checking token status: $e');
    }
  }

  /// Load configured Facebook apps
  Future<void> loadConfiguredApps() async {
    isLoadingApps = true;

    try {
      final doc = await FirebaseFirestore.instance
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
              'addedAt': (config['addedAt'] as Timestamp?)?.toDate().toString() ?? 'Unknown',
            });
          }
        });

        configuredApps = apps;
      } else {
        configuredApps = [];
      }
    } catch (e) {
      print('❌ Error loading apps: $e');
    } finally {
      isLoadingApps = false;
    }
  }

  /// Get token status tooltip text
  String getTokenStatusTooltip() {
    if (tokenStatus == null || !tokenStatus!.configured) {
      return 'Configure Facebook Token\n(Click to setup)';
    }

    if (tokenStatus!.expired) {
      return '⚠️ Token Expired!\nClick to renew now';
    }

    final daysLeft = tokenStatus!.daysLeft ?? 0;

    if (daysLeft <= 7) {
      return '🔴 Token expires in $daysLeft days\nRenew urgently!';
    } else if (daysLeft <= 30) {
      return '🟠 Token expires in $daysLeft days\nConsider renewing soon';
    } else {
      return '✅ Token active ($daysLeft days left)\nClick to view/renew';
    }
  }

  /// Get status color based on days left
  Color getTokenStatusColor() {
    if (tokenStatus == null || !tokenStatus!.configured) {
      return Colors.grey[400]!;
    }

    if (tokenStatus!.expired) {
      return Colors.red[700]!;
    }

    final daysLeft = tokenStatus!.daysLeft ?? 0;

    if (daysLeft <= 7) {
      return Colors.red[700]!;
    } else if (daysLeft <= 30) {
      return Colors.orange[700]!;
    } else {
      return Colors.green[600]!;
    }
  }
}

// ============================================================================
// TOKEN STATUS DIALOG
// ============================================================================

/// Shows token status dialog
void showTokenStatusDialog(
  BuildContext context,
  FacebookIntegrationHelper helper,
  VoidCallback onRefreshNeeded,
) {
  if (helper.tokenStatus == null || !helper.tokenStatus!.configured) {
    showTokenInputModal(context, helper, onRefreshNeeded);
    return;
  }

  final tokenStatus = helper.tokenStatus!;
  final daysLeft = tokenStatus.daysLeft ?? 0;
  final isUrgent = daysLeft <= 30;
  final isExpired = tokenStatus.expired;

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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FacebookIntegrationHelper.fbBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isExpired
                    ? Icons.error_rounded
                    : isUrgent
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                color: FacebookIntegrationHelper.fbBlue,
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isExpired
                  ? "Your access token is no longer valid."
                  : "Here are your current token details.",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildStatusTile(
              icon: Icons.hourglass_bottom_rounded,
              label: "Days Remaining",
              value: isExpired ? "Expired" : "$daysLeft days",
              color: FacebookIntegrationHelper.fbBlue,
              bold: true,
            ),
            const SizedBox(height: 12),
            _buildStatusTile(
              icon: Icons.calendar_month_rounded,
              label: "Expiration Date",
              value: tokenStatus.expiresAt != null
                  ? DateFormat('MMMM d, yyyy').format(
                      DateTime.fromMillisecondsSinceEpoch(tokenStatus.expiresAt!))
                  : "Unknown",
              color: Colors.grey[600]!,
            ),
            if (tokenStatus.pageId != null) ...[
              const SizedBox(height: 12),
              _buildStatusTile(
                icon: Icons.tag_rounded,
                label: "Page ID",
                value: tokenStatus.pageId!,
                color: Colors.grey[600]!,
              ),
            ],
            if (isExpired || isUrgent) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FacebookIntegrationHelper.fbBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FacebookIntegrationHelper.fbBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired ? Icons.error_outline : Icons.info_outline,
                      color: FacebookIntegrationHelper.fbBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isExpired
                            ? "Renew your token to continue system syncing."
                            : "You should renew the token soon to avoid interruption.",
                        style: TextStyle(
                          color: FacebookIntegrationHelper.fbBlue,
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
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                if (!isExpired && !isUrgent) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showTokenInputModal(context, helper, onRefreshNeeded);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FacebookIntegrationHelper.fbBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(isExpired ? Icons.vpn_key_rounded : Icons.refresh_rounded),
                    label: Text(
                      isExpired ? "Renew Now" : "Renew Token",
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

Widget _buildStatusTile({
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
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
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

// ============================================================================
// APP CREDENTIALS DIALOG
// ============================================================================

Future<void> showAppCredentialsDialog(
  BuildContext context,
  FacebookIntegrationHelper helper,
  VoidCallback onRefreshNeeded,
) async {
  await helper.loadConfiguredApps();

  final appIdController = TextEditingController();
  final appSecretController = TextEditingController();

  if (!context.mounted) return;

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
                _buildAppDialogHeader(context),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: _buildAppDialogContent(
                      context,
                      helper,
                      appIdController,
                      appSecretController,
                      setDialogState,
                      onRefreshNeeded,
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

Widget _buildAppDialogHeader(BuildContext context) {
  return Container(
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
  );
}

Widget _buildAppDialogContent(
  BuildContext context,
  FacebookIntegrationHelper helper,
  TextEditingController appIdController,
  TextEditingController appSecretController,
  StateSetter setDialogState,
  VoidCallback onRefreshNeeded,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
      _buildSectionHeader('ADD NEW APP', Icons.add),
      SizedBox(height: 16),
      _buildAppTextField(
        controller: appIdController,
        label: 'App ID',
        hint: 'e.g., 776960582033609',
        icon: Icons.tag,
        enabled: !helper.isLoadingApps,
      ),
      SizedBox(height: 16),
      _buildAppTextField(
        controller: appSecretController,
        label: 'App Secret',
        hint: 'Enter your app secret',
        icon: Icons.vpn_key,
        enabled: !helper.isLoadingApps,
        obscureText: true,
      ),
      SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: helper.isLoadingApps
              ? null
              : () => _handleAddApp(
                    context,
                    appIdController,
                    appSecretController,
                    helper,
                    setDialogState,
                    onRefreshNeeded,
                  ),
          icon: helper.isLoadingApps
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
            helper.isLoadingApps ? 'Adding App...' : 'Add App',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1877F2),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      SizedBox(height: 32),
      _buildSectionHeader('CONFIGURED APPS (${helper.configuredApps.length})', Icons.apps),
      SizedBox(height: 16),
      _buildConfiguredAppsList(context, helper, setDialogState, onRefreshNeeded),
    ],
  );
}

Widget _buildSectionHeader(String title, IconData icon) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Color(0xFF1877F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      SizedBox(width: 10),
      Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey[700],
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

Widget _buildAppTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  required bool enabled,
  bool obscureText = false,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
      hintText: hint,
      prefixIcon: Container(
        margin: EdgeInsets.all(12),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFE7F3FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Color(0xFF1877F2), size: 20),
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
  );
}

Widget _buildConfiguredAppsList(
  BuildContext context,
  FacebookIntegrationHelper helper,
  StateSetter setDialogState,
  VoidCallback onRefreshNeeded,
) {
  if (helper.isLoadingApps) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
        ),
      ),
    );
  }

  if (helper.configuredApps.isEmpty) {
    return Container(
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first Facebook app to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  return Column(
    children: helper.configuredApps.map((app) {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
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
              gradient: LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF0C63D4)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.apps, color: Colors.white, size: 24),
          ),
          title: Text(
            app['appId'] ?? 'Unknown',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.grey[800]),
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
            onPressed: () => _handleDeleteApp(
              context,
              app,
              helper,
              setDialogState,
              onRefreshNeeded,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

Future<void> _handleAddApp(
  BuildContext context,
  TextEditingController appIdController,
  TextEditingController appSecretController,
  FacebookIntegrationHelper helper,
  StateSetter setDialogState,
  VoidCallback onRefreshNeeded,
) async {
  final appId = appIdController.text.trim();
  final appSecret = appSecretController.text.trim();

  if (appId.isEmpty || appSecret.isEmpty) {
    SnackbarUtil.showError(context, 'Please enter both App ID and App Secret');
    return;
  }

  setDialogState(() => helper.isLoadingApps = true);

  try {
    await FirebaseFirestore.instance.collection('fb_app_credentials').doc('apps').set({
      appId: {
        'appSecret': appSecret,
        'addedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

    appIdController.clear();
    appSecretController.clear();

    await helper.loadConfiguredApps();
    setDialogState(() {});
    onRefreshNeeded();

    if (!context.mounted) return;
    SnackbarUtil.showSuccess(context, '✅ App added successfully!');
  } catch (e) {
    if (!context.mounted) return;
    SnackbarUtil.showError(context, 'Error: $e');
  } finally {
    setDialogState(() => helper.isLoadingApps = false);
  }
}

Future<void> _handleDeleteApp(
  BuildContext context,
  Map<String, dynamic> app,
  FacebookIntegrationHelper helper,
  StateSetter setDialogState,
  VoidCallback onRefreshNeeded,
) async {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  .update({app['appId']: FieldValue.delete()});

              await helper.loadConfiguredApps();
              setDialogState(() {});
              onRefreshNeeded();

              if (!context.mounted) return;
              SnackbarUtil.showSuccess(context, '✅ App removed successfully');
            } catch (e) {
              if (!context.mounted) return;
              SnackbarUtil.showError(context, 'Error: $e');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Remove'),
        ),
      ],
    ),
  );
}

// ============================================================================
// TOKEN INPUT MODAL - PART 1
// ============================================================================

Future<void> showTokenInputModal(
  BuildContext context,
  FacebookIntegrationHelper helper,
  VoidCallback onRefreshNeeded,
) async {
  final tokenController = TextEditingController();
  final pageIdController = TextEditingController();
  final appIdController = TextEditingController();

  if (helper.tokenStatus?.pageId != null) {
    pageIdController.text = helper.tokenStatus!.pageId!;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        bool isExchanging = false;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                _buildTokenInputHeader(context, helper),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildTokenInputContent(
                      context,
                      tokenController,
                      pageIdController,
                      appIdController,
                      helper,
                      setDialogState,
                      onRefreshNeeded,
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

// ============================================================================
// TOKEN INPUT MODAL - CONTINUED (add to fb_integration_helpers.dart)
// ============================================================================

// This continues from the _buildTokenInputHeader function...

Widget _buildTokenInputHeader(BuildContext context, FacebookIntegrationHelper helper) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1877F2), Color(0xFF0C63D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.facebook, color: Colors.white, size: 28),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: Colors.white),
                padding: EdgeInsets.all(8),
              ),
            ),
          ],
        ),
        if (helper.tokenStatus != null && helper.tokenStatus!.configured) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  helper.tokenStatus!.expired
                      ? Icons.error
                      : helper.tokenStatus!.needsRenewal
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
                        helper.tokenStatus!.expired
                            ? 'Token Expired'
                            : helper.tokenStatus!.needsRenewal
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
                        helper.tokenStatus!.expired
                            ? 'Renew your token to continue syncing'
                            : 'Expires in ${helper.tokenStatus!.daysLeft} days',
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
  );
}

Widget _buildTokenInputContent(
  BuildContext context,
  TextEditingController tokenController,
  TextEditingController pageIdController,
  TextEditingController appIdController,
  FacebookIntegrationHelper helper,
  StateSetter setDialogState,
  VoidCallback onRefreshNeeded,
) {
  bool isExchanging = false;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Instructions Section
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
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
            _buildInstructionStep('1', 'Visit developers.facebook.com and log in'),
            const SizedBox(height: 12),
            _buildInstructionStep('2', 'Click "My Apps" → "Create App"'),
            const SizedBox(height: 12),
            _buildInstructionStep(
                '3', 'Choose "Manage everything on your Page" as the use case, and select "Business" as the App Type.'),
            const SizedBox(height: 12),
            _buildInstructionStep(
                '4', 'In the right sidebar, open "Use Cases" and select your created app and enable required permissions'),
            const SizedBox(height: 12),
            _buildInstructionStep(
                '5', 'Go to Tools → Graph API Explorer → Select your app and check the same permissions'),
            const SizedBox(height: 12),
            _buildInstructionStep('6', 'Generate and copy your Access Token'),
            const SizedBox(height: 12),
            _buildInstructionStep(
                '7',
                'Page ID: Go to your Facebook Page → About → Page transparency → Page ID. App ID: Find it in your Facebook App dashboard (optional but recommended).'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user, size: 18, color: Colors.green.shade600),
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
      _buildInputLabel('Facebook App ID', Icons.apps, isOptional: true),
      const SizedBox(height: 10),
      _buildTokenTextField(
        controller: appIdController,
        hintText: 'Enter your Facebook App ID',
        icon: Icons.apps,
        enabled: !isExchanging,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 20),
      _buildInputLabel('Facebook Page ID', Icons.tag, isRequired: true),
      const SizedBox(height: 10),
      _buildTokenTextField(
        controller: pageIdController,
        hintText: 'e.g., 730995450096065',
        icon: Icons.tag,
        enabled: !isExchanging,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 20),
      _buildInputLabel('Access Token', Icons.key, isRequired: true),
      const SizedBox(height: 10),
      _buildTokenTextField(
        controller: tokenController,
        hintText: 'Paste your Facebook access token here...',
        icon: Icons.key,
        enabled: !isExchanging,
        maxLines: 3,
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isExchanging
              ? null
              : () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    tokenController.text = data!.text!;
                    if (context.mounted) {
                      SnackbarUtil.showSuccess(context, '✅ Token pasted from clipboard');
                    }
                  }
                },
          icon: Icon(Icons.content_paste_rounded, size: 20),
          label: Text(
            'Paste from Clipboard',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF1877F2),
            side: BorderSide(
              color: isExchanging ? Colors.grey.shade300 : Color(0xFF1877F2),
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isExchanging ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isExchanging
                  ? null
                  : () => _handleTokenExchange(
                        context,
                        tokenController,
                        pageIdController,
                        appIdController,
                        helper,
                        setDialogState,
                        onRefreshNeeded,
                      ),
              icon: isExchanging
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle, size: 22),
              label: Text(
                isExchanging ? 'Saving...' : 'Save & Connect',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
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
        Text('*', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
      if (isOptional) ...[
        SizedBox(width: 6),
        Text(
          '(Optional)',
          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
        ),
      ],
    ],
  );
}

Widget _buildTokenTextField({
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
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[900]),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w400),
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

Future<void> _handleTokenExchange(
  BuildContext context,
  TextEditingController tokenController,
  TextEditingController pageIdController,
  TextEditingController appIdController,
  FacebookIntegrationHelper helper,
  StateSetter setDialogState,
  VoidCallback onRefreshNeeded,
) async {
  final token = tokenController.text.trim();
  final pageId = pageIdController.text.trim();
  final appId = appIdController.text.trim();

  if (pageId.isEmpty) {
    SnackbarUtil.showError(context, 'Please enter your Facebook Page ID');
    return;
  }

  if (!RegExp(r'^\d+$').hasMatch(pageId)) {
    SnackbarUtil.showError(context, 'Page ID should only contain numbers');
    return;
  }

  if (appId.isNotEmpty && !RegExp(r'^\d+$').hasMatch(appId)) {
    SnackbarUtil.showError(context, 'App ID should only contain numbers');
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

  setDialogState(() {});

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

      Navigator.pop(context);

      String successMessage = 'Token and Page ID saved! Valid for ~$daysValid days.';
      if (appUsed != null && appUsed.isNotEmpty) {
        successMessage += '\nUsing App ID: $appUsed';
      }

      SnackbarUtil.showSuccess(context, successMessage);
      await helper.checkTokenStatus();
      onRefreshNeeded();
      return;
    }

    throw Exception(result['message'] ?? result['error']);
  } catch (e) {
    print('❌ Error: $e');
    if (!context.mounted) return;
    final errorMessage = FacebookSyncService.parseErrorMessage(e);
    SnackbarUtil.showError(context, 'Failed to save: $errorMessage');
  }
}