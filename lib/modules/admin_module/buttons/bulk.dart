import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simplified bulk operations widget - Delete only
class BulkDeleteBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onBulkDelete;
  final bool isAllSelected;
  final String itemType;

  const BulkDeleteBar({
    super.key,
    required this.selectedCount,
    required this.onToggleSelectAll,
    required this.onBulkDelete,
    required this.isAllSelected,
    required this.itemType,
  });

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color darkGreen = Color(0xFF14532D);
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color borderGreen = Color(0xFFC8E6C9);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color softRed = Color(0xFFFFF1F2);
  static const Color borderRed = Color(0xFFFECACA);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGreen, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Text(
              '$selectedCount $itemType selected',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),

          TextButton.icon(
            onPressed: onToggleSelectAll,
            icon: Icon(
              isAllSelected ? Icons.deselect : Icons.select_all,
              color: primaryGreen,
              size: 18,
            ),
            label: Text(
              isAllSelected ? 'Unselect All' : 'Select All',
              style: const TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              backgroundColor: softGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: borderGreen),
              ),
            ),
          ),

          const SizedBox(width: 8),

          TextButton.icon(
            onPressed: onBulkDelete,
            icon: const Icon(Icons.delete_outline, color: dangerRed, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(color: dangerRed, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: softRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: borderRed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mixin for bulk selection - simplified for delete only
mixin BulkSelectionMixin<T extends StatefulWidget> on State<T> {
  final Set<String> selectedIds = {};
  bool get isSelectionMode => selectedIds.isNotEmpty;

  void toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void toggleSelectAll(List<String> allIds) {
    setState(() {
      if (selectedIds.length == allIds.length) {
        // If all selected, unselect all
        selectedIds.clear();
      } else {
        // Otherwise, select all
        selectedIds.clear();
        selectedIds.addAll(allIds);
      }
    });
  }

  void clearSelection() {
    setState(() {
      selectedIds.clear();
    });
  }

  bool isSelected(String id) => selectedIds.contains(id);

  bool isAllSelected(List<String> allIds) =>
      selectedIds.length == allIds.length && allIds.isNotEmpty;
}

/// Bulk delete confirmation dialog using existing delete.dart design
Future<bool?> showBulkDeleteConfirmationDialog(
  BuildContext context,
  int count,
  String itemType,
) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Bulk Delete Confirmation',
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
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 24 : 32,
                  isMobile ? 32 : 40,
                  isMobile ? 24 : 32,
                  isMobile ? 16 : 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: const Color(0xFFC8E6C9),
                          width: 1.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF2E7D32),
                        size: 34,
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    Text(
                      'Delete $count $itemType?',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14532D),
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to delete $count $itemType? This action cannot be undone.',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                              side: const BorderSide(
                                color: Color(0xFFC8E6C9),
                                width: 1.2,
                              ),
                              backgroundColor: const Color(0xFFF8FAF8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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

/// Generic bulk delete handler
Future<void> handleBulkDelete({
  required BuildContext context,
  required Set<String> selectedIds,
  required String collection,
  required VoidCallback onSuccess,
  required String itemType,
  Future<void> Function(BuildContext, DocumentSnapshot)? customDeleteHandler,
}) async {
  if (selectedIds.isEmpty) return;

  final confirmed = await showBulkDeleteConfirmationDialog(
    context,
    selectedIds.length,
    itemType,
  );

  if (confirmed != true) return;

  // Show loading
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

  try {
    int successCount = 0;
    int failCount = 0;

    for (final id in selectedIds) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection(collection)
                .doc(id)
                .get();

        if (doc.exists) {
          if (customDeleteHandler != null) {
            await customDeleteHandler(context, doc);
          } else {
            await FirebaseFirestore.instance
                .collection(collection)
                .doc(id)
                .delete();
          }
          successCount++;
        }
      } catch (e) {
        print("Failed to delete document $id: $e");
        failCount++;
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $successCount $itemType'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $successCount $itemType, $failCount failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    onSuccess();
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
