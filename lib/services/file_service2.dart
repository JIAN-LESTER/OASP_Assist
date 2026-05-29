import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:capstone_project/services/gemini_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'package:capstone_project/models/admissions.dart';
import 'package:capstone_project/models/placement.dart';
import 'package:capstone_project/models/scholarships.dart';
import 'package:capstone_project/services/pinecone_service.dart'; // Updated import
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:docx_to_text/docx_to_text.dart';

import 'package:capstone_project/models/info_bank.dart';

/// Service for handling file operations, document processing, and knowledge base management
class FileService {
  final firestore = FirebaseFirestore.instance;
  // final CohereService _cohereService = CohereService();
  final GeminiService _geminiService = GeminiService();
  final PineconeCloudService _pineconeService =
      PineconeCloudService(); // Updated to Pinecone
  final Uuid _uuid = Uuid();

  /// Maximum number of characters per chunk
  static const int maxChunkSize = 1000;

  /// Overlap between chunks to maintain context
  static const int chunkOverlap = 200;

  String sanitizeId(String input) {
    return input.replaceAll('/', '-');
  }

  String _normalizedText(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String _admissionDuplicateKey(String title, Map<String, int>? academicYear) {
    final start = academicYear?['start'];
    final end = academicYear?['end'];
    final yearText =
        start == null
            ? ''
            : end == null
            ? '$start'
            : '$start-$end';
    return '${_normalizedText(title)}|${_normalizedText(yearText)}';
  }

  String _scholarshipDuplicateKey(String name, String provider) {
    return '${_normalizedText(name)}|${_normalizedText(provider)}';
  }

  String _placementDuplicateKey(String company, List<String> positions) {
    final normalizedPositions =
        positions
            .map(_normalizedText)
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort();
    return '${_normalizedText(company)}|${normalizedPositions.join(",")}';
  }

  Future<void> _ensureNoAdmissionDuplicate(
    Admissions admission,
    String currentId,
  ) async {
    final duplicateKey = _admissionDuplicateKey(
      admission.title,
      admission.academicYear,
    );
    if (duplicateKey == '|') {
      return;
    }

    final snapshot = await firestore.collection('admissions').get();
    for (final doc in snapshot.docs) {
      if (doc.id == currentId) {
        continue;
      }
      final data = doc.data();
      final existingKey = _admissionDuplicateKey(
        (data['title'] ?? '').toString(),
        (data['academicYear'] as Map?)?.cast<String, int>(),
      );
      if (existingKey == duplicateKey) {
        throw Exception('Duplicate admission already exists');
      }
    }
  }

  Future<void> _ensureNoScholarshipDuplicates(
    List<Scholarship> scholarships,
  ) async {
    final existing = await firestore.collection('scholarships').get();
    final existingById = {for (final doc in existing.docs) doc.id: doc.data()};
    final batchKeys = <String>{};

    for (final scholarship in scholarships) {
      final currentId = sanitizeId(scholarship.scholarshipID);
      final duplicateKey = _scholarshipDuplicateKey(
        scholarship.name,
        scholarship.scholarshipProvider,
      );
      if (duplicateKey == '|') {
        continue;
      }

      if (!batchKeys.add(duplicateKey)) {
        throw Exception('Duplicate scholarship already exists');
      }

      for (final entry in existingById.entries) {
        if (entry.key == currentId) {
          continue;
        }
        final data = entry.value;
        final existingKey = _scholarshipDuplicateKey(
          (data['name'] ?? '').toString(),
          (data['scholarshipProvider'] ?? '').toString(),
        );
        if (existingKey == duplicateKey) {
          throw Exception('Duplicate scholarship already exists');
        }
      }
    }
  }

  Future<void> _ensureNoPlacementDuplicates(List<Placement> placements) async {
    final existing = await firestore.collection('placements').get();
    final existingById = {for (final doc in existing.docs) doc.id: doc.data()};
    final batchKeys = <String>{};

    for (final placement in placements) {
      final currentId = sanitizeId(placement.placementID);
      final duplicateKey = _placementDuplicateKey(
        placement.partnerCompany,
        placement.positions,
      );
      if (duplicateKey == '|') {
        continue;
      }

      if (!batchKeys.add(duplicateKey)) {
        throw Exception('Duplicate placement already exists');
      }

      for (final entry in existingById.entries) {
        if (entry.key == currentId) {
          continue;
        }
        final data = entry.value;
        final existingKey = _placementDuplicateKey(
          (data['partnerCompany'] ?? '').toString(),
          (data['positions'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
        );
        if (existingKey == duplicateKey) {
          throw Exception('Duplicate placement already exists');
        }
      }
    }
  }

  /// Supported file extensions
  static const List<String> supportedExtensions = ['pdf', 'txt', 'docx', 'doc'];

  /// Pick and read a file from the device
  Future<String?> pickAndReadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await extractTextFromFile(file);
    }

    return null;
  }

  Future<void> saveToInformationBank(
    InformationBank ib, {
    bool isFromUpload = true,
  }) async {
    try {
      //  CHECK PLATFORM SUPPORT FIRST
      if (!_pineconeService.isSupported) {
        throw UnsupportedError(_pineconeService.unsupportedPlatformMessage);
      }

      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        throw Exception('Pinecone service is not available');
      }

      //  FIX: Use category-prefixed ID for category documents
      String finalDocId = ib.id;

      // If this is a category document, use the prefixed format
      if ([
        'admission',
        'scholarship',
        'placement',
      ].contains(ib.category.toLowerCase())) {
        // Check if it already has the prefix
        if (!ib.id.startsWith('${ib.category.toLowerCase()}_')) {
          finalDocId = '${ib.category.toLowerCase()}_${ib.id}';
        }
      }

      final sanitizedId = sanitizeId(finalDocId);

      //  FIX: Check if entry already exists
      final existingDoc =
          await firestore.collection('information_bank').doc(sanitizedId).get();

      if (existingDoc.exists) {
        print(' Information Bank entry already exists: $sanitizedId');

        // Optional: Update existing entry instead of failing
        final existingData = existingDoc.data()!;
        final oldChunkIds = List<String>.from(existingData['chunkIds'] ?? []);

        // Delete old Pinecone vectors
        if (oldChunkIds.isNotEmpty) {
          await _pineconeService.deleteDocuments(oldChunkIds);
          print(' Deleted ${oldChunkIds.length} old Pinecone vectors');
        }

        // Continue with update...
      }

      // Split document into chunks
      final chunks = _splitIntoChunks(ib.content, ib.title, ib.source);
      print(' Document "${ib.title}" split into ${chunks.length} chunks');

      // Process chunks...
      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '${ib.title} (Part ${i + 1}/${chunks.length})'
                : ib.title;

        //  CRITICAL: Use finalDocId (with category prefix)
        final metadata = {
          'docId': finalDocId,
          'originalDocId': finalDocId,
          'documentId': finalDocId,
          'categoryDocId':
              ib.category.toLowerCase() == 'admission' ||
                      ib.category.toLowerCase() == 'scholarship' ||
                      ib.category.toLowerCase() == 'placement'
                  ? ib.id
                  : finalDocId,

          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': ib.title,
          'fileName': ib.title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': ib.source,
          'category': ib.category,
          'categoryID': ib.category,
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),

          'uploadedViaFlutter': true,
          'syncedFromCategory': false,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: ib.source,
          category: ib.category,
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }

        print(
          '   Chunk ${i + 1}/${chunks.length} uploaded (${chunk.text.length} chars)',
        );
      }

      // Save to Firestore with prefixed ID
      await firestore.collection('information_bank').doc(sanitizedId).set({
        'ibID': sanitizedId,
        'id': sanitizedId,
        'ib_title': ib.title,
        'title': ib.title,
        'content': ib.content,
        'source': ib.source,
        'category': ib.category,
        'categoryID': ib.category,
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'chunkSize': maxChunkSize,
        'chunkOverlap': chunkOverlap,
        'uploadedViaFlutter': true,
        'isFromDocumentUpload': isFromUpload,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        ' Document saved to Firebase and ${chunks.length} chunks uploaded to Pinecone',
      );
    } on UnsupportedError catch (e) {
      //  PLATFORM-SPECIFIC ERROR
      print(' Platform not supported: ${e.message}');
      rethrow;
    } catch (e) {
      print(' Error saving document: $e');
      rethrow;
    }
  }

  // Also update the batch upload method
  Future<void> batchUploadToInformationBank(
    List<InformationBank> documents,
  ) async {
    try {
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        throw Exception('Pinecone service is not available');
      }

      final allVectors = <Map<String, dynamic>>[];
      final firebaseUpdates = <Map<String, dynamic>>[];

      for (final ib in documents) {
        final chunks = _splitIntoChunks(ib.content, ib.title, ib.source);
        print(' Document "${ib.title}" split into ${chunks.length} chunks');

        final chunkIds = <String>[];
        String? parentPineconeId;

        for (int i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];

          final embedding = await _geminiService.embedText(chunk.text);

          final chunkTitle =
              chunks.length > 1
                  ? '${ib.title} (Part ${i + 1}-${chunks.length})'
                  : ib.title;

          //  FIXED: Use consistent metadata structure
          allVectors.add({
            'id': chunk.id,
            'embedding': embedding,
            'metadata': {
              // Document ID fields
              'docId': ib.id,
              'originalDocId': ib.id,
              'documentId': ib.id,

              // Title fields
              'title': chunkTitle,
              'fileName': ib.title,
              'originalTitle': ib.title,

              // Content fields
              'text': chunk.text,
              'content': chunk.text,

              // Other metadata
              'source': ib.source,
              'category': ib.category,
              'chunkIndex': i,
              'chunk_index': i,
              'totalChunks': chunks.length,
              'chunkSize': chunk.text.length,
              'isFirstChunk': i == 0,
              'isLastChunk': i == chunks.length - 1,
              'createdAt': DateTime.now().toIso8601String(),
            },
          });

          chunkIds.add(chunk.id);

          if (i == 0) {
            parentPineconeId = chunk.id;
          }
        }

        final sanitizedId = sanitizeId(ib.id);
        firebaseUpdates.add({
          'docId': sanitizedId,
          'data': {
            'ibID': sanitizedId,
            'id': sanitizedId,
            'ib_title': ib.title,
            'title': ib.title,
            'content': ib.content,
            'source': ib.source,
            'category': ib.category,
            'pinecone_id': parentPineconeId,
            'totalChunks': chunks.length,
            'chunkIds': chunkIds,
            'chunked': chunks.length > 1,
            'chunkSize': maxChunkSize,
            'chunkOverlap': chunkOverlap,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      }

      await _pineconeService.insertDocumentsBatch(documents: allVectors);
      print(' Batch uploaded ${allVectors.length} chunks to Pinecone');

      final batch = firestore.batch();
      for (final update in firebaseUpdates) {
        final docRef = firestore
            .collection('information_bank')
            .doc(update['docId']);
        batch.set(docRef, update['data']);
      }
      await batch.commit();

      print(
        ' Batch saved ${documents.length} documents to Firebase and Pinecone',
      );
    } catch (e) {
      print(' Error batch uploading documents: $e');
      rethrow;
    }
  }

  Future<void> updateInformationBankContent({
    required String documentId,
    required String newTitle,
    required String newContent,
    required String newCategory,
  }) async {
    try {
      print(' Starting content update for document: $documentId');

      // Check Pinecone health
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        throw Exception('Pinecone service is not available');
      }

      // Get existing document to find old chunk IDs
      final existingDoc =
          await firestore.collection('information_bank').doc(documentId).get();

      if (!existingDoc.exists) {
        throw Exception('Document not found: $documentId');
      }

      final existingData = existingDoc.data()!;
      final oldChunkIds = List<String>.from(existingData['chunkIds'] ?? []);

      // Delete old Pinecone vectors FIRST
      if (oldChunkIds.isNotEmpty) {
        print(' Deleting ${oldChunkIds.length} old Pinecone vectors...');
        await _pineconeService.deleteDocuments(oldChunkIds);
        print(' Old vectors deleted successfully');
      }

      // Split new content into chunks
      final chunks = _splitIntoChunks(
        newContent,
        newTitle,
        existingData['source'] ?? 'information_bank',
      );
      print(' Document split into ${chunks.length} new chunks');

      // Generate new embeddings and upload to Pinecone
      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];

        // Generate embedding for new content
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$newTitle (Part ${i + 1}/${chunks.length})'
                : newTitle;

        // Prepare metadata (preserve important fields from original)
        final metadata = {
          'docId': documentId,
          'originalDocId': documentId,
          'documentId': documentId,
          'categoryDocId': existingData['categoryDocId'] ?? documentId,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': newTitle,
          'fileName': newTitle,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': existingData['source'] ?? 'information_bank',
          'category': newCategory,
          'categoryID': newCategory.toLowerCase(),
          'categoryType': newCategory.toLowerCase(),
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'uploadedViaFlutter': existingData['uploadedViaFlutter'] ?? true,
          'syncedFromCategory': existingData['syncedFromCategory'] ?? false,
        };

        // Upload new chunk to Pinecone
        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: existingData['source'] ?? 'information_bank',
          category: newCategory,
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }

        print(
          '   Chunk ${i + 1}/${chunks.length} uploaded (${chunk.text.length} chars)',
        );
      }

      // Update Firestore document with new data
      await firestore.collection('information_bank').doc(documentId).update({
        'ib_title': newTitle,
        'title': newTitle,
        'content': newContent,
        'category': newCategory,
        'categoryID': newCategory.toLowerCase(),
        'categoryType': newCategory.toLowerCase(),
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'chunkSize': maxChunkSize,
        'chunkOverlap': chunkOverlap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(' Document updated successfully in Firestore');
      print(' Summary:');
      print('   - Old chunks deleted: ${oldChunkIds.length}');
      print('   - New chunks created: ${chunks.length}');
      print('   - Content length: ${newContent.length} characters');
    } catch (e) {
      print(' Error updating document content: $e');
      rethrow;
    }
  }

  Future<void> saveToAdmission(
    Admissions ad, {
    String? sourceDocumentId,
  }) async {
    try {
      final sanitizedId = sanitizeId(ad.id);
      await _ensureNoAdmissionDuplicate(ad, sanitizedId);

      final Map<String, dynamic> admissionData = {
        'id': sanitizedId,
        'admissionID': sanitizedId,
        'type': ad.type,
        'title': ad.title,
        'content': ad.content,
        'source': ad.source,
        'academicYear': ad.academicYear,
        'steps': ad.steps,
        'contact': ad.contact,
        'requirements': ad.requirements ?? [],
        'links': ad.links,
        'schedules': ad.schedules,
        'extractedFromDocument': sourceDocumentId != null, //  NEW FLAG
        'sourceDocumentId': sourceDocumentId, //  Link to original document
        'createdAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('admissions')
          .doc(sanitizedId)
          .set(admissionData);

      //  SKIP Info Bank creation if extracted from document
      if (sourceDocumentId != null) {
        print(
          ' Skipping Info Bank creation - admission extracted from document: $sourceDocumentId',
        );
        return;
      }

      print(' Admission document saved successfully');
    } catch (e) {
      print(' Error saving admission document: $e');
      rethrow;
    }
  }

  Future<void> saveMultipleScholarships(
    List<Scholarship> scholarships, {
    String? sourceDocumentId,
  }) async {
    try {
      await _ensureNoScholarshipDuplicates(scholarships);
      WriteBatch batch = firestore.batch();

      for (Scholarship scholarship in scholarships) {
        final sanitizedId = sanitizeId(scholarship.scholarshipID);
        final docRef = firestore.collection('scholarships').doc(sanitizedId);

        batch.set(docRef, {
          'scholarshipID': sanitizedId,
          'name': scholarship.name,
          'sourceId': scholarship.sourceId,
          'description': scholarship.description,
          'scholarshipProvider': scholarship.scholarshipProvider,
          'eligibilityRequirements': scholarship.eligibilityRequirements,
          'privileges': scholarship.privileges,
          'deadline':
              scholarship.deadline != null
                  ? Timestamp.fromDate(scholarship.deadline!)
                  : null,
          'applicationLink': scholarship.applicationLink,
          'deleted': false,
          'extractedFromDocument': sourceDocumentId != null, //  NEW FLAG
          'sourceDocumentId': sourceDocumentId, //  Link to original document
          'createdAt': Timestamp.fromDate(scholarship.createdAt),
        });
      }

      await batch.commit();
      print(' Batch saved ${scholarships.length} scholarships successfully');

      //  SKIP Info Bank creation if extracted from document
      if (sourceDocumentId != null) {
        print(
          ' Skipping Info Bank creation - scholarships extracted from document: $sourceDocumentId',
        );
        return;
      }

      // Only create Info Bank for standalone scholarships (e.g., from Facebook posts)
      int created = 0;
      int skipped = 0;

      for (Scholarship scholarship in scholarships) {
        try {
          final infoBankId = 'scholarship_${scholarship.scholarshipID}';
          final infoBankSanitized = sanitizeId(infoBankId);

          final existingInfoBank =
              await firestore
                  .collection('information_bank')
                  .doc(infoBankSanitized)
                  .get();

          if (existingInfoBank.exists) {
            print(
              ' Information Bank entry already exists for scholarship ${scholarship.scholarshipID}',
            );
            skipped++;
            continue;
          }

          await _createInfoBankFromScholarship(scholarship);
          created++;
        } catch (e) {
          print(
            ' Error creating Information Bank for scholarship ${scholarship.scholarshipID}: $e',
          );
        }
      }

      print(' Information Bank: $created created, $skipped skipped');
    } catch (e) {
      print(' Error batch saving scholarships: $e');
      rethrow;
    }
  }

  Future<void> saveMultiplePlacements(
    List<Placement> placements, {
    String? sourceDocumentId,
  }) async {
    try {
      await _ensureNoPlacementDuplicates(placements);
      WriteBatch batch = firestore.batch();

      for (Placement placement in placements) {
        final sanitizedId = sanitizeId(placement.placementID);
        final docRef = firestore.collection('placements').doc(sanitizedId);

        batch.set(docRef, {
          'placementID': sanitizedId,
          'partnerCompany': placement.partnerCompany,
          'contacts': placement.contacts,
          'positions': placement.positions,
          'isRecruiting': placement.isRecruiting,
          'deadline':
              placement.deadline != null
                  ? Timestamp.fromDate(placement.deadline!)
                  : null,
          'deleted': false,
          'extractedFromDocument': sourceDocumentId != null, //  NEW FLAG
          'sourceDocumentId': sourceDocumentId, //  Link to original upload
          'createdAt': Timestamp.fromDate(placement.createdAt),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      print(' Batch saved ${placements.length} placements successfully');

      //  SKIP Info Bank creation if extracted from document
      if (sourceDocumentId != null) {
        print(
          ' Skipping Info Bank creation - placements extracted from document: $sourceDocumentId',
        );
        return;
      }

      // Only create Info Bank for standalone placements (e.g., from Facebook posts)
      int created = 0;
      int skipped = 0;

      for (Placement placement in placements) {
        try {
          final infoBankId = 'placement_${placement.placementID}';
          final infoBankSanitized = sanitizeId(infoBankId);

          final existingInfoBank =
              await firestore
                  .collection('information_bank')
                  .doc(infoBankSanitized)
                  .get();

          if (existingInfoBank.exists) {
            print(
              ' Information Bank entry already exists for placement ${placement.placementID}',
            );
            skipped++;
            continue;
          }

          await _createInfoBankFromPlacement(placement);
          created++;
        } catch (e) {
          print(
            ' Error creating Information Bank for placement ${placement.placementID}: $e',
          );
        }
      }

      print(' Information Bank: $created created, $skipped skipped');
    } catch (e) {
      print(' Error batch saving placements: $e');
      rethrow;
    }
  }

  Future<void> updateInfoBankFromAdmission(Admissions admission) async {
    try {
      final infoBankId = 'admission_${admission.id}';
      final sanitizedId = sanitizeId(infoBankId);

      final existingDoc =
          await firestore.collection('information_bank').doc(sanitizedId).get();

      if (!existingDoc.exists) {
        // Doesn't exist yet, create new
        await _createInfoBankFromAdmission(admission);
        return;
      }

      print(
        ' Updating existing Information Bank entry for admission ${admission.id}',
      );

      // Get existing chunk IDs to delete from Pinecone
      final existingData = existingDoc.data()!;
      final oldChunkIds = List<String>.from(existingData['chunkIds'] ?? []);

      // Delete old Pinecone vectors
      if (oldChunkIds.isNotEmpty) {
        await _pineconeService.deleteDocuments(oldChunkIds);
        print(' Deleted ${oldChunkIds.length} old Pinecone vectors');
      }

      // Create new embeddings with updated content
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone not available - skipping update');
        return;
      }

      final textContent = _formatAdmissionAsText(admission);
      final title = admission.title;
      final chunks = _splitIntoChunks(textContent, title, 'admission_category');

      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$title (Part ${i + 1}/${chunks.length})'
                : title;

        final metadata = {
          'docId': admission.id,
          'originalDocId': admission.id,
          'documentId': admission.id,
          'categoryDocId': admission.id,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': title,
          'fileName': title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': 'admission_category',
          'category': 'admission',
          'categoryID': 'admission',
          'categoryType': 'admission',
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'syncedFromCategory': true,
          'academicYear':
              admission.academicYear != null
                  ? '${admission.academicYear!['start']}-${admission.academicYear!['end'] ?? ''}'
                  : null,
          'hasSchedules':
              admission.schedules != null && admission.schedules!.isNotEmpty,
          'scheduleCount': admission.schedules?.length ?? 0,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: 'admission_category',
          category: 'admission',
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }
      }

      // Update Information Bank document
      await firestore.collection('information_bank').doc(sanitizedId).update({
        'content': textContent,
        'ib_title': title,
        'title': title,
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        ' Information Bank entry updated with ${chunks.length} new Pinecone vectors',
      );
    } catch (e) {
      print(' Error updating Information Bank from admission: $e');
    }
  }

  /// Update Information Bank for scholarship (for individual updates)
  Future<void> updateInfoBankFromScholarship(Scholarship scholarship) async {
    try {
      final infoBankId = 'scholarship_${scholarship.scholarshipID}';
      final sanitizedId = sanitizeId(infoBankId);

      final existingDoc =
          await firestore.collection('information_bank').doc(sanitizedId).get();

      if (!existingDoc.exists) {
        await _createInfoBankFromScholarship(scholarship);
        return;
      }

      print(
        ' Updating existing Information Bank entry for scholarship ${scholarship.scholarshipID}',
      );

      final existingData = existingDoc.data()!;
      final oldChunkIds = List<String>.from(existingData['chunkIds'] ?? []);

      if (oldChunkIds.isNotEmpty) {
        await _pineconeService.deleteDocuments(oldChunkIds);
        print(' Deleted ${oldChunkIds.length} old Pinecone vectors');
      }

      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone not available - skipping update');
        return;
      }

      final textContent = _formatScholarshipAsText(scholarship);
      final title = scholarship.name;
      final chunks = _splitIntoChunks(
        textContent,
        title,
        'scholarship_category',
      );

      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$title (Part ${i + 1}/${chunks.length})'
                : title;

        final metadata = {
          'docId': scholarship.scholarshipID,
          'originalDocId': scholarship.scholarshipID,
          'documentId': scholarship.scholarshipID,
          'categoryDocId': scholarship.scholarshipID,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': title,
          'fileName': title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': 'scholarship_category',
          'category': 'scholarship',
          'categoryID': 'scholarship',
          'categoryType': 'scholarship',
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'syncedFromCategory': true,
          'scholarshipProvider': scholarship.scholarshipProvider,
          'hasDeadline': scholarship.deadline != null,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: 'scholarship_category',
          category: 'scholarship',
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }
      }

      await firestore.collection('information_bank').doc(sanitizedId).update({
        'content': textContent,
        'ib_title': title,
        'title': title,
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        ' Information Bank entry updated with ${chunks.length} new Pinecone vectors',
      );
    } catch (e) {
      print(' Error updating Information Bank from scholarship: $e');
    }
  }

  /// Update Information Bank for placement (for individual updates)
  Future<void> updateInfoBankFromPlacement(Placement placement) async {
    try {
      final infoBankId = 'placement_${placement.placementID}';
      final sanitizedId = sanitizeId(infoBankId);

      final existingDoc =
          await firestore.collection('information_bank').doc(sanitizedId).get();

      if (!existingDoc.exists) {
        await _createInfoBankFromPlacement(placement);
        return;
      }

      print(
        ' Updating existing Information Bank entry for placement ${placement.placementID}',
      );

      final existingData = existingDoc.data()!;
      final oldChunkIds = List<String>.from(existingData['chunkIds'] ?? []);

      if (oldChunkIds.isNotEmpty) {
        await _pineconeService.deleteDocuments(oldChunkIds);
        print(' Deleted ${oldChunkIds.length} old Pinecone vectors');
      }

      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone not available - skipping update');
        return;
      }

      final textContent = _formatPlacementAsText(placement);
      final title = '${placement.partnerCompany} - Job Placement';
      final chunks = _splitIntoChunks(textContent, title, 'placement_category');

      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$title (Part ${i + 1}/${chunks.length})'
                : title;

        final metadata = {
          'docId': placement.placementID,
          'originalDocId': placement.placementID,
          'documentId': placement.placementID,
          'categoryDocId': placement.placementID,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': title,
          'fileName': title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': 'placement_category',
          'category': 'placement',
          'categoryID': 'placement',
          'categoryType': 'placement',
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'syncedFromCategory': true,
          'partnerCompany': placement.partnerCompany,
          'isRecruiting': placement.isRecruiting,
          'positionCount': placement.positions.length,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: 'placement_category',
          category: 'placement',
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }
      }

      await firestore.collection('information_bank').doc(sanitizedId).update({
        'content': textContent,
        'ib_title': title,
        'title': title,
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        ' Information Bank entry updated with ${chunks.length} new Pinecone vectors',
      );
    } catch (e) {
      print(' Error updating Information Bank from placement: $e');
    }
  }

  Future<void> _createInfoBankFromAdmission(Admissions admission) async {
    try {
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone not available - skipping Information Bank creation');
        return;
      }

      final textContent = _formatAdmissionAsText(admission);
      final title = admission.title;
      final chunks = _splitIntoChunks(textContent, title, 'admission_category');

      print(
        ' Creating Information Bank: ${chunks.length} chunks for admission ${admission.id}',
      );

      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$title (Part ${i + 1}/${chunks.length})'
                : title;

        final metadata = {
          'docId': admission.id,
          'originalDocId': admission.id,
          'documentId': admission.id,
          'categoryDocId': admission.id,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': title,
          'fileName': title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': 'admission_category',
          'category': 'admission',
          'categoryID': 'admission',
          'categoryType': 'admission',
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'syncedFromCategory': true,

          //  NEW: Add type to metadata
          'admissionType': admission.type ?? 'general',
          'testType': admission.type ?? 'general',

          'academicYear':
              admission.academicYear != null
                  ? '${admission.academicYear!['start']}-${admission.academicYear!['end'] ?? ''}'
                  : null,
          'hasSchedules':
              admission.schedules != null && admission.schedules!.isNotEmpty,
          'scheduleCount': admission.schedules?.length ?? 0,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: 'admission_category',
          category: 'admission',
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }
      }

      final infoBankId = 'admission_${admission.id}';
      final sanitizedId = sanitizeId(infoBankId);

      await firestore.collection('information_bank').doc(sanitizedId).set({
        'ibID': sanitizedId,
        'id': sanitizedId,
        'ib_title': title,
        'title': title,
        'content': textContent,
        'source': 'admission_category',
        'category': 'admission',
        'categoryID': 'admission',
        'categoryType': 'admission',
        'categoryDocumentId': admission.id,
        'admissionType': admission.type ?? 'general', //  NEW
        'testType': admission.type ?? 'general', //  NEW
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'chunkSize': maxChunkSize,
        'chunkOverlap': chunkOverlap,
        'syncedFromCategory': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(' Information Bank created: ${chunks.length} Pinecone vectors');
      print('   Admission Type: ${admission.type ?? "general"}');
    } catch (e) {
      print(' Error creating Information Bank from admission: $e');
    }
  }

  /// Create Information Bank entry from Scholarship
  Future<void> _createInfoBankFromScholarship(Scholarship scholarship) async {
    try {
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone not available - skipping Information Bank creation');
        return;
      }

      final textContent = _formatScholarshipAsText(scholarship);
      final title = scholarship.name;
      final chunks = _splitIntoChunks(
        textContent,
        title,
        'scholarship_category',
      );

      print(
        ' Creating Information Bank: ${chunks.length} chunks for scholarship ${scholarship.scholarshipID}',
      );

      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$title (Part ${i + 1}/${chunks.length})'
                : title;

        final metadata = {
          'docId': scholarship.scholarshipID,
          'originalDocId': scholarship.scholarshipID,
          'documentId': scholarship.scholarshipID,
          'categoryDocId': scholarship.scholarshipID,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': title,
          'fileName': title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': 'scholarship_category',
          'category': 'scholarship',
          'categoryID': 'scholarship',
          'categoryType': 'scholarship',
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'syncedFromCategory': true,
          'scholarshipProvider': scholarship.scholarshipProvider,
          'hasDeadline': scholarship.deadline != null,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: 'scholarship_category',
          category: 'scholarship',
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }
      }

      final infoBankId = 'scholarship_${scholarship.scholarshipID}';
      final sanitizedId = sanitizeId(infoBankId);

      await firestore.collection('information_bank').doc(sanitizedId).set({
        'ibID': sanitizedId,
        'id': sanitizedId,
        'ib_title': title,
        'title': title,
        'content': textContent,
        'source': 'scholarship_category',
        'category': 'scholarship',
        'categoryID': 'scholarship',
        'categoryType': 'scholarship',
        'categoryDocumentId': scholarship.scholarshipID,
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'chunkSize': maxChunkSize,
        'chunkOverlap': chunkOverlap,
        'syncedFromCategory': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(' Information Bank created: ${chunks.length} Pinecone vectors');
    } catch (e) {
      print(' Error creating Information Bank from scholarship: $e');
    }
  }

  /// Create Information Bank entry from Placement
  Future<void> _createInfoBankFromPlacement(Placement placement) async {
    try {
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone not available - skipping Information Bank creation');
        return;
      }

      final textContent = _formatPlacementAsText(placement);
      final title = '${placement.partnerCompany} - Job Placement';
      final chunks = _splitIntoChunks(textContent, title, 'placement_category');

      print(
        ' Creating Information Bank: ${chunks.length} chunks for placement ${placement.placementID}',
      );

      final chunkIds = <String>[];
      String? parentPineconeId;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _geminiService.embedText(chunk.text);

        final chunkTitle =
            chunks.length > 1
                ? '$title (Part ${i + 1}/${chunks.length})'
                : title;

        final metadata = {
          'docId': placement.placementID,
          'originalDocId': placement.placementID,
          'documentId': placement.placementID,
          'categoryDocId': placement.placementID,
          'text': chunk.text,
          'content': chunk.text,
          'title': chunkTitle,
          'originalTitle': title,
          'fileName': title,
          'chunkIndex': i,
          'chunk_index': i,
          'totalChunks': chunks.length,
          'chunkCount': chunks.length,
          'isFirstChunk': i == 0,
          'isLastChunk': i == chunks.length - 1,
          'source': 'placement_category',
          'category': 'placement',
          'categoryID': 'placement',
          'categoryType': 'placement',
          'chunkSize': chunk.text.length,
          'createdAt': DateTime.now().toIso8601String(),
          'syncedFromCategory': true,
          'partnerCompany': placement.partnerCompany,
          'isRecruiting': placement.isRecruiting,
          'positionCount': placement.positions.length,
        };

        await _pineconeService.insertDocument(
          id: chunk.id,
          embedding: embedding,
          title: chunkTitle,
          content: chunk.text,
          source: 'placement_category',
          category: 'placement',
          metadata: metadata,
        );

        chunkIds.add(chunk.id);
        if (i == 0) {
          parentPineconeId = chunk.id;
        }
      }

      final infoBankId = 'placement_${placement.placementID}';
      final sanitizedId = sanitizeId(infoBankId);

      await firestore.collection('information_bank').doc(sanitizedId).set({
        'ibID': sanitizedId,
        'id': sanitizedId,
        'ib_title': title,
        'title': title,
        'content': textContent,
        'source': 'placement_category',
        'category': 'placement',
        'categoryID': 'placement',
        'categoryType': 'placement',
        'categoryDocumentId': placement.placementID,
        'pinecone_id': parentPineconeId,
        'totalChunks': chunks.length,
        'chunkIds': chunkIds,
        'chunked': chunks.length > 1,
        'chunkSize': maxChunkSize,
        'chunkOverlap': chunkOverlap,
        'syncedFromCategory': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(' Information Bank created: ${chunks.length} Pinecone vectors');
    } catch (e) {
      print(' Error creating Information Bank from placement: $e');
    }
  }

  // ============================================================================
  // Helper functions for formatting category data as text
  // ============================================================================

  String _formatAdmissionAsText(Admissions admission) {
    final buffer = StringBuffer();

    buffer.writeln('ADMISSION INFORMATION\n');

    //  Add type if present
    if (admission.type != null && admission.type!.isNotEmpty) {
      buffer.writeln('Test Type: ${admission.type}\n');
    }

    buffer.writeln('Title: ${admission.title}\n');
    buffer.writeln('Content: ${admission.content}\n');

    if (admission.academicYear != null) {
      buffer.write('Academic Year: ${admission.academicYear!['start']}');
      if (admission.academicYear!['end'] != null) {
        buffer.write('-${admission.academicYear!['end']}');
      }
      buffer.writeln('\n');
    }

    if (admission.steps.isNotEmpty) {
      buffer.writeln('Steps:');
      for (int i = 0; i < admission.steps.length; i++) {
        buffer.writeln('${i + 1}. ${admission.steps[i]}');
      }
      buffer.writeln();
    }

    if (admission.requirements != null && admission.requirements!.isNotEmpty) {
      buffer.writeln('Requirements:');
      for (final req in admission.requirements!) {
        buffer.writeln('- $req');
      }
      buffer.writeln();
    }

    if (admission.schedules != null && admission.schedules!.isNotEmpty) {
      buffer.writeln('Schedules:');
      for (final schedule in admission.schedules!) {
        buffer.write('- ${schedule['date']} (${schedule['dayOfWeek']})');
        if (schedule['year'] != null) {
          buffer.write(' ${schedule['year']}');
        }
        buffer.write(': ${(schedule['locations'] as List).join(', ')}');
        if (schedule['time'] != null && schedule['time'].isNotEmpty) {
          buffer.write(' at ${schedule['time']}');
        }
        buffer.writeln();
      }
      buffer.writeln();
    }

    if (admission.contact != null && admission.contact!.isNotEmpty) {
      buffer.writeln('Contact Information:');
      for (final contact in admission.contact!) {
        buffer.writeln('- $contact');
      }
    }

    return buffer.toString().trim();
  }

  String _formatScholarshipAsText(Scholarship scholarship) {
    final buffer = StringBuffer();

    buffer.writeln('SCHOLARSHIP INFORMATION\n');
    buffer.writeln('Name: ${scholarship.name}\n');
    buffer.writeln('Description: ${scholarship.description}\n');
    buffer.writeln('Provider: ${scholarship.scholarshipProvider}\n');

    if (scholarship.eligibilityRequirements.isNotEmpty) {
      buffer.writeln('Eligibility Requirements:');
      for (final req in scholarship.eligibilityRequirements) {
        buffer.writeln('- $req');
      }
      buffer.writeln();
    }

    if (scholarship.privileges.isNotEmpty) {
      buffer.writeln('Privileges/Benefits:');
      for (final priv in scholarship.privileges) {
        buffer.writeln('- $priv');
      }
      buffer.writeln();
    }

    if (scholarship.deadline != null) {
      buffer.writeln(
        'Deadline: ${scholarship.deadline!.toString().split(' ')[0]}\n',
      );
    }

    if (scholarship.applicationLink.isNotEmpty) {
      buffer.writeln('Application Link: ${scholarship.applicationLink}');
    }

    return buffer.toString().trim();
  }

  String _formatPlacementAsText(Placement placement) {
    final buffer = StringBuffer();

    buffer.writeln('JOB PLACEMENT INFORMATION\n');
    buffer.writeln('Company: ${placement.partnerCompany}\n');
    buffer.writeln(
      'Status: ${placement.isRecruiting ? 'Currently Recruiting' : 'Not Currently Recruiting'}\n',
    );

    if (placement.positions.isNotEmpty) {
      buffer.writeln('Available Positions:');
      for (final position in placement.positions) {
        buffer.writeln('- $position');
      }
      buffer.writeln();
    }

    if (placement.contacts.isNotEmpty) {
      buffer.writeln('Contact Information:');
      for (final contact in placement.contacts) {
        buffer.writeln('- $contact');
      }
      buffer.writeln();
    }

    if (placement.deadline != null) {
      buffer.writeln(
        'Deadline: ${placement.deadline!.toString().split(' ')[0]}',
      );
    }

    return buffer.toString().trim();
  }

  Future<void> syncAnnouncementsToInfoBank() async {
    try {
      final announcementsSnapshot =
          await firestore
              .collection('announcements')
              .where(
                'category',
                whereIn: ['Admission', 'Scholarship', 'Placement'],
              )
              .get();

      for (final doc in announcementsSnapshot.docs) {
        final data = doc.data();
        final category = (data['category'] as String).toLowerCase();

        // Check if category document exists
        final categoryId = doc.id;
        final categoryDoc =
            await firestore.collection('${category}s').doc(categoryId).get();

        if (categoryDoc.exists) {
          // Check if info bank entry exists
          final infoBankId = '${category}_$categoryId';
          final infoBankDoc =
              await firestore
                  .collection('information_bank')
                  .doc(infoBankId)
                  .get();

          if (!infoBankDoc.exists) {
            print(
              ' Missing Info Bank for $category $categoryId - needs manual sync',
            );
          }
        }
      }
    } catch (e) {
      print(' Error checking Info Bank sync: $e');
    }
  }

  /// Initialize Pinecone service
  Future<void> initializePinecone() async {
    try {
      final isHealthy = await _pineconeService.isHealthy();
      if (!isHealthy) {
        print(' Pinecone is not running or accessible');
        return;
      }

      print(' Pinecone initialized successfully');
    } catch (e) {
      print(' Error initializing Pinecone: $e');
    }
  }

  /// Extract text from a file based on its extension
  Future<String> extractTextFromFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();

    if (!supportedExtensions.contains(extension)) {
      throw UnsupportedError('Unsupported file type: $extension');
    }

    try {
      switch (extension) {
        case 'pdf':
          return await _extractTextFromPdf(file);
        case 'txt':
          return await file.readAsString();
        case 'docx':
          return await _extractTextFromDocx(file);
        case 'doc':
          return await _extractTextFromDoc(file);
        default:
          throw UnsupportedError('Unsupported file type: $extension');
      }
    } catch (e) {
      print(' Error extracting text from $extension file: $e');
      rethrow;
    }
  }

  /// Extract text from PDF file
  Future<String> _extractTextFromPdf(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  /// Extract text from PDF bytes
  Future<String> extractTextFromPdfBytes(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  /// Extract text from DOCX file
  Future<String> _extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await _extractTextFromDocxBytes(bytes);
    } catch (e) {
      throw Exception('Failed to extract text from DOCX file: $e');
    }
  }

  /// Extract text from DOCX bytes
  Future<String> _extractTextFromDocxBytes(Uint8List bytes) async {
    try {
      final text = docxToText(bytes);
      if (text.isEmpty) {
        throw Exception('No text content found in DOCX file');
      }
      return text;
    } catch (e) {
      throw Exception('Failed to parse DOCX content: $e');
    }
  }

  /// Extract text from DOC file (legacy Word format)
  /// Note: This is a basic implementation and may not work for all DOC files
  /// For better DOC support, consider using a server-side conversion service
  Future<String> _extractTextFromDoc(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await _extractTextFromDocBytes(bytes);
    } catch (e) {
      throw Exception(
        'Failed to extract text from DOC file: $e. Consider converting to DOCX format for better compatibility.',
      );
    }
  }

  /// Extract text from DOC bytes
  /// This is a simplified implementation that may not work for all DOC files
  Future<String> _extractTextFromDocBytes(Uint8List bytes) async {
    try {
      // Basic text extraction from DOC format
      String content = '';
      final text = String.fromCharCodes(bytes);

      final textPattern = RegExp(r'[\x20-\x7E\x0A\x0D]+');
      final matches = textPattern.allMatches(text);

      for (final match in matches) {
        final extractedText = match.group(0)?.trim() ?? '';
        if (extractedText.length > 10) {
          content += extractedText + '\n';
        }
      }

      if (content.trim().isEmpty) {
        throw Exception('No readable text found in DOC file');
      }

      content =
          content
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll(RegExp(r'[^\x20-\x7E\x0A\x0D]'), '')
              .trim();

      return content;
    } catch (e) {
      throw Exception('Failed to parse DOC content: $e');
    }
  }

  /// Helper method to extract text from uploaded file bytes based on filename
  Future<String> extractTextFromFileBytes(
    Uint8List bytes,
    String filename,
  ) async {
    final extension = filename.split('.').last.toLowerCase();

    if (!supportedExtensions.contains(extension)) {
      throw UnsupportedError('Unsupported file type: $extension');
    }

    try {
      switch (extension) {
        case 'pdf':
          return await extractTextFromPdfBytes(bytes);
        case 'txt':
          return utf8.decode(bytes);
        case 'docx':
          return await _extractTextFromDocxBytes(bytes);
        case 'doc':
          return await _extractTextFromDocBytes(bytes);
        default:
          throw UnsupportedError('Unsupported file type: $extension');
      }
    } catch (e) {
      print(' Error extracting text from $extension file: $e');
      rethrow;
    }
  }

  /// Split document content into chunks for better retrieval
  List<DocumentChunk> _splitIntoChunks(
    String content,
    String title,
    String source,
  ) {
    final List<DocumentChunk> chunks = [];

    // Clean the content - normalize whitespace but preserve paragraphs
    final cleanContent =
        content
            .replaceAll(RegExp(r'\r\n|\r'), '\n') // Normalize line endings
            .replaceAll(RegExp(r'[ \t]+'), ' ') // Normalize spaces/tabs
            .replaceAll(
              RegExp(r'\n[ \t]*\n'),
              '\n\n',
            ) // Normalize paragraph breaks
            .trim();

    if (cleanContent.length <= maxChunkSize) {
      // If content is small enough, return as single chunk
      chunks.add(
        DocumentChunk(
          id: _uuid.v4(),
          text: cleanContent,
          embedding: [],
          metadata: {
            'originalTitle': title,
            'source': source,
            'chunkIndex': 0,
            'totalChunks': 1,
            'chunkSize': cleanContent.length,
          },
        ),
      );
      return chunks;
    }

    // Split by sentences first, then by paragraphs
    final sentences = _splitIntoSentences(cleanContent);

    String currentChunk = '';
    int chunkIndex = 0;

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;

      // Check if adding this sentence would exceed the chunk size
      final proposedChunk =
          currentChunk.isEmpty ? sentence : currentChunk + ' ' + sentence;

      if (proposedChunk.length > maxChunkSize && currentChunk.isNotEmpty) {
        // Save current chunk
        chunks.add(
          DocumentChunk(
            id: _uuid.v4(),
            text: currentChunk.trim(),
            embedding: [],
            metadata: {
              'originalTitle': title,
              'source': source,
              'chunkIndex': chunkIndex,
              'totalChunks': -1, // Will be updated later
              'chunkSize': currentChunk.trim().length,
            },
          ),
        );
        chunkIndex++;

        // Start new chunk with overlap from previous chunk
        if (chunkOverlap > 0) {
          final overlapText = _getOverlapText(currentChunk, chunkOverlap);
          currentChunk =
              overlapText.isEmpty ? sentence : overlapText + ' ' + sentence;
        } else {
          currentChunk = sentence;
        }
      } else {
        currentChunk = proposedChunk;
      }
    }

    // Add remaining content as final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(
        DocumentChunk(
          id: _uuid.v4(),
          text: currentChunk.trim(),
          embedding: [],
          metadata: {
            'originalTitle': title,
            'source': source,
            'chunkIndex': chunkIndex,
            'totalChunks': -1, // Will be updated later
            'chunkSize': currentChunk.trim().length,
          },
        ),
      );
    }

    // Update total chunks count
    for (final chunk in chunks) {
      chunk.metadata['totalChunks'] = chunks.length;
    }

    return chunks;
  }

  /// Split text into sentences for better chunking
  List<String> _splitIntoSentences(String text) {
    // Simple sentence splitting - can be improved with better NLP
    final sentences = <String>[];
    final parts = text.split(RegExp(r'[.!?]+'));

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isNotEmpty) {
        // Add back the punctuation except for the last part
        if (i < parts.length - 1) {
          sentences.add(part + '.');
        } else {
          sentences.add(part);
        }
      }
    }

    return sentences;
  }

  /// Get overlap text from the end of previous chunk
  String _getOverlapText(String text, int maxLength) {
    if (text.length <= maxLength) return text;

    final substring = text.substring(text.length - maxLength);

    // Try to start from a sentence boundary
    final sentenceEnd = substring.lastIndexOf(RegExp(r'[.!?]\s+'));
    if (sentenceEnd > 0) {
      return substring.substring(sentenceEnd + 1).trim();
    }

    // Try to start from a word boundary
    final spaceIndex = substring.indexOf(' ');
    if (spaceIndex > 0) {
      return substring.substring(spaceIndex + 1).trim();
    }

    return substring.trim();
  }

  /// Delete a document and all its chunks from both Pinecone and Firebase
  Future<void> deleteDocument(String documentId) async {
    try {
      // Get document metadata to find chunk IDs
      final docSnapshot =
          await firestore.collection('information_bank').doc(documentId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final chunkIds = List<String>.from(data['chunkIds'] ?? []);

        // Delete all chunks from Pinecone
        if (chunkIds.isNotEmpty) {
          await _pineconeService.deleteDocuments(chunkIds);
        }

        print(' Deleted ${chunkIds.length} chunks from Pinecone');
      }

      // Delete document metadata from Firebase
      await firestore.collection('information_bank').doc(documentId).delete();

      print(' Document and all chunks deleted from both Pinecone and Firebase');
    } catch (e) {
      print(' Error deleting document: $e');
      rethrow;
    }
  }

  /// Get document statistics
  Future<Map<String, int>> getDocumentStats() async {
    try {
      final snapshot = await firestore.collection('information_bank').get();
      int totalDocuments = snapshot.docs.length;
      int totalChunks = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalChunks += (data['totalChunks'] as int?) ?? 0;
      }

      return {'totalDocuments': totalDocuments, 'totalChunks': totalChunks};
    } catch (e) {
      print(' Error getting document stats: $e');
      return {'totalDocuments': 0, 'totalChunks': 0};
    }
  }

  /// Get chunking statistics for a specific document
  Future<Map<String, dynamic>?> getDocumentChunkInfo(String documentId) async {
    try {
      final doc =
          await firestore.collection('information_bank').doc(documentId).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'totalChunks': data['totalChunks'],
        'chunkIds': data['chunkIds'],
        'chunked': data['chunked'] ?? false,
        'chunkSize': data['chunkSize'],
        'chunkOverlap': data['chunkOverlap'],
      };
    } catch (e) {
      print(' Error getting document chunk info: $e');
      return null;
    }
  }
}

class DocumentChunk {
  final String id;
  final String text;
  List<double> embedding;
  final Map<String, dynamic> metadata;

  DocumentChunk({
    required this.id,
    required this.text,
    required this.embedding,
    required this.metadata,
  });

  /// Create a DocumentChunk from JSON data
  factory DocumentChunk.fromJson(Map<String, dynamic> json) {
    return DocumentChunk(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      embedding: List<double>.from(json['embedding'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Convert DocumentChunk to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'embedding': embedding,
      'metadata': metadata,
    };
  }

  /// Get the original document title from metadata
  String get originalTitle => metadata['originalTitle'] ?? 'Unknown';

  /// Get the source from metadata
  String get source => metadata['source'] ?? 'Unknown';

  /// Get the chunk index from metadata
  int get chunkIndex => metadata['chunkIndex'] ?? 0;

  /// Get the total number of chunks from metadata
  int get totalChunks => metadata['totalChunks'] ?? 1;

  /// Get the chunk size from metadata
  int get chunkSize => metadata['chunkSize'] ?? 0;

  /// Check if this is the first chunk of a document
  bool get isFirstChunk => chunkIndex == 0;

  /// Check if this is the last chunk of a document
  bool get isLastChunk => chunkIndex == totalChunks - 1;

  /// Get a summary of the chunk for debugging
  String get summary =>
      'Chunk ${chunkIndex + 1}/${totalChunks} of "$originalTitle" (${chunkSize} chars)';
}
