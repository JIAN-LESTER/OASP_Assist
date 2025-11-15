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
import 'package:capstone_project/models/scholarships.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/services/file_service2.dart';
import 'package:uuid/uuid.dart';
import 'package:capstone_project/models/info_bank.dart';
import 'package:intl/intl.dart';

class ScholarshipFormDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  final bool isEdit;

  const ScholarshipFormDialog({
    Key? key,
    this.doc,
    this.isEdit = false,
  }) : super(key: key);

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
  final TextEditingController _applicationLinkController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  List<TextEditingController> _eligibilityControllers = [TextEditingController()];
  List<TextEditingController> _privilegeControllers = [TextEditingController()];

  bool _isSubmitting = false;
  bool _isProcessing = false;
  DateTime? _selectedDeadline;
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
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _providerController.text = data['scholarshipProvider'] ?? '';
    _applicationLinkController.text = data['applicationLink'] ?? '';

    if (data['deadline'] != null) {
      if (data['deadline'] is Timestamp) {
        _selectedDeadline = (data['deadline'] as Timestamp).toDate();
        _deadlineController.text = DateFormat('yyyy-MM-dd').format(_selectedDeadline!);
      }
    }

    if (data['eligibilityRequirements'] != null && data['eligibilityRequirements'] is List) {
      _eligibilityControllers = (data['eligibilityRequirements'] as List)
          .map((e) => TextEditingController(text: e.toString()))
          .toList();
    }

    if (data['privileges'] != null && data['privileges'] is List) {
      _privilegeControllers = (data['privileges'] as List)
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
      final analysisResult = await _cohereService.analyzeScholarship(text);

      if (analysisResult['scholarships'] is List && 
          (analysisResult['scholarships'] as List).isNotEmpty) {
        final scholarshipData = (analysisResult['scholarships'] as List).first;

        setState(() {
          _nameController.text = scholarshipData['name'] ?? '';
          _descriptionController.text = scholarshipData['description'] ?? '';
          _providerController.text = scholarshipData['scholarshipProvider'] ?? '';
          _applicationLinkController.text = scholarshipData['application_link'] ?? '';

          if (analysisResult['deadline'] != null) {
            _selectedDeadline = analysisResult['deadline'] as DateTime?;
            if (_selectedDeadline != null) {
              _deadlineController.text = DateFormat('yyyy-MM-dd').format(_selectedDeadline!);
            }
          }

          if (scholarshipData['eligibilityRequirements'] is List) {
            _eligibilityControllers = (scholarshipData['eligibilityRequirements'] as List)
                .map((e) => TextEditingController(text: e.toString()))
                .toList();
          }

          if (scholarshipData['privileges'] is List) {
            _privilegeControllers = (scholarshipData['privileges'] as List)
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
                  onTap: () => Navigator.pop(context),
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

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
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
      _showAlert('Please enter scholarship name', AlertType.warning);
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
        eligibilityRequirements: _eligibilityControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        privileges: _privilegeControllers
            .map((p) => p.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        deadline: _selectedDeadline,
        applicationLink: _applicationLinkController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _fileService.saveMultipleScholarships([scholarship]);

      // Save to information bank if there's description
      if (_descriptionController.text.trim().isNotEmpty) {
        final informationBank = InformationBank(
          id: docId,
          title: _nameController.text.trim(),
          content: _descriptionController.text.trim(),
          embedding: [],
          source: _selectedFileName ?? 'Manual Entry',
          category: 'Scholarship',
        );
        await _fileService.saveToInformationBank(informationBank);
      }

      await _logAction(widget.isEdit ? 'Updated' : 'Added');

      _showAlert(
        'Scholarship ${widget.isEdit ? 'updated' : 'added'} successfully!',
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
        'action': '$action scholarship: ${_nameController.text.trim()}',
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
                    child: Icon(Icons.card_giftcard, color: Colors.white, size: 24),
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
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Fill in scholarship details',
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

                    buildTextField(
                      controller: _nameController,
                      isMobile: isMobile,
                      label: 'Scholarship Name *',
                      hint: 'Enter scholarship name',
                      icon: Icons.card_giftcard,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _descriptionController,
                      isMobile: isMobile,
                      label: 'Description',
                      hint: 'Enter description',
                      icon: Icons.description,
                      maxLines: 4,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _providerController,
                      isMobile: isMobile,
                      label: 'Provider',
                      hint: 'Enter scholarship provider',
                      icon: Icons.business,
                    ),
                    SizedBox(height: 16),

                    buildTextField(
                      controller: _applicationLinkController,
                      isMobile: isMobile,
                      label: 'Application Link',
                      hint: 'https://example.com/apply',
                      icon: Icons.link,
                    ),
                    SizedBox(height: 16),

                    // Deadline picker
                    InkWell(
                      onTap: _selectDeadline,
                      child: buildTextField(
                        controller: _deadlineController,
                        isMobile: isMobile,
                        label: 'Deadline',
                        hint: 'Select deadline',
                        icon: Icons.calendar_today,
                        enabled: false,
                      ),
                    ),
                    SizedBox(height: 24),

                    _buildDynamicListSection(
                      'Eligibility Requirements',
                      _eligibilityControllers,
                      Icons.check_circle_outline,
                      'Enter requirement',
                      isMobile,
                    ),
                    SizedBox(height: 24),

                    _buildDynamicListSection(
                      'Benefits/Privileges',
                      _privilegeControllers,
                      Icons.star_outline,
                      'Enter benefit',
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
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
                          : Text('${widget.isEdit ? 'Update' : 'Add'} Scholarship'),
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
          label: Text('Add ${title.split(' ').last}'),
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