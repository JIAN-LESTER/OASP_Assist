import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/responsive/user_constant.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

typedef OnFAQSelected = void Function(String question);

/// FAQSection Widget - Category cards with dropdown expansion
class FAQSection extends StatefulWidget {
  final OnFAQSelected onFAQSelected;
  final bool isLoading;
  final TextEditingController?
  messageController; // Add controller to update text field

  const FAQSection({
    Key? key,
    required this.onFAQSelected,
    this.isLoading = false,
    this.messageController,
  }) : super(key: key);

  @override
  FAQSectionState createState() => FAQSectionState();
}

class FAQSectionState extends State<FAQSection>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Map<String, List<Map<String, String>>> faqCategories = {};
  bool _isLoadingFAQs = true;
  String? _expandedCategory;
  late AnimationController _expandController;

  // Speech-to-text variables
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';
  Timer? _listeningTimer;

  final List<String> categoryOrder = ['Admission', 'Scholarship', 'Placement'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expandController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _initSpeechToText();
    _fetchFAQs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listeningTimer?.cancel();
    _expandController.dispose();
    if (_isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop listening when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isListening) {
        _stopListening();
      }
    }
  }

  Future<void> _initSpeechToText() async {
    _speechToText = stt.SpeechToText();

    // First check if microphone permission is granted
    final permissionStatus = await Permission.microphone.status;
    print('Initial microphone permission: $permissionStatus');

    if (!permissionStatus.isGranted) {
      print('Microphone permission not granted, requesting...');
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        print('Microphone permission denied by user');
        _speechAvailable = false;
        return;
      }
    }

    try {
      print('Initializing speech recognition...');
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            // Show user-friendly error message
            _showSnackBar(
              'Voice input error: ${_getErrorMessage(error.errorMsg)}',
              Icons.error_outline,
              Colors.red,
            );
          }
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
        debugLogging: true,
      );

      print('Speech recognition initialization result: $_speechAvailable');

      if (!_speechAvailable) {
        print('Speech recognition not available after initialization');
        if (mounted) {
          _showSnackBar(
            'Voice input not available on this device',
            Icons.mic_off,
            Colors.orange,
          );
        }
      } else {
        print('Speech recognition successfully initialized');
      }
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      _speechAvailable = false;
      if (mounted) {
        _showSnackBar(
          'Failed to initialize voice input',
          Icons.error_outline,
          Colors.red,
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('network')) {
      return 'Network error';
    } else if (error.contains('permission')) {
      return 'Microphone permission denied';
    } else if (error.contains('busy')) {
      return 'Microphone is busy';
    } else if (error.contains('not available')) {
      return 'Not available on this device';
    }
    return 'Please try again';
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    // Check if speech is available
    if (!_speechAvailable) {
      print('Speech not available, attempting to reinitialize...');
      await _initSpeechToText();

      if (!_speechAvailable) {
        _showSnackBar(
          'Voice input not available. Please check your device settings.',
          Icons.mic_off,
          Colors.orange,
        );
        return;
      }
    }

    // Double-check microphone permission before starting
    final status = await Permission.microphone.status;
    print('Microphone permission check before listening: $status');

    if (!status.isGranted) {
      print('Requesting microphone permission...');
      final result = await Permission.microphone.request();
      print('Permission request result: $result');

      if (!result.isGranted) {
        _showSnackBar(
          'Microphone permission is required for voice input',
          Icons.mic_off,
          Colors.red,
        );

        if (result.isPermanentlyDenied) {
          await Future.delayed(Duration(seconds: 2));
          await openAppSettings();
        }
        return;
      }
    }

    // Verify speech recognition is still initialized
    if (!_speechToText.isAvailable) {
      print('Speech recognition lost availability, reinitializing...');
      await _initSpeechToText();

      if (!_speechAvailable) {
        _showSnackBar(
          'Voice input initialization failed',
          Icons.error_outline,
          Colors.red,
        );
        return;
      }
    }

    // Start listening
    print('Attempting to start listening...');
    await _startListening();
  }

  Future<void> _startListening() async {
    print('_startListening called');

    try {
      // Verify we have permission
      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        print('No microphone permission in _startListening');
        throw Exception('Microphone permission not granted');
      }

      // Check if already listening
      if (_speechToText.isListening) {
        print('Already listening, stopping first...');
        await _speechToText.stop();
        await Future.delayed(Duration(milliseconds: 300));
      }

      setState(() {
        _isListening = true;
        _lastWords = '';
      });

      // Cancel any existing timer
      _listeningTimer?.cancel();

      print('Calling _speechToText.listen()...');

      // Call listen without await
      _speechToText.listen(
        onResult: (result) {
          print('Speech result received: ${result.recognizedWords}');
          if (mounted) {
            setState(() {
              _lastWords = result.recognizedWords;
              if (widget.messageController != null) {
                widget.messageController!.text = _lastWords;
              }
            });
          }
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      print('Listen method called successfully');
      HapticFeedback.mediumImpact();

      // Set a safety timer to stop listening after 30 seconds
      _listeningTimer = Timer(Duration(seconds: 31), () {
        print('Safety timer triggered, stopping listening');
        if (_isListening && mounted) {
          _stopListening();
        }
      });
    } catch (e) {
      print('Error in _startListening: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        _showSnackBar(
          'Failed to start voice input: ${e.toString()}',
          Icons.error_outline,
          Colors.red,
        );
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      _listeningTimer?.cancel();
      await _speechToText.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text(message, style: TextStyle(fontSize: 14))),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 4),
          action:
              message.contains('settings')
                  ? SnackBarAction(
                    label: 'OPEN',
                    textColor: Colors.white,
                    onPressed: () => openAppSettings(),
                  )
                  : null,
        ),
      );
    }
  }

  Future<void> _fetchFAQs() async {
    try {
      // Use cached FAQs from UserConstant
      final groupedFAQs = await UserConstant.getCachedFAQs();

      print('Successfully loaded FAQs: ${groupedFAQs.length} categories');

      if (mounted) {
        setState(() {
          faqCategories = groupedFAQs;
          _isLoadingFAQs = false;
        });
      }
    } on TimeoutException catch (e) {
      print("FAQ fetch timeout: $e");
      if (mounted) {
        setState(() {
          _isLoadingFAQs = false;
          faqCategories = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load FAQs. Please try again.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("Error fetching FAQs: $e");
      if (mounted) {
        setState(() {
          _isLoadingFAQs = false;
          faqCategories = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading FAQs: ${e.toString()}'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Determines if the current view is desktop
  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  /// Gets responsive padding based on screen size
  EdgeInsets _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return EdgeInsets.all(16); // Mobile
    if (width < 1100) return EdgeInsets.all(24); // Tablet
    return EdgeInsets.all(40); // Desktop
  }

  /// Gets responsive spacing between grid items
  double _getGridSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 12; // Mobile
    if (width < 1100) return 16; // Tablet
    return 20; // Desktop
  }

  /// Gets appropriate icon for category
  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'admission':
        return Icons.school_outlined;
      case 'scholarship':
        return Icons.attach_money_outlined;
      case 'placement':
        return Icons.work_outline_rounded;
      case 'general':
        return Icons.help_outline_rounded;
      default:
        return Icons.help_outline;
    }
  }

  /// Builds desktop category card (always expanded with scrollable list)
  Widget _buildDesktopCategoryCard(String category) {
    final faqItems = faqCategories[category] ?? [];
    final icon = _getIconForCategory(category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF2E7D32).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E7D32).withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E7D32).withOpacity(0.1),
                  Color(0xFF388E3C).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(0xFF2E7D32).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: Color(0xFF2E7D32), size: 24),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${faqItems.length} question${faqItems.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable FAQ list
          Expanded(
            child:
                faqItems.isEmpty
                    ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No questions available',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: faqItems.length,
                      itemBuilder: (context, index) {
                        final question = faqItems[index]['question']!;
                        final isLast = index == faqItems.length - 1;
                        return _buildFAQItem(question, isLast);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// Builds mobile/tablet category card (collapsible with dropdown)
  Widget _buildMobileTabletCategoryCard(String category) {
    final isExpanded = _expandedCategory == category;
    final faqItems = faqCategories[category] ?? [];
    final icon = _getIconForCategory(category);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isExpanded
                  ? Color(0xFF2E7D32).withOpacity(0.3)
                  : Colors.grey.shade200,
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isExpanded
                    ? Color(0xFF2E7D32).withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
            blurRadius: isExpanded ? 12 : 6,
            offset: Offset(0, isExpanded ? 4 : 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category header (always visible)
          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() {
                if (isExpanded) {
                  _expandedCategory = null;
                  _expandController.reverse();
                } else {
                  _expandedCategory = category;
                  _expandController.forward();
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          isExpanded
                              ? Color(0xFF2E7D32).withOpacity(0.15)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color:
                            isExpanded
                                ? Color(0xFF2E7D32)
                                : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Category name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isExpanded
                                    ? Color(0xFF2E7D32)
                                    : Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${faqItems.length} question${faqItems.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse arrow
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color:
                          isExpanded ? Color(0xFF2E7D32) : Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content with scrollable list
          if (isExpanded)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: faqItems.length > 4 ? 280 : faqItems.length * 70.0,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: faqItems.length,
                itemBuilder: (context, index) {
                  final question = faqItems[index]['question']!;
                  final isLast = index == faqItems.length - 1;
                  return _buildFAQItem(question, isLast);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Builds individual FAQ item
  Widget _buildFAQItem(String question, [bool isLast = false]) {
    final ValueNotifier<bool> isHovered = ValueNotifier<bool>(false);

    return ValueListenableBuilder<bool>(
      valueListenable: isHovered,
      builder: (context, hovered, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => isHovered.value = true,
          onExit: (_) => isHovered.value = false,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onFAQSelected(question);
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    hovered
                        ? Color(0xFF2E7D32).withOpacity(0.08)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border:
                    isLast
                        ? null
                        : Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade100,
                            width: 1,
                          ),
                        ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: hovered ? 6 : 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color:
                          hovered
                              ? Color(0xFF2E7D32)
                              : Color(0xFF2E7D32).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            hovered ? Color(0xFF2E7D32) : Colors.grey.shade700,
                        fontWeight: hovered ? FontWeight.w600 : FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(hovered ? 4 : 0, 0, 0),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: hovered ? Color(0xFF2E7D32) : Colors.grey.shade400,
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

  Widget _buildDesktopView() {
    final spacing = _getGridSpacing(context);
    final padding = _getResponsivePadding(context);

    final availableCategories =
        categoryOrder.where((cat) => faqCategories.containsKey(cat)).toList();

    for (var cat in faqCategories.keys) {
      if (!availableCategories.contains(cat)) {
        availableCategories.add(cat);
      }
    }

    if (availableCategories.isEmpty) {
      return _buildEmptyState();
    }

    // ✅ Limit to 3 categories
    final displayCategories = availableCategories.take(3).toList();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(),
          SizedBox(height: 20),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1200,
                ), // ✅ Reduced max width
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // ✅ Changed to 3 columns
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: displayCategories.length,
                  itemBuilder: (context, index) {
                    return _buildDesktopCategoryCard(displayCategories[index]);
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  // ✅ Also update _buildMobileTabletView() to limit to 3 FAQs:

  Widget _buildMobileTabletView() {
    final padding = _getResponsivePadding(context);

    final availableCategories =
        categoryOrder.where((cat) => faqCategories.containsKey(cat)).toList();

    for (var cat in faqCategories.keys) {
      if (!availableCategories.contains(cat)) {
        availableCategories.add(cat);
      }
    }

    if (availableCategories.isEmpty) {
      return _buildEmptyState();
    }

    // ✅ Limit to 3 categories
    final displayCategories = availableCategories.take(3).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeader(),
            SizedBox(height: 32),
            // ✅ Center the FAQ cards
            ...displayCategories.map(
              (category) => Container(
                constraints: BoxConstraints(
                  maxWidth: 600,
                ), // ✅ Max width for centering
                child: _buildMobileTabletCategoryCard(category),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ✅ Update _buildEmptyState() to show loading while fetching:

  Widget _buildEmptyState() {
    // ✅ Don't show empty state while loading
    if (_isLoadingFAQs) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 16),
            Text(
              'Loading FAQs...',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline, color: Colors.grey[300], size: 64),
          SizedBox(height: 20),
          Text(
            'No FAQs Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the header section with speech-to-text indicator
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo
        Center(
          child: Container(
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
        ),
        SizedBox(height: 28),
        // Title
        Text(
          'Welcome to OASP Assist',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        // Subtitle
        Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: Text(
            _isDesktop(context)
                ? 'Browse frequently asked questions by category'
                : 'Select a category below to explore frequently asked questions',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Speech-to-text listening indicator
        if (_isListening) ...[
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Color(0xFF2E7D32), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulsingMicIcon(),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listening...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    if (_lastWords.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Text(
                          _lastWords,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Builds pulsing microphone icon animation
  Widget _buildPulsingMicIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1.0 + (value * 0.2),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2E7D32).withOpacity(0.3 * value),
                  blurRadius: 10 * value,
                  spreadRadius: 5 * value,
                ),
              ],
            ),
            child: Icon(Icons.mic, color: Colors.white, size: 20),
          ),
        );
      },
      onEnd: () {
        if (_isListening && mounted) {
          setState(() {});
        }
      },
    );
  }

  /// Builds empty state

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFAQs) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 16),
            Text(
              'Loading FAQs...',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isDesktop(context)) {
      return _buildDesktopView();
    } else {
      return _buildMobileTabletView();
    }
  }

  void toggleSpeechRecognition() {
    _toggleListening();
  }

  bool get isListening => _isListening;
  bool get speechAvailable => _speechAvailable;
  String get lastWords => _lastWords;
}

/// FAQToggleButton Widget
class FAQToggleButton extends StatelessWidget {
  final bool showFAQs;
  final VoidCallback? onToggle;

  const FAQToggleButton({Key? key, required this.showFAQs, this.onToggle})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          showFAQs ? Icons.chat_rounded : Icons.help_outline_rounded,
          key: ValueKey(showFAQs),
          color: showFAQs ? Color(0xFF2E7D32) : Colors.grey.shade600,
          size: 24,
        ),
      ),
      onPressed:
          onToggle != null
              ? () {
                HapticFeedback.lightImpact();
                onToggle!();
              }
              : null,
      tooltip: showFAQs ? 'View Chat' : 'View FAQs',
    );
  }
}

// FAQInputSection

class FAQInputSection extends StatelessWidget {
  final TextEditingController controller;
  final bool showFAQs;
  final bool isLoading;
  final VoidCallback onFAQToggle;
  final VoidCallback onSendMessage;
  final VoidCallback? onMicrophoneTap;
  final bool isListening;
  final GlobalKey? faqButtonKey;
  final GlobalKey? audioButtonKey;

  const FAQInputSection({
    Key? key,
    required this.controller,
    required this.showFAQs,
    required this.isLoading,
    required this.onFAQToggle,
    required this.onSendMessage,
    this.onMicrophoneTap,
    this.isListening = false,
    this.faqButtonKey,
    this.audioButtonKey,
  }) : super(key: key);

  Map<String, double> _getResponsiveSizes(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return {
        'buttonSize': 40.0,
        'horizontalPadding': 12.0,
        'verticalPadding': 8.0,
        'borderRadius': 12.0,
        'iconSize': 22.0,
        'fontSize': 15.0,
      };
    } else if (width < 1100) {
      return {
        'buttonSize': 42.0,
        'horizontalPadding': 16.0,
        'verticalPadding': 10.0,
        'borderRadius': 14.0,
        'iconSize': 23.0,
        'fontSize': 16.0,
      };
    } else {
      return {
        'buttonSize': 44.0,
        'horizontalPadding': 24.0,
        'verticalPadding': 12.0,
        'borderRadius': 16.0,
        'iconSize': 24.0,
        'fontSize': 16.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    final buttonSize = sizes['buttonSize']!;
    final horizontalPadding = sizes['horizontalPadding']!;
    final verticalPadding = sizes['verticalPadding']!;
    final borderRadius = sizes['borderRadius']!;
    final iconSize = sizes['iconSize']!;
    final fontSize = sizes['fontSize']!;

    const primaryColor = Color(0xFF2E7D32);
    final surfaceColor = Colors.grey.shade50;
    final borderColor = Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(color: surfaceColor),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Original input section
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Container(
                constraints: BoxConstraints(maxWidth: 900),
                child: Row(
                  children: [
                    // FAQ Toggle Button
                    Tooltip(
                      message: showFAQs ? 'Hide FAQs' : 'Show FAQs',
                      preferBelow: true,
                      verticalOffset: 12,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize - 2,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Container(
                        key: faqButtonKey,
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap:
                                isLoading
                                    ? null
                                    : () {
                                      HapticFeedback.lightImpact();
                                      onFAQToggle();
                                    },
                            borderRadius: BorderRadius.circular(8),
                            splashColor: Colors.grey.withOpacity(0.1),
                            highlightColor: Colors.grey.withOpacity(0.05),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  showFAQs
                                      ? Icons.chat_bubble_outline_rounded
                                      : Icons.help_outline_rounded,
                                  key: ValueKey(showFAQs),
                                  color:
                                      isLoading
                                          ? Color(0xFFCCCCCC)
                                          : Color(0xFF666666),
                                  size: iconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // Text Input Field
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: buttonSize,
                          maxHeight: 100,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isLoading ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(borderRadius),
                          border: Border.all(
                            color:
                                isLoading ? Colors.grey.shade200 : borderColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: controller,
                          enabled: !isLoading,
                          maxLines: null,
                          minLines: 1,
                          textAlignVertical: TextAlignVertical.center,

                          // Make ENTER trigger onSubmitted
                          textInputAction: TextInputAction.send,

                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            color:
                                isLoading
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade900,
                            height: 1.4,
                          ),

                          decoration: InputDecoration(
                            hintText:
                                isLoading
                                    ? 'Sending message...'
                                    : 'Ask something...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),

                          //  ENTER now triggers sendMessage
                          onSubmitted:
                              isLoading ? null : (_) => onSendMessage(),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // Microphone Button
                    if (onMicrophoneTap != null)
                      Tooltip(
                        message: isListening ? 'Stop listening' : 'Voice input',
                        preferBelow: true,
                        verticalOffset: 12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize - 2,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Container(
                          key: audioButtonKey,
                          width: buttonSize,
                          height: buttonSize,
                          decoration: BoxDecoration(
                            color:
                                isListening
                                    ? primaryColor
                                    : isLoading
                                    ? Color(0xFFEEEEEE)
                                    : Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isListening
                                      ? primaryColor
                                      : isLoading
                                      ? Color(0xFFDDDDDD)
                                      : Color(0xFFE0E0E0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    isListening
                                        ? primaryColor.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.06),
                                blurRadius: isListening ? 12 : 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap:
                                  isLoading
                                      ? null
                                      : () {
                                        HapticFeedback.mediumImpact();
                                        onMicrophoneTap!();
                                      },
                              borderRadius: BorderRadius.circular(8),
                              splashColor:
                                  isListening
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                              highlightColor:
                                  isListening
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.05),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    isListening ? Icons.mic : Icons.mic_none,
                                    key: ValueKey(isListening),
                                    color:
                                        isListening
                                            ? Colors.white
                                            : isLoading
                                            ? Color(0xFFCCCCCC)
                                            : Color(0xFF666666),
                                    size: iconSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(width: 10),
                    // Send Button with Loading State
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: isLoading ? Colors.grey.shade400 : primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow:
                            isLoading
                                ? []
                                : [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isLoading ? null : onSendMessage,
                          borderRadius: BorderRadius.circular(10),
                          splashColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child:
                                  isLoading
                                      ? SizedBox(
                                        width: iconSize - 4,
                                        height: iconSize - 4,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: iconSize,
                                        key: ValueKey('send'),
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
