import 'dart:convert';

import 'package:capstone_project/modules/admin_module/information_bank_module/ib_format.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:capstone_project/modules/admin_module/information_bank_module/ib_info.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:capstone_project/services/file_service2.dart';

void showEditIBModal(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
}) {
  final userData = userDoc.data() as Map<String, dynamic>;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit Document',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _EditIBModalContent(
        userDoc: userDoc,
        userData: userData,
        previousModal: previousModal,
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

class _EditIBModalContent extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final Map<String, dynamic> userData;
  final String? previousModal;

  const _EditIBModalContent({
    required this.userDoc,
    required this.userData,
    this.previousModal,
  });

  @override
  State<_EditIBModalContent> createState() => _EditIBModalContentState();
}

class _EditIBModalContentState extends State<_EditIBModalContent> {
  late TextEditingController titleController;
  late TextEditingController contentController;
  late String selectedCategory;

  final FileService _fileService = FileService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isProcessingFile = false;
  String? _uploadedFileName;

  String? _titleError;
  String? _contentError;
  String? _categoryError;

  final categories = ['Admission', 'Scholarship', 'Placement', 'General'];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(
      text: widget.userData['ib_title'] ?? widget.userData['title'] ?? '',
    );

    // ✅ Use formatForEditing to preserve structure for editing
    final source = widget.userData['source'] ?? 'Unknown';
    final originalContent = widget.userData['content'] ?? '';

    contentController = TextEditingController(
      text: ContentFormatter.formatForEditing(originalContent, source),
    );

    String rawCategory = widget.userData['category'] ?? 'General';
    selectedCategory = _normalizeCategory(rawCategory);
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx', 'doc'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isProcessingFile = true);

        final fileName = result.files.single.name;
        final fileBytes = result.files.single.bytes!;

        String extractedText;
        final extension = fileName.split('.').last.toLowerCase();

        if (extension == 'pdf') {
          extractedText = await _fileService.extractTextFromPdfBytes(fileBytes);
        } else if (extension == 'docx' || extension == 'doc') {
          extractedText = await _fileService.extractTextFromFileBytes(
            fileBytes,
            fileName,
          );
        } else if (extension == 'txt') {
          extractedText = utf8.decode(fileBytes);
        } else {
          throw UnsupportedError('Unsupported file type: $extension');
        }

        setState(() {
          contentController.text = extractedText;
          _uploadedFileName = fileName;
          _isProcessingFile = false;
        });

        if (mounted) {
          SnackbarUtil.showSuccess(context, 'File processed successfully!');
        }
      }
    } catch (e) {
      setState(() => _isProcessingFile = false);
      if (mounted) {
        SnackbarUtil.showError(context, 'Error processing file: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Error picking image: $e');
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        await _processImage(photo);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Error taking photo: $e');
      }
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() => _isProcessingFile = true);

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String extractedText = recognizedText.text;

      if (extractedText.trim().isEmpty) {
        if (mounted) {
          SnackbarUtil.showWarning(context, 'No text found in image');
        }
        setState(() => _isProcessingFile = false);
        return;
      }

      setState(() {
        contentController.text = extractedText;
        _uploadedFileName =
            'Image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _isProcessingFile = false;
      });

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'Text extracted successfully! Found ${extractedText.split(' ').length} words',
        );
      }
    } catch (e) {
      setState(() => _isProcessingFile = false);
      if (mounted) {
        SnackbarUtil.showError(context, 'Error extracting text from image: $e');
      }
    }
  }

  void _showUploadOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replace Document Content',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Choose how you want to update the content',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildUploadOption(
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Upload Document',
                  subtitle: 'PDF, TXT, DOC, DOCX',
                  color: const Color(0xFF2E7D32),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                _buildUploadOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Extract text from image',
                  color: const Color(0xFF1976D2),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildUploadOption(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Capture and extract text',
                  color: const Color(0xFFED6C02),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                child: Row(
                  children: [
                    if (widget.previousModal == 'info' ||
                        widget.previousModal == 'fullContent') ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                if (widget.previousModal == 'info') {
                                  showIBInfoModal(
                                    context,
                                    widget.userDoc,
                                    fromEdit: true,
                                  );
                                }
                              },
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
                            'Edit Document',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update document information',
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
                      // Document Title Section
                      buildSectionHeader('Document Title', Icons.title),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        onChanged: (value) {
                          if (_titleError != null && value.trim().isNotEmpty) {
                            setState(() {
                              _titleError = null;
                            });
                          }
                        },
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter document title',

                          errorText: _titleError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _titleError != null
                                      ? Colors.red
                                      : const Color(0xFFE2E8F0),
                              width: _titleError != null ? 2 : 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _titleError != null
                                      ? Colors.red
                                      : const Color(0xFFE2E8F0),
                              width: _titleError != null ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _titleError != null
                                      ? Colors.red
                                      : const Color(0xFF2E7D32),
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

                      const SizedBox(height: 24),

                      // Document Content Section with Upload Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildSectionHeader(
                            'Document Content',
                            Icons.article_outlined,
                          ),
                          if (!_isProcessingFile)
                            TextButton.icon(
                              onPressed: () {
                                if (isMobile) {
                                  _showUploadOptionsBottomSheet();
                                } else {
                                  _pickFile();
                                }
                              },
                              icon: const Icon(
                                Icons.upload_file,
                                size: 18,
                                color: Color(0xFF2E7D32),
                              ),
                              label: Text(
                                isMobile ? 'Replace' : 'Upload File',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Processing indicator
                      if (_isProcessingFile)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2E7D32).withOpacity(0.2),
                            ),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Processing file...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // File upload indicator
                        if (_uploadedFileName != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2E7D32).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF2E7D32),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Replaced with: $_uploadedFileName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _uploadedFileName = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                        // Content text field
                        TextFormField(
                          controller: contentController,
                          maxLines: 10,
                          onChanged: (value) {
                            if (_contentError != null &&
                                value.trim().isNotEmpty) {
                              setState(() {
                                _contentError = null;
                              });
                            }
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter or edit document content',

                            errorText: _contentError,
                            errorMaxLines: 2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    _contentError != null
                                        ? Colors.red
                                        : const Color(0xFFE2E8F0),
                                width: _contentError != null ? 2 : 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    _contentError != null
                                        ? Colors.red
                                        : const Color(0xFFE2E8F0),
                                width: _contentError != null ? 2 : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    _contentError != null
                                        ? Colors.red
                                        : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),

                        const SizedBox(height: 12),
                        // Character count
                        Text(
                          '${contentController.text.length} characters',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Category Section
                      buildSectionHeader('Category', Icons.category_outlined),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                        decoration: InputDecoration(
                          // ✅ ADD ERROR STYLING
                          errorText: _categoryError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _categoryError != null
                                      ? Colors.red
                                      : const Color(0xFFE2E8F0),
                              width: _categoryError != null ? 2 : 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _categoryError != null
                                      ? Colors.red
                                      : const Color(0xFFE2E8F0),
                              width: _categoryError != null ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _categoryError != null
                                      ? Colors.red
                                      : const Color(0xFF2E7D32),
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
                                        color: _getCategoryColor(category),
                                        borderRadius: BorderRadius.circular(4),
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
                              // ✅ ADD THIS
                              _categoryError = null;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      _buildActionButtons(
                        context,
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
  }

  Widget _buildActionButtons(
    BuildContext context,
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
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed:
                  _isProcessingFile ? null : () => Navigator.of(context).pop(),
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
            child: ElevatedButton.icon(
              onPressed:
                  _isProcessingFile
                      ? null
                      : () {
                        // ✅ ADD VALIDATION BEFORE SAVING
                        setState(() {
                          _titleError = null;
                          _contentError = null;
                          _categoryError = null;
                        });

                        bool hasError = false;

                        if (titleController.text.trim().isEmpty) {
                          setState(() {
                            _titleError = 'Please enter a title';
                          });
                          hasError = true;
                        }

                        if (contentController.text.trim().isEmpty) {
                          setState(() {
                            _contentError = 'Content cannot be empty';
                          });
                          hasError = true;
                        }

                        if (selectedCategory.trim().isEmpty) {
                          setState(() {
                            _categoryError = 'Please select a category';
                          });
                          hasError = true;
                        }

                        if (hasError) {
                          return;
                        }

                        final title = titleController.text.trim();
                        final content = contentController.text.trim();
                        _handleSaveChanges(
                          context,
                          widget.userDoc,
                          title,
                          content,
                          selectedCategory,
                          widget.previousModal,
                        );
                      },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
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
}

Color _getCategoryColor(String category) {
  switch (category) {
    case 'Admission':
      return const Color(0xFF3B82F6);
    case 'Scholarship':
      return const Color(0xFFF59E0B);
    case 'Placement':
      return const Color(0xFFEF4444);
    case 'General':
    default:
      return const Color(0xFF2E7D32);
  }
}

Future<void> _handleSaveChanges(
  BuildContext context,
  DocumentSnapshot userDoc,
  String title,
  String content,
  String category,
  String? previousModal,
) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          ),
    );

    final userData = userDoc.data() as Map<String, dynamic>;
    final source = userData['source'] ?? 'Unknown';

    // ✅ Format both for fair comparison
    final originalContent = ContentFormatter.formatForEditing(
      userData['content'] ?? '',
      source,
    );
    final newContent = ContentFormatter.formatForEditing(content, source);

    // Compare formatted versions
    final contentChanged = newContent.trim() != originalContent.trim();

    if (contentChanged) {
      print('🔄 Content changed - updating Pinecone vectors...');

      final fileService = FileService();
      await fileService.updateInformationBankContent(
        documentId: userDoc.id,
        newTitle: title,
        newContent: content, // Save the user's edited version
        newCategory: category,
      );

      print('✅ Content and vectors updated successfully');
    } else {
      print('ℹ️ Only metadata changed - updating Firestore only...');

      Map<String, dynamic> updateData = {
        'ib_title': title,
        'title': title,
        'category': category,
        'categoryID': category.toLowerCase(),
        'categoryType': category.toLowerCase(),
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('information_bank')
          .doc(userDoc.id)
          .update(updateData);
    }

    final updatedDocSnapshot =
        await FirebaseFirestore.instance
            .collection('information_bank')
            .doc(userDoc.id)
            .get();

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
    final logData = {
      'logId': logRef.id,
      'user': actorName,
      'action':
          'Updated document: $title (Category: $category)${contentChanged ? ' [Content Updated]' : ''}',
      'time': Timestamp.now(),
    };
    await logRef.set(logData);

    if (context.mounted) {
      Navigator.of(context).pop(); 
      Navigator.of(context).pop(); 

      Future.delayed(const Duration(milliseconds: 200), () {
        if (previousModal == 'info') {
          showIBInfoModal(context, updatedDocSnapshot, fromEdit: true);
        }
      });

      SnackbarUtil.showSuccess(
        context,
        contentChanged
            ? 'Document and embeddings updated successfully'
            : 'Document updated successfully',
      );
    }
  } catch (e) {
    print('Error updating document: $e');
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      SnackbarUtil.showError(context, 'Failed to update document: $e');
    }
  }
}

String _normalizeCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return 'Admission';
    case 'scholarship':
      return 'Scholarship';
    case 'placement':
      return 'Placement';
    case 'general':
    default:
      return 'General';
  }
}
