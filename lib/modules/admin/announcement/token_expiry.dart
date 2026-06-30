import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final Stream<DocumentSnapshot> _facebookAdminTokenStream =
    FirebaseFirestore.instance
        .collection('fb_tokens')
        .doc('facebook_admin')
        .snapshots();

/// Widget that displays a warning banner when Facebook token is expiring or expired
/// Should be placed at the top of the admin announcements page
class FacebookTokenExpirationBanner extends StatelessWidget {
  const FacebookTokenExpirationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: _facebookAdminTokenStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final expiresAt = data['expires_at'] as int?;

        if (expiresAt == null) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final msUntilExpiry = expiresAt - now;
        final daysUntilExpiry = (msUntilExpiry / (1000 * 60 * 60 * 24)).ceil();

        //  TESTING: Show for 60 days
        //  PRODUCTION: Change to 14 days
        const NOTIFICATION_THRESHOLD = 60; // Change to 14 for production

        if (daysUntilExpiry <= 0) {
          return _buildExpiredBanner(context);
        } else if (daysUntilExpiry <= NOTIFICATION_THRESHOLD) {
          return _buildExpiringSoonBanner(context, daysUntilExpiry);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildExpiredBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDC2626), // Red-600
            Color(0xFFB91C1C), // Red-700
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.3),
            blurRadius: 12,
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facebook Token Expired',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Action required immediately',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Facebook API token has expired. You cannot sync new posts until you renew the token.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showTokenRenewalInstructions(context);
              },
              icon: const Icon(Icons.key, size: 18),
              label: const Text(
                'Renew Token Now',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSoonBanner(BuildContext context, int daysLeft) {
    final isUrgent = daysLeft <= 7;
    final color =
        isUrgent
            ? const Color(0xFFF59E0B)
            : const Color(0xFF3B82F6); // Orange or Blue

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isUrgent ? Icons.warning_rounded : Icons.info_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Facebook Token Expiring Soon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$daysLeft day${daysLeft != 1 ? "s" : ""} remaining',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$daysLeft days left',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Facebook API token will expire soon. Please renew it to continue syncing posts without interruption.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showTokenRenewalInstructions(context);
              },
              icon: const Icon(Icons.key, size: 18),
              label: const Text(
                'Renew Token',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenRenewalInstructions(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          color: Color(0xFF2E7D32),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Renew Facebook Token',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Follow these steps',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInstructionStep(
                          number: '1',
                          title: 'Go to Announcements page',
                          description:
                              'Navigate to the Announcements section in the admin panel',
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionStep(
                          number: '2',
                          title: 'Click the key () button',
                          description:
                              'Find and click the Facebook configuration button',
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionStep(
                          number: '3',
                          title: 'Get new token from Facebook',
                          description:
                              'Follow the Facebook Graph API Explorer instructions',
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionStep(
                          number: '4',
                          title: 'Enter and save the new token',
                          description:
                              'Paste the new token and click "Save & Exchange Token"',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Navigate to announcements page
                            Navigator.of(context).pushReplacementNamed(
                              '/admin/home',
                              arguments: {'initialTab': 4}, // Announcements tab
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Go to Announcements',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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

  Widget _buildInstructionStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact version for dashboard or other pages
class FacebookTokenExpirationIndicator extends StatelessWidget {
  const FacebookTokenExpirationIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _facebookAdminTokenStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final expiresAt = data['expires_at'] as int?;

        if (expiresAt == null) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final msUntilExpiry = expiresAt - now;
        final daysUntilExpiry = (msUntilExpiry / (1000 * 60 * 60 * 24)).ceil();

        //  TESTING: Show for 60 days
        //  PRODUCTION: Change to 14 days
        const NOTIFICATION_THRESHOLD = 60;

        if (daysUntilExpiry > NOTIFICATION_THRESHOLD) {
          return const SizedBox.shrink();
        }

        final isExpired = daysUntilExpiry <= 0;
        final isUrgent = daysUntilExpiry <= 7;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isExpired
                    ? const Color(0xFFDC2626).withOpacity(0.1)
                    : isUrgent
                    ? const Color(0xFFF59E0B).withOpacity(0.1)
                    : const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isExpired
                      ? const Color(0xFFDC2626).withOpacity(0.3)
                      : isUrgent
                      ? const Color(0xFFF59E0B).withOpacity(0.3)
                      : const Color(0xFF3B82F6).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpired
                    ? Icons.error_rounded
                    : isUrgent
                    ? Icons.warning_rounded
                    : Icons.info_rounded,
                size: 16,
                color:
                    isExpired
                        ? const Color(0xFFDC2626)
                        : isUrgent
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 6),
              Text(
                isExpired
                    ? 'FB Token Expired'
                    : 'FB Token: $daysUntilExpiry day${daysUntilExpiry != 1 ? "s" : ""} left',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isExpired
                          ? const Color(0xFFDC2626)
                          : isUrgent
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
