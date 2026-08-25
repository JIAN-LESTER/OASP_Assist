import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/models/faq_candidate.dart';
import 'package:capstone_project/widgets/empty_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'promote_faq.dart';

class FaqCandidatesTab extends StatefulWidget {
  const FaqCandidatesTab({super.key});

  @override
  State<FaqCandidatesTab> createState() => _FaqCandidatesTabState();
}

class _FaqCandidatesTabState extends State<FaqCandidatesTab> {
  String _statusFilter = 'pending';
  String? _lastLoggedQueryKey;
  final Map<String, Stream<QuerySnapshot>> _candidateStreams = {};

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterRow(),
        const SizedBox(height: 10),
        if (!isMobile) ...[_buildTableHeader(), const SizedBox(height: 6)],
        Expanded(child: _buildCandidateList()),
      ],
    );
  }

  Widget _buildFilterRow() {
    const filters = [
      ('pending', 'Pending', Color(0xFF2E7D32)),
      ('promoted', 'Promoted', Colors.blue),
      ('dismissed', 'Dismissed', Color(0xFF757575)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            filters.map((f) {
              final isSelected = _statusFilter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(f.$2),
                  selected: isSelected,
                  selectedColor: f.$3.withOpacity(0.15),
                  checkmarkColor: f.$3,
                  labelStyle: TextStyle(
                    color: isSelected ? f.$3 : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              'Count',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              'Question',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Answer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 40),
          Expanded(
            flex: 2,
            child: Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 108),
        ],
      ),
    );
  }

  Widget _buildCandidateList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _candidateStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          _logCandidateQueryError(snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final candidate = FAQCandidate.fromFirestore(docs[index]);
            return Padding(
              key: ValueKey(candidate.id),
              padding: const EdgeInsets.only(bottom: 6),
              child: _CandidateRow(
                candidate: candidate,
                index: index,
                onTap: () => showPromoteFAQModal(context, candidate),
              ),
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

    return _candidateStreams.putIfAbsent(
      _statusFilter,
      () =>
          FirebaseFirestore.instance
              .collection('faq_candidates')
              .where('status', isEqualTo: _statusFilter)
              .orderBy('occurrenceCount', descending: true)
              .snapshots(),
    );
  }

  void _logCandidateQueryError(Object? error) {
    debugPrint('[FAQ Candidates] Query error: $error');

    if (error is FirebaseException) {
      debugPrint('[FAQ Candidates] Firebase code: ${error.code}');
      debugPrint('[FAQ Candidates] Firebase message: ${error.message}');

      final message = error.message ?? error.toString();
      final match = RegExp(
        r'https://console\.firebase\.google\.com/\S+',
      ).firstMatch(message);

      if (match != null) {
        debugPrint('[FAQ Candidates] Create index URL: ${match.group(0)}');
      }
    }
  }

  Widget _buildEmptyState() {
    final item = switch (_statusFilter) {
      'promoted' => 'Promoted Candidates',
      'dismissed' => 'Dismissed Candidates',
      _ => 'FAQ Candidates',
    };

    return buildManagementEmptyState(
      hasFilters: false,
      isMobileOrTablet: MediaQuery.of(context).size.width < 900,
      item: item,
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final FAQCandidate candidate;
  final int index;
  final VoidCallback onTap;

  const _CandidateRow({
    required this.candidate,
    required this.index,
    required this.onTap,
  });

  String get _statusLabel {
    return switch (candidate.status) {
      'promoted' => 'Promoted',
      'dismissed' => 'Dismissed',
      _ => 'Review',
    };
  }

  Color get _statusColor {
    return switch (candidate.status) {
      'promoted' => Colors.blue,
      'dismissed' => Colors.grey,
      _ => const Color(0xFF2E7D32),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isPending = candidate.status == 'pending';

    return InkWell(
      onTap: isPending ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 12 : 8,
          horizontal: isMobile ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : const Color(0xFFF8FFFE),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: isMobile ? _buildMobileContent() : _buildDesktopContent(),
      ),
    );
  }

  Widget _buildDesktopContent() {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: _OccurrencePill(
            count: candidate.occurrenceCount,
            color: _statusColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            candidate.question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            candidate.answer,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _CategoryBadge(category: candidate.category),
          ),
        ),
        SizedBox(
          width: 108,
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildTrailingAction(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OccurrencePill(count: candidate.occurrenceCount, color: _statusColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.question,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                candidate.answer,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CategoryBadge(category: candidate.category),
                  const Spacer(),
                  _buildTrailingAction(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingAction() {
    if (candidate.status == 'pending') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Review',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
          SizedBox(width: 2),
          Icon(
            Icons.arrow_forward_rounded,
            size: 13,
            color: Color(0xFF2E7D32),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _statusColor,
        ),
      ),
    );
  }
}

class _OccurrencePill extends StatelessWidget {
  final int count;
  final Color color;

  const _OccurrencePill({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final categoryStyle = getCategoryStyle(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: categoryStyle.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        categoryStyle.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: categoryStyle.textColor,
        ),
      ),
    );
  }
}
