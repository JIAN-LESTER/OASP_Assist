import 'dart:async';

import 'package:flutter/material.dart';

/// BouncingDotsTypingIndicator Widget
/// Displays an animated typing indicator with three bouncing dots
class BouncingDotsTypingIndicator extends StatefulWidget {
  const BouncingDotsTypingIndicator({super.key});

  @override
  _BouncingDotsTypingIndicatorState createState() =>
      _BouncingDotsTypingIndicatorState();
}

class _BouncingDotsTypingIndicatorState
    extends State<BouncingDotsTypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  @override
  void initState() {
    super.initState();

    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Stagger the animations for a cascading effect
    Future.delayed(
      const Duration(milliseconds: 150),
      () => _controller2.repeat(reverse: true),
    );
    Future.delayed(
      const Duration(milliseconds: 300),
      () => _controller3.repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  /// Builds individual animated dot for the typing indicator
  /// Each dot bounces up and down to simulate typing
  Widget _buildDot(AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -10 * controller.value),
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(_controller1),
          _buildDot(_controller2),
          _buildDot(_controller3),
        ],
      ),
    );
  }
}

/// ChatUtilities Class
/// Contains static utility functions for chat operations and helper methods
class ChatUtilities {
  /// Primary color used throughout the chat interface
  static const Color primaryColor = Color(0xFF2E7D32);

  /// Alternative primary color for gradients
  static const Color primaryColorAlt = Color(0xFF388E3C);

  /// Formats a timestamp into a human-readable string
  /// Returns different formats based on how long ago the message was sent:
  /// - Today: shows time only (e.g., "2:30 PM")
  /// - Yesterday: shows "Yesterday" with time (e.g., "Yesterday 2:30 PM")
  /// - This week: shows day name with time (e.g., "Monday 2:30 PM")
  /// - Older: shows full date with time (e.g., "Dec 15, 2024 2:30 PM")
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time only
      return _formatTimeOnly(timestamp);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${_formatTimeOnly(timestamp)}';
    } else if (difference.inDays < 7) {
      // This week - show day and time
      return _formatDayAndTime(timestamp);
    } else {
      // Older - show full date
      return _formatFullDateTime(timestamp);
    }
  }

  /// Helper method to format time only (e.g., "2:30 PM")
  static String _formatTimeOnly(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Helper method to format day and time (e.g., "Monday 2:30 PM")
  static String _formatDayAndTime(DateTime timestamp) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final day = days[timestamp.weekday - 1];
    return '$day ${_formatTimeOnly(timestamp)}';
  }

  /// Helper method to format full date and time (e.g., "Dec 15, 2024 2:30 PM")
  static String _formatFullDateTime(DateTime timestamp) {
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
    final month = months[timestamp.month - 1];
    final day = timestamp.day;
    final year = timestamp.year;
    return '$month $day, $year ${_formatTimeOnly(timestamp)}';
  }

  /// Determines the appropriate icon for a FAQ category
  /// Used to display visual indicators for different question types
  static IconData getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'admission':
        return Icons.school_outlined;
      case 'scholarship':
        return Icons.attach_money_outlined;
      case 'placement':
        return Icons.work_outline_rounded;
      default:
        return Icons.help_outline;
    }
  }

  /// Validates if a message is empty or contains only whitespace
  /// Returns true if message is valid (non-empty), false otherwise
  static bool isValidMessage(String message) {
    return message.trim().isNotEmpty;
  }

  /// Truncates a long string to a maximum length with ellipsis
  /// Useful for displaying preview text
  /// Example: truncateText("Hello world this is long", 10) = "Hello w..."
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  /// Gets a color based on rating type
  /// Used for like/dislike button styling
  static Color getRatingColor(String ratingType) {
    if (ratingType == 'like') {
      return primaryColor;
    } else if (ratingType == 'dislike') {
      return Colors.red;
    }
    return Colors.grey;
  }

  /// Formats a number to a readable string
  /// Example: 1000 = "1.0K", 1000000 = "1.0M"
  static String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
  }

  /// Validates email format
  /// Returns true if email is valid, false otherwise
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Checks if text contains any URLs
  /// Returns true if URL patterns are found
  static bool containsUrl(String text) {
    final urlRegex = RegExp(
      r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&/=]*)',
    );
    return urlRegex.hasMatch(text);
  }

  /// Checks if text contains any email addresses
  /// Returns true if email patterns are found
  static bool containsEmail(String text) {
    final emailRegex = RegExp(
      r'[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*',
    );
    return emailRegex.hasMatch(text);
  }

  /// Checks if text contains any phone numbers
  /// Returns true if phone number patterns are found
  static bool containsPhoneNumber(String text) {
    final phoneRegex = RegExp(
      r'(?:\+|\d)?(?:\d{1,3})?(?:[-.\s])?(?:\d{3})?(?:[-.\s])?(?:\d{4})',
    );
    return phoneRegex.hasMatch(text);
  }

  /// Extracts all URLs from text
  /// Returns a list of URLs found in the text
  static List<String> extractUrls(String text) {
    final urlRegex = RegExp(
      r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&/=]*)',
    );
    return urlRegex.allMatches(text).map((m) => m.group(0) ?? '').toList();
  }

  /// Extracts all email addresses from text
  /// Returns a list of emails found in the text
  static List<String> extractEmails(String text) {
    final emailRegex = RegExp(
      r'[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*',
    );
    return emailRegex.allMatches(text).map((m) => m.group(0) ?? '').toList();
  }

  /// Gets a readable description for message status
  /// Maps status strings to user-friendly descriptions
  static String getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'read':
        return 'Read';
      case 'error':
        return 'Failed to send';
      case 'pending':
        return 'Sending...';
      default:
        return status;
    }
  }

  /// Gets an icon for message status
  /// Returns appropriate icon based on message status
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      case 'error':
        return Icons.error_outline;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  /// Gets a color for message status icon
  /// Returns color based on message delivery status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
      case 'delivered':
      case 'read':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Converts timestamp to relative time string
  /// Example: "2 minutes ago", "1 hour ago", "3 days ago"
  static String getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Checks if message is very recent (less than 1 minute old)
  static bool isRecentMessage(DateTime timestamp) {
    final now = DateTime.now();
    return now.difference(timestamp).inSeconds < 60;
  }

  /// Calculates word count in text
  static int getWordCount(String text) {
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Calculates character count excluding whitespace
  static int getCharacterCount(String text) {
    return text.replaceAll(RegExp(r'\s'), '').length;
  }

  /// Checks if text is mostly uppercase (3 or more consecutive uppercase letters)
  /// Useful for detecting "shouting" in messages
  static bool containsShoutingPattern(String text) {
    return RegExp(r'[A-Z]{3,}').hasMatch(text);
  }

  /// Sanitizes message text by trimming and removing extra spaces
  static String sanitizeMessage(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Adds line breaks every N characters to prevent long words from breaking layout
  static String wrapText(String text, int charactersPerLine) {
    if (text.length <= charactersPerLine) {
      return text;
    }

    final buffer = StringBuffer();
    var currentLine = '';

    for (var i = 0; i < text.length; i++) {
      currentLine += text[i];
      if (currentLine.length >= charactersPerLine && text[i] == ' ') {
        buffer.writeln(currentLine.trim());
        currentLine = '';
      }
    }

    if (currentLine.isNotEmpty) {
      buffer.write(currentLine);
    }

    return buffer.toString();
  }

  /// Converts emoji to description for accessibility
  /// Maps common emojis to text descriptions
  static String emojiToDescription(String emoji) {
    final emojiMap = {
      '😀': 'smiling face',
      '😂': 'face with tears of joy',
      '❤️': 'red heart',
      '👍': 'thumbs up',
      '👎': 'thumbs down',
      '🎉': 'party popper',
      '🚀': 'rocket',
      '✅': 'check mark',
      '❌': 'cross mark',
      '⚠️': 'warning',
    };
    return emojiMap[emoji] ?? emoji;
  }

  /// Creates a gradient between two colors
  /// Useful for creating message bubble gradients
  static LinearGradient createGradient(
    Color color1,
    Color color2, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: [color1, color2]);
  }

  /// Gets contrast color (black or white) based on background color
  /// Useful for determining text color for readability
  static Color getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Compresses text to fit within character limit
  /// Removes unnecessary words and shortens phrases
  static String compressText(String text, int maxCharacters) {
    if (text.length <= maxCharacters) {
      return text;
    }

    // Remove common filler words
    final fillers = [
      ' really',
      ' very',
      ' basically',
      ' literally',
      ' actually',
    ];
    var compressed = text;

    for (var filler in fillers) {
      compressed = compressed.replaceAll(filler, '');
      if (compressed.length <= maxCharacters) {
        return compressed;
      }
    }

    // Truncate if still too long
    return '${text.substring(0, maxCharacters - 3)}...';
  }

  /// Generates a unique identifier for messages
  /// Based on timestamp and random component
  static String generateMessageId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Validates conversation ID format
  static bool isValidConversationId(String conversationId) {
    return conversationId.isNotEmpty && conversationId.length >= 8;
  }

  /// Gets readable conversation duration
  /// Example: "2 hours", "3 days"
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inDays}d';
    }
  }

  /// Capitalizes first letter of each word
  static String capitalizeWords(String text) {
    return text
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : '',
        )
        .join(' ');
  }

  /// Removes all special characters from text
  static String removeSpecialCharacters(String text) {
    return text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
  }

  /// Counts occurrences of a substring in text
  static int countOccurrences(String text, String substring) {
    return substring.isEmpty
        ? 0
        : (text.length - text.replaceAll(substring, '').length) ~/
            substring.length;
  }

  /// Highlights search results in text
  /// Returns text with search term highlighted with special markers
  static String highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) return text;
    return text.replaceAllMapped(
      RegExp(searchTerm, caseSensitive: false),
      (match) => '[HIGHLIGHT]${match.group(0)}[/HIGHLIGHT]',
    );
  }

  /// Generates initials from a name
  /// Example: "John Doe" -> "JD"
  static String generateInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].length > 0 ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0].toUpperCase()}${parts[parts.length - 1][0].toUpperCase()}';
  }

  /// Validates message safety (basic content filtering)
  /// Returns false if message contains potentially problematic patterns
  static bool isSafeMessage(String message) {
    final suspiciousPatterns = [
      RegExp(r'href=', caseSensitive: false),
      RegExp(r'script>', caseSensitive: false),
      RegExp(r'onclick=', caseSensitive: false),
    ];

    for (var pattern in suspiciousPatterns) {
      if (pattern.hasMatch(message)) {
        return false;
      }
    }
    return true;
  }

  /// Gets a random color from a predefined palette
  /// Useful for assigning colors to different users/categories
  static Color getRandomColor([int seed = 0]) {
    final colors = [
      Color(0xFF2E7D32),
      Color(0xFF1976D2),
      Color(0xFF388E3C),
      Color(0xFFD32F2F),
      Color(0xFFF57C00),
      Color(0xFF7B1FA2),
    ];
    return colors[seed % colors.length];
  }
}

class MessageLimitDialog extends StatefulWidget {
  final Duration timeUntilReset;

  const MessageLimitDialog({Key? key, required this.timeUntilReset})
    : super(key: key);

  @override
  State<MessageLimitDialog> createState() => _MessageLimitDialogState();
}

class _MessageLimitDialogState extends State<MessageLimitDialog> {
  late Duration _remainingTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.timeUntilReset;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingTime = _remainingTime - Duration(seconds: 1);

        if (_remainingTime.isNegative) {
          timer.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Message Limit Reached',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You\'ve used all 10 messages today',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Countdown Timer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 48,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Next reset in:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_remainingTime),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Resets daily at 6:00 AM',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This limit helps us provide quality service to all users. You can send 10 more messages after the reset.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageLimitWarningDialog extends StatelessWidget {
  final int remainingMessages;
  final Duration timeUntilReset;

  const MessageLimitWarningDialog({
    Key? key,
    required this.remainingMessages,
    required this.timeUntilReset,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Running Low on Messages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You\'re approaching your daily limit',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Remaining messages indicator
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$remainingMessages message${remainingMessages == 1 ? '' : 's'} left',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'out of 10 daily messages',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reset info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resets in ${_formatDuration(timeUntilReset)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Limit resets daily at 6:00 AM',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
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
            ),

            // Close button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  //  Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          () =>
                              Navigator.of(context).pop(false), // Returns false
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  //  MODIFIED: Send anyway button
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).pop(true), // Returns true
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Send Anyway',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
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
}
