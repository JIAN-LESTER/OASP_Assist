import 'package:flutter/material.dart';

Widget buildEmptyState(bool isLoading, bool isMobileOrTablet, String item, ) {
  final titleCaseItem = _toTitleCase(item);

  if (isLoading) {
    return  Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          SizedBox(height: 16),
          Text(
            'Loading $titleCaseItem...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.history,
          size: isMobileOrTablet ? 48 : 64,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          'No $titleCaseItem Yet',
          style: TextStyle(
            fontSize: isMobileOrTablet ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$titleCaseItem will appear here once users interacts with the system.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobileOrTablet ? 14 : 16,
            color: Colors.grey[500],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Text(
            '$titleCaseItem will automatically appear here',
            style: TextStyle(
              fontSize: isMobileOrTablet ? 12 : 14,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildManagementEmptyState({
  required bool hasFilters,
  required bool isMobileOrTablet,
  required String item,
}) {
  final titleCaseItem = _toTitleCase(item);
  final title =
      hasFilters ? 'No $titleCaseItem Found' : 'No $titleCaseItem Yet';
  final message =
      hasFilters
          ? 'Try adjusting your search or filters.'
          : '$titleCaseItem will appear here once they are added.';

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasFilters ? Icons.search_off_rounded : Icons.inbox_rounded,
          size: isMobileOrTablet ? 48 : 64,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobileOrTablet ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobileOrTablet ? 14 : 16,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

String _toTitleCase(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
        if (word.toLowerCase() == 'faq' || word.toLowerCase() == 'faqs') {
          return word.toLowerCase() == 'faq' ? 'FAQ' : 'FAQs';
        }
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}
