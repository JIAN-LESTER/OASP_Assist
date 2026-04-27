import 'package:capstone_project/models/faq_candidate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'promote_faq.dart';

/// Drop this widget into whatever tab/section you add to FaqManagementPage.
class FaqCandidatesTab extends StatefulWidget {
  const FaqCandidatesTab({super.key});

  @override
  State<FaqCandidatesTab> createState() => _FaqCandidatesTabState();
}

class _FaqCandidatesTabState extends State<FaqCandidatesTab> {
  String _statusFilter = 'pending'; // 'pending' | 'promoted' | 'dismissed'
  String? _lastLoggedQueryKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterRow(),
        const SizedBox(height: 12),
        Expanded(child: _buildCandidateList()),
      ],
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    const filters = [
      ('pending', 'Pending', Color(0xFF2E7D32)),
      ('promoted', 'Promoted', Colors.blue),
      ('dismissed', 'Dismissed', Color(0xFF757575)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _statusFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isSelected,
              selectedColor: f.$3.withOpacity(0.15),
              checkmarkColor: f.$3,
              labelStyle: TextStyle(
                color: isSelected ? f.$3 : Colors.grey.shade700,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? f.$3 : Colors.grey.shade300,
              ),
              onSelected: (_) => setState(() => _statusFilter = f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Stream list ───────────────────────────────────────────────────────────

  Widget _buildCandidateList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _candidateStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          );
        }

        if (snapshot.hasError) {
          _logCandidateQueryError(snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final candidate =
                FAQCandidate.fromFirestore(docs[index]);
            return _CandidateCard(
              candidate: candidate,
              onTap: () => showPromoteFAQModal(context, candidate),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _candidateStream() {
    final queryKey = 'status=$_statusFilter|orderBy=occurrenceCount:desc';

    if (_lastLoggedQueryKey != queryKey) {
      _lastLoggedQueryKey = queryKey;
      debugPrint(
        '[FAQ Candidates] Firestore query -> '
        'collection=faq_candidates, '
        'where(status == $_statusFilter), '
        'orderBy(occurrenceCount desc)',
      );
      debugPrint(
        '[FAQ Candidates] Required composite index -> '
        'faq_candidates: status ASC, occurrenceCount DESC',
      );
    }

    return FirebaseFirestore.instance
        .collection('faq_candidates')
        .where('status', isEqualTo: _statusFilter)
        .orderBy('occurrenceCount', descending: true)
        .snapshots();
  }

  void _logCandidateQueryError(Object? error) {
    debugPrint('[FAQ Candidates] Query error: $error');

    if (error is FirebaseException) {
      debugPrint('[FAQ Candidates] Firebase code: ${error.code}');
      debugPrint('[FAQ Candidates] Firebase message: ${error.message}');

      final message = error.message ?? error.toString();
      final match = RegExp(r'https://console\.firebase\.google\.com/\S+')
          .firstMatch(message);

      if (match != null) {
        debugPrint('[FAQ Candidates] Create index URL: ${match.group(0)}');
      }
    }
  }

  Widget _buildEmptyState() {
    final messages = {
      'pending': (
        Icons.hourglass_empty_outlined,
        'No pending candidates',
        'Candidates appear here when a question reaches 10+ occurrences.',
      ),
      'promoted': (
        Icons.check_circle_outline,
        'No promoted candidates yet',
        'Questions you promote will appear here.',
      ),
      'dismissed': (
        Icons.block_outlined,
        'No dismissed candidates',
        'Dismissed candidates will appear here.',
      ),
    };

    final info = messages[_statusFilter]!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.$1, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            info.$2,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.$3,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Individual candidate card
// ============================================================================

class _CandidateCard extends StatelessWidget {
  final FAQCandidate candidate;
  final VoidCallback onTap;

  const _CandidateCard({required this.candidate, required this.onTap});

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Color get _statusColor {
    return switch (candidate.status) {
      'promoted' => Colors.blue,
      'dismissed' => Colors.grey,
      _ => const Color(0xFF2E7D32),
    };
  }

  String get _statusLabel {
    return switch (candidate.status) {
      'promoted' => 'Promoted',
      'dismissed' => 'Dismissed',
      _ => '${candidate.occurrenceCount} occurrences',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isPending = candidate.status == 'pending';

    return InkWell(
      onTap: isPending ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPending
                ? const Color(0xFFC8E6C9)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            if (isPending)
              BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Occurrence badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${candidate.occurrenceCount}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          candidate.question,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CategoryBadge(category: candidate.category),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    candidate.answer,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 12,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 11,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_formatDate(candidate.firstSeen)} – ${_formatDate(candidate.lastSeen)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      if (isPending) ...[
                        const Spacer(),
                        Text(
                          'Review →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  static const _colors = {
    'Admission': (Color(0xFFEFF6FF), Color(0xFF1D4ED8)),
    'Scholarship': (Color(0xFFFFFBEB), Color(0xFFB45309)),
    'Placement': (Color(0xFFF5F3FF), Color(0xFF6D28D9)),
    'General': (Color(0xFFF3F4F6), Color(0xFF374151)),
  };

  @override
  Widget build(BuildContext context) {
    final colors = _colors[category] ?? _colors['General']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: colors.$2,
        ),
      ),
    );
  }
}
