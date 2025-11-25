import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:capstone_project/services/admin_functions.dart'
    show FirebaseFunctionsService;
import 'package:capstone_project/utils/snackbar_util.dart';

class DeleteConfig {
  final String title;
  final String confirmationMessage;
  final String successMessage;
  final String titleField;
  final Color? headerColor;
  final IconData? icon;
  final bool isComplex;

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
        'Are you sure you want to delete this document? This action cannot be undone.',
    successMessage: 'Document deleted successfully',
    titleField: 'ib_title',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: true,
  );

  static const announcement = DeleteConfig(
    title: 'Delete Announcement',
    confirmationMessage:
        'Are you sure you want to delete this announcement? This action cannot be undone.',
    successMessage: 'Announcement deleted successfully',
    titleField: 'message',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const log = DeleteConfig(
    title: 'Delete Log',
    confirmationMessage:
        'Are you sure you want to delete this log entry? This action cannot be undone.',
    successMessage: 'Log deleted successfully',
    titleField: 'action',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const msgLog = DeleteConfig(
    title: 'Delete Message Log',
    confirmationMessage:
        'Are you sure you want to delete this message log entry? This action cannot be undone.',
    successMessage: 'Message Log deleted successfully',
    titleField: 'question',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const scholarships = DeleteConfig(
    title: 'Delete Scholarship',
    confirmationMessage:
        'Are you sure you want to delete this scholarship? This action cannot be undone.',
    successMessage: 'Scholarship deleted successfully',
    titleField: 'name',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const faqs = DeleteConfig(
    title: 'Delete FAQ',
    confirmationMessage:
        'Are you sure you want to delete this FAQ? This action cannot be undone.',
    successMessage: 'FAQ deleted successfully',
    titleField: 'question',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const admissions = DeleteConfig(
    title: 'Delete Admission',
    confirmationMessage:
        'Are you sure you want to delete this admission document? This action cannot be undone.',
    successMessage: 'Admission document deleted successfully',
    titleField: 'title',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: true,
  );

  static const affiliations = DeleteConfig(
    title: 'Delete Affiliation',
    confirmationMessage:
        'Are you sure you want to delete this affiliation? This action cannot be undone.',
    successMessage: 'Affiliation document deleted successfully',
    titleField: 'name',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const users = DeleteConfig(
    title: 'Delete User',
    confirmationMessage:
        'Are you sure you want to delete this user? This action cannot be undone.',
    successMessage: 'User deleted successfully',
    titleField: 'name',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );

  static const placements = DeleteConfig(
    title: 'Delete Company',
    confirmationMessage:
        'Are you sure you want to delete this company? This action cannot be undone.',
    successMessage: 'Company deleted successfully',
    titleField: 'partnerCompany',
    headerColor: Color(0xFFEF4444),
    icon: Icons.warning_amber_outlined,
    isComplex: false,
  );
}

// Reusable delete confirmation dialog with modern UI
void showDeleteConfirmation(
  BuildContext context,
  DocumentSnapshot doc,
  DeleteConfig config,
  String collection, {
  Future<void> Function(BuildContext, DocumentSnapshot)? customDeleteHandler,
  Set<String>? deletedItemsTracker,
}) {
  final data = doc.data() as Map<String, dynamic>;
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '${config.title} Confirmation',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 24 : 32,
                  isMobile ? 32 : 40,
                  isMobile ? 24 : 32,
                  isMobile ? 16 : 20,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
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
                        config.icon ?? Icons.warning_outlined,
                        color: config.headerColor ?? const Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    Text(
                      config.title,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: Column(
                  children: [
                    Text(
                      config.confirmationMessage,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Document Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${config.title.split(' ').last}:',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getDisplayTitle(data, config.titleField),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              color: const Color(0xFF111827),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(
                      context,
                      doc,
                      config,
                      collection,
                      isMobile,
                      customDeleteHandler: customDeleteHandler,
                      deletedItemsTracker: deletedItemsTracker,
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
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

Widget _buildActionButtons(
  BuildContext context,
  DocumentSnapshot doc,
  DeleteConfig config,
  String collection,
  bool isMobile, {
  Future<void> Function(BuildContext, DocumentSnapshot)? customDeleteHandler,
  Set<String>? deletedItemsTracker,
}) {
  double buttonHeight = 48;
  double fontSize = isMobile ? 15 : 16;
  double borderRadius = 8;

  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
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
                () => _handleReusableDelete(
                  context,
                  doc,
                  config,
                  collection,
                  customDeleteHandler: customDeleteHandler,
                  deletedItemsTracker: deletedItemsTracker,
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: config.headerColor ?? const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// Helper function to get display title
String _getDisplayTitle(Map<String, dynamic> data, String titleField) {
  String title = data[titleField]?.toString() ?? 'Untitled';
  if (titleField == 'message' && title.length > 80) {
    title = '${title.substring(0, 80)}...';
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
            child: CircularProgressIndicator(
              color: Color(0xFF2E7D32),
              strokeWidth: 3,
            ),
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

    final functionsService = FirebaseFunctionsService();
    
    try {
      print('🔄 Calling deleteUser Cloud Function for: ${doc.id}');
      await functionsService.deleteUserAuth(doc.id);
      print('✅ Cloud Function completed successfully');
    } catch (e) {
      print('❌ Cloud Function failed: $e');
      throw e; // Re-throw to be caught by outer try-catch
    }

    // Close dialogs and show success
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close confirmation dialog

      SnackbarUtil.showSuccess(
        context, 
        'User and all related data deleted successfully'
      );
    }

  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      // Show more specific error message
      String errorMessage = 'Delete failed: ';
      if (error.toString().contains('permission-denied')) {
        errorMessage += 'You do not have permission to delete users';
      } else if (error.toString().contains('unauthenticated')) {
        errorMessage += 'Please log in as an admin';
      } else if (error.toString().contains('not-found')) {
        errorMessage += 'User not found';
      } else {
        errorMessage += error.toString();
      }
      
      SnackbarUtil.showError(context, errorMessage);
    }
  }
}

Future<void> handleInformationBankDelete(
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
    String deletedTitle = docData['ib_title'] ?? docData['title'] ?? 'Unknown';

    // Get chunk IDs and Pinecone namespace
    final chunkIds = List<String>.from(docData['chunkIds'] ?? []);
    final pineconeNamespace = docData['pinecone_namespace'];

    final firestore = FirebaseFirestore.instance;

    // Delete related scholarships
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

    // Delete related admissions
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

    // Delete related placements
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

    // Delete vectors from Pinecone FIRST (before deleting Firestore doc)
    bool pineconeDeleteSuccess = true;
    if (chunkIds.isNotEmpty) {
      try {
        print("🗑️ Deleting ${chunkIds.length} vectors from Pinecone...");
        await _deleteFromPinecone(chunkIds, pineconeNamespace);
        print("✅ Pinecone vectors deleted successfully");
      } catch (e) {
        print("⚠️ Pinecone deletion failed: $e");
        pineconeDeleteSuccess = false;
        // Continue with Firestore deletion anyway
      }
    }

    // Delete the main information_bank document
    await firestore.collection('information_bank').doc(doc.id).delete();
    print("✅ Deleted information_bank document");

    // Close dialogs and show feedback
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close confirmation

      int totalFailures =
          failedScholarshipDeletes.length +
          failedAdmissionDeletes.length +
          failedPlacementDeletes.length;

      if (totalFailures == 0 && pineconeDeleteSuccess) {
        SnackbarUtil.showSuccess(context, 'Document deleted successfully');
      } else if (!pineconeDeleteSuccess) {
        SnackbarUtil.showWarning(
          context,
          'Document deleted, but Pinecone cleanup may have failed',
        );
      } else {
        SnackbarUtil.showWarning(
          context,
          'Document deleted ($totalFailures related items failed)',
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
        'admissions_deleted':
            admissionsSnap.docs.length - failedAdmissionDeletes.length,
        'placements_deleted':
            placementsSnap.docs.length - failedPlacementDeletes.length,
      });
    } catch (e) {
      print("⚠️ Failed to log action: $e");
    }
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

// ============================================================================
// FIXED: Admission Delete Handler
// ============================================================================
Future<void> handleAdmissionDelete(
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
    String deletedTitle = docData['title'] ?? 'Unknown';
    final docId = doc.id;
    final firestore = FirebaseFirestore.instance;

    // Check if there's a corresponding information_bank document
    final ibDoc =
        await firestore.collection('information_bank').doc(docId).get();

    if (ibDoc.exists) {
      final ibData = ibDoc.data() as Map<String, dynamic>;
      final chunkIds = List<String>.from(ibData['chunkIds'] ?? []);
      final pineconeNamespace = ibData['pinecone_namespace'];

      // Delete from Pinecone FIRST
      if (chunkIds.isNotEmpty) {
        try {
          print("🗑️ Deleting ${chunkIds.length} vectors from Pinecone...");
          await _deleteFromPinecone(chunkIds, pineconeNamespace);
          print("✅ Pinecone vectors deleted successfully");
        } catch (e) {
          print("⚠️ Pinecone deletion failed: $e");
          // Continue anyway
        }
      }

      // Delete from information_bank
      await firestore.collection('information_bank').doc(docId).delete();
      print('✅ Deleted from information_bank');
    }

    // Delete from admissions collection
    await firestore.collection('admissions').doc(docId).delete();
    print('✅ Deleted from admissions');

    // Close dialogs and show feedback
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading (from _handleReusableDelete)
      Navigator.of(context).pop(); // Close confirmation

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
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

// ============================================================================
// FIXED: Scholarship Delete Handler
// ============================================================================
Future<void> handleScholarshipDelete(
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
    String deletedTitle = docData['name'] ?? 'Unknown';
    final sourceId = docData['sourceId'];
    final firestore = FirebaseFirestore.instance;

    // Delete the scholarship
    await firestore.collection('scholarships').doc(doc.id).delete();
    print('✅ Deleted scholarship');

    // Check if we should also delete the source document
    // (Only if this is the last scholarship from that source)
    if (sourceId != null) {
      final remainingScholarships =
          await firestore
              .collection('scholarships')
              .where('sourceId', isEqualTo: sourceId)
              .get();

      if (remainingScholarships.docs.isEmpty) {
        // This was the last scholarship, check if we should delete the source
        final ibDoc =
            await firestore.collection('information_bank').doc(sourceId).get();

        if (ibDoc.exists) {
          final ibData = ibDoc.data() as Map<String, dynamic>;

          // Only delete if there are no other related documents
          final hasAdmissions =
              await firestore
                  .collection('admissions')
                  .where('sourceId', isEqualTo: sourceId)
                  .limit(1)
                  .get();

          final hasPlacements =
              await firestore
                  .collection('placements')
                  .where('sourceId', isEqualTo: sourceId)
                  .limit(1)
                  .get();

          if (hasAdmissions.docs.isEmpty && hasPlacements.docs.isEmpty) {
            final chunkIds = List<String>.from(ibData['chunkIds'] ?? []);
            final pineconeNamespace = ibData['pinecone_namespace'];

            // Delete from Pinecone FIRST
            if (chunkIds.isNotEmpty) {
              try {
                print(
                  "🗑️ Deleting ${chunkIds.length} orphaned vectors from Pinecone...",
                );
                await _deleteFromPinecone(chunkIds, pineconeNamespace);
                print("✅ Orphaned Pinecone vectors deleted");
              } catch (e) {
                print("⚠️ Failed to delete orphaned Pinecone vectors: $e");
                // Continue anyway
              }
            }

            // Delete the information_bank document
            await firestore
                .collection('information_bank')
                .doc(sourceId)
                .delete();
            print('✅ Deleted orphaned information_bank document');
          }
        }
      }
    }

    // Close dialogs and show feedback
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading (from _handleReusableDelete)
      Navigator.of(context).pop(); // Close confirmation

      SnackbarUtil.showSuccess(context, 'Scholarship deleted successfully');
    }

    // Log the action
    try {
      final logRef = firestore.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Deleted scholarship: $deletedTitle',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print("⚠️ Failed to log action: $e");
    }
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

// ============================================================================
// FIXED: Placement Delete Handler
// ============================================================================
Future<void> handlePlacementDelete(
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
    String deletedTitle = docData['partnerCompany'] ?? 'Unknown';
    final sourceId = docData['sourceId'];
    final firestore = FirebaseFirestore.instance;

    // Delete the placement
    await firestore.collection('placements').doc(doc.id).delete();
    print('✅ Deleted placement');

    // Check if we should also delete the source document
    if (sourceId != null) {
      final remainingPlacements =
          await firestore
              .collection('placements')
              .where('sourceId', isEqualTo: sourceId)
              .get();

      if (remainingPlacements.docs.isEmpty) {
        final ibDoc =
            await firestore.collection('information_bank').doc(sourceId).get();

        if (ibDoc.exists) {
          final ibData = ibDoc.data() as Map<String, dynamic>;

          // Only delete if there are no other related documents
          final hasAdmissions =
              await firestore
                  .collection('admissions')
                  .where('sourceId', isEqualTo: sourceId)
                  .limit(1)
                  .get();

          final hasScholarships =
              await firestore
                  .collection('scholarships')
                  .where('sourceId', isEqualTo: sourceId)
                  .limit(1)
                  .get();

          if (hasAdmissions.docs.isEmpty && hasScholarships.docs.isEmpty) {
            final chunkIds = List<String>.from(ibData['chunkIds'] ?? []);
            final pineconeNamespace = ibData['pinecone_namespace'];

            // Delete from Pinecone FIRST
            if (chunkIds.isNotEmpty) {
              try {
                print(
                  "🗑️ Deleting ${chunkIds.length} orphaned vectors from Pinecone...",
                );
                await _deleteFromPinecone(chunkIds, pineconeNamespace);
                print("✅ Orphaned Pinecone vectors deleted");
              } catch (e) {
                print("⚠️ Failed to delete orphaned Pinecone vectors: $e");
                // Continue anyway
              }
            }

            // Delete the information_bank document
            await firestore
                .collection('information_bank')
                .doc(sourceId)
                .delete();
            print('✅ Deleted orphaned information_bank document');
          }
        }
      }
    }

    // Close dialogs and show feedback
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading (from _handleReusableDelete)
      Navigator.of(context).pop(); // Close confirmation

      SnackbarUtil.showSuccess(context, 'Placement deleted successfully');
    }

    // Log the action
    try {
      final logRef = firestore.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Deleted placement: $deletedTitle',
        'time': Timestamp.now(),
      });
    } catch (e) {
      print("⚠️ Failed to log action: $e");
    }
  } catch (error) {
    print("❌ Delete operation failed: $error");

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}

// ============================================================================
// Pinecone Delete Functions
// ============================================================================
Future<void> _deleteFromPinecone(
  List<String> chunkIds,
  String? pineconeNamespace,
) async {
  try {
    // final apiKey = 'pcsk_41xXt3_J3U7iPvCEojTLLfUwFhKuQXkFFnuYJu9qcio175Ne2dLNS8t3TTzRie2QmTNdLa';
    // // final indexHost = 'https://oasp-assist-tpewr0x.svc.aped-4627-b74a.pinecone.io';
    final indexHost = 'https://oasp-assist-gemini-tpewr0x.svc.aped-4627-b74a.pinecone.io';
    final apiKey =
        'pcsk_41xXt3_J3U7iPvCEojTLLfUwFhKuQXkFFnuYJu9qcio175Ne2dLNS8t3TTzRie2QmTNdLa';
    // final indexHost =
    //     'https://oasp-assist-tpewr0x.svc.aped-4627-b74a.pinecone.io';

    final authHeader = {'Content-Type': 'application/json', 'Api-Key': apiKey};

    int successfulDeletes = 0;
    int failedDeletes = 0;

    if (chunkIds.isEmpty) {
      print("ℹ️ No chunk IDs provided for Pinecone deletion");
      return;
    }

    try {
      print(
        "🗑️ Attempting to delete ${chunkIds.length} vectors from Pinecone...",
      );

      final deleteUrl = Uri.parse('$indexHost/vectors/delete');
      final body = jsonEncode({
        'ids': chunkIds,
        if (pineconeNamespace != null && pineconeNamespace.isNotEmpty)
          'namespace': pineconeNamespace,
      });

      print("📤 Request body: $body");

      final res = await http
          .post(deleteUrl, headers: authHeader, body: body)
          .timeout(const Duration(seconds: 30));

      print("📥 Pinecone response status: ${res.statusCode}");
      print("📥 Pinecone response body: ${res.body}");

      if (res.statusCode == 200) {
        print("✅ Pinecone vectors deleted successfully");
        successfulDeletes = chunkIds.length;
      } else {
        print(
          "⚠️ Failed to delete Pinecone vectors: ${res.statusCode} - ${res.body}",
        );
        failedDeletes = chunkIds.length;
        throw Exception(
          "Pinecone deletion failed with status ${res.statusCode}",
        );
      }
    } catch (e) {
      print("❌ Error deleting vectors from Pinecone: $e");
      failedDeletes = chunkIds.length;
      rethrow; // Propagate error so caller knows deletion failed
    }

    print("📊 Pinecone cleanup summary:");
    print("   - Vectors attempted: ${chunkIds.length}");
    print("   - Successful: $successfulDeletes");
    print("   - Failed: $failedDeletes");
  } catch (e) {
    print("❌ Pinecone deletion failed: $e");
    rethrow;
  }
}

// Background version (fire and forget)
void _deleteFromPineconeInBackground(
  List<String> chunkIds,
  String? pineconeNamespace,
) {
  _deleteFromPinecone(chunkIds, pineconeNamespace).catchError((error) {
    print("❌ Background Pinecone deletion error: $error");
  });
}
