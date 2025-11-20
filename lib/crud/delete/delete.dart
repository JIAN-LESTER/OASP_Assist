import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:capstone_project/services/admin_functions.dart'
    show FirebaseFunctionsService;
// Add the snackbar utility import
import 'package:capstone_project/utils/snackbar_util.dart';

class DeleteConfig {
  final String title;
  final String confirmationMessage;
  final String successMessage;
  final String titleField;
  final Color? headerColor;
  final IconData? icon;
  final bool
  isComplex; // true for document-like deletes, false for simple deletes

  const DeleteConfig({
    required this.title,
    required this.confirmationMessage,
    required this.successMessage,
    required this.titleField,
    this.headerColor,
    this.icon,
    this.isComplex = false,
  });
}

// Predefined delete configurations
class DeleteConfigs {
  static const document = DeleteConfig(
    title: 'Delete Document',
    confirmationMessage:
        'Are you sure you want to delete this document? This action cannot be undone and will also delete related scholarships.',
    successMessage: 'Document deleted successfully',
    titleField: 'ib_title',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: true,
  );

  static const announcement = DeleteConfig(
    title: 'Delete Announcement',
    confirmationMessage:
        'Are you sure you want to delete this announcement? This action cannot be undone.',
    successMessage: 'Announcement deleted successfully',
    titleField: 'message',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const log = DeleteConfig(
    title: 'Delete Log',
    confirmationMessage: 'Are you sure you want to delete this log entry?',
    successMessage: 'Log deleted successfully',
    titleField: 'action',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const msgLog = DeleteConfig(
    title: 'Delete Message Log',
    confirmationMessage:
        'Are you sure you want to delete this message log entry?',
    successMessage: 'Message Log deleted successfully',
    titleField: 'question',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const scholarships = DeleteConfig(
    title: 'Delete Scholarship',
    confirmationMessage: 'Are you sure you want to delete this scholarship?',
    successMessage: 'Scholarship deleted successfully',
    titleField: 'name',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const faqs = DeleteConfig(
    title: 'Delete FAQ',
    confirmationMessage: 'Are you sure you want to delete this FAQ?',
    successMessage: 'FAQ deleted successfully',
    titleField: 'question',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const admissions = DeleteConfig(
    title: 'Delete Admission',
    confirmationMessage:
        'Are you sure you want to delete this admission document?',
    successMessage: 'Admission document deleted successfully',
    titleField: 'title',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: true,
  );

  static const affiliations = DeleteConfig(
    title: 'Delete Affiliation',
    confirmationMessage: 'Are you sure you want to delete this affiliation?',
    successMessage: 'Affiliation document deleted successfully',
    titleField: 'name',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const users = DeleteConfig(
    title: 'Delete User',
    confirmationMessage: 'Are you sure you want to delete this user?',
    successMessage: 'User deleted successfully',
    titleField: 'name',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );

  static const placements = DeleteConfig(
    title: 'Delete Company',
    confirmationMessage: 'Are you sure you want to delete this company?',
    successMessage: 'Company deleted successfully',
    titleField: 'partnerCompany',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    isComplex: false,
  );
}

// Reusable delete confirmation dialog
void showDeleteConfirmation(
  BuildContext context,
  DocumentSnapshot doc,
  DeleteConfig config,
  String collection, {
  Future<void> Function(BuildContext, DocumentSnapshot)? customDeleteHandler,
  Set<String>? deletedItemsTracker, // For announcements tracking
}) {
  final data = doc.data() as Map<String, dynamic>;
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '${config.title} Confirmation',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(
                        config.icon ?? Icons.warning_amber_rounded,
                        color: config.headerColor ?? const Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      config.title,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      config.confirmationMessage,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${config.title.split(' ').last}:',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDisplayTitle(data, config.titleField),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: const Color(0xFF1F2937),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => _handleReusableDelete(
                                  context,
                                  doc,
                                  config,
                                  collection,
                                  customDeleteHandler: customDeleteHandler,
                                  deletedItemsTracker: deletedItemsTracker,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  config.headerColor ?? const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

// Helper function to get display title
String _getDisplayTitle(Map<String, dynamic> data, String titleField) {
  String title = data[titleField]?.toString() ?? 'Untitled';
  if (titleField == 'message' && title.length > 50) {
    // For announcements, truncate long messages
    title = '${title.substring(0, 50)}...';
  }
  return title;
}

// Main reusable delete handler
Future<void> _handleReusableDelete(
  BuildContext context,
  DocumentSnapshot doc,
  DeleteConfig config,
  String collection, {
  Future<void> Function(BuildContext, DocumentSnapshot)? customDeleteHandler,
  Set<String>? deletedItemsTracker,
}) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          ),
    );

    // Use custom handler if provided (for complex deletes like documents)
    if (customDeleteHandler != null) {
      await customDeleteHandler(context, doc);
      return;
    }

    // Standard delete logic for simple cases
    await _performStandardDelete(
      context,
      doc,
      config,
      collection,
      deletedItemsTracker: deletedItemsTracker,
    );
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      // Use consistent error snackbar
      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

// Standard delete for simple cases
Future<void> _performStandardDelete(
  BuildContext context,
  DocumentSnapshot doc,
  DeleteConfig config,
  String collection, {
  Set<String>? deletedItemsTracker,
}) async {
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

  final docData = doc.data() as Map<String, dynamic>;
  String deletedTitle = _getDisplayTitle(docData, config.titleField);

  // For announcements, add to tracking
  if (deletedItemsTracker != null) {
    deletedItemsTracker.add(doc.id);

    // Store in deleted_announcements collection
    await FirebaseFirestore.instance
        .collection('deleted_announcements')
        .doc(doc.id)
        .set({
          'post_id': doc.id,
          'deleted_at': FieldValue.serverTimestamp(),
          'original_data': docData,
        });
  }

  // Delete the document
  await FirebaseFirestore.instance.collection(collection).doc(doc.id).delete();

  // Pop dialogs
  if (context.mounted) {
    Navigator.of(context).pop(); // Close loading
    Navigator.of(context).pop(); // Close confirmation dialog

    // Use consistent success snackbar
    SnackbarUtil.showSuccess(context, config.successMessage);
  }

  // Log the action
  try {
    final logRef = FirebaseFirestore.instance.collection('logs').doc();
    await logRef.set({
      'logId': logRef.id,
      'user': actorName,
      'action': '${config.title}: $deletedTitle',
      'time': Timestamp.now(),
    });
  } catch (e) {
    print("⚠️ Failed to log action: $e");
  }
}

Future<void> handleUserDelete(
  BuildContext context,
  DocumentSnapshot doc,
) async {
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

    final docData = doc.data() as Map<String, dynamic>;
    String deletedUserName = docData['name'] ?? 'Unknown User';
    String deletedUserEmail = docData['email'] ?? '';

    // Step 1: Delete from Firebase Authentication using Cloud Function
    final functionsService = FirebaseFunctionsService();
    try {
      await functionsService.deleteUserAuth(doc.id);
      print('✅ User deleted from Firebase Authentication');
    } catch (e) {
      print('⚠️ Failed to delete from Authentication: $e');
      // Continue with Firestore deletion even if Auth deletion fails
    }

    // Step 2: Delete user document from Firestore
    await FirebaseFirestore.instance.collection('users').doc(doc.id).delete();
    print('✅ User document deleted from Firestore');

    // Close dialogs
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close confirmation dialog

      // Use consistent success snackbar
      SnackbarUtil.showSuccess(context, 'User deleted successfully');
    }

    // Step 3: Log the action
    try {
      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Deleted User: $deletedUserName ($deletedUserEmail)',
        'time': Timestamp.now(),
      });
      print('✅ Deletion logged successfully');
    } catch (e) {
      print("⚠️ Failed to log action: $e");
    }
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      // Use consistent error snackbar
      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

Future<void> handleComplexDocumentDelete(
  BuildContext context,
  DocumentSnapshot doc,
  String collectionName, {
  List<String>? additionalCollections,
}) async {
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

    final docData = doc.data() as Map<String, dynamic>;
    String deletedTitle = docData['ib_title'] ?? docData['title'] ?? docData['name'] ?? 'Unknown';
    final pineconeNamespace = docData['pinecone_namespace'];

    final firestore = FirebaseFirestore.instance;

    // Determine what to delete based on collection
    if (collectionName == 'information_bank') {
      // --- Delete related scholarships ---
      final scholarshipsSnap =
          await firestore
              .collection('scholarships')
              .where('sourceId', isEqualTo: doc.id)
              .get();

      List<String> failedScholarshipDeletes = [];
      for (final scholarshipDoc in scholarshipsSnap.docs) {
        try {
          await firestore
              .collection('scholarships')
              .doc(scholarshipDoc.id)
              .delete();
          print("✅ Deleted scholarship ${scholarshipDoc.id}");
        } catch (e) {
          print("❌ Failed to delete scholarship ${scholarshipDoc.id}: $e");
          failedScholarshipDeletes.add(scholarshipDoc.id);
        }
      }

      // --- Delete related admissions ---
      final admissionsSnap =
          await firestore
              .collection('admissions')
              .where('sourceId', isEqualTo: doc.id)
              .get();

      List<String> failedAdmissionDeletes = [];
      for (final admissionDoc in admissionsSnap.docs) {
        try {
          await firestore.collection('admissions').doc(admissionDoc.id).delete();
          print("✅ Deleted admission ${admissionDoc.id}");
        } catch (e) {
          print("❌ Failed to delete admission ${admissionDoc.id}: $e");
          failedAdmissionDeletes.add(admissionDoc.id);
        }
      }

      // --- Delete related placements ---
      final placementsSnap =
          await firestore
              .collection('placements')
              .where('sourceId', isEqualTo: doc.id)
              .get();

      List<String> failedPlacementDeletes = [];
      for (final placementDoc in placementsSnap.docs) {
        try {
          await firestore.collection('placements').doc(placementDoc.id).delete();
          print("✅ Deleted placement ${placementDoc.id}");
        } catch (e) {
          print("❌ Failed to delete placement ${placementDoc.id}: $e");
          failedPlacementDeletes.add(placementDoc.id);
        }
      }

      // --- Delete the main information_bank doc ---
      await firestore.collection('information_bank').doc(doc.id).delete();
      print("✅ Deleted information_bank document");

      // Delete vectors in Pinecone in the background
      _deleteFromPineconeInBackground(docData, pineconeNamespace);

      // Close dialogs and show feedback
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close confirmation

        int totalFailures =
            failedScholarshipDeletes.length +
            failedAdmissionDeletes.length +
            failedPlacementDeletes.length;

        if (totalFailures == 0) {
          SnackbarUtil.showSuccess(context, 'Document deleted successfully');
        } else {
          SnackbarUtil.showWarning(
            context,
            'Document deleted successfully ($totalFailures related docs could not be deleted)',
          );
        }
      }

      // Log the action
      try {
        final logRef = firestore.collection('logs').doc();
        await logRef.set({
          'logId': logRef.id,
          'user': actorName,
          'action': 'Deleted document: $deletedTitle',
          'time': Timestamp.now(),
          'scholarships_deleted':
              scholarshipsSnap.docs.length - failedScholarshipDeletes.length,
          'scholarships_failed': failedScholarshipDeletes.length,
          'admissions_deleted':
              admissionsSnap.docs.length - failedAdmissionDeletes.length,
          'admissions_failed': failedAdmissionDeletes.length,
          'placements_deleted':
              placementsSnap.docs.length - failedPlacementDeletes.length,
          'placements_failed': failedPlacementDeletes.length,
        });
      } catch (e) {
        print("⚠️ Failed to log action: $e");
      }
    } else if (collectionName == 'admissions') {
      // ✅ NEW: Handle admission deletion
      final docId = doc.id;

      // 1. Delete from information_bank if exists
      try {
        final ibDoc = await firestore.collection('information_bank').doc(docId).get();
        
        if (ibDoc.exists) {
          final ibData = ibDoc.data() as Map<String, dynamic>;
          
          // Delete from Pinecone
          _deleteFromPineconeInBackground(ibData, ibData['pinecone_namespace']);
          
          // Delete from information_bank
          await firestore.collection('information_bank').doc(docId).delete();
          print('✅ Deleted from information_bank');
        }
      } catch (e) {
        print('⚠️ Error deleting from information_bank: $e');
      }

      // 2. Delete from admissions collection
      await firestore.collection('admissions').doc(docId).delete();
      print('✅ Deleted from admissions');

      // Close dialogs and show feedback
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close confirmation or info modal

        SnackbarUtil.showSuccess(context, 'Admission deleted successfully');
      }

      // Log the action
      try {
        final logRef = firestore.collection('logs').doc();
        await logRef.set({
          'logId': logRef.id,
          'user': actorName,
          'action': 'Deleted admission: $deletedTitle',
          'time': Timestamp.now(),
        });
      } catch (e) {
        print("⚠️ Failed to log action: $e");
      }
    } else {
      // Handle other complex deletions
      throw Exception('Unsupported collection type for complex delete: $collectionName');
    }
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

// Improved Weaviate deletion with better error handling
void _deleteFromPineconeInBackground(
  Map<String, dynamic> docData,
  String? pineconeNamespace,
) async {
  try {
    final chunkIds = List<String>.from(docData['chunkIds'] ?? []);
    final apiKey =
        'pcsk_41xXt3_J3U7iPvCEojTLLfUwFhKuQXkFFnuYJu9qcio175Ne2dLNS8t3TTzRie2QmTNdLa';
    final indexHost =
        'https://oasp-assist-tpewr0x.svc.aped-4627-b74a.pinecone.io';

    final authHeader = {'Content-Type': 'application/json', 'Api-Key': apiKey};

    int successfulDeletes = 0;
    int failedDeletes = 0;

    if (chunkIds.isNotEmpty) {
      try {
        final deleteUrl = Uri.parse('$indexHost/vectors/delete');
        final body = jsonEncode({
          'ids': chunkIds,
          if (pineconeNamespace != null && pineconeNamespace.isNotEmpty)
            'namespace': pineconeNamespace,
        });

        final res = await http
            .post(deleteUrl, headers: authHeader, body: body)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          print("✅ Pinecone vectors deleted successfully");
          successfulDeletes = chunkIds.length;
        } else {
          print(
            "⚠️ Failed to delete Pinecone vectors: ${res.statusCode} - ${res.body}",
          );
          failedDeletes = chunkIds.length;
        }
      } catch (e) {
        print("❌ Error deleting vectors from Pinecone: $e");
        failedDeletes = chunkIds.length;
      }
    } else {
      print("ℹ️ No chunk IDs provided for deletion");
    }

    // Summary log
    print("📊 Pinecone cleanup summary:");
    print("   - Vectors attempted: ${chunkIds.length}");
    print("   - Vectors successfully deleted: $successfulDeletes");
    print("   - Vectors failed to delete: $failedDeletes");
  } catch (e) {
    print("❌ Pinecone background deletion failed: $e");
  }
}
