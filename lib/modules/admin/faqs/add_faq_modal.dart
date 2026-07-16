import 'dart:async';

import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void showAddFaqModal(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add FAQ',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const AddFaqModal();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

class AddFaqModal extends StatelessWidget {
  const AddFaqModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildModal(context, true, false, false),
      tabletBody: _buildModal(context, false, true, false),
      desktopBody: _buildModal(context, false, false, true),
    );
  }

  Widget _buildModal(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive dimensions
    double modalWidth;
    double modalHeight;
    EdgeInsets modalPadding;

    if (isMobile) {
      modalWidth = screenWidth * 0.95;
      modalHeight = screenHeight * 0.85;
      modalPadding = const EdgeInsets.all(16);
    } else if (isTablet) {
      modalWidth = screenWidth * 0.80;
      modalHeight = screenHeight * 0.80;
      modalPadding = const EdgeInsets.all(24);
    } else {
      modalWidth = 600;
      modalHeight = screenHeight * 0.76;
      modalPadding = const EdgeInsets.all(32);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: modalPadding,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            child: AddFaqContent(
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
            ),
          ),
        ),
      ),
    );
  }
}

class AddFaqContent extends StatefulWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  const AddFaqContent({
    Key? key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<AddFaqContent> createState() => _AddFaqContentState();
}

class _AddFaqContentState extends State<AddFaqContent> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  String _selectedCategory = 'Admission';
  bool _isSubmitting = false;

  String? _questionError;
  String? _answerError;

  Future<List<double>> _generateEmbedding(String text) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'generateEmbedding',
    );

    final result = await callable.call({'text': text});

    return (result.data['embedding'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
  }

  final List<String> _categories = ['Admission', 'Scholarship', 'Placement'];

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _saveFaq() async {
    setState(() {
      _questionError = null;
      _answerError = null;
    });

    bool hasError = false;

    if (_questionController.text.trim().isEmpty) {
      setState(() {
        _questionError = 'Please enter a question';
      });
      hasError = true;
    }

    if (_answerController.text.trim().isEmpty) {
      setState(() {
        _answerError = 'Please enter an answer';
      });
      hasError = true;
    }

    if (hasError) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final question = _questionController.text.trim();
      final answer = _answerController.text.trim();
      final category = _selectedCategory;
      final feedbackContext = Navigator.of(context, rootNavigator: true).context;

      unawaited(() async {
        try {
          List<double>? embedding;
          try {
            embedding = await _generateEmbedding('Q: $question\nA: $answer');
          } catch (e) {
            print(' Failed to generate embedding: $e');
          }

          final Map<String, dynamic> faqData = {
            'question': question,
            'answer': answer,
            'category': category,
            'isPredefined': true,
            'createdAt': Timestamp.now(),
            'similarityCount': 0,
          };

          if (embedding != null) {
            faqData['embedding'] = embedding;
            faqData['geminiEmbedding'] = embedding;
            faqData['contextEmbedding'] = embedding;
            faqData['faqContextEmbedding'] = embedding;
            faqData['embeddingModel'] = 'gemini-embedding-001';
            faqData['embeddingDimensions'] = embedding.length;
          }

          await FirebaseFirestore.instance.collection('faqs').add(faqData);
          await _logCreateAction();

          if (feedbackContext.mounted) {
            if (embedding != null) {
              SnackbarUtil.showSuccess(
                feedbackContext,
                'FAQ created successfully!',
              );
            } else {
              SnackbarUtil.showWarning(
                feedbackContext,
                'FAQ created successfully!',
              );
            }
          }
        } catch (e) {
          if (feedbackContext.mounted) {
            SnackbarUtil.showError(
              feedbackContext,
              'FAQ creation failed: $e',
            );
          }
        }
      }());

      SnackbarUtil.showInfo(context, 'FAQ created successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      SnackbarUtil.showError(context, 'FAQ creation failed: $e');
    }
  }

  Future<void> _logCreateAction() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final currentUserDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        if (currentUserDoc.exists) {
          final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
          actorName = currentUserData['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Created new FAQ: ${_questionController.text.trim()}',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print('Failed to log action: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
            decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.help_outline,
                    color: Colors.white,
                    size: widget.isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New FAQ',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a frequently asked question',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 14 : 16,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 20 : 28,
                vertical: widget.isMobile ? 20 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Section
                      buildSectionHeader('Question', Icons.quiz_outlined),
                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _questionController,
                            onChanged: (value) {
                              if (_questionError != null &&
                                  value.trim().isNotEmpty) {
                                setState(() {
                                  _questionError = null;
                                });
                              }
                            },
                            maxLines: 2,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              labelText: 'FAQ Question',
                              hintText:
                                  'Enter the frequently asked question...',
                              alignLabelWithHint: true,
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 48,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 10,
                                  top: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: Icon(
                                    Icons.help_outline,
                                    color:
                                        _questionError != null
                                            ? Colors.red
                                            : const Color(0xFF6B7280),
                                    size: 20,
                                  ),
                                ),
                              ),
                              errorText: _questionError,
                              labelStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color:
                                    _questionError != null
                                        ? Colors.red
                                        : const Color(0xFF6B7280),
                                fontWeight: FontWeight.w400,
                              ),
                              hintStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w300,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color:
                                      _questionError != null
                                          ? Colors.red
                                          : const Color(0xFFE5E7EB),
                                  width: _questionError != null ? 2 : 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color:
                                      _questionError != null
                                          ? Colors.red
                                          : const Color(0xFF2E7D32),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFBFC),
                              contentPadding: const EdgeInsets.fromLTRB(
                                0,
                                16,
                                16,
                                16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Category Section
                      buildSectionHeader('Category', Icons.category_outlined),
                      const SizedBox(height: 16),
                      _buildCategorySection(),

                      const SizedBox(height: 24),

                      // Answer Section
                      buildSectionHeader(
                        'Answer',
                        Icons.question_answer_outlined,
                      ),
                      const SizedBox(height: 16),

                      //  REPLACE WITH CUSTOM TEXTFIELD WITH ERROR HANDLING
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _answerController,
                            onChanged: (value) {
                              if (_answerError != null &&
                                  value.trim().isNotEmpty) {
                                setState(() {
                                  _answerError = null;
                                });
                              }
                            },
                            maxLines: 5,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              labelText: 'FAQ Answer',
                              hintText:
                                  'Enter the detailed answer to this question...',
                              alignLabelWithHint: true,
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 48,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 10,
                                  top: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: Icon(
                                    Icons.article_outlined,
                                    color:
                                        _answerError != null
                                            ? Colors.red
                                            : const Color(0xFF6B7280),
                                    size: 20,
                                  ),
                                ),
                              ),
                              errorText: _answerError,
                              errorMaxLines: 2,
                              labelStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color:
                                    _answerError != null
                                        ? Colors.red
                                        : const Color(0xFF6B7280),
                                fontWeight: FontWeight.w400,
                              ),
                              hintStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w300,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color:
                                      _answerError != null
                                          ? Colors.red
                                          : const Color(0xFFE5E7EB),
                                  width: _answerError != null ? 2 : 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color:
                                      _answerError != null
                                          ? Colors.red
                                          : const Color(0xFF2E7D32),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFBFC),
                              contentPadding: const EdgeInsets.fromLTRB(
                                0,
                                16,
                                16,
                                16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      _buildActionButtons(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: widget.isMobile ? 8 : 10,
          runSpacing: widget.isMobile ? 8 : 10,
          children:
              _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isMobile ? 16 : 20,
                        vertical: widget.isMobile ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: widget.isMobile ? 13 : 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    double buttonHeight =
        widget.isMobile
            ? 40
            : widget.isTablet
            ? 44
            : 46;
    double fontSize = widget.isMobile ? 14 : 15;
    double borderRadius = 10;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 20,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveFaq,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 20,
                ),
              ),
              child:
                  _isSubmitting
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Creating...',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                      : Text(
                        'Create FAQ',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
