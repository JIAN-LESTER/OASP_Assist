import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================================================================
// CATEGORY DISTRIBUTION DETAIL DIALOG
// ============================================================================

class CategoryDistributionDetailDialog extends StatefulWidget {
  final Map<String, int> categoryData;
  final String timeFrame;

  const CategoryDistributionDetailDialog({
    super.key,
    required this.categoryData,
    required this.timeFrame,
  });

  @override
  State<CategoryDistributionDetailDialog> createState() =>
      _CategoryDistributionDetailDialogState();
}

class _CategoryDistributionDetailDialogState
    extends State<CategoryDistributionDetailDialog> {
  String? selectedCategory;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryData.isNotEmpty) {
      selectedCategory = widget.categoryData.keys.first;
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (selectedCategory == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final startDate = _getStartDate(widget.timeFrame);
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('sender', isEqualTo: 'user')
          .where('category', isEqualTo: selectedCategory)
          .where('sent_at', isGreaterThanOrEqualTo: startDate)
          .orderBy('sent_at', descending: true)
          .limit(100)
          .get();

      setState(() {
        messages = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'content': data['content'] ?? 'N/A',
            'category': data['category'] ?? 'General',
            'timestamp': (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'isAnswered': data['isAnswered'] ?? false,
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime _getStartDate(String timeFrame) {
    final now = DateTime.now();
    switch (timeFrame) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(2000, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final sortedCategories = widget.categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 700,
        height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pie_chart, color: Colors.purple[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Distribution',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Messages by category',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sortedCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = sortedCategories[index];
                  final isSelected = selectedCategory == entry.key;
                  return FilterChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.key),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.purple[700] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCategory = entry.key;
                        });
                        _loadMessages();
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Messages List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No messages found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return _MessageCard(
                              message: msg['text'],
                              category: msg['category'],
                              timestamp: msg['timestamp'],
                              isAnswered: msg['isAnswered'],
                              isMobile: isMobile,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INQUIRY TRENDS DETAIL DIALOG
// ============================================================================

class InquiryTrendsDetailDialog extends StatefulWidget {
  final String timeFrame;

  const InquiryTrendsDetailDialog({
    super.key,
    required this.timeFrame,
  });

  @override
  State<InquiryTrendsDetailDialog> createState() =>
      _InquiryTrendsDetailDialogState();
}

class _InquiryTrendsDetailDialogState extends State<InquiryTrendsDetailDialog> {
  String? selectedCategory;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  Set<String> categories = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      isLoading = true;
    });

    try {
      final startDate = _getStartDate(widget.timeFrame);
      Query query = FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('sender', isEqualTo: 'user')
          .where('sent_at', isGreaterThanOrEqualTo: startDate);

      if (selectedCategory != null) {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      final snapshot = await query
          .orderBy('sent_at', descending: true)
          .limit(100)
          .get();

      final loadedMessages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        categories.add(data['category'] ?? 'General');
        return {
          'text': data['text'] ?? 'N/A',
          'category': data['category'] ?? 'General',
          'timestamp': (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'isAnswered': data['isAnswered'] ?? false,
        };
      }).toList();

      setState(() {
        messages = loadedMessages;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime _getStartDate(String timeFrame) {
    final now = DateTime.now();
    switch (timeFrame) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(2000, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final sortedCategories = categories.toList()..sort();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 700,
        height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.show_chart, color: Colors.green[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inquiry Trends',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Messages over time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Filter
            if (sortedCategories.isNotEmpty) ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      selected: selectedCategory == null,
                      label: const Text('All'),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedCategory = null;
                          });
                          _loadMessages();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ...sortedCategories.map((category) {
                      final isSelected = selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(category),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedCategory = category;
                              });
                              _loadMessages();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Messages List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No messages found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return _MessageCard(
                              message: msg['text'],
                              category: msg['category'],
                              timestamp: msg['timestamp'],
                              isAnswered: msg['isAnswered'],
                              isMobile: isMobile,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SYSTEM LOGS DETAIL DIALOG
// ============================================================================

class SystemLogsDetailDialog extends StatefulWidget {
  final String timeFrame;

  const SystemLogsDetailDialog({
    super.key,
    required this.timeFrame,
  });

  @override
  State<SystemLogsDetailDialog> createState() => _SystemLogsDetailDialogState();
}

class _SystemLogsDetailDialogState extends State<SystemLogsDetailDialog> {
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('logs')
          .orderBy('time', descending: true)
          .limit(100)
          .get();

      setState(() {
        logs = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'user': data['user'] ?? 'Unknown',
            'action': data['action'] ?? 'N/A',
            'time': (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 600,
        height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.history, color: Colors.blue[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Logs',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${logs.length} activities',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Logs List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No logs found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return _SystemLogCard(
                              user: log['user'],
                              action: log['action'],
                              time: log['time'],
                              isMobile: isMobile,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGE LOGS DETAIL DIALOG
// ============================================================================

class MessageLogsDetailDialog extends StatefulWidget {
  final String timeFrame;

  const MessageLogsDetailDialog({
    super.key,
    required this.timeFrame,
  });

  @override
  State<MessageLogsDetailDialog> createState() =>
      _MessageLogsDetailDialogState();
}

class _MessageLogsDetailDialogState extends State<MessageLogsDetailDialog> {
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('message_logs')
          .orderBy('time', descending: true)
          .limit(100)
          .get();

      setState(() {
        logs = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'user': data['user'] ?? 'Unknown',
            'message': data['message'] ?? 'N/A',
            'reply': data['reply'] ?? '',
            'time': (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading message logs: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 700,
        height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chat_bubble, color: Colors.green[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Conversations',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${logs.length} conversations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Logs List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No conversations found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return _ConversationCard(
                              user: log['user'],
                              message: log['message'],
                              reply: log['reply'],
                              time: log['time'],
                              isMobile: isMobile,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE CARD WIDGETS
// ============================================================================

class _MessageCard extends StatelessWidget {
  final String message;
  final String category;
  final DateTime timestamp;
  final bool isAnswered;
  final bool isMobile;

  const _MessageCard({
    required this.message,
    required this.category,
    required this.timestamp,
    required this.isAnswered,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getCategoryColor(category),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                isAnswered ? Icons.check_circle : Icons.pending,
                size: 16,
                color: isAnswered ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isAnswered ? 'Answered' : 'Pending',
                style: TextStyle(
                  fontSize: 11,
                  color: isAnswered ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, yyyy • h:mm a').format(timestamp),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'admission':
        return Colors.blue;
      case 'scholarship':
        return Colors.green;
      case 'placement':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }
}

class _SystemLogCard extends StatelessWidget {
  final String user;
  final String action;
  final DateTime time;
  final bool isMobile;

  const _SystemLogCard({
    required this.user,
    required this.action,
    required this.time,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getActionColor(action).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getActionIcon(action),
              color: _getActionColor(action),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('h:mm a').format(time),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.orange;
      case 'create':
        return Colors.blue;
      case 'update':
        return Colors.amber;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }
}

class _ConversationCard extends StatelessWidget {
  final String user;
  final String message;
  final String reply;
  final DateTime time;
  final bool isMobile;

  const _ConversationCard({
    required this.user,
    required this.message,
    required this.reply,
    required this.time,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green[100],
                child: Icon(Icons.person, size: 18, color: Colors.green[700]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                DateFormat('h:mm a').format(time),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: Colors.grey[800],
              ),
            ),
          ),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                reply,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}