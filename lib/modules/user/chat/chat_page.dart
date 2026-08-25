import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:capstone_project/modules/user/chat/chat_utilities.dart';
import 'package:capstone_project/modules/user/chat/typing_animation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:intl/intl.dart';

import 'package:capstone_project/models/message.dart';
import 'package:capstone_project/provider/chat_provider.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;

import 'faq_section.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String? initialMessage;
  final bool showFAQs;
  final VoidCallback? onFAQToggle;
  final GlobalKey? faqButtonKey;
  final GlobalKey? faqCardsKey;
  final GlobalKey? textInputKey;
  final GlobalKey? audioButtonKey;

  const ChatPage({
    Key? key,
    required this.conversationId,
    this.initialMessage,
    this.showFAQs = false,
    this.onFAQToggle,
    this.faqButtonKey,
    this.faqCardsKey,
    this.textInputKey,
    this.audioButtonKey,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  final Map<String, String?> _localRatings = {};
  final Map<String, bool> _ratingLoading =
      {}; // Track loading state per message

  String? actualConversationId;
  bool isLoading = true;
  bool _isDisposing = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<FAQSectionState> _faqSectionKey =
      GlobalKey<FAQSectionState>();

  late AnimationController _micAnimationController;
  late AnimationController _attachmentAnimationController;

  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';

  final Set<String> _initialMessageIds = {};

  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  late ChatProvider chatProvider;

  bool _showFAQs = false;

  bool _isLoadingConversation = true;

  String? _currentLoadedConversationId;
  bool _isInitialized = false;
  bool _isSettingUpConversation = false;

  Future<void> _initializeConversation() async {
    if (_isSettingUpConversation) {
      print(' Already setting up conversation');
      return;
    }

    _isSettingUpConversation = true;

    try {
      print(' Initializing conversation: ${widget.conversationId}');

      if (mounted) {
        setState(() {
          _isLoadingConversation = true;
        });
      }

      if (widget.conversationId.isEmpty) {
        chatProvider.clearMessages();
        if (mounted) {
          setState(() {
            _showFAQs = true;
            _isLoadingConversation = false;
            _currentLoadedConversationId = null;
          });
        }
        return;
      }

      if (chatProvider.conversationId == widget.conversationId &&
          chatProvider.messages.isNotEmpty) {
        _initialMessageIds.clear();
        for (var message in chatProvider.messages) {
          _initialMessageIds.add(message.id);
        }

        if (mounted) {
          setState(() {
            _currentLoadedConversationId = widget.conversationId;
            _showFAQs = false;
            _isLoadingConversation = false;
          });
          _scrollToBottomInstant();
        }
        return;
      }

      if (_currentLoadedConversationId == widget.conversationId) {
        print(' Conversation already loaded: ${widget.conversationId}');
        if (mounted) {
          setState(() {
            _isLoadingConversation = false;
          });
        }
        _isSettingUpConversation = false;
        return;
      }

      await chatProvider.setConversationId(widget.conversationId);

      _initialMessageIds.clear();
      for (var message in chatProvider.messages) {
        _initialMessageIds.add(message.id);
      }

      final hasMessages = chatProvider.messages.isNotEmpty;

      if (mounted) {
        setState(() {
          _currentLoadedConversationId = widget.conversationId;
          _showFAQs = !hasMessages;
          _isLoadingConversation = false;
        });
      }

      //  IMPROVED: Multiple scroll attempts with longer delays
      if (hasMessages && mounted) {
        // First attempt - immediate
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollToBottomInstant();
          }
        });

        // Second attempt - after 100ms
        await Future.delayed(Duration(milliseconds: 100));
        if (mounted && _scrollController.hasClients) {
          _scrollToBottomInstant();
        }

        // Third attempt - after 300ms (for slower devices)
        await Future.delayed(Duration(milliseconds: 200));
        if (mounted && _scrollController.hasClients) {
          _scrollToBottomInstant();
        }
      }

      print(' Conversation initialized: ${widget.conversationId}');
      print('   - Messages: ${chatProvider.messages.length}');
      print('   - Show FAQs: $_showFAQs');
    } catch (e) {
      print(' Error initializing conversation: $e');
      if (mounted) {
        setState(() {
          _isLoadingConversation = false;
          _showFAQs = true;
        });
      }
    } finally {
      _isSettingUpConversation = false;
    }
  }

  @override
  void initState() {
    super.initState();

    print(' ChatPage initState: ${widget.conversationId}');

    _micAnimationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _attachmentAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final isAtBottom =
            _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100;
      }
    });

    _showFAQs = widget.showFAQs;

    _initChatSpeechToText();
    chatProvider = Provider.of<ChatProvider>(context, listen: false);

    chatProvider.setScrollCallback(() {
      if (mounted && !_showFAQs && _scrollController.hasClients) {
        _scrollToBottomSmooth();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _initializeConversation();
        chatProvider.loadUserMessageCount();
        chatProvider.listenToUserMessageCount();

        //   Load and listen to escalation counts
        chatProvider.loadUserEscalationCount();
        chatProvider.listenToUserEscalationCount();

        chatProvider.cleanExistingConversationTitles();
        _isInitialized = true;
      }
    });
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

    // Only react to actual conversation changes
    if (widget.conversationId != oldWidget.conversationId) {
      print(' ChatPage conversation changed:');
      print('   - Old: ${oldWidget.conversationId}');
      print('   - New: ${widget.conversationId}');

      // Only reinitialize if it's a different conversation
      if (_currentLoadedConversationId != widget.conversationId) {
        _isInitialized = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isInitialized) {
            _initializeConversation();
            _isInitialized = true;
          }
        });
      }
      return;
    }

    // React to FAQ visibility changes
    if (widget.showFAQs != oldWidget.showFAQs) {
      if (mounted) {
        setState(() {
          _showFAQs = widget.showFAQs;
        });

        if (!_showFAQs && chatProvider.messages.isNotEmpty) {
          _scrollToBottomInstant();
        }
      }
      print(' ChatPage FAQ visibility changed: $_showFAQs');
    }
  }

  void _toggleFAQsDisplay() {
    HapticFeedback.lightImpact();
    setState(() {
      _showFAQs = !_showFAQs;
    });

    //  INSTANT: Scroll when switching from FAQs to chat
    if (!_showFAQs && chatProvider.messages.isNotEmpty) {
      _scrollToBottomInstant();
    }

    if (widget.onFAQToggle != null) {
      widget.onFAQToggle!();
    }
  }

  void _onFAQSelected(String question) {
    print('FAQ selected: $question');

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.incrementFAQSimilarityCount(question);

    // Set the question in the controller
    _controller.text = question;

    //  INSTANT: Close FAQs immediately
    if (mounted) {
      setState(() {
        _showFAQs = false;
      });
    }

    //  INSTANT: Scroll to bottom when closing FAQs
    if (mounted && chatProvider.messages.isNotEmpty) {
      _scrollToBottomInstant();
    }

    //  INSTANT: Send message immediately
    if (mounted && !chatProvider.isLoading) {
      _sendMessage(chatProvider, isFAQSelection: true);
    }
  }

  // Replace the content section in _buildMessageBubble with this updated version

  Widget _buildMessageBubble(Message message, bool isUser) {
    return FutureBuilder<String?>(
      future: isUser ? _getUserAvatarUrl() : null,
      builder: (context, snapshot) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: true);
        final streamingContent = chatProvider.getStreamingContent(message.id);
        final isStreaming = streamingContent != null;

        final displayContent = isStreaming ? streamingContent : message.content;
        final isEmptyStreaming =
            !isUser && isStreaming && displayContent.trim().isEmpty;

        final isEscalatedMessage =
            message.sender == 'bot' && message.rating == 'dislike';

        return FutureBuilder<Map<String, dynamic>?>(
          future:
              isEscalatedMessage
                  ? _getEscalationStatus(message.id)
                  : Future.value(null),
          builder: (context, escalationSnapshot) {
            final escalationData = escalationSnapshot.data;
            final isEscalated = escalationData != null;
            final isResolved = escalationData?['status'] == 'resolved';

            return GestureDetector(
              onLongPress: () => _showMessageOptions(context, message),
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Column(
                  crossAxisAlignment:
                      isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    //  REMOVED: Escalation badge completely removed
                    Row(
                      mainAxisAlignment:
                          isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Bot avatar
                        if (!isUser)
                          Container(
                            width: 32,
                            height: 32,
                            margin: EdgeInsets.only(right: 8, bottom: 4),
                            decoration: BoxDecoration(
                              color:
                                  message.sender == 'staff'
                                      ? Colors.green.shade100
                                      : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    message.sender == 'staff'
                                        ? Colors.green.shade300
                                        : Color(0xFF2E7D32).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child:
                                  message.sender == 'staff'
                                      ? Icon(
                                        Icons.support_agent,
                                        color: Colors.green.shade700,
                                        size: 18,
                                      )
                                      : Transform.scale(
                                        scale: 1.9,
                                        child: Image.asset(
                                          'lib/images/oasp.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Icon(
                                              Icons.smart_toy_outlined,
                                              color: Color(0xFF2E7D32),
                                              size: 18,
                                            );
                                          },
                                        ),
                                      ),
                            ),
                          ),

                        // Message bubble
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient:
                                  isUser
                                      ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF2E7D32),
                                          Color(0xFF388E3C),
                                        ],
                                      )
                                      : message.sender == 'staff'
                                      ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Colors.grey.shade50,
                                        ],
                                      )
                                      : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Colors.grey.shade50,
                                        ],
                                      ),
                              border:
                                  message.sender == 'staff'
                                      ? Border.all(
                                        color: Color(0xFF2E7D32),
                                        width: 2,
                                      )
                                      : null,
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
                                          : message.sender == 'staff'
                                          ? Color(0xFF2E7D32).withOpacity(0.2)
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
                                // Content section (unchanged)
                                if (displayContent.trim().isNotEmpty)
                                  //  Has content - show text (with cursor if streaming)
                                  if (isStreaming)
                                    // Streaming with content
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child:
                                              isUser
                                                  ? SelectableLinkify(
                                                    onOpen: _onLinkTap,
                                                    text:
                                                        _convertMarkdownLinksToPlainUrls(
                                                          displayContent,
                                                        ),
                                                    textAlign:
                                                        TextAlign.justify,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      height: 1.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    linkStyle: TextStyle(
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                      color: Colors.yellow[100],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    options: LinkifyOptions(
                                                      humanize: false,
                                                      looseUrl: true,
                                                      defaultToHttps: true,
                                                    ),
                                                  )
                                                  : MarkdownBody(
                                                    data:
                                                        _convertMarkdownLinksToPlainUrls(
                                                          displayContent,
                                                        ),
                                                    selectable: true,
                                                    onTapLink: (
                                                      text,
                                                      href,
                                                      title,
                                                    ) {
                                                      if (href != null) {
                                                        _onLinkTap(
                                                          LinkableElement(
                                                            href,
                                                            text,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    styleSheet: MarkdownStyleSheet(
                                                      // ... (keep existing styles)
                                                      p: TextStyle(
                                                        color:
                                                            message.sender ==
                                                                        'staff' ||
                                                                    message.sender ==
                                                                        'admin'
                                                                ? Colors
                                                                    .green
                                                                    .shade900
                                                                : Colors
                                                                    .grey
                                                                    .shade800,
                                                        fontSize: 15,
                                                        height: 1.5,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      // ... (rest of your styles)
                                                    ),
                                                    extensionSet:
                                                        md.ExtensionSet(
                                                          md
                                                              .ExtensionSet
                                                              .gitHubFlavored
                                                              .blockSyntaxes,
                                                          [
                                                            md.EmojiSyntax(),
                                                            ...md
                                                                .ExtensionSet
                                                                .gitHubFlavored
                                                                .inlineSyntaxes,
                                                          ],
                                                        ),
                                                  ),
                                        ),
                                        SizedBox(width: 4),
                                        Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: BlinkingCursor(
                                            color:
                                                isUser
                                                    ? Colors.white70
                                                    : Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (!isStreaming &&
                                      displayContent.trim().isNotEmpty)
                                    //  Not streaming - show final content
                                    if (isUser)
                                      SelectableLinkify(
                                        onOpen: _onLinkTap,
                                        text: _convertMarkdownLinksToPlainUrls(
                                          displayContent,
                                        ),
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
                                    else
                                      MarkdownBody(
                                        data: _convertMarkdownLinksToPlainUrls(
                                          displayContent,
                                        ),
                                        selectable: true,
                                        onTapLink: (text, href, title) {
                                          if (href != null) {
                                            _onLinkTap(
                                              LinkableElement(href, text),
                                            );
                                          }
                                        },
                                        styleSheet: MarkdownStyleSheet(
                                          // ... (keep all your existing markdown styles)
                                          p: TextStyle(
                                            color:
                                                message.sender == 'staff' ||
                                                        message.sender ==
                                                            'admin'
                                                    ? Colors.green.shade900
                                                    : Colors.grey.shade800,
                                            fontSize: 15,
                                            height: 1.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          // ... (rest of styles)
                                        ),
                                        extensionSet: md.ExtensionSet(
                                          md
                                              .ExtensionSet
                                              .gitHubFlavored
                                              .blockSyntaxes,
                                          [
                                            md.EmojiSyntax(),
                                            ...md
                                                .ExtensionSet
                                                .gitHubFlavored
                                                .inlineSyntaxes,
                                          ],
                                        ),
                                      ),

                                //  Only show timestamp if there's content
                                if (displayContent.trim().isNotEmpty) ...[
                                  SizedBox(height: 6),

                                  // Timestamp
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimestamp(message.sentAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              isUser
                                                  ? Colors.white70
                                                  : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Rating buttons (only show if not streaming and has content)
                                if (!isUser &&
                                    message.sender == 'bot' &&
                                    !isStreaming &&
                                    displayContent.trim().isNotEmpty &&
                                    (!isEscalated || !isResolved)) ...[
                                  _buildEscalateButton(message),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // User avatar (unchanged)
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageContent(
    Message message,
    bool isUser,
    String displayContent,
    bool isStreaming,
  ) {
    // Check if this is a staff response
    final isStaffResponse =
        message.sender == 'staff' ||
        (message.content.contains('**Staff Response from') &&
            message.content.contains(':**'));

    if (isStaffResponse && !isUser) {
      // Parse staff response
      String staffName = 'Staff';
      String responseContent = displayContent;

      // Extract staff name and content
      final staffResponseMatch = RegExp(
        r'\*\*Staff Response from (.+?):\*\*\n\n(.+)',
        dotAll: true,
      ).firstMatch(displayContent);

      if (staffResponseMatch != null) {
        staffName = staffResponseMatch.group(1) ?? 'Staff';
        responseContent = staffResponseMatch.group(2) ?? displayContent;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  PROFESSIONAL HEADER
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Official Staff Response',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'from $staffName',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          //  EMPHASIZED CONTENT AREA
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFF2E7D32).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Color(0xFF2E7D32).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child:
                isStreaming
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: MarkdownBody(
                            data: _convertMarkdownLinksToPlainUrls(
                              responseContent,
                            ),
                            selectable: true,
                            onTapLink: (text, href, title) {
                              if (href != null) {
                                _onLinkTap(LinkableElement(href, text));
                              }
                            },
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: Color(0xFF1B5E20),
                                fontSize: 15.5,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                              strong: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B5E20),
                              ),
                              em: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF2E7D32),
                              ),
                              a: TextStyle(
                                color: Color(0xFF1565C0),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                              listBullet: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            extensionSet: md.ExtensionSet(
                              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                              [
                                md.EmojiSyntax(),
                                ...md
                                    .ExtensionSet
                                    .gitHubFlavored
                                    .inlineSyntaxes,
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: BlinkingCursor(color: Color(0xFF2E7D32)),
                        ),
                      ],
                    )
                    : MarkdownBody(
                      data: _convertMarkdownLinksToPlainUrls(responseContent),
                      selectable: true,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          _onLinkTap(LinkableElement(href, text));
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 15.5,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                        em: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF2E7D32),
                        ),
                        a: TextStyle(
                          color: Color(0xFF1565C0),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        listBullet: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                        h1: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                        h2: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                        h3: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      extensionSet: md.ExtensionSet(
                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        [
                          md.EmojiSyntax(),
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                        ],
                      ),
                    ),
          ),

          SizedBox(height: 10),

          //  VERIFICATION FOOTER
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: Color(0xFF2E7D32).withOpacity(0.7),
              ),
              SizedBox(width: 6),
              Text(
                'Verified Staff Member',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32).withOpacity(0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      );
    }

    //  REGULAR MESSAGE (User or Bot)
    if (isStreaming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child:
                isUser
                    ? SelectableLinkify(
                      onOpen: _onLinkTap,
                      text: _convertMarkdownLinksToPlainUrls(displayContent),
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
                    : MarkdownBody(
                      data: _convertMarkdownLinksToPlainUrls(displayContent),
                      selectable: true,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          _onLinkTap(LinkableElement(href, text));
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      extensionSet: md.ExtensionSet(
                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        [
                          md.EmojiSyntax(),
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                        ],
                      ),
                    ),
          ),
          SizedBox(width: 4),
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: BlinkingCursor(
              color: isUser ? Colors.white70 : Color(0xFF2E7D32),
            ),
          ),
        ],
      );
    }

    // Final content (not streaming)
    return isUser
        ? SelectableLinkify(
          onOpen: _onLinkTap,
          text: _convertMarkdownLinksToPlainUrls(displayContent),
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
        : MarkdownBody(
          data: _convertMarkdownLinksToPlainUrls(displayContent),
          selectable: true,
          onTapLink: (text, href, title) {
            if (href != null) {
              _onLinkTap(LinkableElement(href, text));
            }
          },
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          extensionSet: md.ExtensionSet(
            md.ExtensionSet.gitHubFlavored.blockSyntaxes,
            [
              md.EmojiSyntax(),
              ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
            ],
          ),
        );
  }

  String _convertMarkdownLinksToPlainUrls(String text) {
    return text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^\)]+)\)'), (match) {
      final linkText = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      return '$linkText ($url)'; //  Shows both text and URL
    });
  }

  //   Simpler typing cursor widget
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

  // void _scrollToBottomSmooth() {
  //   if (!_scrollController.hasClients) return;

  //   final double currentPosition = _scrollController.position.pixels;
  //   final double targetPosition = _scrollController.position.maxScrollExtent;

  //   if ((targetPosition - currentPosition).abs() < 50) {
  //     return;
  //   }

  //   final double distance = (targetPosition - currentPosition).abs();
  //   final int duration =
  //       (distance / 2)
  //           .clamp(200, 800)
  //           .toInt();

  void _scrollToBottomInstant() {
    void jumpWhenReady() {
      if (_isDisposing ||
          !mounted ||
          _showFAQs ||
          !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;

      _scrollController.jumpTo(position.minScrollExtent);
    }

    // The message list is often mounted by the same setState that requests the
    // scroll, so retry across layout frames instead of requiring clients now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpWhenReady();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        jumpWhenReady();
      });
    });

    Future.delayed(Duration(milliseconds: 100), jumpWhenReady);
    Future.delayed(Duration(milliseconds: 300), jumpWhenReady);
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

  //  FIXED: Updated _buildEscalateButton to hide when resolved
  Widget _buildEscalateButton(Message message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final isLoadingEscalation = _ratingLoading[message.id] ?? false;
    final hasEscalated = _localRatings[message.id] == 'escalated';

    // Check if user can still escalate
    final canEscalate = chatProvider.canEscalate;
    final remainingEscalations =
        ChatProvider.MAX_DAILY_ESCALATIONS -
        chatProvider.userDailyEscalationCount;

    return FutureBuilder<Map<String, dynamic>?>(
      future:
          hasEscalated ? _getEscalationStatus(message.id) : Future.value(null),
      builder: (context, escalationSnapshot) {
        final escalationData = escalationSnapshot.data;
        final isResolved = escalationData?['status'] == 'resolved';

        return Container(
          margin: EdgeInsets.only(top: 8),
          child: InkWell(
            onTap:
                isLoadingEscalation || hasEscalated
                    ? null
                    : () => _handleEscalation(message, chatProvider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isResolved
                        ? Colors.green.withOpacity(0.1)
                        : hasEscalated
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isResolved
                          ? Colors.green.shade600
                          : hasEscalated
                          ? Colors.orange
                          : isLoadingEscalation
                          ? Colors.grey.shade200
                          : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoadingEscalation)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                    )
                  else
                    Icon(
                      isResolved
                          ? Icons.check_circle
                          : hasEscalated
                          ? Icons.support_agent
                          : Icons.support_agent,
                      size: 18,
                      color:
                          isResolved
                              ? Colors.green.shade700
                              : hasEscalated
                              ? Colors.orange
                              : Colors.grey.shade700,
                    ),
                  SizedBox(width: 6),
                  Text(
                    isResolved
                        ? 'Resolved by Staff'
                        : hasEscalated
                        ? 'Escalated to Staff'
                        : canEscalate
                        ? 'Escalate to Staff ($remainingEscalations left)'
                        : 'No escalations left',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isResolved
                              ? Colors.green.shade700
                              : hasEscalated
                              ? Colors.orange
                              : isLoadingEscalation
                              ? Colors.grey.shade400
                              : canEscalate
                              ? Colors.grey.shade700
                              : Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleEscalation(
    Message message,
    ChatProvider chatProvider,
  ) async {
    if (!mounted) return;

    // Check if user has escalations left
    if (chatProvider.isEscalationLimitReached) {
      final timeUntilReset = chatProvider.getTimeUntilEscalationReset();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => EscalationLimitDialog(timeUntilReset: timeUntilReset),
      );
      return;
    }

    // Show warning when 1 escalation left
    if (chatProvider.userDailyEscalationCount ==
        ChatProvider.MAX_DAILY_ESCALATIONS - 1) {
      final bool? shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder:
            (context) => EscalationWarningDialog(
              remainingEscalations: 1,
              timeUntilReset: chatProvider.getTimeUntilEscalationReset(),
            ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    // Start loading
    setState(() {
      _ratingLoading[message.id] = true;
      _localRatings[message.id] = 'escalated';
    });

    try {
      // Show escalation dialog and get reason
      final bool? shouldEscalate = await _showEscalationReasonDialog(message);

      if (shouldEscalate == true && mounted) {
        // Increment escalation count
        await chatProvider.updateUserEscalationCount();

        // Update message rating in Firestore
        await chatProvider.rateMessage(
          message.id,
          false, // false = dislike/escalated
          chatProvider.conversationId ?? widget.conversationId,
        );

        print(' Message escalated successfully');
      } else {
        // User cancelled - revert UI
        if (mounted) {
          setState(() {
            _localRatings.remove(message.id);
          });
        }
      }
    } catch (e) {
      print(' Error escalating message: $e');

      if (mounted) {
        setState(() {
          _localRatings.remove(message.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to escalate message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _ratingLoading[message.id] = false;
        });
      }
    }
  }

  Future<bool?> _showEscalationReasonDialog(Message message) async {
    final success = await _processManualEscalation(message);
    return success;
  }
  //  DIALOG 1: Need Better Help?

  Future<void> _handleLikeDislike(
    String messageId,
    bool isLike, [
    Message? message,
  ]) async {
    if (!mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final actualConversationId =
        chatProvider.conversationId ?? widget.conversationId;

    if (actualConversationId.isEmpty) {
      print('Error: No conversation ID available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to rate message - no active conversation'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    //  ONLY start loading for "Not helpful" (dislike)
    if (!isLike) {
      setState(() {
        _ratingLoading[messageId] = true;
        _localRatings[messageId] = 'dislike';
      });
    } else {
      // For "Helpful" - just update rating immediately (no loading)
      setState(() {
        _localRatings[messageId] = 'like';
      });
    }

    try {
      await chatProvider.rateMessage(messageId, isLike, actualConversationId);

      //  Stop loading after success
      if (mounted && !isLike) {
        setState(() {
          _ratingLoading[messageId] = false;
        });
      }
    } catch (e) {
      print('Error rating message: $e');

      //  Stop loading and revert on error
      if (mounted) {
        setState(() {
          if (!isLike) {
            _ratingLoading[messageId] = false;
          }
          _localRatings.remove(messageId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rating'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    //  Show escalation dialog only for dislike (after loading completes)
    if (!isLike && message != null && mounted) {
      final bool? escalate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 450,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2E7D32),
                            const Color(0xFF43A047),
                          ],
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
                              Icons.feedback_outlined,
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
                                  'Need Better Help?',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Let our staff team assist you',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white70,
                                    letterSpacing: 0.0,
                                    height: 1.4,
                                  ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "This response wasn't helpful. Would you like to escalate this to our staff for personalized assistance?",
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade800,
                              height: 1.6,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'A staff member will review your question and respond within 3 business days.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade900,
                                      height: 1.5,
                                      letterSpacing: 0.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Not Now',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.support_agent, size: 19),
                                  SizedBox(width: 8),
                                  Text(
                                    'Yes, Escalate',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15.5,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (escalate == true && mounted) {
        await _processManualEscalation(message);
      }
    }
  }

  // DIALOG 2: Request Staff Assistance

  Future<bool> _processManualEscalation(Message message) async {
    String selectedReason = 'Bot response not accurate';
    String? userReason;

    try {
      final Map<String, dynamic>?
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          final TextEditingController reasonController =
              TextEditingController();
          bool isSubmitting = false; //  Track loading state

          return StatefulBuilder(
            builder:
                (dialogState, setDialogState) => WillPopScope(
                  onWillPop:
                      () async =>
                          !isSubmitting, //  Prevent back while submitting
                  child: Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    insetPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 500,
                        maxHeight:
                            MediaQuery.of(dialogContext).size.height * 0.85,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Fixed Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF43A047),
                                ],
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
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.support_agent,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Request Staff Assistance',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Get personalized help from our team',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white70,
                                          letterSpacing: 0.0,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                //  Disable close button while submitting
                                IconButton(
                                  onPressed:
                                      isSubmitting
                                          ? null
                                          : () => Navigator.of(
                                            dialogContext,
                                          ).pop(null),
                                  icon: Icon(
                                    Icons.close,
                                    color:
                                        isSubmitting
                                            ? Colors.white38
                                            : Colors.white70,
                                    size: 24,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                          // SCROLLABLE Content
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Reason selection
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        size: 18,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'What went wrong?',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildReasonTile(
                                          context: dialogContext,
                                          title: 'Bot response not accurate',
                                          icon: Icons.error_outline,
                                          value: 'Bot response not accurate',
                                          groupValue: selectedReason,
                                          onChanged:
                                              isSubmitting //  Disable while submitting
                                                  ? (
                                                    _,
                                                  ) {} // Empty function when disabled
                                                  : (val) {
                                                    setDialogState(() {
                                                      selectedReason =
                                                          val ?? selectedReason;
                                                    });
                                                  },
                                          isFirst: true,
                                        ),
                                        Divider(
                                          height: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildReasonTile(
                                          context: dialogContext,
                                          title:
                                              'Bot did not understand my question',
                                          icon: Icons.help_outline,
                                          value:
                                              'Bot did not understand my question',
                                          groupValue: selectedReason,
                                          onChanged:
                                              isSubmitting
                                                  ? (
                                                    _,
                                                  ) {} // Empty function when disabled
                                                  : (val) {
                                                    setDialogState(() {
                                                      selectedReason =
                                                          val ?? selectedReason;
                                                    });
                                                  },
                                        ),
                                        Divider(
                                          height: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildReasonTile(
                                          context: dialogContext,
                                          title:
                                              'Need clarification from staff',
                                          icon: Icons.contact_support_outlined,
                                          value:
                                              'Need clarification from staff',
                                          groupValue: selectedReason,
                                          onChanged:
                                              isSubmitting
                                                  ? (
                                                    _,
                                                  ) {} // Empty function when disabled
                                                  : (val) {
                                                    setDialogState(() {
                                                      selectedReason =
                                                          val ?? selectedReason;
                                                    });
                                                  },
                                          isLast: true,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Additional details
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 18,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Additional details (optional)',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  //  Disable text field while submitting
                                  TextField(
                                    controller: reasonController,
                                    maxLines: 3,
                                    maxLength: 200,
                                    textInputAction: TextInputAction.done,
                                    enabled: !isSubmitting,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey.shade800,
                                      height: 1.5,
                                      letterSpacing: 0.0,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Tell us more about what you need help with...',
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade400,
                                        letterSpacing: 0.0,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
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
                                      fillColor:
                                          isSubmitting
                                              ? Colors.grey.shade100
                                              : Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(14),
                                      counterStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade500,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          //  PROFESSIONAL BUTTONS WITH LOADING STATE
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        isSubmitting
                                            ? null
                                            : () => Navigator.of(
                                              dialogContext,
                                            ).pop(null),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      side: BorderSide(
                                        color:
                                            isSubmitting
                                                ? Colors.grey.shade200
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color:
                                            isSubmitting
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15.5,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        isSubmitting
                                            ? null
                                            : () async {
                                              //  Start loading
                                              setDialogState(() {
                                                isSubmitting = true;
                                              });

                                              //  Simulate submission delay
                                              await Future.delayed(
                                                Duration(milliseconds: 800),
                                              );

                                              //  Return result and close dialog
                                              if (dialogContext.mounted) {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop({
                                                  'submit': true,
                                                  'selectedReason':
                                                      selectedReason,
                                                  'userReason':
                                                      reasonController.text
                                                          .trim(),
                                                });
                                              }
                                            },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isSubmitting
                                              ? Colors.grey.shade400
                                              : const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      elevation: isSubmitting ? 0 : 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                    child:
                                        isSubmitting
                                            ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Submitting...',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15.5,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.send, size: 19),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Submit',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15.5,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          );
        },
      );

      //  Handle dialog result
      if (result == null || result['submit'] != true || !mounted) {
        print(' Escalation cancelled by user');
        return false;
      }

      selectedReason = result['selectedReason'] as String;
      userReason = result['userReason'] as String?;

      final fullReason =
          userReason != null && userReason.isNotEmpty
              ? '$selectedReason — $userReason'
              : selectedReason;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final messages = chatProvider.messages;

      String userQuestion = 'No question found';
      String messageCategory = 'General';

      final botMessageIndex = messages.indexWhere((m) => m.id == message.id);

      if (botMessageIndex > 0) {
        for (int i = botMessageIndex - 1; i >= 0; i--) {
          if (messages[i].sender == 'user') {
            userQuestion = messages[i].content;
            messageCategory = messages[i].category ?? 'General';
            print(' Found user question with category: $messageCategory');
            break;
          }
        }
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      final userDoc = await _firestore.collection('users').doc(uid).get();

      final userName = userDoc.data()?['name'] ?? 'Unknown User';

      final escalationRef = _firestore.collection('escalations').doc();
      final escalationId = escalationRef.id;

      final escalatedData = {
        'escalationId': escalationId,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'user': userName,
        'conversationId': message.conversationId,
        'question': userQuestion,
        'botAnswer':
            message.sender == 'bot'
                ? message.content
                : 'No bot response available',
        'status': 'pending',
        'reason': fullReason,
        'category': messageCategory,
        'createdAt': Timestamp.now(),
        'messageId': message.id,
      };

      await escalationRef.set(escalatedData);

      print(' Manual escalation created with ID: $escalationId');
      print('User question: $userQuestion');
      print(' Category: $messageCategory');

      //  Show success dialog immediately after submission
      if (mounted) {
        await _showEscalationSuccessDialog();
      }

      return true;
    } catch (e) {
      print(' Error creating manual escalation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to escalate: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return false;
    }
  }

  Widget _buildReasonTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String value,
    required String groupValue,
    required Function(String?) onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32).withOpacity(0.05) : null,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(12) : Radius.zero,
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade800,
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF2E7D32),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG 3: Request Submitted

  Future<void> _showEscalationSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success animation area
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Request Submitted!',
                          style: TextStyle(
                            fontSize: 26, //  Larger, professional
                            fontWeight: FontWeight.w700, //  Bold
                            color: Color(0xFF2E7D32),
                            letterSpacing: -0.8,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your request has been escalated to our staff team.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w400, //  Regular
                            color: Colors.grey.shade700,
                            height: 1.5,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Info section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.green.shade100),
                        bottom: BorderSide(color: Colors.green.shade100),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.schedule,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expected Response Time',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600, //  Semibold
                                      color: Colors.green.shade900,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Within 3 business days',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700, //  Bold
                                      color: Colors.green.shade700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'You\'ll receive a notification when a staff member responds',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500, //  Medium
                                    color: Colors.green.shade900,
                                    height: 1.4,
                                    letterSpacing: 0.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // What happens next
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What happens next?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600, //  Semibold
                            color: Colors.grey.shade800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildNextStepItem(
                          icon: Icons.person_search,
                          text: 'A staff member will review your conversation',
                        ),
                        const SizedBox(height: 10),
                        _buildNextStepItem(
                          icon: Icons.chat_bubble_outline,
                          text: 'They\'ll provide personalized assistance',
                        ),
                        const SizedBox(height: 10),
                        _buildNextStepItem(
                          icon: Icons.email_outlined,
                          text:
                              'You\'ll be notified via device notification and in-app',
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 18, //  Professional height
                          ),
                        ),
                        child: const Text(
                          'Got it, thanks!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600, //  Semibold
                            fontSize: 16,
                            letterSpacing: -0.2, //  Tight spacing
                          ),
                        ),
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
  }

  //  Future<void> _showWelcomeDialog() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   try {
  //     //  Check Firestore first
  //     final userDoc = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(user.uid)
  //         .get();

  //     final hasSeenOnboardingGuide =
  //         userDoc.data()?['hasSeenOnboardingGuide'] ?? false;

  //     //  Only show welcome dialog if user has NOT seen onboarding
  //     if (!hasSeenOnboardingGuide) {
  //       // Check SharedPreferences flag
  //       final prefs = await SharedPreferences.getInstance();
  //       final shouldShowWelcome =
  //           prefs.getBool('should_show_welcome_dialog') ?? false;

  //       if (shouldShowWelcome && mounted) {
  //         // Clear the flag so it doesn't show again
  //         await prefs.setBool('should_show_welcome_dialog', false);

  //         // Show the dialog
  //         await showDialog(
  //           context: context,
  //           barrierDismissible: false,
  //           builder: (context) => const FirstTimeWelcomeDialog(),
  //         );
  //       }
  //     } else {
  //       //  User has seen onboarding, clear the flag to prevent showing
  //       final prefs = await SharedPreferences.getInstance();
  //       await prefs.setBool('should_show_welcome_dialog', false);
  //     }
  //   } catch (e) {
  //     print('Error checking welcome dialog status: $e');
  //   }
  // }

  //  Helper method for next steps (if not already in your code)
  Widget _buildNextStepItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400, //  Regular
              color: Colors.grey.shade700,
              height: 1.4,
              letterSpacing: 0.0,
            ),
          ),
        ),
      ],
    );
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
        // Opens phone dialer or copies number
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
        // Opens email client or copies email
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
        // Opens web URLs in external browser
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
      // Fallback: copy link to clipboard
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

  void _sendMessage(
    ChatProvider chatProvider, {
    bool isFAQSelection = false,
  }) async {
    final text = _controller.text.trim();
    if (text.isEmpty || chatProvider.isLoading) return;

    //  FIX 1: Check if user has reached the limit BEFORE sending
    if (chatProvider.isMessageLimitReached) {
      final timeUntilReset = chatProvider.getTimeUntilReset();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => MessageLimitDialog(timeUntilReset: timeUntilReset),
      );
      return; // Stop here - don't proceed
    }

    //  FIX 2: Calculate remaining messages correctly
    final remainingMessages =
        ChatProvider.MAX_DAILY_MESSAGES - chatProvider.userDailyMessageCount;

    //  FIX 3: Show warning when user has exactly 1 message left (not 2)
    if (remainingMessages == 1) {
      final bool? shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder:
            (context) => MessageLimitWarningDialog(
              remainingMessages: remainingMessages,
              timeUntilReset: chatProvider.getTimeUntilReset(),
            ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    //  Clear controller and hide FAQs immediately
    _controller.clear();

    if (_showFAQs && mounted) {
      setState(() {
        _showFAQs = false;
      });
    }

    try {
      // Send message - the scroll callback will be triggered automatically
      await chatProvider.askQuestionWithStreaming(
        context,
        text,
        isFAQSelection: isFAQSelection,
      );
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
                Expanded(child: Text('Error sending message: ${e.toString()}')),
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
    print(' ChatPage disposing...');
    _isDisposing = true;
    _controller.dispose();
    _scrollController.dispose();
    _conversationsSubscription?.cancel();
    _micAnimationController.dispose();
    _attachmentAnimationController.dispose();

    // Clear loading states
    _ratingLoading.clear();
    _currentLoadedConversationId = null;
    _isInitialized = false;

    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final messages = chatProvider.messages;

          return Column(
            children: [
              Expanded(
                child:
                    _showFAQs
                        ? FAQSection(
                          key: _faqSectionKey,
                          onFAQSelected: _onFAQSelected,
                          messageController: _controller,
                          faqCardsKey: widget.faqCardsKey,
                        )
                        : (messages.isEmpty
                            ? _buildEmptyChatState()
                            : _buildMessagesList(messages, chatProvider)),
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
                faqButtonKey: widget.faqButtonKey,
                textInputKey: widget.textInputKey,
                audioButtonKey: widget.audioButtonKey,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 800), //  Added max width
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
                child: Transform.scale(
                  scale: 1.8,
                  child: Image.asset(
                    'lib/images/oasp.png',
                    fit: BoxFit.contain,
                  ),
                ),
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
      ),
    );
  }

  Widget _buildTypingIndicatorBubble() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          Container(
            width: 32,
            height: 32,
            margin: EdgeInsets.only(right: 8, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Color(0xFF2E7D32).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: Transform.scale(
                scale: 1.9,
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
          ),
          // Typing bubble
          Container(
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
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                SizedBox(width: 6),
                _buildTypingDot(1),
                SizedBox(width: 6),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED: Faster scroll with reduced delay
  void _scrollToBottomSmooth() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final double currentPosition = _scrollController.position.pixels;
      final double targetPosition = _scrollController.position.minScrollExtent;

      // If already at bottom (within 50px), don't scroll
      if ((targetPosition - currentPosition).abs() < 50) {
        return;
      }

      //  FASTER: Reduced duration calculation
      final double distance = (targetPosition - currentPosition).abs();
      final int duration =
          (distance / 5).clamp(100, 400).toInt(); // Faster than before

      _scrollController.animateTo(
        targetPosition,
        duration: Duration(milliseconds: duration),
        curve: Curves.easeOutCubic,
      );
    });
  }

  //  IMPROVED: Messages list with better scroll behavior

  Widget _buildMessagesList(List<Message> messages, ChatProvider chatProvider) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: BouncingScrollPhysics(),
      itemCount:
          messages
              .length, //  REMOVED: + (chatProvider.showTypingIndicator ? 1 : 0)
      padding: EdgeInsets.only(top: 16, bottom: 24, left: 8, right: 8),
      itemBuilder: (context, index) {
        final Message message = messages[messages.length - 1 - index];
        final bool isUser = message.sender == 'user';
        final bool isLastMessage = index == 0;

        //   Better streaming detection
        final streamingContent = chatProvider.getStreamingContent(message.id);
        final isStreaming = streamingContent != null;
        final hasContent =
            isStreaming
                ? streamingContent.trim().isNotEmpty
                : message.content.trim().isNotEmpty;

        //   For bot messages that are streaming without content yet
        // Show typing bubble WITHIN the message list item (not as separate item)
        if (!isUser && isStreaming && !hasContent) {
          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 1250),
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: Duration(milliseconds: 200),
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLastMessage ? 16 : 4),
                  child: _buildTypingIndicatorBubble(),
                ),
              ),
            ),
          );
        }

        //  Regular message rendering (has content or is user message)
        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 1250),
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: Duration(milliseconds: 200),
              child: Padding(
                padding: EdgeInsets.only(bottom: isLastMessage ? 16 : 4),
                child: _buildMessageBubble(message, isUser),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FirstTimeWelcomeDialog extends StatelessWidget {
  const FirstTimeWelcomeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : (isMobile ? double.infinity : 450),
          maxHeight: screenHeight * 0.85, //  Responsive max height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //  Fixed Header (Green, compact)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: isMobile ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chat with OASP Assist!',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your daily message information',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 20 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feature items
                    _buildFeatureItem(
                      icon: Icons.chat_bubble_outline,
                      title: '3 Messages Per Day',
                      description:
                          'Ask up to 3 questions daily to get instant answers',
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 14 : 16),
                    _buildFeatureItem(
                      icon: Icons.refresh,
                      title: 'Daily Reset at 8:00 AM',
                      description: 'Your message limit refreshes every morning',
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 14 : 16),
                    _buildFeatureItem(
                      icon: Icons.help_outline,
                      title: 'Browse FAQs',
                      description: 'Explore common questions',
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 14 : 16),
                    _buildFeatureItem(
                      icon: Icons.support_agent,
                      title: 'Human Support Available',
                      description: 'Get escalated to staff if AI can\'t help',
                      isMobile: isMobile,
                    ),
                  ],
                ),
              ),
            ),

            //  Fixed Footer with Button
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 15 : 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isMobile,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: isMobile ? 18 : 20, color: Color(0xFF2E7D32)),
        ),
        SizedBox(width: isMobile ? 12 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildTypingDot(int index) {
  return _AnimatedTypingDot(index: index);
}

//   Stateful widget for continuous animation
class _AnimatedTypingDot extends StatefulWidget {
  final int index;

  const _AnimatedTypingDot({required this.index});

  @override
  State<_AnimatedTypingDot> createState() => _AnimatedTypingDotState();
}

class _AnimatedTypingDotState extends State<_AnimatedTypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    // Create staggered animation based on dot index
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          widget.index * 0.2,
          0.6 + (widget.index * 0.2),
          curve: Curves.easeInOut,
        ),
      ),
    );

    _controller.repeat(); //  This makes it loop forever
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final scale = 0.5 + (_animation.value * 0.5);
        final opacity = 0.3 + (_animation.value * 0.7);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(0xFF2E7D32).withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class EscalationWarningDialog extends StatelessWidget {
  final int remainingEscalations;
  final Duration timeUntilReset;

  const EscalationWarningDialog({
    Key? key,
    required this.remainingEscalations,
    required this.timeUntilReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 48,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Last Escalation Today',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You have $remainingEscalations escalation remaining today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Resets in ${hours}h ${minutes}m (8:00 AM)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Limit Reached Dialog (0 escalations left)
class EscalationLimitDialog extends StatelessWidget {
  final Duration timeUntilReset;

  const EscalationLimitDialog({Key? key, required this.timeUntilReset})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_rounded,
                color: Colors.red.shade700,
                size: 48,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Daily Limit Reached',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You\'ve used all 2 escalations for today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Resets in ${hours}h ${minutes}m',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your escalation limit will reset at 8:00 AM tomorrow',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Try browsing FAQs or rephrase your question',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
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
