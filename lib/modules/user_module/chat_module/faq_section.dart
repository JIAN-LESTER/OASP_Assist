import 'dart:async';
import 'dart:io';

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

   bool _speechInitialized = false;
  bool _isDisposing = false;

   @override
  Future<void> _initSpeechToText() async {
    _speechToText = stt.SpeechToText();

    final permissionStatus = await Permission.microphone.status;
    print('Initial microphone permission: $permissionStatus');

    if (!permissionStatus.isGranted) {
      print('Microphone permission not granted, requesting...');
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        print('Microphone permission denied by user');
        _speechAvailable = false;
        _speechInitialized = false;
        return;
      }
    }

    try {
      print('Initializing speech recognition...');
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          if (mounted && !_isDisposing) {
            setState(() {
              _isListening = false;
            });
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
            if (mounted && !_isDisposing) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
        debugLogging: false, // ✅ Disable debug logging to prevent crashes
      );

      print('Speech recognition initialization result: $_speechAvailable');
      _speechInitialized = _speechAvailable;

      if (!_speechAvailable) {
        print('Speech recognition not available after initialization');
        if (mounted && !_isDisposing) {
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
      _speechInitialized = false;
      if (mounted && !_isDisposing) {
        _showSnackBar(
          'Failed to initialize voice input',
          Icons.error_outline,
          Colors.red,
        );
      }
    }
  }

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
    print('FAQSection disposing...');
    _isDisposing = true;
    
    // 1. Remove observer first
    WidgetsBinding.instance.removeObserver(this);
    
    // 2. Cancel timer
    _listeningTimer?.cancel();
    
    // 3. Stop speech recognition safely
    _cleanupSpeechRecognition();
    
    // 4. Dispose controllers
    _expandController.dispose();
    
    super.dispose();
    print('FAQSection disposed');
  }

  // ✅ NEW: Safe cleanup method
  void _cleanupSpeechRecognition() {
    try {
      if (_speechInitialized && _speechToText.isAvailable) {
        if (_speechToText.isListening) {
          print('Stopping speech recognition in dispose...');
          _speechToText.cancel(); // Use cancel for immediate stop
        }
      }
    } catch (e) {
      print('Error cleaning up speech recognition: $e');
      // Ignore errors during dispose
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposing) return;
    
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      print('App lifecycle changed to: $state');
      _safeStopListening();
    }
  }

 Future<void> _safeStopListening() async {
    if (_isDisposing) return;
    
    try {
      _listeningTimer?.cancel();
      
      if (_speechInitialized && _speechToText.isAvailable) {
        if (_speechToText.isListening) {
          await _speechToText.cancel();
        }
      }
      
      if (mounted && !_isDisposing) {
        setState(() {
          _isListening = false;
        });
      }
    } catch (e) {
      print('Error in _safeStopListening: $e');
      // Force reset state
      if (mounted && !_isDisposing) {
        setState(() {
          _isListening = false;
        });
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
    if (_isDisposing) return;
    
    if (_isListening) {
      await _safeStopListening();
      return;
    }

    if (!_speechAvailable || !_speechInitialized) {
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

    print('Attempting to start listening...');
    await _startListening();
  }

   
  Future<void> _startListening() async {
    if (_isDisposing) return;
    
    print('_startListening called');

    try {
      // Check initialization
      if (!_speechInitialized || !_speechToText.isAvailable) {
        throw Exception('Speech recognition not initialized');
      }

      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        print('No microphone permission in _startListening');
        throw Exception('Microphone permission not granted');
      }

      // Stop any existing session with longer delay
      if (_speechToText.isListening) {
        print('Already listening, canceling first...');
        await _speechToText.cancel();
        await Future.delayed(Duration(milliseconds: 800)); // ✅ Longer delay
      }

      if (_isDisposing || !mounted) return;

      setState(() {
        _isListening = true;
        _lastWords = '';
      });

      _listeningTimer?.cancel();

      print('Calling _speechToText.listen()...');

      // ✅ Simplified listen configuration
      _speechToText.listen(
        onResult: (result) {
          if (_isDisposing || !mounted) return;
          
          print('Speech result received: ${result.recognizedWords}');
          setState(() {
            _lastWords = result.recognizedWords;
            if (widget.messageController != null) {
              widget.messageController!.text = _lastWords;
            }
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
      );

      print('Listen method called successfully');
      HapticFeedback.mediumImpact();

      // Safety timer
      _listeningTimer = Timer(Duration(seconds: 31), () {
        if (!_isDisposing && _isListening && mounted) {
          print('Safety timer triggered, stopping listening');
          _safeStopListening();
        }
      });
    } catch (e) {
      print('Error in _startListening: $e');
      if (mounted && !_isDisposing) {
        setState(() {
          _isListening = false;
        });
        _showSnackBar(
          'Failed to start voice input',
          Icons.error_outline,
          Colors.red,
        );
      }
    }
  }

  

Future<void> _stopListening() async {
    await _safeStopListening();
    HapticFeedback.lightImpact();
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

class FAQInputSection extends StatefulWidget {
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

  @override
  State<FAQInputSection> createState() => _FAQInputSectionState();
}

class _FAQInputSectionState extends State<FAQInputSection> {
  late FocusNode _textFieldFocusNode;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode = FocusNode();
    _textFieldFocusNode.addListener(_onFocusChange);
    
    // Prevent focus issues on Windows
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _textFieldFocusNode.skipTraversal = false;
      _textFieldFocusNode.canRequestFocus = true;
    }
  }

  @override
  void dispose() {
    _textFieldFocusNode.removeListener(_onFocusChange);
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_textFieldFocusNode.hasFocus && mounted) {
      setState(() {});
    }
  }

  // ✅ CRITICAL FIX: Desktop-compatible message sending
  void _handleSendMessage() {
    if (_isSending || widget.isLoading) return;
    
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    print('🚀 _handleSendMessage called');
    print('   Platform: ${Platform.operatingSystem}');
    print('   Has focus: ${_textFieldFocusNode.hasFocus}');

    // Prevent multiple sends
    setState(() {
      _isSending = true;
    });

    // Stop speech if active
    if (widget.isListening && widget.onMicrophoneTap != null) {
      widget.onMicrophoneTap!();
    }

    // ✅ DESKTOP FIX: Handle focus removal safely
    if (_textFieldFocusNode.hasFocus) {
      print('   Removing focus...');
      
      // Schedule focus removal for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        try {
          // Use primary focus unfocus for desktop compatibility
          FocusManager.instance.primaryFocus?.unfocus();
          print('   ✅ Focus removed successfully');
        } catch (e) {
          print('   ⚠️ Focus removal error: $e');
        }
      });
    }

    // Send message immediately (don't wait for focus removal)
    Future.microtask(() {
      if (!mounted) return;
      
      print('   Calling onSendMessage...');
      widget.onSendMessage();
      
      // Reset sending flag
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
          print('   ✅ Message sent');
        }
      });
    });
  }

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
                      message: widget.showFAQs ? 'Hide FAQs' : 'Show FAQs',
                      child: Container(
                        key: widget.faqButtonKey,
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_isSending || widget.isLoading)
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    widget.onFAQToggle();
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child: Icon(
                                widget.showFAQs
                                    ? Icons.chat_bubble_outline_rounded
                                    : Icons.help_outline_rounded,
                                color: (_isSending || widget.isLoading)
                                    ? Color(0xFFCCCCCC)
                                    : Color(0xFF666666),
                                size: iconSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),

                    // ✅ Text Input with KeyboardListener for Desktop
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          // Handle Enter key on desktop
                          if ((Platform.isWindows ||
                                  Platform.isLinux ||
                                  Platform.isMacOS) &&
                              event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            if (!_isSending && !widget.isLoading) {
                              print('📥 Enter key pressed (desktop)');
                              _handleSendMessage();
                            }
                          }
                        },
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: buttonSize,
                            maxHeight: 100,
                          ),
                          decoration: BoxDecoration(
                            color: (_isSending || widget.isLoading)
                                ? Colors.grey.shade100
                                : Colors.white,
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(
                              color: (_isSending || widget.isLoading)
                                  ? Colors.grey.shade200
                                  : borderColor,
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _textFieldFocusNode,
                            enabled: !_isSending && !widget.isLoading,
                            maxLines: null,
                            minLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            textInputAction: TextInputAction.send,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                              color: (_isSending || widget.isLoading)
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade900,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: (_isSending || widget.isLoading)
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
                            // ✅ Disable onSubmitted on desktop (KeyboardListener handles it)
                            onSubmitted: (Platform.isWindows ||
                                    Platform.isLinux ||
                                    Platform.isMacOS)
                                ? null
                                : (_) {
                                    if (!_isSending && !widget.isLoading) {
                                      print('📥 Enter key pressed (mobile)');
                                      _handleSendMessage();
                                    }
                                  },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),

                    // Microphone Button
                    if (widget.onMicrophoneTap != null)
                      Container(
                        key: widget.audioButtonKey,
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: widget.isListening
                              ? primaryColor
                              : Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isListening
                                ? primaryColor
                                : Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_isSending || widget.isLoading)
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    widget.onMicrophoneTap!();
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child: Icon(
                                widget.isListening ? Icons.mic : Icons.mic_none,
                                color: widget.isListening
                                    ? Colors.white
                                    : Color(0xFF666666),
                                size: iconSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(width: 10),

                    // Send Button
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: (_isSending || widget.isLoading)
                            ? Colors.grey.shade400
                            : primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (_isSending || widget.isLoading)
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  print('🖱️ Send button clicked');
                                  _handleSendMessage();
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Center(
                            child: (_isSending || widget.isLoading)
                                ? SizedBox(
                                    width: iconSize - 4,
                                    height: iconSize - 4,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: iconSize,
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