import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:capstone_project/pages/user_pages/typewriter.dart';
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
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart';

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
  final Map<String, String?> _localRatings = {};

  String? actualConversationId;
  bool isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<FAQSectionState> _faqSectionKey =
      GlobalKey<FAQSectionState>();

  late AnimationController _micAnimationController;
  late AnimationController _attachmentAnimationController;
  late Animation<double> _micScaleAnimation;
  late Animation<double> _attachmentRotationAnimation;

  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';

  final Map<String, bool> _completedTypewriterMessages = {};
  bool _isTyping = false;
  final Set<String> _initialMessageIds =
      {}; // Track messages that existed on load

  String? _expandedCategory;
  String? _selectedConversationId;
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  late ChatProvider chatProvider;

  bool _showAttachmentOptions = false;
  bool _showFAQs = false;

  bool _isLoadingConversation = false;

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

    _showFAQs = widget.showFAQs;

    _initChatSpeechToText();
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

          // ✅ IMPORTANT: Wait for messages to load
          await Future.delayed(Duration(milliseconds: 800));

          // Mark all loaded messages as initial (don't typewrite them)
          for (var message in chatProvider.messages) {
            _initialMessageIds.add(message.id);
          }

          final hasMessages = chatProvider.messages.isNotEmpty;

          if (mounted) {
            setState(() {
              _selectedConversationId = widget.conversationId;
              _showFAQs = !hasMessages;
              _isLoadingConversation = false;
            });

            // ✅ NEW: Check for any escalation responses
            await _checkAndLoadEscalationResponses();
          }

          print(
            'DEBUG: ChatPage loaded. Messages: ${chatProvider.messages.length}, Show FAQs: $_showFAQs',
          );
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
        setState(() {
          _showFAQs = true;
          _isLoadingConversation = false;
        });
      }
    });
  }

  Future<void> _checkAndLoadEscalationResponses() async {
    if (widget.conversationId.isEmpty) return;

    try {
      print(
        '🔍 Checking for escalation responses in conversation: ${widget.conversationId}',
      );

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Query escalations for this conversation that have staff responses
      final escalationsSnapshot =
          await _firestore
              .collection('escalations')
              .where('conversationId', isEqualTo: widget.conversationId)
              .where('status', isEqualTo: 'resolved')
              .get();

      if (escalationsSnapshot.docs.isEmpty) {
        print('ℹ️ No resolved escalations found');
        return;
      }

      print('✅ Found ${escalationsSnapshot.docs.length} resolved escalations');

      for (var escalationDoc in escalationsSnapshot.docs) {
        final escalation = escalationDoc.data();
        final staffResponse = escalation['staffResponse'] as String?;
        final respondedBy = escalation['respondedBy'] as String? ?? 'Staff';
        final messageId = escalation['messageId'] as String?;
        final escalationId = escalationDoc.id;

        if (staffResponse == null || staffResponse.isEmpty) continue;

        // ✅ CRITICAL FIX: Check if staff response already exists in Firestore
        final existingStaffMessages =
            await _firestore
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .where('sender', isEqualTo: 'staff')
                .where(
                  'content',
                  isEqualTo:
                      '**Staff Response from $respondedBy:**\n\n$staffResponse',
                )
                .limit(1)
                .get();

        if (existingStaffMessages.docs.isNotEmpty) {
          print(
            'ℹ️ Staff response already exists in Firestore for escalation $escalationId',
          );
          continue;
        }

        // Also check in-memory messages
        final existingInMemory = chatProvider.messages.any(
          (msg) => msg.content.contains(staffResponse) && msg.sender == 'staff',
        );

        if (existingInMemory) {
          print(
            'ℹ️ Staff response already exists in memory for escalation $escalationId',
          );
          continue;
        }

        print('📝 Adding staff response to chat for escalation $escalationId');

        // Create a staff message
        final staffMessageRef =
            _firestore
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .doc();

        final staffMessage = Message(
          id: staffMessageRef.id,
          conversationId: widget.conversationId,
          content: '**Staff Response from $respondedBy:**\n\n$staffResponse',
          sender: 'staff',
          status: 'sent',
          type: 'text',
          sentAt: DateTime.now(),
        );

        // Save to Firestore
        await chatProvider.saveMessageToFirebase(
          widget.conversationId,
          staffMessage,
        );

        // Update the original escalated message
        if (messageId != null && messageId.isNotEmpty) {
          try {
            await _firestore
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .doc(messageId)
                .update({
                  'escalationResolved': true,
                  'escalationResponse': staffResponse,
                  'escalationRespondedBy': respondedBy,
                  'escalationRespondedAt': Timestamp.now(),
                  'escalationId': escalationId,
                });

            print(
              '✅ Updated original message $messageId with escalation response',
            );
          } catch (e) {
            print('⚠️ Could not update original message: $e');
          }
        }
      }

      // Refresh messages
      await chatProvider.loadExistingMessages();
    } catch (e) {
      print('❌ Error checking escalation responses: $e');
    }
  }

  Future<void> _initChatSpeechToText() async {
    _speechToText = stt.SpeechToText();
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          print('Chat speech recognition error: $error');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onStatus: (status) {
          print('Chat speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
      );
      print('Chat speech recognition available: $_speechAvailable');
    } catch (e) {
      print('Failed to initialize chat speech recognition: $e');
      _speechAvailable = false;
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSnackBar(
        'Speech recognition not available on this device',
        Icons.mic_off,
      );
      return;
    }

    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        _showSnackBar('Microphone permission denied', Icons.mic_off);
        return;
      }
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
      _micAnimationController.reverse();
    } else {
      setState(() {
        _isListening = true;
        _lastWords = '';
      });
      _micAnimationController.repeat(reverse: true);

      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _controller.text = _lastWords;
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }

    HapticFeedback.mediumImpact();
  }

  void _handleMicrophoneTap() {
    if (_showFAQs) {
      _faqSectionKey.currentState?.toggleSpeechRecognition();
    } else {
      _toggleListening();
    }
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.conversationId != oldWidget.conversationId) {
      setState(() {
        _isLoadingConversation = true;
      });

      print(
        'DEBUG: Conversation changing from ${oldWidget.conversationId} to ${widget.conversationId}',
      );

      if (widget.conversationId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final chatProvider = Provider.of<ChatProvider>(
              context,
              listen: false,
            );
            await chatProvider.setConversationId(widget.conversationId);

            await Future.delayed(Duration(milliseconds: 500));

            // Mark all loaded messages as initial (don't typewrite them)
            _initialMessageIds.clear();
            for (var message in chatProvider.messages) {
              _initialMessageIds.add(message.id);
            }

            final hasMessages = chatProvider.messages.isNotEmpty;

            if (mounted) {
              setState(() {
                _showFAQs = !hasMessages;
                _isLoadingConversation = false;
              });
            }

            print(
              'DEBUG: Conversation changed. Messages: ${chatProvider.messages.length}, Show FAQs: $_showFAQs',
            );
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
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.clearMessages();

        if (mounted) {
          setState(() {
            _showFAQs = true;
            _isLoadingConversation = false;
          });
        }
      }
      return;
    }

    if (widget.showFAQs != oldWidget.showFAQs) {
      setState(() {
        _showFAQs = widget.showFAQs;
      });
      print('DEBUG: ChatPage received FAQ state update: $_showFAQs');
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          Text(
            'Please wait a moment',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<void> _setupConversation() async {
    try {
      String conversationId;
         final user = FirebaseAuth.instance.currentUser;

      if (widget.conversationId.isEmpty) {
        if (widget.initialMessage != null) {
          conversationId = await UserConstant.createNewConversation(user!.uid);
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
  print('📝 FAQ selected: $question');
  
  final chatProvider = Provider.of<ChatProvider>(context, listen: false);
  chatProvider.incrementFAQSimilarityCount(question);

  // ✅ Set the question in the controller
  _controller.text = question;

  // ✅ Close FAQs immediately
  if (mounted) {
    setState(() {
      _expandedCategory = null;
      _showFAQs = false;
    });
  }

  // ✅ Send the message after a short delay
  Future.delayed(Duration(milliseconds: 150), () {
    if (mounted && !chatProvider.isLoading) {
      _sendMessage(chatProvider);
    }
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
      // Get streaming content if this message is currently streaming
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final streamingContent = chatProvider.getStreamingContent(message.id);
      final isStreaming = streamingContent != null;
      
      // ✅ FIX: Use streaming content ONLY if streaming, otherwise use message content
      final displayContent = isStreaming ? streamingContent : message.content;
      
      // Check if this is a new message that just arrived (for initial messages, skip typewriter)
      final isNewMessage = !_initialMessageIds.contains(message.id);
      
      // ✅ FIX: Only show typing cursor while actively streaming AND not empty
      final showTypingCursor = isStreaming && displayContent.isNotEmpty;
      
      final isEscalatedMessage = message.sender == 'bot' && message.rating == 'dislike';
      
      return FutureBuilder<Map<String, dynamic>?>(
        future: isEscalatedMessage ? _getEscalationStatus(message.id) : Future.value(null),
        builder: (context, escalationSnapshot) {
          final escalationData = escalationSnapshot.data;
          final isEscalated = escalationData != null;
          final isResolved = escalationData?['status'] == 'resolved';
          
          return GestureDetector(
            onLongPress: () => _showMessageOptions(context, message),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isEscalated)
                    Container(
                      margin: EdgeInsets.only(bottom: 4, left: isUser ? 0 : 44),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isResolved ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isResolved ? Colors.green.shade300 : Colors.orange.shade300
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isResolved ? Icons.check_circle : Icons.support_agent,
                            size: 14,
                            color: isResolved ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isResolved ? 'Resolved by staff' : 'Escalated to staff',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isResolved ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser)
                        Container(
                          width: 32,
                          height: 32,
                          margin: EdgeInsets.only(right: 8, bottom: 4),
                          decoration: BoxDecoration(
                            color: message.sender == 'staff' 
                                ? Colors.blue.shade100 
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: message.sender == 'staff'
                                  ? Colors.blue.shade300
                                  : Color(0xFF2E7D32).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: message.sender == 'staff'
                                ? Icon(
                                    Icons.support_agent,
                                    color: Colors.blue.shade700,
                                    size: 18,
                                  )
                                : Image.asset(
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
                            gradient: isUser
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                                  )
                                : message.sender == 'staff'
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Colors.blue.shade50, Colors.blue.shade100],
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
                                color: isUser
                                    ? Color(0xFF2E7D32).withOpacity(0.3)
                                    : Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Display content without inline cursor
                              isUser 
                                  ? // User messages - plain text with links
                                    Linkify(
                                      onOpen: _onLinkTap,
                                      text: displayContent,
                                      textAlign: TextAlign.justify,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      linkStyle: TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Colors.yellow[100],
                                        fontWeight: FontWeight.w600,
                                      ),
                                      options: LinkifyOptions(
                                        humanize: false,
                                        looseUrl: true,
                                        defaultToHttps: true,
                                      ),
                                    )
                                  : // Bot/Staff messages - markdown support
                                    MarkdownBody(
                                      data: displayContent,
                                      selectable: true,
                                      onTapLink: (text, href, title) {
                                        if (href != null) {
                                          _onLinkTap(LinkableElement(href, text));
                                        }
                                      },
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade800,
                                          fontSize: 15,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        strong: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade900,
                                        ),
                                        em: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade800,
                                        ),
                                        a: TextStyle(
                                          decoration: TextDecoration.underline,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        listBullet: TextStyle(
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade800,
                                          fontSize: 15,
                                        ),
                                        h1: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade900,
                                        ),
                                        h2: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade900,
                                        ),
                                        h3: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: message.sender == 'staff'
                                              ? Colors.blue.shade900
                                              : Colors.grey.shade900,
                                        ),
                                        code: TextStyle(
                                          backgroundColor: Colors.grey.shade100,
                                          color: Colors.red.shade700,
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                        blockquote: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        blockquoteDecoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border(
                                            left: BorderSide(
                                              color: Colors.grey.shade400,
                                              width: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      extensionSet: md.ExtensionSet(
                                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                                        [
                                          md.EmojiSyntax(),
                                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
                                        ],
                                      ),
                                    ),
                              // ✅ FIX: Show cursor below the text when streaming
                              if (showTypingCursor) ...[
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildTypingCursor(),
                                ),
                              ],
                              SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTimestamp(message.sentAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isUser ? Colors.white70 : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isStreaming) ...[
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isUser ? Colors.white70 : Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!isUser && message.sender == 'bot' && !isStreaming && (!isEscalated || !isResolved)) ...[
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
                            child: snapshot.data != null
                                ? CachedNetworkImage(
                                    imageUrl: snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        _buildDefaultUserAvatar(),
                                  )
                                : _buildDefaultUserAvatar(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ✅ NEW: Simpler typing cursor widget
Widget _buildTypingCursor() {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: Duration(milliseconds: 530),
    builder: (context, value, child) {
      return Opacity(
        opacity: value > 0.5 ? 1.0 : 0.0,
        child: Container(
          width: 8,
          height: 2,
          decoration: BoxDecoration(
            color: Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    },
    onEnd: () {
      // Restart animation
      if (mounted) {
        setState(() {});
      }
    },
  );
}

  Future<Map<String, dynamic>?> _getEscalationStatus(String messageId) async {
    try {
      final escalationSnapshot =
          await _firestore
              .collection('escalations')
              .where('messageId', isEqualTo: messageId)
              .limit(1)
              .get();

      if (escalationSnapshot.docs.isEmpty) {
        return null;
      }

      return escalationSnapshot.docs.first.data();
    } catch (e) {
      print('Error getting escalation status: $e');
      return null;
    }
  }

  Future<bool> _checkIfMessageEscalated(String messageId) async {
    try {
      final escalationSnapshot =
          await _firestore
              .collection('escalations')
              .where('messageId', isEqualTo: messageId)
              .limit(1)
              .get();

      return escalationSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking escalation: $e');
      return false;
    }
  }

  Widget _buildLikeDislikeButtons(Message message) {
    final localRating = _localRatings[message.id];

    if (localRating != null) {
      return _buildRatingButtonsUI(message.id, localRating, message);
    }

    final cachedRating = Provider.of<ChatProvider>(
      context,
      listen: false,
    ).getCachedRating(message.id);

    if (cachedRating != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_localRatings.containsKey(message.id)) {
          setState(() {
            _localRatings[message.id] = cachedRating;
          });
        }
      });
      return _buildRatingButtonsUI(message.id, cachedRating, message);
    }

    if (message.rating != null && message.rating!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_localRatings.containsKey(message.id)) {
          setState(() {
            _localRatings[message.id] = message.rating;
          });
        }
      });
      return _buildRatingButtonsUI(message.id, message.rating, message);
    }

    return _buildRatingButtonsUI(message.id, null, message);
  }

  Widget _buildRatingButtonsUI(
    String messageId,
    String? currentRating,
    Message message,
  ) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _handleLikeDislike(messageId, true),
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
            onTap: () => _handleLikeDislike(messageId, false, message),
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
  }

  Future<void> _handleLikeDislike(
    String messageId,
    bool isLike, [
    Message? message,
  ]) async {
    if (!mounted) return;

    if (widget.conversationId.isEmpty) {
      print('Error: No conversation ID available');
      if (mounted) {
        _showSnackBar('Unable to rate message', Icons.error);
      }
      return;
    }

    setState(() {
      _localRatings[messageId] = isLike ? 'like' : 'dislike';
    });

    try {
      await Provider.of<ChatProvider>(
        context,
        listen: false,
      ).rateMessage(messageId, isLike, widget.conversationId);
    } catch (e) {
      print('Error rating message: $e');
      if (mounted) {
        setState(() {
          _localRatings.remove(messageId);
        });
        _showSnackBar('Failed to save rating', Icons.error);
      }
      return;
    }

    if (!isLike && message != null && mounted) {
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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

      if (escalate == true && mounted) {
        await _processManualEscalation(message);
      }
    }
  }

  Future<void> _processManualEscalation(Message message) async {
    final reasonController = TextEditingController();
    String selectedReason = 'Bot response not accurate';

    try {
      final bool? shouldEscalate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Escalate to Staff?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
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
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Select a reason:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('Bot response not accurate'),
                              value: 'Bot response not accurate',
                              groupValue: selectedReason,
                              onChanged:
                                  (val) =>
                                      setState(() => selectedReason = val!),
                              dense: true,
                            ),
                            RadioListTile<String>(
                              title: const Text(
                                'Bot did not understand my question',
                              ),
                              value: 'Bot did not understand my question',
                              groupValue: selectedReason,
                              onChanged:
                                  (val) =>
                                      setState(() => selectedReason = val!),
                              dense: true,
                            ),
                            RadioListTile<String>(
                              title: const Text(
                                'Need clarification from staff',
                              ),
                              value: 'Need clarification from staff',
                              groupValue: selectedReason,
                              onChanged:
                                  (val) =>
                                      setState(() => selectedReason = val!),
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Additional details (optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText:
                                'e.g., "I need more specific information about scholarship deadlines"',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                            counterStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
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
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Yes, Escalate',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
          );
        },
      );

      if (shouldEscalate != true || !mounted) return;

      final userReason = reasonController.text.trim();
      final fullReason =
          userReason.isNotEmpty
              ? '$selectedReason — $userReason'
              : selectedReason;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final messages = chatProvider.messages;

      String userQuestion = 'No question found';

      final botMessageIndex = messages.indexWhere((m) => m.id == message.id);

      if (botMessageIndex > 0) {
        for (int i = botMessageIndex - 1; i >= 0; i--) {
          if (messages[i].sender == 'user') {
            userQuestion = messages[i].content;
            break;
          }
        }
      }

      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      final escalatedData = {
        'escalationId': escalationId,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'conversationId': message.conversationId,
        'question': userQuestion,
        'botAnswer':
            message.sender == 'bot'
                ? message.content
                : 'No bot response available',
        'status': 'pending',
        'reason': fullReason,
        'createdAt': Timestamp.now(),
        'messageId': message.id,
      };

      await escalationRef.set(escalatedData);

      print('✅ Manual escalation created with ID: $escalationId');
      print('📝 User question: $userQuestion');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
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
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating manual escalation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to escalate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      reasonController.dispose();
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
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Could not show SnackBar: $e');
    }
  }

void _sendMessage(ChatProvider chatProvider) async {
  final text = _controller.text.trim();
  if (text.isEmpty || chatProvider.isLoading) return;

  // ✅ Clear the input immediately
  _controller.clear();

  // ✅ Close FAQs when sending a message
  if (_showFAQs && mounted) {
    setState(() {
      _showFAQs = false;
    });
  }

  try {
    await chatProvider.askQuestionWithStreaming(context, text);
    
    // ✅ Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showFAQs) {
        _scrollToBottom();
      }
    });
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
  print('🧹 ChatPage disposing...');
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
                child:
                    _isLoadingConversation
                        ? _buildLoadingIndicator()
                        : (_showFAQs
                            ? FAQSection(
                              key: _faqSectionKey,
                              onFAQSelected: _onFAQSelected,
                              messageController: _controller,
                            )
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
                onMicrophoneTap: _handleMicrophoneTap,
                isListening:
                    _showFAQs
                        ? (_faqSectionKey.currentState?.isListening ?? false)
                        : _isListening,
              ),
            ],
          );
        },
      ),
    );
  }

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

  Widget _buildMessagesList(List<Message> messages, ChatProvider chatProvider) {
  // ✅ FIX: Check if we have any streaming messages
  final hasStreamingMessage = messages.any((msg) => 
    chatProvider.getStreamingContent(msg.id) != null
  );
  print("Current message IDs: ${chatProvider.messages.map((m) => m.id).toList()}");

  return ListView.builder(
    controller: _scrollController,
    shrinkWrap: true,
    physics: BouncingScrollPhysics(),
    // ✅ FIX: Don't add extra loading indicator if we're streaming
    itemCount: messages.length,
    padding: EdgeInsets.symmetric(vertical: 20),
    itemBuilder: (context, index) {
      final Message message = messages[index];
      final bool isUser = message.sender == 'user';

      return _buildMessageBubble(message, isUser);
    },
  );
}
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
