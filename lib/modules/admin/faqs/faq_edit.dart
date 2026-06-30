import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modules/admin/faqs/faq_info.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

void showEditFAQModal(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
}) {
  final faqData = userDoc.data() as Map<String, dynamic>;
  final questionController = TextEditingController(
    text: faqData['question'] ?? '',
  );
  final answerController = TextEditingController(text: faqData['answer'] ?? '');

  String selectedCategory = faqData['category'] ?? 'General';
  final categories = ['Admission', 'Scholarship', 'Placement', 'General'];

  String? questionError;
  String? answerError;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit FAQ',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                      child: Row(
                        children: [
                          if (previousModal == 'info') ...[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Future.delayed(
                                    const Duration(milliseconds: 200),
                                    () => showFAQInfoModal(
                                      context,
                                      userDoc,
                                      fromEdit: true,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.edit_document,
                              color: Colors.white,
                              size: isMobile ? 24 : 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit FAQ',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Update FAQ information',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
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
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question Section
                            buildSectionHeader('Question', Icons.help_outline),
                            const SizedBox(height: 12),

                            //  REPLACE WITH ERROR HANDLING
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: questionController,
                                  onChanged: (value) {
                                    if (questionError != null &&
                                        value.trim().isNotEmpty) {
                                      setState(() {
                                        questionError = null;
                                      });
                                    }
                                  },
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter the frequently asked question...',
                                    errorText: questionError,
                                    errorMaxLines: 2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            questionError != null
                                                ? Colors.red
                                                : const Color(0xFFE2E8F0),
                                        width: questionError != null ? 2 : 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            questionError != null
                                                ? Colors.red
                                                : const Color(0xFFE2E8F0),
                                        width: questionError != null ? 2 : 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            questionError != null
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
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Answer Section
                            buildSectionHeader(
                              'Answer',
                              Icons.lightbulb_outline,
                            ),
                            const SizedBox(height: 12),

                            //  REPLACE WITH ERROR HANDLING
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: answerController,
                                  onChanged: (value) {
                                    if (answerError != null &&
                                        value.trim().isNotEmpty) {
                                      setState(() {
                                        answerError = null;
                                      });
                                    }
                                  },
                                  maxLines: 4,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter the detailed answer to this question...',
                                    errorText: answerError,
                                    errorMaxLines: 2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            answerError != null
                                                ? Colors.red
                                                : const Color(0xFFE2E8F0),
                                        width: answerError != null ? 2 : 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            answerError != null
                                                ? Colors.red
                                                : const Color(0xFFE2E8F0),
                                        width: answerError != null ? 2 : 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            answerError != null
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
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Category Section
                            buildSectionHeader(
                              'Category',
                              Icons.category_outlined,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
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
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              items:
                                  categories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                category,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(category),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedCategory = newValue;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 32),

                            // Action Buttons
                            _buildActionButtons(
                              context,
                              userDoc,
                              questionController,
                              answerController,
                              selectedCategory,
                              previousModal,
                              isMobile,
                              setState, //  PASS setState
                              () => questionError, //  PASS error getters
                              () => answerError,
                              (error) =>
                                  questionError = error, //  PASS error setters
                              (error) => answerError = error,
                            ),
                          ],
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

Widget _buildActionButtons(
  BuildContext context,
  DocumentSnapshot userDoc,
  TextEditingController questionController,
  TextEditingController answerController,
  String selectedCategory,
  String? previousModal,
  bool isMobile,
  StateSetter setState, //  ADD setState parameter
  String? Function() getQuestionError, //  ADD error getters
  String? Function() getAnswerError,
  Function(String?) setQuestionError, //  ADD error setters
  Function(String?) setAnswerError,
) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth >= 600 && screenWidth < 1100;

  double buttonHeight = isMobile ? 40 : (isTablet ? 44 : 46);
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              //  ADD VALIDATION
              setState(() {
                setQuestionError(null);
                setAnswerError(null);
              });

              bool hasError = false;

              if (questionController.text.trim().isEmpty) {
                setState(() {
                  setQuestionError('Please enter a question');
                });
                hasError = true;
              }

              if (answerController.text.trim().isEmpty) {
                setState(() {
                  setAnswerError('Please enter an answer');
                });
                hasError = true;
              }

              if (hasError) {
                return;
              }

              _handleSaveChanges(
                context,
                userDoc,
                questionController.text.trim(),
                answerController.text.trim(),
                selectedCategory,
                previousModal,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
            child: Text(
              'Save Changes',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ],
  );
}

Color _getCategoryColor(String category) {
  switch (category) {
    case 'Admission':
      return const Color(0xFF10B981);
    case 'Scholarship':
      return const Color(0xFFF59E0B);
    case 'Placement':
      return const Color(0xFF3B82F6);
    case 'General':
    default:
      return const Color(0xFF6B7280);
  }
}

Future<void> _handleSaveChanges(
  BuildContext context,
  DocumentSnapshot userDoc,
  String question,
  String answer,
  String category,
  String? previousModal,
) async {
  try {
    final faqData = userDoc.data() as Map<String, dynamic>;
    final originalQuestion = faqData['question'] ?? 'Unknown';
    final feedbackContext = Navigator.of(context, rootNavigator: true).context;

    unawaited(() async {
      try {
        await FirebaseFirestore.instance.collection('faqs').doc(userDoc.id).update({
          'question': question,
          'answer': answer,
          'category': category,
          'updatedAt': Timestamp.now(),
        });

        final currentUser = FirebaseAuth.instance.currentUser;
        String actorName = 'Unknown';

        if (currentUser != null) {
          final doc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            actorName = data['name'] ?? currentUser.email ?? 'Unknown';
          }
        }

        final logRef = FirebaseFirestore.instance.collection('logs').doc();
        await logRef.set({
          'logId': logRef.id,
          'user': actorName,
          'action': 'Updated FAQ: $originalQuestion to $question',
          'time': Timestamp.now(),
        });

        final updatedDoc =
            await FirebaseFirestore.instance
                .collection('faqs')
                .doc(userDoc.id)
                .get();

        if (feedbackContext.mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (previousModal == 'info' && updatedDoc.exists) {
              showFAQInfoModal(feedbackContext, updatedDoc, fromEdit: true);
            }
          });

          SnackbarUtil.showSuccess(feedbackContext, 'FAQ updated successfully');
        }
      } catch (e) {
        if (feedbackContext.mounted) {
          SnackbarUtil.showError(
            feedbackContext,
            'FAQ update failed: ${e.toString()}',
          );
        }
      }
    }());

    SnackbarUtil.showInfo(context, 'FAQ updated successfully');
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (context.mounted) {
      SnackbarUtil.showError(context, 'FAQ update failed: ${e.toString()}');
    }
  }
}
