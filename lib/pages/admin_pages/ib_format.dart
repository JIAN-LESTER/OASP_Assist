/// Add these functions to a shared utility file or at the top of your files
/// Smart content formatter that handles PDF vs non-PDF content differently

class ContentFormatter {
  /// Main formatting function - decides how to format based on source
  static String formatForDisplay(String content, String source) {
    // Check if it's from a PDF source
    if (_isPdfSource(source)) {
      return formatPdfContent(content);
    }
    
    // For non-PDF sources, return exactly as-is
    return content;
  }

  /// Check if the source indicates a PDF document
  static bool _isPdfSource(String source) {
    final lowercaseSource = source.toLowerCase();
    return lowercaseSource.endsWith('.pdf') || 
           lowercaseSource.contains('pdf');
  }

  /// Format PDF content with intelligent paragraph detection
  static String formatPdfContent(String content) {
    if (content.isEmpty) return content;

    // Step 1: Normalize line endings
    String cleaned = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Step 2: Identify and preserve intentional paragraph breaks
    // (two or more consecutive newlines)
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '<<<PARAGRAPH_BREAK>>>');

    // Step 3: Handle bullet points and numbered lists
    // Preserve line breaks before bullets/numbers
    cleaned = cleaned.replaceAll(
      RegExp(r'\n(?=[•\-\*\d+\.]\s)'),
      '<<<LIST_BREAK>>>',
    );

    // Step 4: Remove single line breaks within paragraphs
    cleaned = cleaned.replaceAll(RegExp(r'(?<!<<<PARAGRAPH_BREAK>>>)\n(?!<<<)'), ' ');

    // Step 5: Restore paragraph breaks
    cleaned = cleaned.replaceAll('<<<PARAGRAPH_BREAK>>>', '\n\n');
    cleaned = cleaned.replaceAll('<<<LIST_BREAK>>>', '\n');

    // Step 6: Clean up excessive spaces
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    // Step 7: Fix spacing around punctuation
    cleaned = cleaned.replaceAll(RegExp(r' +([.,;:!?])'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'([.,;:!?])([A-Za-z])'), r'$1 $2');

    // Step 8: Clean up whitespace at line starts/ends
    List<String> lines = cleaned.split('\n');
    lines = lines.map((line) => line.trim()).toList();
    
    // Step 9: Remove empty lines but keep intentional paragraph breaks
    List<String> result = [];
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].isNotEmpty) {
        result.add(lines[i]);
      } else if (i > 0 && i < lines.length - 1 && 
                 lines[i - 1].isNotEmpty && lines[i + 1].isNotEmpty) {
        // Keep empty line between non-empty lines (paragraph break)
        result.add('');
      }
    }

    return result.join('\n').trim();
  }

  /// Advanced PDF formatting with table detection
  static String formatPdfContentAdvanced(String content) {
    if (content.isEmpty) return content;

    String cleaned = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    
    List<String> lines = cleaned.split('\n');
    List<String> formattedLines = [];
    bool inTable = false;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      
      if (line.isEmpty) {
        // Empty line - potential paragraph break
        if (formattedLines.isNotEmpty && 
            formattedLines.last.isNotEmpty) {
          formattedLines.add(''); // Preserve paragraph break
        }
        inTable = false;
        continue;
      }

      // Detect table-like content (multiple spaces or tabs)
      if (RegExp(r'\s{3,}|\t{2,}').hasMatch(line)) {
        // Format as table row
        String tableRow = line.replaceAll(RegExp(r'\s{2,}|\t+'), ' | ');
        formattedLines.add(tableRow);
        inTable = true;
      } 
      // Detect list items
      else if (RegExp(r'^[•\-\*\d+\.]\s').hasMatch(line)) {
        formattedLines.add(line);
        inTable = false;
      }
      // Detect headers (short lines, often capitalized)
      else if (line.length < 60 && 
               RegExp(r'^[A-Z][A-Z\s]+$').hasMatch(line)) {
        if (formattedLines.isNotEmpty && formattedLines.last.isNotEmpty) {
          formattedLines.add(''); // Add space before header
        }
        formattedLines.add(line);
        formattedLines.add(''); // Add space after header
        inTable = false;
      }
      // Regular paragraph text
      else {
        if (inTable) {
          // Start new paragraph after table
          if (formattedLines.isNotEmpty) {
            formattedLines.add('');
          }
          inTable = false;
        }
        
        // Combine with previous line if it's a continuation
        if (formattedLines.isNotEmpty && 
            !formattedLines.last.isEmpty &&
            !formattedLines.last.endsWith('.') &&
            !formattedLines.last.endsWith('!') &&
            !formattedLines.last.endsWith('?') &&
            !formattedLines.last.endsWith(':')) {
          formattedLines[formattedLines.length - 1] += ' ' + line;
        } else {
          formattedLines.add(line);
        }
      }
    }

    // Clean up excessive spacing
    String result = formattedLines.join('\n');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    result = result.replaceAll(RegExp(r' {2,}'), ' ');
    
    return result.trim();
  }

  /// Get preview text (for list display)
  static String getPreviewText(String content, String source, {int maxLength = 100}) {
    String formatted = formatForDisplay(content, source);
    
    if (formatted.length <= maxLength) {
      return formatted;
    }
    
    // Find a good breaking point (end of sentence or word)
    int breakPoint = maxLength;
    
    // Try to break at sentence
    int lastPeriod = formatted.substring(0, maxLength).lastIndexOf('.');
    int lastQuestion = formatted.substring(0, maxLength).lastIndexOf('?');
    int lastExclamation = formatted.substring(0, maxLength).lastIndexOf('!');
    
    int sentenceEnd = [lastPeriod, lastQuestion, lastExclamation].reduce(
      (a, b) => a > b ? a : b
    );
    
    if (sentenceEnd > maxLength * 0.7) {
      breakPoint = sentenceEnd + 1;
    } else {
      // Break at word boundary
      int lastSpace = formatted.substring(0, maxLength).lastIndexOf(' ');
      if (lastSpace > maxLength * 0.8) {
        breakPoint = lastSpace;
      }
    }
    
    return formatted.substring(0, breakPoint).trim() + '...';
  }

  /// Format for editing (preserve original structure more)
  static String formatForEditing(String content, String source) {
    if (!_isPdfSource(source)) {
      return content; // Keep exactly as-is for non-PDF
    }
    
    // For PDFs, do minimal cleanup for editing
    String cleaned = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r' {3,}'), '  '); // Reduce excessive spaces but keep some
    
    return cleaned;
  }
}

/// Widget helper for displaying formatted content
class FormattedContentDisplay extends StatelessWidget {
  final String content;
  final String source;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const FormattedContentDisplay({
    Key? key,
    required this.content,
    required this.source,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedContent = ContentFormatter.formatForDisplay(
      content,
      source,
    );

    return Text(
      formattedContent,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// Widget for selectable formatted content (for modals)
class SelectableFormattedContent extends StatelessWidget {
  final String content;
  final String source;
  final TextStyle? style;

  const SelectableFormattedContent({
    Key? key,
    required this.content,
    required this.source,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedContent = ContentFormatter.formatForDisplay(
      content,
      source,
    );

    return SelectableText(
      formattedContent,
      style: style,
    );
  }
}