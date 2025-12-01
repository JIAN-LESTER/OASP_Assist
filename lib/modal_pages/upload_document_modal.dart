import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

import 'package:capstone_project/models/admissions.dart';
import 'package:capstone_project/models/placement.dart';
import 'package:capstone_project/models/scholarships.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/services/file_service2.dart';
import 'package:uuid/uuid.dart';
import 'package:capstone_project/models/info_bank.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';

void showUploadDocumentModal(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Upload Document',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const UploadDocumentModal();
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

class UploadDocumentModal extends StatelessWidget {
  const UploadDocumentModal({super.key});

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

    double modalWidth;
    double modalHeight;
    EdgeInsets modalPadding;

    if (isMobile) {
      modalWidth = screenWidth * 0.95;
      modalHeight = screenHeight * 0.90;
      modalPadding = const EdgeInsets.all(16);
    } else if (isTablet) {
      modalWidth = screenWidth * 0.80;
      modalHeight = screenHeight * 0.85;
      modalPadding = const EdgeInsets.all(24);
    } else {
      modalWidth = 700;
      modalHeight = screenHeight * .90;
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
            child: UploadDocumentContent(
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

class UploadDocumentContent extends StatefulWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  const UploadDocumentContent({
    Key? key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<UploadDocumentContent> createState() => _UploadDocumentContentState();
}

class _UploadDocumentContentState extends State<UploadDocumentContent> {
  final FileService _fileService = FileService();
  final TextEditingController _titleController = TextEditingController();
  final CohereService _cohereService = CohereService();
  final TextEditingController _categoryController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  String? _selectedFileName;
  String? _extractedText;
  File? _selectedFile;
  bool _isUploading = false;
  bool _isProcessingImage = false;

  bool _isProcessing = true;
  bool _fileProcessed = false;
  bool _fileReady = false;

  final List<String> _predefinedCategories = [
    'Admission',
    'Scholarship',
    'Placement',
    'General',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
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

      if (result != null && result.files.single.bytes != null) {
        final fileName = result.files.single.name;
        final fileBytes = result.files.single.bytes!;

        setState(() {
          _selectedFileName = fileName;
          _isProcessing = true;
          _fileReady = false;
          _extractedText = null;
        });

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
          _extractedText = extractedText;
          _fileReady = true;
          _titleController.text = fileName.split('.').first;
          _isProcessing = false;
        });

        SnackbarUtil.showSuccess(context, 'File processed successfully!');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _fileReady = false;
        _extractedText = null;
      });
      SnackbarUtil.showError(context, 'Error processing file: $e');
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
      SnackbarUtil.showError(context, 'Error picking image: $e');
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
      SnackbarUtil.showError(context, 'Error taking photo: $e');
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _isProcessingImage = true;
      _fileReady = false;
      _extractedText = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String extractedText = recognizedText.text;

      if (extractedText.trim().isEmpty) {
        SnackbarUtil.showWarning(context, 'No text found in image');
        setState(() {
          _isProcessingImage = false;
          _fileReady = false;
        });
        return;
      }

      final fileName = 'Image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      setState(() {
        _selectedFile = File(image.path);
        _selectedFileName = fileName;
        _extractedText = extractedText;
        _fileReady = true;
        _isProcessingImage = false;
        _titleController.text =
            'Document from Image ${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}';
      });

      SnackbarUtil.showSuccess(
        context,
        'Text extracted successfully! Found ${extractedText.split(' ').length} words',
      );
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
        _fileReady = false;
        _extractedText = null;
      });
      SnackbarUtil.showError(context, 'Error extracting text from image: $e');
    }
  }

  void _showUploadOptionsBottomSheet() {
    if (widget.isMobile) {
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Upload Method',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Select how you want to add your document',
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
                    color: Color(0xFF1976D2),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      );
    }
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
                    offset: Offset(0, 2),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
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

  Future<void> _uploadDocument() async {
    if (_extractedText == null || _extractedText!.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please select a file first');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please enter a title');
      return;
    }

    if (_categoryController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please select or enter a category');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final uuid = Uuid();
      final documentId = uuid.v4();

      final informationBank = InformationBank(
        id: documentId,
        title: _titleController.text.trim(),
        content: _extractedText!,
        embedding: [],
        source: _selectedFileName ?? 'Unknown',
        category: _categoryController.text.trim(),
      );

      await _fileService.saveToInformationBank(informationBank);

      Navigator.of(context).pop(true);

      switch (_categoryController.text.trim()) {
        case 'Admission':
          print("🔍 Analyzing admission document...");
          final admissionCohere = await _cohereService.analyzeAdmission(
            _extractedText!,
          );

          print("📋 Admission analysis result: $admissionCohere");

          List<String>? contactsList;
          try {
            if (admissionCohere['contacts'] is List<Map<String, dynamic>>) {
              List<Map<String, dynamic>> contactsData =
                  admissionCohere['contacts'] as List<Map<String, dynamic>>;
              if (contactsData.isNotEmpty) {
                contactsList =
                    contactsData.map((contact) {
                      String type = contact['type']?.toString() ?? '';
                      String value = contact['value']?.toString() ?? '';
                      return '$type: $value';
                    }).toList();
              }
            }
          } catch (e) {
            print("❌ Error processing contacts: $e");
            contactsList = null;
          }

          List<String> stepsList = <String>[];
          try {
            if (admissionCohere['steps'] is List<String>) {
              stepsList = admissionCohere['steps'] as List<String>;
            } else if (admissionCohere['steps'] is List) {
              stepsList =
                  (admissionCohere['steps'] as List)
                      .map((e) => e.toString())
                      .toList();
            }
          } catch (e) {
            print("❌ Error processing steps: $e");
            stepsList = <String>[];
          }

          final admissions = Admissions(
            id: documentId,
            steps: stepsList,
            requirements: admissionCohere['requirements'],
            title: _titleController.text.trim(),
            content: _extractedText!,
            contact: contactsList,
            academicYear: admissionCohere['academicYear'],
            links: admissionCohere['links'],
            source: _selectedFileName ?? 'Unknown',
            createdAt: DateTime.now(),
          );

          await _fileService.saveToAdmission(admissions);
          break;

        case 'Scholarship':
          print("🔍 Analyzing scholarship document...");
          final scholarshipCohere = await _cohereService.analyzeScholarship(
            _extractedText!,
          );

          print("📋 Scholarship analysis result: $scholarshipCohere");

          if (scholarshipCohere['scholarships'] is List &&
              scholarshipCohere['scholarships'].isNotEmpty) {
            List<dynamic> scholarshipDataList =
                scholarshipCohere['scholarships'];
            print("📚 Found ${scholarshipDataList.length} scholarship(s)");

            List<Scholarship> scholarships = [];

            for (int i = 0; i < scholarshipDataList.length; i++) {
              final scholarshipData = scholarshipDataList[i];
              final scholarshipId = i == 0 ? documentId : '${documentId}_$i';

              print(
                "📝 Preparing scholarship ${i + 1}/${scholarshipDataList.length} with ID: $scholarshipId",
              );

              final scholarship = Scholarship(
                scholarshipID: scholarshipId,
                sourceId: scholarshipId,
                name: scholarshipData['name'] ?? 'Unnamed Scholarship',
                description:
                    scholarshipData['description'] ??
                    'No description available',
                scholarshipProvider:
                    scholarshipData['scholarshipProvider'] ??
                    'Unknown Provider',
                eligibilityRequirements:
                    scholarshipData['eligibilityRequirements'] ?? <String>[],
                privileges: scholarshipData['privileges'] ?? <String>[],
                deadline: scholarshipCohere['deadline'],
                applicationLink: scholarshipData['application_link'] ?? '',
                createdAt: DateTime.now(),
              );

              scholarships.add(scholarship);
            }

            await _fileService.saveMultipleScholarships(scholarships);

            SnackbarUtil.showSuccess(
              context,
              'Found and saved ${scholarships.length} scholarship(s)!',
            );
          } else {
            print("⚠️ No scholarships found in the document");
            SnackbarUtil.showWarning(
              context,
              'No scholarships found in the document',
            );
          }
          break;

        case 'Placement':
          print("🔍 Analyzing placement document...");
          final placementCohere = await _cohereService.analyzePlacement(
            _extractedText!,
          );

          print("📋 Placement analysis result: $placementCohere");

          if (placementCohere['placements'] is List &&
              placementCohere['placements'].isNotEmpty) {
            List<dynamic> placementDataList = placementCohere['placements'];
            print("📚 Found ${placementDataList.length} placement(s)");

            List<Placement> placements = [];

            for (int i = 0; i < placementDataList.length; i++) {
              final placementData = placementDataList[i];
              final placementId = i == 0 ? documentId : '${documentId}_$i';

              print(
                "📝 Preparing placement ${i + 1}/${placementDataList.length} with ID: $placementId",
              );

              final placement = Placement(
                placementID: placementId,
                isRecruiting: true,
                partnerCompany:
                    placementData['partnerCompany'] ?? 'Unnamed Placement',
                contacts:
                    placementData['contacts'] is List
                        ? List<String>.from(
                          placementData['contacts'].map((e) => e.toString()),
                        )
                        : <String>[],
                positions:
                    placementData['positions'] is List
                        ? List<String>.from(
                          placementData['positions'].map((e) => e.toString()),
                        )
                        : <String>[],
                createdAt:
                    DateTime.tryParse(placementData['createdAt'] ?? '') ??
                    DateTime.now(),
              );

              placements.add(placement);
            }

            await _fileService.saveMultiplePlacements(placements);

            SnackbarUtil.showSuccess(
              context,
              'Found and saved ${placements.length} placement(s)!',
            );
          } else {
            print("⚠️ No placements found in the document");
            SnackbarUtil.showWarning(
              context,
              'No placements found in the document',
            );
          }
          break;

        default:
          print(
            "ℹ️ Category '${_categoryController.text.trim()}' does not require special processing",
          );
          break;
      }

      await _logUploadAction();

      SnackbarUtil.showSuccess(context, 'Document uploaded successfully!');
      Navigator.of(context).pop(true);
    } catch (e) {
      print("❌ Upload error: $e");
      SnackbarUtil.showError(context, 'Upload failed: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _logUploadAction() async {
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
        'action': 'Uploaded document: ${_titleController.text.trim()}',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print('Failed to log action: $e');
    }
  }

  Widget _buildFileUploadArea() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _fileReady
                  ? const Color(0xFF2E7D32).withOpacity(0.4)
                  : const Color(0xFFE5E7EB),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              _isProcessingImage
                  ? null
                  : (widget.isMobile
                      ? _showUploadOptionsBottomSheet
                      : _pickFile),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 20 : 32,
              vertical: widget.isMobile ? 24 : 32,
            ),
            child: Column(
              children: [
                if (_isProcessingImage)
                  Column(
                    children: [
                      CircularProgressIndicator(color: const Color(0xFF2E7D32)),
                      const SizedBox(height: 16),
                      Text(
                        'Extracting text from image...',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 14 : 16,
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (_fileReady)
                  Column(
                    children: [
                      Container(
                        width: widget.isMobile ? 56 : 72,
                        height: widget.isMobile ? 56 : 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: widget.isMobile ? 28 : 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFileName ?? 'File ready for upload',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 15 : 16,
                          color: const Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
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
                              fontSize: widget.isMobile ? 13 : 14,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (widget.isMobile) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Tap to upload a different file',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: widget.isMobile ? 56 : 72,
                        height: widget.isMobile ? 56 : 72,
                        decoration: BoxDecoration(
                          color: Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.upload_file,
                          color: const Color(0xFF2E7D32),
                          size: widget.isMobile ? 28 : 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isMobile
                            ? 'Choose upload method below'
                            : 'Upload Files',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 15 : 16,
                          color: const Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isMobile
                            ? 'Select an option below to get started'
                            : 'Documents in formats (.doc | .docx | .pdf | .txt)',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 13 : 14,
                          color: const Color(0xFF9CA3AF),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
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
                    Icons.cloud_upload_outlined,
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
                        'Upload Document',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add new document to knowledge base',
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

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 20 : 28,
                vertical: widget.isMobile ? 20 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('File Selection', Icons.upload_file),
                  const SizedBox(height: 16),
                  _buildFileUploadArea(),

                  const SizedBox(height: 24),

                  _buildSectionHeader('Document Details', Icons.description),
                  const SizedBox(height: 16),

                  buildTextField(
                    isMobile: false,
                    controller: _titleController,
                    label: 'Document Title',
                    hint: 'Enter a descriptive title',
                    icon: Icons.title,
                  ),

                  const SizedBox(height: 20),

                  _buildCategorySection(),

                  const SizedBox(height: 32),

                  _buildActionButtons(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: widget.isMobile ? 8 : 10,
          runSpacing: widget.isMobile ? 8 : 10,
          children:
              _predefinedCategories.map((category) {
                final isSelected = _categoryController.text == category;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      setState(() {
                        _categoryController.text = isSelected ? '' : category;
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
        const SizedBox(height: 16),
        buildTextField(
          controller: _categoryController,
          isMobile: false,
          label: 'Custom Category',
          hint: 'Or enter a custom category',
          icon: Icons.category_outlined,
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
                  _isUploading ? null : () => Navigator.of(context).pop(),
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
              onPressed:
                  (_isUploading || !_fileReady || _extractedText == null)
                      ? null
                      : _uploadDocument,
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
                  _isUploading
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
                            'Uploading...',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                      : Text(
                        'Upload Document',
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
