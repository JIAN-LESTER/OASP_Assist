import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:capstone_project/models/scholarships.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/services/file_service2.dart';
import 'package:uuid/uuid.dart';
import 'package:capstone_project/models/info_bank.dart';
import 'package:intl/intl.dart';

class ScholarshipFormDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  final bool isEdit;

  const ScholarshipFormDialog({Key? key, this.doc, this.isEdit = false})
    : super(key: key);

  @override
  State<ScholarshipFormDialog> createState() => _ScholarshipFormDialogState();
}

class _ScholarshipFormDialogState extends State<ScholarshipFormDialog> {
  final FileService _fileService = FileService();
  final CohereService _cohereService = CohereService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _applicationLinkController =
      TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  List<TextEditingController> _eligibilityControllers = [
    TextEditingController(),
  ];
  List<TextEditingController> _privilegeControllers = [TextEditingController()];

  bool _isSubmitting = false;
  bool _isProcessing = false;
  DateTime? _selectedDeadline;
  String? _selectedFileName;
  File? _selectedFile;
  bool _fileUploaded = false;
  String? _extractedContent;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.doc != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.doc!.data() as Map<String, dynamic>;
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _providerController.text = data['scholarshipProvider'] ?? '';
    _applicationLinkController.text = data['applicationLink'] ?? '';

    if (data['deadline'] != null) {
      if (data['deadline'] is Timestamp) {
        _selectedDeadline = (data['deadline'] as Timestamp).toDate();
        _deadlineController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDeadline!);
      }
    }

    if (data['eligibilityRequirements'] != null &&
        data['eligibilityRequirements'] is List) {
      _eligibilityControllers =
          (data['eligibilityRequirements'] as List)
              .map((e) => TextEditingController(text: e.toString()))
              .toList();
    }

    if (data['privileges'] != null && data['privileges'] is List) {
      _privilegeControllers =
          (data['privileges'] as List)
              .map((p) => TextEditingController(text: p.toString()))
              .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _providerController.dispose();
    _applicationLinkController.dispose();
    _deadlineController.dispose();
    for (var c in _eligibilityControllers) c.dispose();
    for (var p in _privilegeControllers) p.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx', 'doc'],
        withData: true,
      );

      if (result != null) {
        final fileName = result.files.single.name;
        final fileBytes = result.files.single.bytes;

        // Web platform - use bytes directly
        if (kIsWeb || fileBytes != null) {
          if (fileBytes == null) {
            throw Exception('No file data available');
          }

          setState(() {
            _selectedFileName = fileName;
            _isProcessing = true;
            _fileUploaded = false;
          });

          String extractedText;
          final extension = fileName.split('.').last.toLowerCase();

          if (extension == 'pdf') {
            extractedText = await _fileService.extractTextFromPdfBytes(
              fileBytes,
            );
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

          await _processExtractedText(extractedText, fileName);

          setState(() {
            _isProcessing = false;
            _fileUploaded = true;
          });

          if (mounted) {
            SnackbarUtil.showSuccess(context, 'File processed successfully!');
          }
        }
        // Mobile/Desktop platform - use file path
        else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);

          setState(() {
            _selectedFile = file;
            _selectedFileName = fileName;
            _isProcessing = true;
            _fileUploaded = false;
          });

          String extractedText = await _fileService.extractTextFromFile(file);
          await _processExtractedText(extractedText, fileName);

          setState(() {
            _isProcessing = false;
            _fileUploaded = true;
          });

          if (mounted) {
            SnackbarUtil.showSuccess(context, 'File processed successfully!');
          }
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _fileUploaded = false;
      });

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
      if (image != null) await _processImage(image);
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
      if (photo != null) await _processImage(photo);
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Error taking photo: $e');
      }
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _isProcessing = true;
      _fileUploaded = false;
    });

    try {
      String extractedText;

      if (kIsWeb || Platform.isWindows) {
        extractedText = "OCR not yet implemented for web/windows";
        if (mounted) {
          SnackbarUtil.showWarning(
            context,
            'Tesseract OCR not yet implemented',
          );
        }
        setState(() {
          _isProcessing = false;
          _fileUploaded = false;
        });
        return;
      } else {
        final inputImage = InputImage.fromFilePath(image.path);
        final RecognizedText recognizedText = await _textRecognizer
            .processImage(inputImage);
        extractedText = recognizedText.text;
      }

      if (extractedText.trim().isEmpty) {
        if (mounted) {
          SnackbarUtil.showWarning(context, 'No text found in image');
        }
        setState(() {
          _isProcessing = false;
          _fileUploaded = false;
        });
        return;
      }

      setState(() {
        _selectedFile = File(image.path);
        _selectedFileName =
            'Image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });

      await _processExtractedText(extractedText, _selectedFileName!);

      setState(() {
        _isProcessing = false;
        _fileUploaded = true;
      });

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'Text extracted successfully!');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _fileUploaded = false;
      });

      if (mounted) {
        SnackbarUtil.showError(context, 'Error extracting text: $e');
      }
    }
  }

  Future<void> _processExtractedText(String text, String fileName) async {
    try {
      // Save the extracted text
      _extractedContent = text;

      final analysisResult = await _cohereService.analyzeScholarship(text);

      if (analysisResult['scholarships'] is List &&
          (analysisResult['scholarships'] as List).isNotEmpty) {
        final scholarshipData = (analysisResult['scholarships'] as List).first;

        setState(() {
          _nameController.text = scholarshipData['name'] ?? '';
          _descriptionController.text = scholarshipData['description'] ?? '';
          _providerController.text =
              scholarshipData['scholarshipProvider'] ?? '';
          _applicationLinkController.text =
              scholarshipData['application_link'] ?? '';

          if (analysisResult['deadline'] != null) {
            _selectedDeadline = analysisResult['deadline'] as DateTime?;
            if (_selectedDeadline != null) {
              _deadlineController.text = DateFormat(
                'yyyy-MM-dd',
              ).format(_selectedDeadline!);
            }
          }

          if (scholarshipData['eligibilityRequirements'] is List) {
            _eligibilityControllers =
                (scholarshipData['eligibilityRequirements'] as List)
                    .map((e) => TextEditingController(text: e.toString()))
                    .toList();
          }

          if (scholarshipData['privileges'] is List) {
            _privilegeControllers =
                (scholarshipData['privileges'] as List)
                    .map((p) => TextEditingController(text: p.toString()))
                    .toList();
          }
        });
      }
    } catch (e) {
      print('Error analyzing scholarship: $e');
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Input Method',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select how you want to add scholarship information',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                _buildUploadOption(
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Upload Document',
                  subtitle: 'PDF, TXT, DOC, DOCX',
                  color: Color(0xFF2E7D32),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                if (!kIsWeb &&
                    !(Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS))
                  _buildUploadOption(
                    icon: Icons.photo_library_outlined,
                    title: 'Choose from Gallery',
                    subtitle: 'Extract text from image',
                    color: Color(0xFF1976D2),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                if (!kIsWeb &&
                    !(Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS))
                  _buildUploadOption(
                    icon: Icons.camera_alt_outlined,
                    title: 'Take Photo',
                    subtitle: 'Capture and extract text',
                    color: Color(0xFFED6C02),
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                _buildUploadOption(
                  icon: Icons.edit_outlined,
                  title: 'Manual Entry',
                  subtitle: 'Fill in details manually',
                  color: Color(0xFF9C27B0),
                  onTap: () => Navigator.pop(context),
                ),
                SizedBox(height: 24),
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
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
        _deadlineController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        SnackbarUtil.showWarning(context, 'Please enter scholarship name');
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uuid = Uuid();
      final docId = widget.isEdit ? widget.doc!.id : uuid.v4();

      final scholarship = Scholarship(
        scholarshipID: docId,
        sourceId: docId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        scholarshipProvider: _providerController.text.trim(),
        eligibilityRequirements:
            _eligibilityControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        privileges:
            _privilegeControllers
                .map((p) => p.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        deadline: _selectedDeadline,
        applicationLink: _applicationLinkController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _fileService.saveMultipleScholarships([scholarship]);

      // Save to information bank if we have extracted content from a file
      if (_extractedContent != null && _extractedContent!.trim().isNotEmpty) {
        final informationBank = InformationBank(
          id: docId,
          title: _nameController.text.trim(),
          content: _extractedContent!,
          embedding: [],
          source: _selectedFileName ?? 'Manual Entry',
          category: 'Scholarship',
        );
        await _fileService.saveToInformationBank(informationBank);

        print(
          '✅ Saved to information bank with ${_extractedContent!.length} characters',
        );
      } else if (_descriptionController.text.trim().isNotEmpty) {
        // Fallback: If no file was uploaded but description was manually entered
        final informationBank = InformationBank(
          id: docId,
          title: _nameController.text.trim(),
          content: _descriptionController.text.trim(),
          embedding: [],
          source: 'Manual Entry',
          category: 'Scholarship',
        );
        await _fileService.saveToInformationBank(informationBank);

        print('✅ Saved to information bank from manual description');
      }

      await _logAction(widget.isEdit ? 'Updated' : 'Added');

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'Scholarship ${widget.isEdit ? 'updated' : 'added'} successfully!',
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _logAction(String action) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          actorName = userData['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': '$action scholarship: ${_nameController.text.trim()}',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print('⚠️ Failed to log action: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    double modalWidth;
    double modalHeight;
    if (isMobile) {
      modalWidth = screenWidth * 0.95;
      modalHeight = screenHeight * 0.90;
    } else if (isTablet) {
      modalWidth = screenWidth * 0.80;
      modalHeight = screenHeight * 0.85;
    } else {
      modalWidth = 700;
      modalHeight = screenHeight * 0.80;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 16 : 24,
      ),
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
              offset: Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 28),
              decoration: BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isMobile ? 16 : 20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.card_giftcard_outlined,
                      color: Colors.white,
                      size: isMobile ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.isEdit ? 'Edit' : 'Add'} Scholarship',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage scholarship details',
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
                        padding: EdgeInsets.all(8),
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
                  horizontal: isMobile ? 20 : 28,
                  vertical: isMobile ? 20 : 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload button
                    if (!widget.isEdit) ...[
                      buildUploadArea(isMobile),
                      SizedBox(height: 24),
                    ],
                    if (_isProcessing)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2E7D32),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Processing document...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: 24),

                    // Form fields
                    buildTextField(
                      controller: _nameController,
                      isMobile: isMobile,
                      label: 'Scholarship Name *',
                      hint: 'Enter scholarship name',
                      icon: Icons.card_giftcard_outlined,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _descriptionController,
                      isMobile: isMobile,
                      label: 'Description',
                      hint: 'Enter scholarship description',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _providerController,
                      isMobile: isMobile,
                      label: 'Provider',
                      hint: 'Enter scholarship provider',
                      icon: Icons.business_outlined,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _applicationLinkController,
                      isMobile: isMobile,
                      label: 'Application Link',
                      hint: 'https://example.com/apply',
                      icon: Icons.link_outlined,
                    ),
                    SizedBox(height: 16),

                    // Deadline picker
                    InkWell(
                      onTap: _selectDeadline,
                      child: AbsorbPointer(
                        child: buildTextField(
                          controller: _deadlineController,
                          isMobile: isMobile,
                          label: 'Deadline',
                          hint: 'Select deadline',
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Dynamic Lists
                    _buildDynamicListSection(
                      'Eligibility Requirements',
                      _eligibilityControllers,
                      Icons.check_circle_outline,
                      'Enter requirement',
                      isMobile,
                    ),
                    SizedBox(height: 10),

                    _buildDynamicListSection(
                      'Benefits & Privileges',
                      _privilegeControllers,
                      Icons.star_outline,
                      'Enter benefit or privilege',
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 28,
                vertical: isMobile ? 16 : 20,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: isMobile ? 40 : 46,
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF6B7280),
                          side: BorderSide(
                            color: Color(0xFFD1D5DB),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: isMobile ? 40 : 46,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor: Color(0xFFE5E7EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '${widget.isEdit ? 'Updating' : 'Creating'}...',
                                      style: TextStyle(
                                        fontSize: isMobile ? 14 : 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  '${widget.isEdit ? 'Update' : 'Add'} Scholarship',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.w600,
                                  ),
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

  Widget buildUploadArea(bool isMobile) {
    final hasFile = _selectedFile != null || _fileUploaded;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasFile ? Color(0xFF2E7D32).withOpacity(0.4) : Color(0xFFE5E7EB),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isProcessing ? null : _showUploadOptionsBottomSheet,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 32,
              vertical: isMobile ? 24 : 32,
            ),
            child: Column(
              children: [
                // Processing state
                if (_isProcessing)
                  Column(
                    children: [
                      SizedBox(
                        width: isMobile ? 56 : 72,
                        height: isMobile ? 56 : 72,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 16,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                // File uploaded state
                else if (hasFile)
                  Column(
                    children: [
                      Container(
                        width: isMobile ? 56 : 72,
                        height: isMobile ? 56 : 72,
                        decoration: BoxDecoration(
                          color: Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: isMobile ? 28 : 32,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _selectedFileName ?? 'File uploaded',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 16,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF2E7D32),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'File processed successfully',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Click to upload a different file',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  )
                // No file state
                else
                  Column(
                    children: [
                      Container(
                        width: isMobile ? 56 : 72,
                        height: isMobile ? 56 : 72,
                        decoration: BoxDecoration(
                          color: Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.upload_file,
                          color: Color(0xFF2E7D32),
                          size: isMobile ? 28 : 32,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Click to upload document or image',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 16,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Documents: PDF, TXT, DOC, DOCX • Images: JPG, PNG',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicListSection(
    String title,
    List<TextEditingController> controllers,
    IconData icon,
    String hint,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: buildTextField(
                    controller: controller,
                    isMobile: isMobile,
                    label: title,
                    hint: hint,
                    icon: icon,
                  ),
                ),
                if (controllers.length > 1) ...[
                  SizedBox(width: 8),
                  Container(
                    height: 46,
                    width: 46,
                    margin: EdgeInsets.only(top: 0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            controller.dispose();
                            controllers.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(Icons.add_circle_outline, size: 18),
          label: Text(
            'Add ${title.split(' ').last}',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF2E7D32),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () {
            setState(() {
              controllers.add(TextEditingController());
            });
          },
        ),
      ],
    );
  }
}
