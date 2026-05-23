import 'package:capstone_project/modules/admin/services/admission/add_edit_admission.dart';
import 'package:capstone_project/modules/admin/services/placement/add_edit_placement.dart';
import 'package:capstone_project/modules/admin/services/scholarship/add_edit_scholarship.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../information_bank/ib_add.dart';

class UploadDocumentButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onUploadComplete;
  final String? formType; // 'admission', 'scholarship', 'placement', or null for general upload

  const UploadDocumentButton({
    Key? key, 
    this.onPressed, 
    this.onUploadComplete,
    this.formType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        // Using the same breakpoints as ResponsiveLayout
        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        // Responsive dimensions
        double height = isMobile ? 40 : (isTablet ? 46 : 48);
        double fontSize = isMobile ? 12 : (isTablet ? 14 : 15);
        double horizontalPadding = isMobile ? 12 : (isTablet ? 18 : 20);
        double iconSize = isMobile ? 16 : (isTablet ? 20 : 22);
        double borderRadius = 8;

        // Text for different screen sizes
        String buttonText = isMobile ? 'Upload' : 'Upload New Document';

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: isMobile ? 3 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
           borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed ?? () => _showOptionsModal(context),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: iconSize,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

   void _showOptionsModal(BuildContext context) {
    HapticFeedback.mediumImpact();

    if (formType != null) {
      // Show specific form dialog
      _showFormDialog(context, formType!);
    } else {
      // Show the general upload document modal
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (BuildContext context) {
          return const UploadDocumentModal();
        },
      ).then((result) {
        if (result == true && onUploadComplete != null) {
          onUploadComplete!();
        }
      });
    }
  }

    void _showFormDialog(BuildContext context, String type) {
    Widget dialog;
    
    switch (type) {
      case 'admission':
        dialog = AdmissionFormDialog(isEdit: false);
        break;
      case 'scholarship':
        dialog = ScholarshipFormDialog(isEdit: false);
        break;
      case 'placement':
        dialog = PlacementFormDialog(isEdit: false);
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) => dialog,
    ).then((result) {
      if (result == true && onUploadComplete != null) {
        onUploadComplete!();
      }
    });
  }
}

// Alternative compact version for tight spaces
class CompactUploadButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onUploadComplete;

  const CompactUploadButton({Key? key, this.onPressed, this.onUploadComplete})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed ?? () => _showUploadDocumentModal(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.cloud_upload_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadDocumentModal(BuildContext context) {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        // Use UploadDocumentModal instead of UploadDocumentContent
        return const UploadDocumentModal();
      },
    ).then((result) {
      // Call the callback if upload was successful
      if (result == true && onUploadComplete != null) {
        onUploadComplete!();
      }
    });
  }
}

// Floating Action Button version
class UploadDocumentFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onUploadComplete;

  const UploadDocumentFAB({Key? key, this.onPressed, this.onUploadComplete})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed ?? () => _showUploadDocumentModal(context),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      icon: Icon(Icons.cloud_upload_outlined),
      label: Text(
        'Upload Document',
        style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
      elevation: 4,
      hoverElevation: 8,
    );
  }

  void _showUploadDocumentModal(BuildContext context) {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        // Use UploadDocumentModal instead of UploadDocumentContent
        return const UploadDocumentModal();
      },
    ).then((result) {
      // Call the callback if upload was successful
      if (result == true && onUploadComplete != null) {
        onUploadComplete!();
      }
    });
  }
}