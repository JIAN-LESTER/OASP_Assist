import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple test widget to create Information Bank entries
class InfoBankTestWidget extends StatefulWidget {
  const InfoBankTestWidget({super.key});

  @override
  State<InfoBankTestWidget> createState() => _InfoBankTestWidgetState();
}

class _InfoBankTestWidgetState extends State<InfoBankTestWidget> {
  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  String? _result;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final snapshot = await _firestore
          .collection('announcements')
          .where('deleted', isEqualTo: false)
          .where('category', whereIn: ['Admission', 'Scholarship', 'Placement'])
          .orderBy('created_time', descending: true)
          .limit(10)
          .get();

      setState(() {
        _announcements = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'category': data['category'],
            'message': (data['message'] ?? '').toString().substring(
              0, 
              (data['message'] ?? '').toString().length > 50 ? 50 : (data['message'] ?? '').toString().length
            ),
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading announcements: $e');
    }
  }

  Future<void> _testCreateInfoBank(String announcementId) async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      print('🧪 Testing Information Bank creation for $announcementId...');
      
      final result = await _functions
          .httpsCallable('testCreateInfoBank')
          .call({'announcementId': announcementId});

      final data = Map<String, dynamic>.from(result.data);

      if (data['success'] == true) {
        setState(() {
          _result = '✅ SUCCESS!\n'
              'Info Bank ID: ${data['infoBankId']}\n'
              'Category: ${data['category']}\n'
              'Chunks: ${data['data']?['totalChunks']}\n'
              'Content: ${data['data']?['contentLength']} chars';
        });
      } else {
        setState(() {
          _result = '❌ Failed: ${data['message']}';
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _result = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _listInfoBankEntries() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final result = await _functions
          .httpsCallable('listInfoBankEntries')
          .call();

      final data = Map<String, dynamic>.from(result.data);
      final entries = List<Map<String, dynamic>>.from(data['entries'] ?? []);

      setState(() {
        _result = '📋 Information Bank Entries: ${entries.length}\n\n'
            '${entries.take(5).map((e) => 
              '• ${e['title']}\n  Category: ${e['category']}\n  Chunks: ${e['totalChunks']}'
            ).join('\n\n')}';
      });
    } catch (e) {
      setState(() {
        _result = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Information Bank Test'),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _listInfoBankEntries,
                      icon: Icon(Icons.list),
                      label: Text('List All Info Bank Entries'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Recent Announcements
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Recent Announcements (Click to Test)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _announcements.isEmpty
                          ? Center(child: Text('No announcements found'))
                          : ListView.builder(
                              itemCount: _announcements.length,
                              itemBuilder: (context, index) {
                                final announcement = _announcements[index];
                                return ListTile(
                                  title: Text(announcement['message']),
                                  subtitle: Text(
                                    '${announcement['category']} • ${announcement['id']}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: _isLoading 
                                      ? null 
                                      : () => _testCreateInfoBank(announcement['id']),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Result Display
            if (_isLoading)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing...'),
                    ],
                  ),
                ),
              )
            else if (_result != null)
              Card(
                color: _result!.startsWith('✅') 
                    ? Colors.green[50] 
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Result',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => setState(() => _result = null),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _result!,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add this button to your Information Bank page for quick testing
class InfoBankTestButton extends StatelessWidget {
  const InfoBankTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InfoBankTestWidget(),
              ),
            );
          },
          child: Tooltip(
            message: 'Test Information Bank Creation',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science, color: Colors.purple[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Test',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}