import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/modal_pages/modal_widget/top_right_alert.dart';
import 'package:capstone_project/models/admissions.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/services/file_service2.dart';
import 'package:uuid/uuid.dart';
import 'package:capstone_project/models/info_bank.dart';

class AdmissionFormDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  final bool isEdit;

  const AdmissionFormDialog({
    Key? key,
    this.doc,
    this.isEdit = false,
  }) : super(key: key);

  @override
  State<AdmissionFormDialog> createState() => _AdmissionFormDialogState();
}

class _AdmissionFormDialogState extends State<AdmissionFormDialog> {
  final FileService _fileService = FileService();
  final CohereService _cohereService = CohereService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _academicYearController = TextEditingController();

  List<TextEditingController> _contactControllers = [TextEditingController()];
  List<TextEditingController> _stepControllers = [TextEditingController()];
  List<TextEditingController> _linkControllers = [TextEditingController()];

  bool _isSubmitting = false;
  bool _isProcessing = false;
  String? _selectedFileName;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.doc != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.doc!.data() as Map<String, dynamic>;
    _titleController.text = data['title'] ?? '';
    _contentController.text = data['content'] ?? '';
    _sourceController.text = data['source'] ?? '';
    _academicYearController.text = data['academicYear'] ?? '';

    if (data['contact'] != null && data['contact'] is List) {
      _contactControllers = (data['contact'] as List)
          .map((c) => TextEditingController(text: c.toString()))
          .toList();
    }

    if (data['steps'] != null && data['steps'] is List) {
      _stepControllers = (data['steps'] as List)
          .map((s) => TextEditingController(text: s.toString()))
          .toList();
    }

    if (data['links'] != null && data['links'] is List) {
      _linkControllers = (data['links'] as List)
          .map((l) => TextEditingController(text: l.toString()))
          .toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _sourceController.dispose();
    _academicYearController.dispose();
    for (var c in _contactControllers) c.dispose();
    for (var s in _stepControllers) s.dispose();
    for (var l in _linkControllers) l.dispose();
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

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileBytes = result.files.single.bytes;

        setState(() {
          _selectedFile = file;
          _selectedFileName = fileName;
          _isProcessing = true;
        });

        String extractedText;
        final extension = fileName.split('.').last.toLowerCase();

        if (extension == 'pdf' && fileBytes != null) {
          extractedText = await _fileService.extractTextFromPdfBytes(fileBytes);
        } else {
          extractedText = await _fileService.extractTextFromFile(file);
        }

        await _processExtractedText(extractedText, fileName);

        setState(() => _isProcessing = false);
        _showAlert('File processed successfully!', AlertType.success);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showAlert('Error processing file: $e', AlertType.error);
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
      _showAlert('Error picking image: $e', AlertType.error);
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
      _showAlert('Error taking photo: $e', AlertType.error);
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() => _isProcessing = true);

    try {
      String extractedText;

      if (kIsWeb || Platform.isWindows) {
        extractedText = "OCR not yet implemented for web/windows";
        _showAlert('Tesseract OCR not yet implemented', AlertType.warning);
        setState(() => _isProcessing = false);
        return;
      } else {
        final inputImage = InputImage.fromFilePath(image.path);
        final RecognizedText recognizedText = 
            await _textRecognizer.processImage(inputImage);
        extractedText = recognizedText.text;
      }

      if (extractedText.trim().isEmpty) {
        _showAlert('No text found in image', AlertType.warning);
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _selectedFile = File(image.path);
        _selectedFileName = 'Image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });

      await _processExtractedText(extractedText, _selectedFileName!);

      setState(() => _isProcessing = false);
      _showAlert('Text extracted successfully!', AlertType.success);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showAlert('Error extracting text: $e', AlertType.error);
    }
  }

  Future<void> _processExtractedText(String text, String fileName) async {
    try {
      final analysisResult = await _cohereService.analyzeAdmission(text);

      setState(() {
        if (_titleController.text.isEmpty) {
          _titleController.text = fileName.split('.').first;
        }
        _contentController.text = text;
        _sourceController.text = fileName;
        _academicYearController.text = analysisResult['academicYear'] ?? '';

        if (analysisResult['contacts'] is List<Map<String, dynamic>>) {
          List<Map<String, dynamic>> contacts =
              analysisResult['contacts'] as List<Map<String, dynamic>>;
          if (contacts.isNotEmpty) {
            _contactControllers = contacts
                .map((c) => TextEditingController(
                    text: '${c['type']}: ${c['value']}'))
                .toList();
          }
        }

        if (analysisResult['steps'] is List) {
          _stepControllers = (analysisResult['steps'] as List)
              .map((s) => TextEditingController(text: s.toString()))
              .toList();
        }

        if (analysisResult['links'] is List) {
          _linkControllers = (analysisResult['links'] as List)
              .map((l) => TextEditingController(text: l.toString()))
              .toList();
        }
      });
    } catch (e) {
      print('Error analyzing admission: $e');
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
                        'Select how you want to add admission information',
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
                if (!kIsWeb && !Platform.isWindows)
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
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
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

  Future<void> _submitForm() async {
    if (_titleController.text.trim().isEmpty) {
      _showAlert('Please enter a title', AlertType.warning);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uuid = Uuid();
      final docId = widget.isEdit ? widget.doc!.id : uuid.v4();

      final admission = Admissions(
        id: docId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        source: _sourceController.text.trim(),
        academicYear: _academicYearController.text.trim(),
        contact: _contactControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        steps: _stepControllers
            .map((s) => s.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        links: _linkControllers
            .map((l) => l.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        createdAt: DateTime.now(),
      );

      await _fileService.saveToAdmission(admission);

      if (_contentController.text.trim().isNotEmpty) {
        final informationBank = InformationBank(
          id: docId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          embedding: [],
          source: _sourceController.text.trim(),
          category: 'Admission',
        );
        await _fileService.saveToInformationBank(informationBank);
      }

      await _logCreateAction(widget.isEdit ? 'Updated' : 'Added');

      _showAlert(
        'Admission ${widget.isEdit ? 'updated' : 'added'} successfully!',
        AlertType.success,
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      _showAlert('Error: $e', AlertType.error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _logCreateAction(String action) async {
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
        'action': '$action admission: ${_titleController.text.trim()}',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print('⚠️ Failed to log action: $e');
    }
  }

  void _showAlert(String message, AlertType type) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => TopRightAlert(
        message: message,
        type: type,
        onDismiss: () => overlayEntry.remove(),
        isMobile: MediaQuery.of(context).size.width < 600,
        isTablet: MediaQuery.of(context).size.width >= 600 &&
            MediaQuery.of(context).size.width < 1100,
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: 4), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
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
                      Icons.school_outlined,
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
                          '${widget.isEdit ? 'Edit' : 'Add'} Admission',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage admission information',
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
                    if (!widget.isEdit)
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF1976D2).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.upload_file_outlined, size: 20),
                            label: Text(
                              'Import from Document/Image',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isProcessing ? null : _showUploadOptionsBottomSheet,
                          ),
                        ),
                      ),

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
                      controller: _titleController,
                      isMobile: isMobile,
                      label: 'Title *',
                      hint: 'Enter admission title',
                      icon: Icons.title_outlined,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _contentController,
                      isMobile: isMobile,
                      label: 'Content',
                      hint: 'Enter admission content',
                      icon: Icons.description_outlined,
                      maxLines: 5,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _sourceController,
                      isMobile: isMobile,
                      label: 'Source',
                      hint: 'Enter source',
                      icon: Icons.source_outlined,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _academicYearController,
                      isMobile: isMobile,
                      label: 'Academic Year',
                      hint: 'e.g., 2024-2025',
                      icon: Icons.calendar_today_outlined,
                    ),
                    SizedBox(height: 24),

                    // Dynamic Lists
                    _buildDynamicListSection(
                      'Contact Information',
                      _contactControllers,
                      Icons.contact_phone_outlined,
                      'Email: email@example.com',
                      isMobile,
                    ),
                    SizedBox(height: 24),

                    _buildDynamicListSection(
                      'Application Steps',
                      _stepControllers,
                      Icons.list_alt_outlined,
                      'Enter step',
                      isMobile,
                    ),
                    SizedBox(height: 24),

                    _buildDynamicListSection(
                      'Relevant Links',
                      _linkControllers,
                      Icons.link_outlined,
                      'https://example.com',
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
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF6B7280),
                          side: BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
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
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
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
                                '${widget.isEdit ? 'Update' : 'Add'} Admission',
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
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Color(0xFF2E7D32)),
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
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
                    label: '',
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
            'Add ${title.split(' ').first}',
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