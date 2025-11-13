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
  final DocumentSnapshot? doc; // null for add, non-null for edit
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
  bool _useOCR = false;
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

    // Load contacts
    if (data['contact'] != null && data['contact'] is List) {
      _contactControllers = (data['contact'] as List)
          .map((c) => TextEditingController(text: c.toString()))
          .toList();
    }

    // Load steps
    if (data['steps'] != null && data['steps'] is List) {
      _stepControllers = (data['steps'] as List)
          .map((s) => TextEditingController(text: s.toString()))
          .toList();
    }

    // Load links
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
        // Use Tesseract for web/windows
        // Uncomment and implement when flusseract is added
        // final tesseract = Tesseract();
        // extractedText = await tesseract.extractText(image.path);
        extractedText = "OCR not yet implemented for web/windows";
        _showAlert('Tesseract OCR not yet implemented', AlertType.warning);
        setState(() => _isProcessing = false);
        return;
      } else {
        // Use ML Kit for mobile
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

        // Process contacts
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

        // Process steps
        if (analysisResult['steps'] is List) {
          _stepControllers = (analysisResult['steps'] as List)
              .map((s) => TextEditingController(text: s.toString()))
              .toList();
        }

        // Process links
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
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Choose Input Method',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 24),
                _buildUploadOption(
                  icon: Icons.insert_drive_file,
                  title: 'Upload Document',
                  subtitle: 'PDF, TXT, DOC, DOCX',
                  color: Color(0xFF2E7D32),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                _buildUploadOption(
                  icon: Icons.photo_library,
                  title: 'Choose from Gallery',
                  subtitle: 'Extract text from image',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                if (!kIsWeb && !Platform.isWindows)
                  _buildUploadOption(
                    icon: Icons.camera_alt,
                    title: 'Take Photo',
                    subtitle: 'Capture and extract text',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                _buildUploadOption(
                  icon: Icons.edit,
                  title: 'Manual Entry',
                  subtitle: 'Fill in details manually',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _useOCR = false);
                  },
                ),
                SizedBox(height: 16),
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
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
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
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
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

      // Create admission object
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

      // Save to Firestore
      await _fileService.saveToAdmission(admission);

      // If there's extracted text, save to information bank
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

      await _logAction(widget.isEdit ? 'Updated' : 'Added');

      _showAlert(
        'Admission ${widget.isEdit ? 'updated' : 'added'} successfully!',
        AlertType.success,
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      _showAlert('Error: $e', AlertType.error);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _logAction(String action) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
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
        'action': '$action admission: ${_titleController.text.trim()}',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print('Failed to log action: $e');
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
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 700,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 28),
              decoration: BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school, color: Colors.white, size: 24),
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
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Fill in admission details',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload button
                    if (!widget.isEdit)
                      Center(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.upload_file),
                          label: Text('Import from Document/Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _isProcessing ? null : _showUploadOptionsBottomSheet,
                        ),
                      ),

                    if (_isProcessing)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    SizedBox(height: 24),

                    // Form fields
                    buildTextField(
                      controller: _titleController,
                      isMobile: isMobile,
                      label: 'Title *',
                      hint: 'Enter admission title',
                      icon: Icons.title,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _contentController,
                      isMobile: isMobile,
                      label: 'Content',
                      hint: 'Enter admission content',
                      icon: Icons.description,
                      maxLines: 5,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _sourceController,
                      isMobile: isMobile,
                      label: 'Source',
                      hint: 'Enter source',
                      icon: Icons.source,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _academicYearController,
                      isMobile: isMobile,
                      label: 'Academic Year',
                      hint: 'e.g., 2024-2025',
                      icon: Icons.calendar_today,
                    ),
                    SizedBox(height: 24),

                    // Dynamic lists
                    _buildDynamicListSection(
                      'Contacts',
                      _contactControllers,
                      Icons.contact_phone,
                      'Email: email@example.com',
                      isMobile,
                    ),
                    SizedBox(height: 24),

                    _buildDynamicListSection(
                      'Steps',
                      _stepControllers,
                      Icons.list,
                      'Enter step',
                      isMobile,
                    ),
                    SizedBox(height: 24),

                    _buildDynamicListSection(
                      'Links',
                      _linkControllers,
                      Icons.link,
                      'https://example.com',
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E7D32),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text('${widget.isEdit ? 'Update' : 'Add'} Admission'),
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
            Icon(icon, size: 20, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
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
                SizedBox(width: 8),
                if (controllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        controller.dispose();
                        controllers.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }).toList(),
        TextButton.icon(
          icon: Icon(Icons.add),
          label: Text('Add $title'),
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