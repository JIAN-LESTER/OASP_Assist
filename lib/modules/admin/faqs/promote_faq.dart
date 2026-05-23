import 'package:capstone_project/models/faq_candidate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'faq_candidate_tab.dart';

// ---------------------------------------------------------------------------
// Entry point — call this from the FAQ Management page
// ---------------------------------------------------------------------------
void showPromoteFAQModal(BuildContext context, FAQCandidate candidate) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PromoteFAQModal(candidate: candidate),
  );
}

// ---------------------------------------------------------------------------
// Modal widget
// ---------------------------------------------------------------------------
class _PromoteFAQModal extends StatefulWidget {
  final FAQCandidate candidate;
  const _PromoteFAQModal({required this.candidate});

  @override
  State<_PromoteFAQModal> createState() => _PromoteFAQModalState();
}

class _PromoteFAQModalState extends State<_PromoteFAQModal> {
  late final TextEditingController _questionCtrl;
  late final TextEditingController _answerCtrl;
  late String _selectedCategory;

  bool _isPromoting = false;
  bool _isDismissing = false;

  static const _categories = [
    'General',
    'Admission',
    'Scholarship',
    'Placement',
  ];

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.candidate.question);
    _answerCtrl = TextEditingController(text: widget.candidate.answer);
    _selectedCategory = _categories.contains(widget.candidate.category)
        ? widget.candidate.category
        : 'General';
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  // ---- helpers ----

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _promote() async {
    final question = _questionCtrl.text.trim();
    final answer = _answerCtrl.text.trim();

    if (question.isEmpty || answer.isEmpty) {
      _showSnack('Question and answer cannot be empty.', isError: true);
      return;
    }

    setState(() => _isPromoting = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Write to faqs collection
      final faqRef = db.collection('faqs').doc();
      batch.set(faqRef, {
        'question': question,
        'answer': answer,
        'category': _selectedCategory,
        'isPredefined': false,
        'createdAt': Timestamp.now(),
        'embedding': widget.candidate.embedding,
        'geminiEmbedding': widget.candidate.embedding,
        'similarityCount': widget.candidate.occurrenceCount,
        'lastAsked': widget.candidate.lastSeen,
      });

      // 2. Mark candidate as promoted
      final candidateRef = db.collection('faq_candidates').doc(widget.candidate.id);
      batch.update(candidateRef, {
        'status': 'promoted',
        'promotedAt': Timestamp.now(),
        'promotedFaqId': faqRef.id,
      });

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        _showSnack('FAQ promoted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to promote FAQ: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPromoting = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _isDismissing = true);
    try {
      await FirebaseFirestore.instance
          .collection('faq_candidates')
          .doc(widget.candidate.id)
          .update({'status': 'dismissed', 'dismissedAt': Timestamp.now()});

      if (mounted) {
        Navigator.of(context).pop();
        _showSnack('Candidate dismissed.');
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to dismiss: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDismissing = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isBusy = _isPromoting || _isDismissing;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _Header(candidate: widget.candidate, formatDate: _formatDate),

            // ── Body ────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatsRow(candidate: widget.candidate, formatDate: _formatDate),
                    const SizedBox(height: 20),
                    _SectionLabel(icon: Icons.help_outline, label: 'Question'),
                    const SizedBox(height: 8),
                    _EditableField(
                      controller: _questionCtrl,
                      maxLines: 3,
                      enabled: !isBusy,
                      hint: 'Enter the FAQ question…',
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(icon: Icons.chat_bubble_outline, label: 'Answer'),
                    const SizedBox(height: 8),
                    _EditableField(
                      controller: _answerCtrl,
                      maxLines: 6,
                      enabled: !isBusy,
                      hint: 'Enter the FAQ answer…',
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(icon: Icons.label_outline, label: 'Category'),
                    const SizedBox(height: 8),
                    _CategoryDropdown(
                      value: _selectedCategory,
                      categories: _categories,
                      enabled: !isBusy,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            _Footer(
              isPromoting: _isPromoting,
              isDismissing: _isDismissing,
              onDismiss: _dismiss,
              onPromote: _promote,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Sub-widgets (private)
// ============================================================================

class _Header extends StatelessWidget {
  final FAQCandidate candidate;
  final String Function(Timestamp) formatDate;
  const _Header({required this.candidate, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promote FAQ Candidate',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Review and edit before publishing',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final FAQCandidate candidate;
  final String Function(Timestamp) formatDate;
  const _StatsRow({required this.candidate, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.repeat_rounded,
            label: 'Occurrences',
            value: '${candidate.occurrenceCount}',
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 16),
          _StatChip(
            icon: Icons.calendar_today_outlined,
            label: 'First seen',
            value: formatDate(candidate.firstSeen),
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 16),
          _StatChip(
            icon: Icons.schedule_outlined,
            label: 'Last seen',
            value: formatDate(candidate.lastSeen),
            color: Colors.blueGrey,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

class _EditableField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLines;
  final bool enabled;
  final String hint;
  const _EditableField({
    required this.controller,
    required this.maxLines,
    required this.enabled,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade800,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        contentPadding: const EdgeInsets.all(13),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<String> categories;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        ),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade800,
        ),
        items: categories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool isPromoting;
  final bool isDismissing;
  final VoidCallback onDismiss;
  final VoidCallback onPromote;
  const _Footer({
    required this.isPromoting,
    required this.isDismissing,
    required this.onDismiss,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = isPromoting || isDismissing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Dismiss button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : onDismiss,
              icon: isDismissing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD32F2F),
                      ),
                    )
                  : const Icon(Icons.block_outlined, size: 18),
              label: Text(isDismissing ? 'Dismissing…' : 'Dismiss'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F),
                side: BorderSide(
                  color: isBusy
                      ? Colors.grey.shade200
                      : const Color(0xFFD32F2F).withOpacity(0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Promote button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : onPromote,
              icon: isPromoting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text(isPromoting ? 'Promoting…' : 'Promote to FAQ'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isBusy ? Colors.grey.shade400 : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: isBusy ? 0 : 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}