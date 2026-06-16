import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin testing panel for Facebook token expiration notifications
/// Place this in your admin settings or testing page
class FacebookTokenTestingPanel extends StatefulWidget {
  const FacebookTokenTestingPanel({super.key});

  @override
  State<FacebookTokenTestingPanel> createState() =>
      _FacebookTokenTestingPanelState();
}

class _FacebookTokenTestingPanelState extends State<FacebookTokenTestingPanel> {
  bool _isLoading = false;
  String? _lastTestResult;
  Map<String, dynamic>? _tokenStatus;

  @override
  void initState() {
    super.initState();
    _loadTokenStatus();
  }

  Future<void> _loadTokenStatus() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('fb_tokens')
              .doc('facebook_admin')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        final expiresAt = data['expires_at'] as int?;

        if (expiresAt != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final daysLeft = ((expiresAt - now) / (1000 * 60 * 60 * 24)).ceil();

          setState(() {
            _tokenStatus = {
              'expiresAt': DateTime.fromMillisecondsSinceEpoch(expiresAt),
              'daysLeft': daysLeft,
              'expired': daysLeft <= 0,
            };
          });
        }
      }
    } catch (e) {
      print('Error loading token status: $e');
    }
  }

  Future<void> _triggerManualCheck() async {
    setState(() {
      _isLoading = true;
      _lastTestResult = null;
    });

    try {
      print(' Triggering manual Facebook token check...');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'manualCheckFacebookToken',
      );

      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;

      print(' Manual check result: $data');

      if (data['success'] == true) {
        setState(() {
          _lastTestResult =
              'SUCCESS: ${data['message']}\n\n'
              'Days until expiry: ${data['daysUntilExpiry']}\n'
              'Status: ${data['status']}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(' ${data['message']}'),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Check failed');
      }
    } catch (e) {
      print(' Error: $e');

      setState(() {
        _lastTestResult = 'ERROR: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Error: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Token Expiration Testing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Test FCM notifications for token expiration',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Current Status
            if (_tokenStatus != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _tokenStatus!['expired'] == true
                          ? Colors.red[50]
                          : _tokenStatus!['daysLeft'] <= 7
                          ? Colors.orange[50]
                          : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _tokenStatus!['expired'] == true
                            ? Colors.red[200]!
                            : _tokenStatus!['daysLeft'] <= 7
                            ? Colors.orange[200]!
                            : Colors.green[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _tokenStatus!['expired'] == true
                              ? Icons.error_rounded
                              : Icons.info_rounded,
                          color:
                              _tokenStatus!['expired'] == true
                                  ? Colors.red[700]
                                  : _tokenStatus!['daysLeft'] <= 7
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Token Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                _tokenStatus!['expired'] == true
                                    ? Colors.red[900]
                                    : _tokenStatus!['daysLeft'] <= 7
                                    ? Colors.orange[900]
                                    : Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      'Days Remaining',
                      '${_tokenStatus!['daysLeft']} days',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow(
                      'Expires On',
                      _formatDate(_tokenStatus!['expiresAt']),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow(
                      'Status',
                      _tokenStatus!['expired'] == true
                          ? 'EXPIRED'
                          : _tokenStatus!['daysLeft'] <= 14
                          ? 'EXPIRING SOON'
                          : 'ACTIVE',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Testing Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Testing Configuration',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Schedule', 'Every 3 days at 9 AM Manila time'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Testing Threshold', '59-60 days'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Production Threshold', '14 days (not active)'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Notification Types', 'In-app + FCM push'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Test Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _triggerManualCheck,
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _isLoading
                      ? 'Sending Test Notification...'
                      : 'Send Test Notification',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Result Display
            if (_lastTestResult != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _lastTestResult!.startsWith('SUCCESS')
                          ? Colors.green[50]
                          : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _lastTestResult!.startsWith('SUCCESS')
                            ? Colors.green[200]!
                            : Colors.red[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastTestResult!.startsWith('SUCCESS')
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color:
                              _lastTestResult!.startsWith('SUCCESS')
                                  ? Colors.green[700]
                                  : Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Test Result',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                _lastTestResult!.startsWith('SUCCESS')
                                    ? Colors.green[900]
                                    : Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lastTestResult!,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Instructions
            ExpansionTile(
              title: const Text(
                'How to Test',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionStep(
                        '1',
                        'Click "Send Test Notification" above',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '2',
                        'Check your device for FCM push notification',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '3',
                        'Check Firestore notifications collection',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '4',
                        'Verify notification appears in your in-app notifications',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: Colors.amber[800],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tip: The scheduler runs automatically every 3 days. '
                                'This manual trigger lets you test immediately.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
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
            color: Colors.blue[700],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
                fontSize: 13,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
