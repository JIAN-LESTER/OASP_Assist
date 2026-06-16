import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';

void showEditPlacementDialog(DocumentSnapshot doc, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final placementIdController = TextEditingController(text: data['placementID'] ?? '');
    final eventsController = TextEditingController(text: data['events'] ?? '');
    final partnerCompanyController = TextEditingController(text: data['partnerCompany'] ?? '');
    final placementProviderController = TextEditingController(text: data['placementProvider'] ?? '');
    final contactsController = TextEditingController(
      text: data['contacts'] is List 
        ? (data['contacts'] as List).join(', ') 
        : (data['contacts'] ?? '').toString()
    );
    
    DateTime selectedDeadline = data['deadline'] != null
        ? (data['deadline'] as Timestamp).toDate()
        : DateTime.now().add(Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Edit Placement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Form
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: buildTextField(
                                  isMobile: false,
                                  controller: placementIdController,
                                  label: 'Placement ID',
                                  hint: 'Enter Placement ID',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: buildTextField(
                                   isMobile: false,
                                  controller: partnerCompanyController,
                                  hint: 'Enter Partner Company',
                                  label: 'Partner Company',
                                  icon: Icons.business,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          buildTextField(
                             isMobile: false,
                            controller: placementProviderController,
                            label: 'Placement Provider',
                            hint: 'Enter Placement Provider',
                            icon: Icons.business_center,
                          ),
                          SizedBox(height: 16),
                          buildTextField(
                             isMobile: false,
                            controller: contactsController,
                            hint: 'Enter Contact ',
                            label: 'Contact Information',
                            icon: Icons.contact_phone,
                          ),
                          SizedBox(height: 16),
                          
                          // Deadline picker
                          Text(
                            'Application Deadline',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDeadline,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 365 * 2)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Color(0xFF10B981),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null && picked != selectedDeadline) {
                                setState(() {
                                  selectedDeadline = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.grey[500]),
                                  SizedBox(width: 12),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(selectedDeadline),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Spacer(),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          Text(
                            'Events & Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 200,
                            child: TextField(
                              controller: eventsController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: 'Enter placement events, requirements, and details...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF10B981)),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _savePlacement(
                                  doc,
                                  context,
                                  placementIdController,
                                  eventsController,
                                  partnerCompanyController,
                                  placementProviderController,
                                  contactsController,
                                  selectedDeadline,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('Save Changes'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _savePlacement(
    DocumentSnapshot doc,
    BuildContext context,
    TextEditingController placementIdController,
    TextEditingController eventsController,
    TextEditingController partnerCompanyController,
    TextEditingController placementProviderController,
    TextEditingController contactsController,
    DateTime deadline,
  ) async {
    try {
      // Parse contact field
      dynamic contactValue;
      String contactText = contactsController.text.trim();
      if (contactText.isNotEmpty) {
        if (contactText.contains(',')) {
          contactValue = contactText.split(',').map((e) => e.trim()).toList();
        } else {
          contactValue = contactText;
        }
      }

      unawaited(() async {
        try {
          await FirebaseFirestore.instance
              .collection('placements')
              .doc(doc.id)
              .update({
            'placementID': placementIdController.text,
            'events': eventsController.text,
            'partnerCompany': partnerCompanyController.text,
            'placementProvider': placementProviderController.text,
            'contacts': contactValue,
            'deadline': Timestamp.fromDate(deadline),
            'updated_at': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Placement updated successfully'),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Error updating placement: $e'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }());

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Placement update is running in background'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Error updating placement: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
