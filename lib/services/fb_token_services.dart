import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FacebookTokenPage extends StatefulWidget {
  const FacebookTokenPage({super.key});

  @override
  State<FacebookTokenPage> createState() => _FacebookTokenPageState();
}

class _FacebookTokenPageState extends State<FacebookTokenPage> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _isExchanging = false;
  Map<String, dynamic>? _currentTokenInfo;

  @override
  void initState() {
    super.initState();
    _loadCurrentToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentToken() async {
    try {
      setState(() => _isLoading = true);

      final doc = await FirebaseFirestore.instance
          .collection('fb_tokens')
          .doc('facebook_admin')
          .get();

      if (doc.exists) {
        setState(() {
          _currentTokenInfo = doc.data();
        });
      }
    } catch (e) {
      print('Error loading token: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

   static Future<Map<String, dynamic>> testConnection() async {
  print('🧪 Testing Facebook connection...');
  
  try {
    final callable = FirebaseFunctions.instance
        .httpsCallable('testFacebookConnection');
    
    final result = await callable.call(<String, dynamic>{})
        .timeout(Duration(seconds: 30));
    
    print('📦 Test result: ${json.encode(result.data)}');
    return result.data as Map<String, dynamic>;
  } catch (e) {
    print('❌ Test failed: $e');
    rethrow;
  }
}

  Future<void> _exchangeToken() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      _showSnackBar('Please enter a token', isError: true);
      return;
    }

    if (token.length < 50) {
      _showSnackBar('Token seems too short. Please check and try again.', isError: true);
      return;
    }

    setState(() => _isExchanging = true);

    try {
      print('🔄 Exchanging token...');

      final response = await http.post(
        Uri.parse('https://exchangetoken-kt3rxdstza-uc.a.run.app'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'uid': 'facebook_admin',
          'short_token': token,
        }),
      ).timeout(Duration(seconds: 30));

      print('Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['ok'] == true) {
          final daysValid = (data['expires_in'] / 86400).round();

          _showSnackBar(
            '✅ Token configured successfully! Valid for ~$daysValid days',
            isError: false,
          );

          _tokenController.clear();
          await _loadCurrentToken();
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
      _showSnackBar('Failed to exchange token: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isExchanging = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 8 : 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Facebook Token Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCurrentTokenCard(),
                      SizedBox(height: 24),
                      _buildInstructionsCard(),
                      SizedBox(height: 24),
                      _buildTokenInputCard(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentTokenCard() {
    if (_currentTokenInfo == null) {
      return _buildCard(
        title: 'Current Status',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
        child: Column(
          children: [
            Icon(Icons.token, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Token Configured',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please add a Facebook access token below',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final expiresAt = _currentTokenInfo!['expires_at'] as int?;
    final updatedAt = _currentTokenInfo!['updated_at'] as int?;
    
    DateTime? expiryDate;
    int? daysRemaining;
    bool isExpiringSoon = false;
    bool isExpired = false;

    if (expiresAt != null) {
      expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      daysRemaining = expiryDate.difference(DateTime.now()).inDays;
      isExpiringSoon = daysRemaining < 7;
      isExpired = daysRemaining < 0;
    }

    return _buildCard(
      title: 'Current Token Status',
      icon: isExpired ? Icons.error : (isExpiringSoon ? Icons.warning : Icons.check_circle),
      iconColor: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.green),
      child: Column(
        children: [
          _buildInfoRow(
            'Status',
            isExpired
                ? 'Expired'
                : isExpiringSoon
                    ? 'Expiring Soon'
                    : 'Active',
            color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.green),
          ),
          Divider(height: 24),
          if (expiryDate != null) ...[
            _buildInfoRow(
              'Expires',
              DateFormat('MMM dd, yyyy hh:mm a').format(expiryDate),
            ),
            Divider(height: 24),
          ],
          if (daysRemaining != null)
            _buildInfoRow(
              'Days Remaining',
              '$daysRemaining days',
              color: isExpiringSoon ? Colors.orange : null,
            ),
          if (updatedAt != null) ...[
            Divider(height: 24),
            _buildInfoRow(
              'Last Updated',
              _formatTimeAgo(updatedAt),
            ),
          ],
          if (isExpiringSoon && !isExpired) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Token expires soon. Consider refreshing.',
                      style: TextStyle(color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isExpired) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Token has expired. Please refresh immediately.',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildInstructionsCard() {
    return _buildCard(
      title: 'How to Get a Facebook Token',
      icon: Icons.help_outline,
      iconColor: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStep(
            '1',
            'Visit Facebook Graph API Explorer',
            'Open https://developers.facebook.com/tools/explorer/',
          ),
          SizedBox(height: 12),
          _buildStep(
            '2',
            'Select Your App',
            'Choose your Facebook app from the dropdown',
          ),
          SizedBox(height: 12),
          _buildStep(
            '3',
            'Generate Token',
            'Click "Generate Access Token" and grant permissions',
          ),
          SizedBox(height: 12),
          _buildStep(
            '4',
            'Copy & Paste',
            'Copy the token and paste it in the field below',
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The short-lived token will be automatically converted to a long-lived token (~60 days)',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInputCard() {
    return _buildCard(
      title: 'Enter New Token',
      icon: Icons.vpn_key,
      iconColor: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _tokenController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Paste your Facebook access token here...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: EdgeInsets.all(16),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExchanging
                      ? null
                      : () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _tokenController.text = data!.text!;
                            _showSnackBar('Token pasted from clipboard', isError: false);
                          }
                        },
                  icon: Icon(Icons.paste),
                  label: Text('Paste'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isExchanging ? null : _exchangeToken,
                  icon: _isExchanging
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Icon(Icons.upload),
                  label: Text(_isExchanging ? 'Exchanging...' : 'Save Token'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
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
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}