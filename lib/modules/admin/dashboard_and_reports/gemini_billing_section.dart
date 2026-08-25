// gemini_billing_section.dart
import 'package:flutter/material.dart';
import 'gemini_billing_service.dart';

class GeminiBillingSection extends StatefulWidget {
  final String timeFrame;
  final DateTimeRange? customDateRange;
  final ExternalToolsUsageSummary? initialData;
  final bool showHeader;
  final bool showReportDetails;
  const GeminiBillingSection({
    super.key,
    required this.timeFrame,
    this.customDateRange,
    this.initialData,
    this.showHeader = true,
    this.showReportDetails = false,
  });

  @override
  State<GeminiBillingSection> createState() => _GeminiBillingSectionState();
}

class _GeminiBillingSectionState extends State<GeminiBillingSection> {
  ExternalToolsUsageSummary? _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  @override
  void didUpdateWidget(GeminiBillingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData) {
      setState(() {
        _data = widget.initialData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF1A73E8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'External Tools Usage',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (_data == null)
          const _BillingEmpty()
        else
          _BillingBody(
            data: _data!,
            isMobile: isMobile,
            timeFrame: widget.timeFrame,
            customDateRange: widget.customDateRange,
            showReportDetails: widget.showReportDetails,
          ),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────

// Pass timeFrame into _BillingBody
class _BillingBody extends StatelessWidget {
  final ExternalToolsUsageSummary data;
  final bool isMobile;
  final String timeFrame; // ADD
  final DateTimeRange? customDateRange; // ADD
  final bool showReportDetails;
  const _BillingBody({
    required this.data,
    required this.isMobile,
    required this.timeFrame,
    this.customDateRange,
    required this.showReportDetails,
  });

  String _periodLabel(String timeFrame, DateTimeRange? range) {
    if (timeFrame == 'Custom' && range != null) {
      final s = range.start, e = range.end;
      return '${s.day}/${s.month} – ${e.day}/${e.month}';
    }
    return switch (timeFrame) {
      'Today' => 'today',
      'This Week' => 'this week',
      'This Month' => 'this month',
      'This Year' => 'this year',
      'All' => 'all time',
      _ => 'selected period',
    };
  }

  @override
  Widget build(BuildContext context) {
    final period = _periodLabel(timeFrame, customDateRange);

    return Column(
      children: [
        // ── 2 stat cards ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _BillingStatCard(
                label: 'Total Cost',
                value: data.formattedTotalCost,
                sub:
                    showReportDetails
                        ? '${formatTokenCount(data.gemini.totalTokens)} Gemini tokens'
                        : 'Firebase, LLM, Genkit, Pinecone',
                icon: Icons.attach_money,
                color: const Color(0xFF1A73E8),
              ),
            ),
            SizedBox(width: isMobile ? 12 : 20),
            Expanded(
              child: _BillingStatCard(
                label: showReportDetails ? 'Input Tokens' : 'Firebase Cost',
                value:
                    showReportDetails
                        ? formatTokenCount(data.gemini.totalInputTokens)
                        : formatBillingCost(data.firebaseTotalCostUsd),
                sub:
                    showReportDetails
                        ? 'for $period'
                        : '${data.totalReads} reads, ${data.totalWrites} writes',
                icon: showReportDetails ? Icons.login : Icons.storage_outlined,
                color: showReportDetails ? Colors.orange : Colors.teal,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 20),
            Expanded(
              child: _BillingStatCard(
                label: showReportDetails ? 'Output Tokens' : 'LLM Cost',
                value:
                    showReportDetails
                        ? formatTokenCount(data.gemini.totalOutputTokens)
                        : formatBillingCost(data.llmTotalCostUsd),
                sub: showReportDetails ? 'for $period' : 'Gemini API billing',
                icon: showReportDetails ? Icons.logout : Icons.psychology,
                color: Colors.purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (showReportDetails) ...[
          _ExternalToolsCard(tools: data.tools),
          const SizedBox(height: 20),
          _OperationCostCard(firebase: data.firebase),
        ],

        const SizedBox(height: 20),

        // ── Daily trend + Model side by side ──────────────────
        isMobile
            ? Column(
              children: [
                SizedBox(
                  height: 280,
                  child: _DailyTrendCard(
                    trend: data.gemini.dailyTrend,
                    timeFrame: timeFrame,
                    customDateRange: customDateRange,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child:
                      showReportDetails
                          ? _ModelCard(
                            models: data.gemini.byModel,
                            timeFrame: timeFrame,
                          )
                          : _FirebaseOpsTrendCard(
                            trend: data.firebase.trend,
                            showCosts: false,
                          ),
                ),
              ],
            )
            : SizedBox(
              height: 320,
              child: Row(
                children: [
                  Expanded(
                    child: _DailyTrendCard(
                      trend: data.gemini.dailyTrend,
                      timeFrame: timeFrame,
                      customDateRange: customDateRange,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child:
                        showReportDetails
                            ? _ModelCard(
                              models: data.gemini.byModel,
                              timeFrame: timeFrame,
                            )
                            : _FirebaseOpsTrendCard(
                              trend: data.firebase.trend,
                              showCosts: false,
                            ),
                  ),
                ],
              ),
            ),
        if (showReportDetails) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 320,
            child: _FirebaseOpsTrendCard(
              trend: data.firebase.trend,
              showCosts: true,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Stat card — mirrors buildStatCard from charts.dart ────────────

class _BillingStatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _BillingStatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;
    final padding = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);
    final iconSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
    final valueFontSize = isMobile ? 15.0 : (isTablet ? 17.0 : 19.0);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border(
          left: BorderSide(color: color, width: isMobile ? 3.0 : 4.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8.0 : 12.0),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10.0 : 12.0,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: isMobile ? 10.0 : 11.0,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily trend — matches buildSystemLogsCard container style ─────

class _ExternalToolsCard extends StatelessWidget {
  final List<ExternalToolStat> tools;

  const _ExternalToolsCard({required this.tools});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.hub_outlined,
                  color: Colors.teal[700],
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Text(
                  'Firebase, Genkit, and Pinecone',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 18),
          isMobile
              ? Column(
                children:
                    tools
                        .map(
                          (tool) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ExternalToolRow(tool: tool),
                          ),
                        )
                        .toList(),
              )
              : Row(
                children:
                    tools
                        .map(
                          (tool) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _ExternalToolRow(tool: tool),
                            ),
                          ),
                        )
                        .toList(),
              ),
        ],
      ),
    );
  }
}

class _ExternalToolRow extends StatelessWidget {
  final ExternalToolStat tool;

  const _ExternalToolRow({required this.tool});

  @override
  Widget build(BuildContext context) {
    final isFirebase = tool.name == 'Firebase';
    final detail =
        isFirebase
            ? '${tool.readCount} reads  ${tool.writeCount} writes  ${tool.deleteCount} deletes'
            : '${tool.usageCount} usage logs';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tool.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                tool.formattedCost,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A73E8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DailyTrendCard extends StatefulWidget {
  final List<GeminiDailyPoint> trend;
  final String timeFrame; // ADD
  final DateTimeRange? customDateRange; // ADD
  const _DailyTrendCard({
    required this.trend,
    required this.timeFrame,
    this.customDateRange,
  });
  @override
  State<_DailyTrendCard> createState() => _DailyTrendCardState();
}

class _DailyTrendCardState extends State<_DailyTrendCard> {
  String _mode = 'cost';

  String _trendSubtitle() {
    final buckets = _trendBars();
    return switch (widget.timeFrame) {
      'Today' => 'Hourly breakdown',
      'This Week' => 'Last 7 days',
      'This Month' => '${buckets.length} weeks this month',
      'This Year' => '${buckets.length} months this year',
      'All' => 'All recorded days',
      'Custom' => () {
        final r = widget.customDateRange;
        if (r == null) return '${widget.trend.length} days';
        return '${buckets.length} ${buckets.length == 1 ? 'period' : 'periods'} selected';
      }(),
      _ => '${widget.trend.length} days',
    };
  }

  List<_TrendBarPoint> _trendBars() {
    if (widget.timeFrame == 'Today') {
      final current = widget.trend.isEmpty ? null : widget.trend.first;
      final now = DateTime.now();
      return List.generate(24, (hour) {
        final valueCost =
            hour == now.hour && current != null ? current.costUsd : 0.0;
        final valueTokens =
            hour == now.hour && current != null ? current.tokens : 0;
        return _TrendBarPoint(
          label: _hourLabel(hour),
          tooltip: _hourLabel(hour),
          costUsd: valueCost,
          tokens: valueTokens,
          isToday: hour == now.hour,
        );
      });
    }

    if (widget.timeFrame == 'This Month') {
      return _bucketTrend((point) {
        final dt = DateTime.tryParse(point.date);
        if (dt == null) return 'Week 1';
        return 'Week ${((dt.day - 1) ~/ 7) + 1}';
      }, ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5']);
    }

    if (widget.timeFrame == 'This Year') {
      return _bucketTrend((point) {
        final dt = DateTime.tryParse(point.date);
        return dt == null ? point.date : _monthLabel(dt.month);
      }, List.generate(12, (i) => _monthLabel(i + 1)));
    }

    if (widget.timeFrame == 'Custom') {
      final range = widget.customDateRange;
      final days =
          range == null
              ? widget.trend.length
              : range.end.difference(range.start).inDays + 1;
      if (days > 365) {
        return _bucketTrend((point) {
          final dt = DateTime.tryParse(point.date);
          return dt == null ? point.date : '${dt.year}';
        }, null);
      }
      if (days > 31) {
        return _bucketTrend((point) {
          final dt = DateTime.tryParse(point.date);
          return dt == null ? point.date : '${_monthLabel(dt.month)} ${dt.year}';
        }, null);
      }
    }

    return widget.trend.map((point) {
      final dt = DateTime.tryParse(point.date);
      final label =
          widget.timeFrame == 'This Week' && dt != null
              ? _weekdayLabel(dt.weekday)
              : point.date.length >= 10
                  ? point.date.substring(8)
                  : point.date;
      return _TrendBarPoint(
        label: label,
        tooltip: label,
        costUsd: point.costUsd,
        tokens: point.tokens,
        isToday: point.date == _dateStr(DateTime.now()),
      );
    }).toList();
  }

  List<_TrendBarPoint> _bucketTrend(
    String Function(GeminiDailyPoint point) labelFor,
    List<String>? orderedLabels,
  ) {
    final buckets = <String, _TrendBarPoint>{};
    for (final label in orderedLabels ?? const <String>[]) {
      buckets[label] = _TrendBarPoint(label: label, tooltip: label);
    }

    for (final point in widget.trend) {
      final label = labelFor(point);
      final bucket = buckets.putIfAbsent(
        label,
        () => _TrendBarPoint(label: label, tooltip: label),
      );
      bucket.costUsd += point.costUsd;
      bucket.tokens += point.tokens;
      bucket.isToday = bucket.isToday || point.date == _dateStr(DateTime.now());
    }

    return buckets.values.toList();
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12am';
    if (hour == 12) return '12pm';
    return '${hour % 12}${hour < 12 ? 'am' : 'pm'}';
  }

  String _weekdayLabel(int weekday) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  }

  String _monthLabel(int month) {
    return [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final bars = widget.trend.isEmpty ? <_TrendBarPoint>[] : _trendBars();
    final values =
        bars
            .map((d) => _mode == 'cost' ? d.costUsd : d.tokens.toDouble())
            .toList();
    final maxVal =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — same pattern as buildSystemLogsCard
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart,
                  color: const Color(0xFF1A73E8),
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Usage',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    Text(
                      _trendSubtitle(),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Toggle(
                      label: 'Cost',
                      active: _mode == 'cost',
                      onTap: () => setState(() => _mode = 'cost'),
                    ),
                    _Toggle(
                      label: 'Tokens',
                      active: _mode == 'tokens',
                      onTap: () => setState(() => _mode = 'tokens'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 20),

          Expanded(
            child:
                bars.isEmpty
                    ? Center(
                      child: Text(
                        'No usage data yet',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                    
                    : LayoutBuilder(
                      builder: (ctx, box) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            bars.length,
                            (i) {
                              final d = bars[i];
                              final val = _mode == 'cost'
                                  ? d.costUsd
                                  : d.tokens.toDouble();

                              final ratio = maxVal > 0 ? val / maxVal : 0.0;
                              final barH = (ratio * (box.maxHeight - 28)).clamp(
                                2.0,
                                box.maxHeight - 28,
                              );

                              return Expanded(
                                child: Tooltip(
                                  message:
                                      '${d.tooltip}\n'
                                      '${_mode == 'cost' ? formatBillingCost(d.costUsd) : '${formatTokenCount(d.tokens)} tokens'}',
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        height: barH,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              d.isToday
                                                  ? Colors.deepOrange
                                                  : const Color(
                                                    0xFF1A73E8,
                                                  ).withOpacity(0.72),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(3),
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 16,
                                        child:
                                            d.label.isNotEmpty
                                                ? Text(
                                                  d.label,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.grey[500],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                )
                                                : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),

          if (widget.trend.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(
                  color: const Color(0xFF1A73E8),
                  label: 'Previous days',
                ),
                const SizedBox(width: 12),
                _LegendDot(color: Colors.deepOrange, label: 'Today'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Model breakdown ───────────────────────────────────────────────

class _TrendBarPoint {
  final String label;
  final String tooltip;
  double costUsd;
  int tokens;
  bool isToday;

  _TrendBarPoint({
    required this.label,
    required this.tooltip,
    this.costUsd = 0,
    this.tokens = 0,
    this.isToday = false,
  });
}

class _OperationCostCard extends StatelessWidget {
  final FirebaseUsageSummary firebase;

  const _OperationCostCard({required this.firebase});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final items = [
      _OperationCostItem(
        label: 'Read',
        count: firebase.stat.readCount,
        cost: firebase.readCostUsd,
        color: const Color(0xFF1A73E8),
        icon: Icons.visibility_outlined,
      ),
      _OperationCostItem(
        label: 'Write',
        count: firebase.stat.writeCount,
        cost: firebase.writeCostUsd,
        color: Colors.teal,
        icon: Icons.edit_outlined,
      ),
      _OperationCostItem(
        label: 'Delete',
        count: firebase.stat.deleteCount,
        cost: firebase.deleteCostUsd,
        color: Colors.redAccent,
        icon: Icons.delete_outline,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cost by Operation',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: isMobile ? 14 : 18),
          isMobile
              ? Column(
                children:
                    items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: item,
                          ),
                        )
                        .toList(),
              )
              : Row(
                children:
                    items
                        .map(
                          (item) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: item,
                            ),
                          ),
                        )
                        .toList(),
              ),
        ],
      ),
    );
  }
}

class _OperationCostItem extends StatelessWidget {
  final String label;
  final int count;
  final double cost;
  final Color color;
  final IconData icon;

  const _OperationCostItem({
    required this.label,
    required this.count,
    required this.cost,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
                Text(
                  '${formatTokenCount(count)} ops',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            formatBillingCost(cost),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FirebaseOpsTrendCard extends StatelessWidget {
  final List<FirebaseOperationPoint> trend;
  final bool showCosts;

  const _FirebaseOpsTrendCard({required this.trend, required this.showCosts});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final values =
        trend
            .expand(
              (point) =>
                  showCosts
                      ? [
                        point.readCostUsd,
                        point.writeCostUsd,
                        point.deleteCostUsd,
                      ]
                      : [
                        point.reads.toDouble(),
                        point.writes.toDouble(),
                        point.deletes.toDouble(),
                      ],
            )
            .toList();
    final maxVal =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.stacked_bar_chart,
                  color: Colors.teal[700],
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firebase Operations Over Time',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    Text(
                      showCosts
                          ? 'Read, write, delete costs'
                          : 'Reads, writes, deletes',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 20),
          Expanded(
            child:
                trend.isEmpty
                    ? Center(
                      child: Text(
                        'No Firebase usage data yet',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                    : LayoutBuilder(
                      builder: (context, box) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children:
                              trend.map((point) {
                                final read =
                                    showCosts
                                        ? point.readCostUsd
                                        : point.reads.toDouble();
                                final write =
                                    showCosts
                                        ? point.writeCostUsd
                                        : point.writes.toDouble();
                                final delete =
                                    showCosts
                                        ? point.deleteCostUsd
                                        : point.deletes.toDouble();
                                return Expanded(
                                  child: Tooltip(
                                    message:
                                        '${point.label}\n'
                                        'Read: ${point.reads} (${formatBillingCost(point.readCostUsd)})\n'
                                        'Write: ${point.writes} (${formatBillingCost(point.writeCostUsd)})\n'
                                        'Delete: ${point.deletes} (${formatBillingCost(point.deleteCostUsd)})',
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _OpsBar(
                                                value: read,
                                                maxValue: maxVal,
                                                maxHeight: box.maxHeight - 28,
                                                color: const Color(0xFF1A73E8),
                                              ),
                                              _OpsBar(
                                                value: write,
                                                maxValue: maxVal,
                                                maxHeight: box.maxHeight - 28,
                                                color: Colors.teal,
                                              ),
                                              _OpsBar(
                                                value: delete,
                                                maxValue: maxVal,
                                                maxHeight: box.maxHeight - 28,
                                                color: Colors.redAccent,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 16,
                                          child: Text(
                                            point.label,
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.grey[500],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF1A73E8), label: 'Read'),
              SizedBox(width: 12),
              _LegendDot(color: Colors.teal, label: 'Write'),
              SizedBox(width: 12),
              _LegendDot(color: Colors.redAccent, label: 'Delete'),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpsBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final double maxHeight;
  final Color color;

  const _OpsBar({
    required this.value,
    required this.maxValue,
    required this.maxHeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? value / maxValue : 0.0;
    final height =
        value <= 0
            ? 2.0
            : (ratio * maxHeight).clamp(2.0, maxHeight).toDouble();

    return Container(
      width: 5,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.72),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final List<GeminiModelStat> models;
  final String timeFrame; // ADD
  const _ModelCard({required this.models, required this.timeFrame});

  String _modelPeriodLabel(String tf) => switch (tf) {
    'Today' => 'today',
    'This Week' => 'this week',
    'This Month' => 'this month',
    'This Year' => 'this year',
    'All' => 'all time',
    _ => 'selected range',
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final maxCost = models.isEmpty ? 1.0 : models.first.costUsd;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.purple[700],
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cost by Model',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  Text(
                    '${models.length} model${models.length == 1 ? '' : 's'} · ${_modelPeriodLabel(timeFrame)}',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 20),
          models.isEmpty
              ? Expanded(
                child: Center(
                  child: Text(
                    'No data',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              )
              : Expanded(
                child: ListView.separated(
                  itemCount: models.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final m = models[i];
                    final ratio = maxCost > 0 ? m.costUsd / maxCost : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                m.model,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              m.formattedCost,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A73E8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '↑ ${formatTokenCount(m.inputTokens)} in  ↓ ${formatTokenCount(m.outputTokens)} out',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: Colors.grey[100],
                            color: const Color(0xFF1A73E8).withOpacity(0.7),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

// ── Top conversations ─────────────────────────────────────────────

// ── Shared small widgets ──────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Toggle({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1A73E8) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : Colors.grey[500],
        ),
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ],
  );
}

// ── States ────────────────────────────────────────────────────────

class _BillingSkeleton extends StatelessWidget {
  const _BillingSkeleton();
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Column(
      children: [
        isMobile
            ? Column(
              children: [
                Row(
                  children: List.generate(
                    2,
                    (_) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    2,
                    (_) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
            : Row(
              children: List.generate(
                4,
                (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 20),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            2,
            (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _BillingError({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.red[50],
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: Colors.red, width: 4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            error,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _BillingEmpty extends StatelessWidget {
  const _BillingEmpty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long, size: 44, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            'No billing data yet',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Usage will appear once the chatbot is used',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    ),
  );
}
