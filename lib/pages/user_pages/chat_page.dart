import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_project/models/notification.dart';
import 'package:capstone_project/responsive/user_constant.dart';

import 'package:capstone_project/models/message.dart';
import 'package:capstone_project/provider/chat_provider.dart';

import 'package:capstone_project/services/file_service2.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_utilities.dart';
import 'faq_section.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String? initialMessage;
  final bool showFAQs;
  final VoidCallback? onFAQToggle;

  const ChatPage({
    Key? key,
    required this.conversationId,
    this.initialMessage,
    this.showFAQs = false,
    this.onFAQToggle,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FileService _fileService = FileService();
  String? actualConversationId;
  bool isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _micAnimationController;
  late AnimationController _attachmentAnimationController;
  late Animation<double> _micScaleAnimation;
  late Animation<double> _attachmentRotationAnimation;

  String? _expandedCategory;
  String? _selectedConversationId;
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  late ChatProvider chatProvider;

  bool _showAttachmentOptions = false;
  bool _showFAQs = false;

bool _isLoadingConversation = false;

// Updated initState() method
@override
void initState() {
  super.initState();

  _micAnimationController = AnimationController(
    duration: Duration(milliseconds: 200),
    vsync: this,
  );
  _attachmentAnimationController = AnimationController(
    duration: Duration(milliseconds: 300),
    vsync: this,
  );

  _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
    CurvedAnimation(
      parent: _micAnimationController,
      curve: Curves.elasticOut,
    ),
  );

  _attachmentRotationAnimation = Tween<double>(
    begin: 0.0,
    end: 0.125,
  ).animate(
    CurvedAnimation(
      parent: _attachmentAnimationController,
      curve: Curves.easeInOut,
    ),
  );

  // FIXED: Initialize FAQ state from widget parameter
  _showFAQs = widget.showFAQs;

  _setupConversation();

  chatProvider = Provider.of<ChatProvider>(context, listen: false);

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (widget.conversationId.isNotEmpty) {
      setState(() {
        _isLoadingConversation = true;
      });

      try {
        await chatProvider.setConversationId(widget.conversationId);
        
        // Wait for messages to load
        await Future.delayed(Duration(milliseconds: 500));
        
        // Check if there are messages and update FAQ state accordingly
        final hasMessages = chatProvider.messages.isNotEmpty;
        
        if (mounted) {
          setState(() {
            _selectedConversationId = widget.conversationId;
            // Close FAQs if conversation has messages
            _showFAQs = !hasMessages;
            _isLoadingConversation = false;
          });
        }
        
        print('DEBUG: ChatPage loaded. Messages: ${chatProvider.messages.length}, Show FAQs: $_showFAQs');
      } catch (e) {
        print('DEBUG: Error loading conversation: $e');
        if (mounted) {
          setState(() {
            _isLoadingConversation = false;
          });
        }
      }
    } else {
      chatProvider.clearMessages();
      // Show FAQs for empty conversation
      setState(() {
        _showFAQs = true;
        _isLoadingConversation = false;
      });
    }
  });
}

// Updated didUpdateWidget to handle loading state IMMEDIATELY
@override
void didUpdateWidget(ChatPage oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // Handle conversation ID changes FIRST - show loading immediately
  if (widget.conversationId != oldWidget.conversationId) {
    // IMMEDIATELY show loading indicator when conversation changes
    setState(() {
      _isLoadingConversation = true;
    });
    
    print('DEBUG: Conversation changing from ${oldWidget.conversationId} to ${widget.conversationId}');

    if (widget.conversationId.isNotEmpty) {
      // Load the new conversation
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          await chatProvider.setConversationId(widget.conversationId);
          
          await Future.delayed(Duration(milliseconds: 500));
          
          final hasMessages = chatProvider.messages.isNotEmpty;
          
          if (mounted) {
            setState(() {
              _showFAQs = !hasMessages;
              _isLoadingConversation = false;
            });
          }
          
          print('DEBUG: Conversation changed. Messages: ${chatProvider.messages.length}, Show FAQs: $_showFAQs');
        } catch (e) {
          print('DEBUG: Error updating conversation: $e');
          if (mounted) {
            setState(() {
              _isLoadingConversation = false;
            });
          }
        }
      });
    } else {
      // Empty conversation ID - clear messages and show FAQs
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.clearMessages();
      
      if (mounted) {
        setState(() {
          _showFAQs = true;
          _isLoadingConversation = false;
        });
      }
    }
    return; // Exit early since we handled conversation change
  }
  
  // Update local state when parent changes showFAQs (only if conversation didn't change)
  if (widget.showFAQs != oldWidget.showFAQs) {
    setState(() {
      _showFAQs = widget.showFAQs;
    });
    print('DEBUG: ChatPage received FAQ state update: $_showFAQs');
  }
}

// Add this new method to build the loading indicator
Widget _buildLoadingIndicator() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated loading spinner
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              strokeWidth: 3,
            ),
          ),
        ),
        SizedBox(height: 24),
        // Loading text
        Text(
          'Loading chat...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 8),
        // Subtle hint text
        Text(
          'Please wait a moment',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    ),
  );
}

  Future<void> _setupConversation() async {
    try {
      String conversationId;

      if (widget.conversationId.isEmpty) {
        if (widget.initialMessage != null) {
          conversationId = await UserConstant.createNewConversation();
        } else {
          conversationId = widget.conversationId;
        }
      } else {
        conversationId = widget.conversationId;
      }

      if (mounted) {
        setState(() {
          actualConversationId = conversationId;
          isLoading = false;
        });

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.setConversationId(conversationId);

        if (widget.initialMessage != null) {
          await Future.delayed(Duration(milliseconds: 500));

          final userMessage = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            conversationId: conversationId,
            content: widget.initialMessage!.trim(),
            sender: 'user',
            status: 'sent',
            type: 'text',
            sentAt: DateTime.now(),
          );
          await chatProvider.saveMessageToFirebase(conversationId, userMessage);
        }
      }
    } catch (e) {
      print('DEBUG: Error setting up conversation: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        
      }
    }
  }

  void _toggleFAQsDisplay() {
    HapticFeedback.lightImpact();
    setState(() {
      _showFAQs = !_showFAQs;
    });

    if (widget.onFAQToggle != null) {
      widget.onFAQToggle!();
    }
  }

  void _onFAQSelected(String question) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.incrementFAQSimilarityCount(question);

    // Set the question in the text field
    _controller.text = question;

    // Automatically hide FAQs
    setState(() {
      _expandedCategory = null;
      _showFAQs = false;
    });

    // Automatically send the message after a brief delay
    // This allows the UI to update smoothly
    Future.delayed(Duration(milliseconds: 100), () {
      _sendMessage(chatProvider);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Message message, bool isUser) {
    return FutureBuilder<String?>(
      future: isUser ? _getUserAvatarUrl() : null,
      builder: (context, snapshot) {
        return GestureDetector(
          onLongPress: () => _showMessageOptions(context, message),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser)
                  Container(
                    width: 32,
                    height: 32,
                    margin: EdgeInsets.only(right: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFF2E7D32).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'lib/images/oasp.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.smart_toy_outlined,
                            color: Color(0xFF2E7D32),
                            size: 18,
                          );
                        },
                      ),
                    ),
                  ),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient:
                          isUser
                              ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                              )
                              : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Colors.grey.shade50],
                              ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isUser
                                  ? Color(0xFF2E7D32).withOpacity(0.3)
                                  : Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Linkify(
                          onOpen: _onLinkTap,
                          text: message.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.grey.shade800,
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          linkStyle: TextStyle(
                            decoration: TextDecoration.underline,
                            color: isUser ? Colors.yellow[100] : Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                          options: LinkifyOptions(
                            humanize: false,
                            looseUrl: true,
                            defaultToHttps: true,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          _formatTimestamp(message.sentAt),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isUser ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        if (!isUser && message.sender == 'bot') ...[
                          _buildLikeDislikeButtons(message),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isUser)
                  Container(
                    width: 32,
                    height: 32,
                    margin: EdgeInsets.only(left: 8, bottom: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFF2E7D32).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child:
                          snapshot.data != null
                              ? CachedNetworkImage(
                                imageUrl: snapshot.data!,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (context, url, error) =>
                                        _buildDefaultUserAvatar(),
                              )
                              : _buildDefaultUserAvatar(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikeDislikeButtons(Message message) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Provider.of<ChatProvider>(
        context,
        listen: false,
      ).getMessageRating(message.id),
      builder: (context, snapshot) {
        final ratingData = snapshot.data;
        final currentRating = ratingData?['rating'];

        return Container(
          margin: EdgeInsets.only(top: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _handleLikeDislike(message.id, true),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        currentRating == 'like'
                            ? Color(0xFF2E7D32).withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          currentRating == 'like'
                              ? Color(0xFF2E7D32)
                              : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 16,
                        color:
                            currentRating == 'like'
                                ? Color(0xFF2E7D32)
                                : Colors.grey.shade600,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Helpful',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              currentRating == 'like'
                                  ? Color(0xFF2E7D32)
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              InkWell(
                onTap: () => _handleLikeDislike(message.id, false, message),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        currentRating == 'dislike'
                            ? Colors.red.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          currentRating == 'dislike'
                              ? Colors.red
                              : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thumb_down_outlined,
                        size: 16,
                        color:
                            currentRating == 'dislike'
                                ? Colors.red
                                : Colors.grey.shade600,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Not helpful',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              currentRating == 'dislike'
                                  ? Colors.red
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLikeDislike(
    String messageId,
    bool isLike, [
    Message? message,
  ]) async {
    await Provider.of<ChatProvider>(
      context,
      listen: false,
    ).rateMessage(messageId, isLike);

    if (!isLike && message != null) {
      final bool? escalate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Escalate to Staff?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This response wasn't helpful. Would you like to escalate this message to staff for human assistance?",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    "A staff member will review your conversation and provide personalized assistance.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Yes, Escalate',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );

      if (escalate == true) {
        await _processManualEscalation(message);
      }
    }
  }

  Future<void> _processManualEscalation(Message message) async {
    try {
      String userQuestion = '';
      String botAnswer = '';

      if (message.sender == 'bot') {
        botAnswer = message.content;

        final userMessages =
            Provider.of<ChatProvider>(context, listen: false).messages
                .where(
                  (m) =>
                      m.sender == 'user' &&
                      m.conversationId == message.conversationId &&
                      m.sentAt.isBefore(message.sentAt),
                )
                .toList();

        if (userMessages.isNotEmpty) {
          userMessages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
          userQuestion = userMessages.first.content;
        }
      } else {
        userQuestion = message.content;
        botAnswer = 'No bot response available';
      }

      final escalationId = _firestore.collection('escalations').doc().id;
      final escalatedData = {
        'escalationId': escalationId,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'conversationId': message.conversationId,
        'question': userQuestion,
        'botAnswer': botAnswer,
        'status': 'pending',
        'reason': 'User reported as not helpful',
        'createdAt': Timestamp.now(),
        'messageId': message.id,
      };

      await _firestore.collection('escalations').add(escalatedData);
      print('Manual escalation logged for message ${message.id}');

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      final userNotification = Notifications(
        notificationId: _firestore.collection('notifications').doc().id,
        userId: currentUserId,
        title: 'Your message was escalated',
        body:
            'You reported a message as not helpful. Staff will review your question and respond.',
        type: 'escalation',
        relatedId: escalationId,
        targetRole: 'user',
        read: false,
        createdAt: Timestamp.now(),
      );
      await _firestore
          .collection('notifications')
          .add(userNotification.toMap());

      final staffNotification = Notifications(
        notificationId: _firestore.collection('notifications').doc().id,
        userId: null,
        title: 'Manual escalation reported',
        body:
            'A user reported a bot message as not helpful. Please review and respond.',
        type: 'escalation',
        relatedId: escalationId,
        targetRole: 'staff',
        read: false,
        createdAt: Timestamp.now(),
      );
      await _firestore
          .collection('notifications')
          .add(staffNotification.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your request has been escalated to staff. We\'ll get back to you soon!',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error creating manual escalation: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Failed to escalate. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<String?> _getUserAvatarUrl() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['profileImage'] as String?;
      }
    } catch (e) {
      print('Error getting user avatar: $e');
    }
    return null;
  }

  Widget _buildDefaultUserAvatar() {
    return Container(
      color: Color(0xFF2E7D32),
      child: Center(child: Icon(Icons.person, color: Colors.white, size: 18)),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE h:mm a').format(timestamp);
    } else {
      return DateFormat('MMM d, y h:mm a').format(timestamp);
    }
  }

  Future<void> _onLinkTap(LinkableElement link) async {
    final url = link.url;

    try {
      if (url.startsWith('tel:')) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Clipboard.setData(
            ClipboardData(text: url.replaceFirst('tel:', '')),
          );
          if (mounted) {
            _showSnackBar('Phone number copied to clipboard', Icons.phone);
          }
        }
      } else if (url.startsWith('mailto:')) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Clipboard.setData(
            ClipboardData(text: url.replaceFirst('mailto:', '')),
          );
          if (mounted) {
            _showSnackBar('Email copied to clipboard', Icons.email);
          }
        }
      } else {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            _showSnackBar('Link copied to clipboard', Icons.link);
          }
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        _showSnackBar('Link copied to clipboard', Icons.content_copy);
      }
    }
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: Color(0xFF2E7D32)),
                  title: Text('Copy Message'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Message copied to clipboard'),
                        backgroundColor: Color(0xFF2E7D32),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: Colors.grey.shade600,
                  ),
                  title: Text('Message Info'),
                  subtitle: Text(_formatTimestamp(message.sentAt)),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatProvider chatProvider) async {
    final text = _controller.text.trim();
    if (text.isEmpty || chatProvider.isLoading) return;

    _controller.clear();

    try {
      await chatProvider.askQuestion(context, text);
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error sending message: ${e.toString()}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _conversationsSubscription?.cancel();
    _micAnimationController.dispose();
    _attachmentAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_showFAQs && !_isLoadingConversation) _scrollToBottom();
          });

          final messages = chatProvider.messages;

          return Column(
          children: [
            Expanded(
              child: _isLoadingConversation
                  ? _buildLoadingIndicator()
                  : (_showFAQs
                      ? FAQSection(onFAQSelected: _onFAQSelected)
                      : (messages.isEmpty
                          ? _buildEmptyChatState()
                          : _buildMessagesList(messages, chatProvider))),
            ),
            FAQInputSection(
              controller: _controller,
              showFAQs: _showFAQs,
              isLoading: chatProvider.isLoading || _isLoadingConversation,
              onFAQToggle: _toggleFAQsDisplay,
              onSendMessage: () => _sendMessage(chatProvider),
            ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the empty chat state
  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Image.asset('lib/images/oasp.png', fit: BoxFit.contain),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Start Chatting!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Type a message below or tap the help icon to see FAQs',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the messages list
  Widget _buildMessagesList(List<Message> messages, ChatProvider chatProvider) {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: BouncingScrollPhysics(),
      itemCount: messages.length + (chatProvider.isLoading ? 1 : 0),
      padding: EdgeInsets.symmetric(vertical: 20),
      itemBuilder: (context, index) {
        // Show typing indicator as last item when loading
        if (index == messages.length && chatProvider.isLoading) {
          return _buildTypingIndicator();
        }

        final Message message = messages[index];
        final bool isUser = message.sender == 'user';

        return _buildMessageBubble(message, isUser);
      },
    );
  }

  /// Builds the typing indicator
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(left: 12, right: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF2E7D32).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'lib/images/oasp.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.smart_toy_outlined,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    );
                  },
                ),
              ),
            ),
            BouncingDotsTypingIndicator(),
          ],
        ),
      ),
    );
  }
}
