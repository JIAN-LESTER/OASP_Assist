import 'dart:convert';
import 'dart:io';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/models/admissions.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/services/file_service2.dart';
import 'package:uuid/uuid.dart';
import 'package:capstone_project/models/info_bank.dart';

class AdmissionFormDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  final bool isEdit;

  const AdmissionFormDialog({Key? key, this.doc, this.isEdit = false})
    : super(key: key);

  @override
  State<AdmissionFormDialog> createState() => _AdmissionFormDialogState();
}

class ScheduleController {
  final TextEditingController dateController;
  final TextEditingController dayController;
  final List<TextEditingController> locationControllers;

  ScheduleController({
    String date = '',
    String day = '',
    List<String>? locations,
  }) : dateController = TextEditingController(text: date),
       dayController = TextEditingController(text: day),
       locationControllers =
           (locations ?? [''])
               .map((loc) => TextEditingController(text: loc))
               .toList();

  void dispose() {
    dateController.dispose();
    dayController.dispose();
    for (var controller in locationControllers) {
      controller.dispose();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'date': dateController.text.trim(),
      'dayOfWeek': dayController.text.trim(),
      'locations':
          locationControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
    };
  }
}

class _AdmissionFormDialogState extends State<AdmissionFormDialog> {
  final FileService _fileService = FileService();
  final CohereService _cohereService = CohereService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  List<ScheduleController> _scheduleControllers = [];
  String? _selectedType;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _academicYearController = TextEditingController();

  List<TextEditingController> _contactControllers = [TextEditingController()];
  List<TextEditingController> _stepControllers = [TextEditingController()];
  List<TextEditingController> _linkControllers = [TextEditingController()];
  List<TextEditingController> _requirementControllers = [
    TextEditingController(),
  ];

  bool _isSubmitting = false;
  bool _isProcessing = false;
  String? _selectedFileName;
  File? _selectedFile;
  bool _fileUploaded = false;
  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.doc != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.doc!.data() as Map<String, dynamic>;

    //  Load type
    _selectedType = data['type']?.toString();

    _titleController.text = data['title'] ?? '';
    _contentController.text = data['content'] ?? '';
    _sourceController.text = data['source'] ?? '';

    // Format academic year for display
    if (data['academicYear'] is Map) {
      final yearMap = Map<String, dynamic>.from(data['academicYear']);
      if (yearMap.containsKey('end')) {
        _academicYearController.text = '${yearMap['start']}-${yearMap['end']}';
      } else {
        _academicYearController.text = '${yearMap['start']}';
      }
    } else if (data['academicYear'] is String) {
      _academicYearController.text = data['academicYear'];
    }

    if (data['contact'] != null && data['contact'] is List) {
      _contactControllers =
          (data['contact'] as List)
              .map((c) => TextEditingController(text: c.toString()))
              .toList();
    }

    if (data['steps'] != null && data['steps'] is List) {
      _stepControllers =
          (data['steps'] as List)
              .map((s) => TextEditingController(text: s.toString()))
              .toList();
    }

    if (data['requirements'] != null && data['requirements'] is List) {
      _requirementControllers =
          (data['requirements'] as List)
              .map((r) => TextEditingController(text: r.toString()))
              .toList();
    }

    if (data['links'] != null && data['links'] is List) {
      _linkControllers =
          (data['links'] as List)
              .map((l) => TextEditingController(text: l.toString()))
              .toList();
    }

    // Load schedules
    if (data['schedules'] != null && data['schedules'] is List) {
      _scheduleControllers =
          (data['schedules'] as List).map((schedule) {
            final scheduleMap = Map<String, dynamic>.from(schedule);
            return ScheduleController(
              date: scheduleMap['date']?.toString() ?? '',
              day: scheduleMap['dayOfWeek']?.toString() ?? '',
              locations:
                  scheduleMap['locations'] is List
                      ? List<String>.from(scheduleMap['locations'])
                      : null,
            );
          }).toList();
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
    for (var r in _requirementControllers) r.dispose();
    for (var l in _linkControllers) l.dispose();
    for (var sc in _scheduleControllers) sc.dispose();
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
        if (mounted) {
          SnackbarUtil.showWarning(
            context,
            'OCR not yet implemented for web/windows',
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

  Future<void> _processExtractedText(String text, String fileName) async {
    try {
      final analysisResult = await _cohereService.analyzeAdmission(text);

      setState(() {
        //  Set type
        if (analysisResult['type'] != null &&
            analysisResult['type'].toString().isNotEmpty) {
          _selectedType = analysisResult['type'].toString();
        }

        if (_titleController.text.isEmpty) {
          _titleController.text = fileName.split('.').first;
        }
        _contentController.text = text;
        _sourceController.text = fileName;

        // Format academic year for display
        if (analysisResult['academicYear'] is Map) {
          final yearMap = analysisResult['academicYear'] as Map<String, int>;
          if (yearMap.containsKey('end')) {
            _academicYearController.text =
                '${yearMap['start']}-${yearMap['end']}';
          } else {
            _academicYearController.text = '${yearMap['start']}';
          }
        }

        if (analysisResult['contacts'] is List<Map<String, dynamic>>) {
          List<Map<String, dynamic>> contacts =
              analysisResult['contacts'] as List<Map<String, dynamic>>;
          if (contacts.isNotEmpty) {
            _contactControllers =
                contacts
                    .map(
                      (c) => TextEditingController(
                        text: '${c['type']}: ${c['value']}',
                      ),
                    )
                    .toList();
          }
        }

        if (analysisResult['steps'] is List) {
          _stepControllers =
              (analysisResult['steps'] as List)
                  .map((s) => TextEditingController(text: s.toString()))
                  .toList();
        }

        if (analysisResult['requirements'] is List) {
          _requirementControllers =
              (analysisResult['requirements'] as List)
                  .map((r) => TextEditingController(text: r.toString()))
                  .toList();
        }

        if (analysisResult['links'] is List) {
          _linkControllers =
              (analysisResult['links'] as List)
                  .map((l) => TextEditingController(text: l.toString()))
                  .toList();
        }

        // Handle schedules
        if (analysisResult['schedules'] is List &&
            (analysisResult['schedules'] as List).isNotEmpty) {
          _scheduleControllers =
              (analysisResult['schedules'] as List).map((schedule) {
                final scheduleMap = Map<String, dynamic>.from(schedule);
                return ScheduleController(
                  date: scheduleMap['date']?.toString() ?? '',
                  day: scheduleMap['dayOfWeek']?.toString() ?? '',
                  locations:
                      scheduleMap['locations'] is List
                          ? List<String>.from(scheduleMap['locations'])
                          : null,
                );
              }).toList();

          print(" Extracted ${_scheduleControllers.length} schedules");
        }
      });
    } catch (e) {
      print('Error analyzing admission: $e');
      if (mounted) {
        SnackbarUtil.showError(context, 'Error analyzing document: $e');
      }
    }
  }

  Map<String, int>? parseAcademicYear(
    String? yearStr, [
    String fallbackText = '',
  ]) {
    if ((yearStr == null || yearStr.trim().isEmpty) &&
        fallbackText.isNotEmpty) {
      yearStr = fallbackText;
    }

    if (yearStr == null || yearStr.trim().isEmpty) return null;

    final rangeRegex = RegExp(r'(\d{4})\s*[-–]\s*(\d{4})');
    final rangeMatch = rangeRegex.firstMatch(yearStr);
    if (rangeMatch != null) {
      return {
        'start': int.parse(rangeMatch.group(1)!),
        'end': int.parse(rangeMatch.group(2)!),
      };
    }

    final singleRegex = RegExp(r'(\d{4})');
    final singleMatch = singleRegex.firstMatch(yearStr);
    if (singleMatch != null) {
      return {'start': int.parse(singleMatch.group(1)!)};
    }

    return null;
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
                // Only show gallery option if NOT Web or Desktop
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

  Future<void> _submitForm() async {
    if (_titleController.text.trim().isEmpty) {
      if (mounted) {
        SnackbarUtil.showWarning(context, 'Please enter a title');
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uuid = Uuid();
      final docId = widget.isEdit ? widget.doc!.id : uuid.v4();

      final schedulesList =
          _scheduleControllers
              .map((sc) => sc.toMap())
              .where((s) => s['date'].toString().isNotEmpty)
              .toList();

      final admission = Admissions(
        id: docId,
        type: _selectedType, //  NEW FIELD
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        source: _sourceController.text.trim(),
        academicYear: parseAcademicYear(_academicYearController.text.trim()),
        contact:
            _contactControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        steps:
            _stepControllers
                .map((s) => s.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        requirements:
            _requirementControllers
                .map((r) => r.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        links:
            _linkControllers
                .map((l) => l.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        schedules: schedulesList.isNotEmpty ? schedulesList : null,
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

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'Admission ${widget.isEdit ? 'updated' : 'added'} successfully with ${schedulesList.length} schedule(s)!',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        if (message.contains('Duplicate admission already exists')) {
          SnackbarUtil.showWarning(
            context,
            'Duplicate admission already exists',
          );
        } else {
          SnackbarUtil.showError(context, 'Error: $e');
        }
      }
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
      print(' Failed to log action: $e');
    }
  }

  Widget _buildTypeDropdown(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_outlined, size: 20, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text(
              'Admission Test Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
              hintText: 'Select test type (optional)',
              hintStyle: TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text('Not specified')),
              DropdownMenuItem(value: 'CMUCAT', child: Text('CMUCAT')),
              DropdownMenuItem(value: 'GSAT', child: Text('GSAT')),
              DropdownMenuItem(value: 'ULHSAT', child: Text('ULHSAT')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedType = value;
              });
            },
          ),
        ),
      ],
    );
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
                      controller: _titleController,
                      isMobile: isMobile,
                      label: 'Title *',
                      hint: 'Enter admission title',
                      icon: Icons.title_outlined,
                    ),
                    SizedBox(height: 16),

                    _buildTypeDropdown(isMobile), //  ADD THIS
                    SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: Color(0xFF2E7D32),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Content',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF374151),
                                letterSpacing: -0.1,
                              ),
                            ),
                            Spacer(),
                            if (_contentController.text.isNotEmpty)
                              Text(
                                '${_contentController.text.length} characters',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _contentController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Enter admission content (extracted text will appear here)',
                              hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w400,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Extracted text from uploaded documents will automatically appear here',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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
                    SizedBox(height: 10),

                    // Dynamic Lists
                    _buildDynamicListSection(
                      'Contact Information',
                      _contactControllers,
                      Icons.contact_phone_outlined,
                      'Email: email@example.com',
                      isMobile,
                    ),
                    SizedBox(height: 10),

                    _buildDynamicListSection(
                      'Application Steps',
                      _stepControllers,
                      Icons.list_alt_outlined,
                      'Enter step',
                      isMobile,
                    ),
                    SizedBox(height: 10),
                    _buildDynamicListSection(
                      'Requirements',
                      _requirementControllers,
                      Icons.checklist_outlined,
                      'e.g., Form 137, Birth Certificate',
                      isMobile,
                    ),

                    SizedBox(height: 24),

                    // Schedule Section
                    _buildScheduleSection(isMobile),
                    SizedBox(height: 10),
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

  Widget _buildScheduleSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionHeader('Schedule', Icons.calendar_month_outlined),
        SizedBox(height: 16),
        if (_scheduleControllers.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No schedule entries. Click "Add Schedule" to create one.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          )
        else
          ..._scheduleControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final scheduleController = entry.value;

            return Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with delete button
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Schedule ${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              scheduleController.dispose();
                              _scheduleControllers.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Date field
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: buildTextField(
                          controller: scheduleController.dateController,
                          isMobile: isMobile,
                          label: 'Date',
                          hint: 'e.g., OCT 4, 2025',
                          icon: Icons.event,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: buildTextField(
                          controller: scheduleController.dayController,
                          isMobile: isMobile,
                          label: 'Day',
                          hint: 'SATURDAY',
                          icon: Icons.today,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Locations
                  Text(
                    'Locations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 8),
                  ...scheduleController.locationControllers.asMap().entries.map(
                    (locEntry) {
                      final locIndex = locEntry.key;
                      final locController = locEntry.value;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: locController,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter location',
                                  prefixIcon: Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Color(0xFF2E7D32),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (scheduleController.locationControllers.length >
                                1) ...[
                              SizedBox(width: 8),
                              Container(
                                height: 42,
                                width: 42,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setState(() {
                                        locController.dispose();
                                        scheduleController.locationControllers
                                            .removeAt(locIndex);
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ).toList(),

                  // Add location button
                  TextButton.icon(
                    icon: Icon(Icons.add_location_outlined, size: 16),
                    label: Text(
                      'Add Location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF2E7D32),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () {
                      setState(() {
                        scheduleController.locationControllers.add(
                          TextEditingController(),
                        );
                      });
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        SizedBox(height: 12),

        // Add schedule button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(Icons.add_circle_outline, size: 20),
            label: Text(
              'Add Schedule Entry',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF2E7D32),
              side: BorderSide(color: Color(0xFF2E7D32), width: 1.5),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              setState(() {
                _scheduleControllers.add(ScheduleController());
              });
            },
          ),
        ),
      ],
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
