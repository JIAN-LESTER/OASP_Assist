import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/export.dart';
import 'package:flutter/material.dart';

import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/admin_dashboard_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/user_demographics_data.dart';

class ExportButton extends StatelessWidget {
  final String pageType; // 'dashboard', 'inquiry', 'chatbot', 'demographics'
  final String timeFrame;
  final String? userName;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final AdminDashboardData? ad;

  const ExportButton({
    super.key,
    required this.pageType,
    required this.timeFrame,
    this.userName,
    this.inq,
    this.cb,
    this.ud,
    this.ad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Export',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey.shade700),
            ],
          ),
        ),
        onSelected: (value) => _handleExport(context, value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'pdf',
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Export as PDF',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'csv',
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.table_chart, color: Colors.green, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Export as CSV',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, String format) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Generating ${format.toUpperCase()} export...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few moments',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      String filePath;
      if (format == 'pdf') {
        filePath = await _exportToPDF();
      } else {
        filePath = await _exportToCSV();
      }

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show success message with file path
      if (context.mounted) {
        _showSuccessSnackBar(context, format, filePath);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        _showErrorSnackBar(context, e.toString());
      }
    }
  }

  void _showSuccessSnackBar(BuildContext context, String format, String filePath) {
    final fileName = filePath.split('/').last;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Successful',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Saved as ${format.toUpperCase()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      format == 'pdf' ? Icons.picture_as_pdf : Icons.table_chart,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Location: $filePath',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Export Failed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    error,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<String> _exportToPDF() async {
    switch (pageType) {
      case 'dashboard':
        return await ExportService.exportDashboardToPDF(
          userName: userName ?? 'Admin',
          timeFrame: timeFrame,
          inq: inq,
          ud: ud,
          ad: ad,
        );
      case 'inquiry':
        return await ExportService.exportInquiryTrendsToPDF(
          timeFrame: timeFrame,
          data: inq,
          ad: ad,
        );
      case 'chatbot':
        return await ExportService.exportChatbotUsageToPDF(
          timeFrame: timeFrame,
          data: cb,
        );
      case 'demographics':
        return await ExportService.exportUserDemographicsToPDF(
          timeFrame: timeFrame,
          data: ud,
        );
      default:
        throw Exception('Unknown page type');
    }
  }

  Future<String> _exportToCSV() async {
    switch (pageType) {
      case 'dashboard':
        return await ExportService.exportDashboardToCSV(
          timeFrame: timeFrame,
          inq: inq,
          ud: ud,
          ad: ad,
        );
      case 'inquiry':
        return await ExportService.exportInquiryTrendsToCSV(
          timeFrame: timeFrame,
          data: inq,
        );
      case 'chatbot':
        return await ExportService.exportChatbotUsageToCSV(
          timeFrame: timeFrame,
          data: cb,
        );
      case 'demographics':
        return await ExportService.exportUserDemographicsToCSV(
          timeFrame: timeFrame,
          data: ud,
        );
      default:
        throw Exception('Unknown page type');
    }
  }
}