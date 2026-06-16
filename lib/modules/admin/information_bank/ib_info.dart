import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modules/admin/information_bank/ib_format.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modules/admin/information_bank/ib_edit.dart';

import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';


void showIBInfoModal(
  BuildContext context,
  DocumentSnapshot doc, {
  bool fromEdit = false,
}) {
  final data = doc.data() as Map<String, dynamic>;

  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1024;
  final isDesktop = screenWidth >= 1024;

  final Timestamp timeStamp = data['createdAt'] ?? Timestamp.now();
  final DateTime date = timeStamp.toDate();
  final String formattedDate = DateFormat(
    'MMM dd, yyyy • hh:mm a',
  ).format(date);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Document Info',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 800),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                  child: Row(
                    children: [
                      // Back button (shown when coming from edit)
                      if (fromEdit) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.of(context).pop(),
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
                          Icons.description_outlined,
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
                              'Document Details',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Information and metadata',
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
                        // Title Section
                        buildSectionHeader('Title', Icons.title),
                        const SizedBox(height: 12),
                        _buildContentCard(
                          data['ib_title'] ?? 'Untitled Document',
                        ),

                        const SizedBox(height: 24),

                        // Content Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildSectionHeader(
                              'Content',
                              Icons.article_outlined,
                            ),
                            TextButton.icon(
                              onPressed:
                                  () => _showFullContentModal(
                                    context,
                                    data,
                                    isMobile,
                                    isTablet,
                                    doc,
                                  ),
                              icon: const Icon(
                                Icons.open_in_full,
                                size: 16,
                                color: Color(0xFF2E7D32),
                              ),
                              label: const Text(
                                'View Full',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                           child: FormattedContentDisplay(
  content: data['content'] ?? 'No content available.',
  source: data['source'] ?? 'Unknown',
  style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF475569),
    height: 1.6,
    fontWeight: FontWeight.w400,
  ),
),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Metadata Section
                        buildSectionHeader('Metadata', Icons.info_outline),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildMetadataRow(
                                'Source',
                                data['source'],
                                Icons.source_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Category',
                                data['category'],
                                Icons.category_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Created',
                                formattedDate,
                                Icons.schedule_outlined,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        _buildActionButtons(
                          context,
                          doc,
                          isMobile,
                          isTablet,
                          isDesktop,
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

String cleanPdfContent(String content) {
  // Remove single line breaks but keep paragraph breaks (double line breaks)
  String cleaned = content
      // Replace single line breaks with space
      .replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ')
      // Normalize multiple spaces to single space
      .replaceAll(RegExp(r' +'), ' ')
      // Clean up spacing around punctuation
      .replaceAll(RegExp(r' +([.,;:!?])'), r'$1')
      // Remove leading/trailing whitespace
      .trim();
  
  return cleaned;
}

// Alternative: More aggressive cleaning for heavily broken PDFs
String cleanPdfContentAggressive(String content) {
  return content
      // Replace all line breaks with spaces
      .replaceAll('\n', ' ')
      // Replace multiple spaces with single space
      .replaceAll(RegExp(r' +'), ' ')
      // Clean up spacing around punctuation
      .replaceAll(RegExp(r' +([.,;:!?])'), r'$1')
      .trim();
}

Widget _buildActionButtons(
  BuildContext context,
  DocumentSnapshot doc,
  bool isMobile,
  bool isTablet,
  bool isDesktop,
) {
  double buttonHeight =
      isMobile
          ? 40
          : isTablet
          ? 44
          : 46;
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      // Delete Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () =>showDeleteConfirmation(context, doc, DeleteConfigs.document, 'information_bank', customDeleteHandler: handleInformationBankDelete),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Edit Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                () => showEditIBModal(context, doc, previousModal: 'info'),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Edit',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
    ],
  );
}

void _showFullContentModal(
  BuildContext context,
  Map<String, dynamic> data,
  bool isMobile,
  bool isTablet,
  DocumentSnapshot doc,
) {
  Navigator.of(context).pop();

  Future.delayed(const Duration(milliseconds: 200), () {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Full Content',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 800,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
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
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                    child: Row(
                      children: [
                        // Back button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              Navigator.of(context).pop();
                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () => showIBInfoModal(context, doc),
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.article,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full Content',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['ib_title'] ?? 'Document Content',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 15,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

                  // Full Content
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Content stats
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Color(0xFF2E7D32).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF2E7D32),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(data['content'] ?? '').toString().length} characters',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Scrollable content
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: SingleChildScrollView(
child: SelectableFormattedContent(
  content: data['content'] ?? 'No content available.',
  source: data['source'] ?? 'Unknown',
  style: TextStyle(
    fontSize: isMobile ? 14 : 16,
    color: const Color(0xFF334155),
    height: 1.6,
    fontWeight: FontWeight.w400,
  ),
),                     ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Action Buttons
                          _buildFullContentActionButtons(
                            context,
                            doc,
                            isMobile,
                            isTablet,
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
  });
}

Widget _buildFullContentActionButtons(
  BuildContext context,
  DocumentSnapshot doc,
  bool isMobile,
  bool isTablet,
) {
  double buttonHeight =
      isMobile
          ? 40
          : isTablet
          ? 44
          : 46;
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      // Delete Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => showDeleteConfirmation(context, doc, DeleteConfigs.document, 'information_bank', customDeleteHandler: handleInformationBankDelete),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Edit Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                () =>
                    showEditIBModal(context, doc, previousModal: 'fullContent'),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Edit',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
    ],
  );
}



Widget _buildContentCard(String content) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
    ),
    child: Text(
      content,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF334155),
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    ),
  );
}

Widget _buildMetadataRow(String label, dynamic value, IconData icon) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF64748B)),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          value?.toString() ?? 'Not available',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ],
  );
}
