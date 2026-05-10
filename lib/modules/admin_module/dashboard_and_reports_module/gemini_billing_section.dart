// gemini_billing_section.dart
import 'package:flutter/material.dart';
import 'gemini_billing_service.dart';

class GeminiBillingSection extends StatefulWidget {
  final String timeFrame;
  final DateTimeRange? customDateRange;
  const GeminiBillingSection({
    super.key,
    required this.timeFrame,
    this.customDateRange,
  });

  @override
  State<GeminiBillingSection> createState() => _GeminiBillingSectionState();
}

class _GeminiBillingSectionState extends State<GeminiBillingSection> {
  GeminiBillingSummary? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await fetchGeminiBillingFromFirestore(
        timeFrame: widget.timeFrame,
        customDateRange: widget.customDateRange,
      );
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void didUpdateWidget(GeminiBillingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeFrame != widget.timeFrame ||
        oldWidget.customDateRange != widget.customDateRange) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemini API Billing',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    Text(
                      kShowPhp ? 'Costs shown in PHP' : 'Costs shown in USD',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!_loading)
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A73E8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading)
          const _BillingSkeleton()
        else if (_error != null)
          _BillingError(error: _error!, onRetry: _load)
        else if (_data == null)
          const _BillingEmpty()
        else
          _BillingBody(
            data: _data!,
            isMobile: isMobile,
            timeFrame: widget.timeFrame,
            customDateRange: widget.customDateRange,
          ),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────

// Pass timeFrame into _BillingBody
class _BillingBody extends StatelessWidget {
  final GeminiBillingSummary data;
  final bool isMobile;
  final String timeFrame; // ADD
  final DateTimeRange? customDateRange; // ADD
  const _BillingBody({
    required this.data,
    required this.isMobile,
    required this.timeFrame,
    this.customDateRange,
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
    return Column(
      children: [
        // ── 2 stat cards ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _BillingStatCard(
                label: 'Total Cost',
                value: data.formattedTotalCost,
                sub: '${formatTokenCount(data.totalTokens)} tokens',
                icon: Icons.attach_money,
                color: const Color(0xFF1A73E8),
              ),
            ),
            SizedBox(width: isMobile ? 12 : 20),
            Expanded(
              child: _BillingStatCard(
                label: 'Input Tokens',
                value: formatTokenCount(data.totalInputTokens),
                sub: 'for ${_periodLabel(timeFrame, customDateRange)}',
                icon: Icons.login,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 20),
            Expanded(
              child: _BillingStatCard(
                label: 'Output Tokens',
                value: formatTokenCount(data.totalOutputTokens),
                sub: 'for ${_periodLabel(timeFrame, customDateRange)}',
                icon: Icons.logout,
                color: Colors.purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Daily trend + Model side by side ──────────────────
        isMobile
            ? Column(
              children: [
                SizedBox(
                  height: 280,
                  child: _DailyTrendCard(
                    trend: data.dailyTrend,
                    timeFrame: timeFrame,
                    customDateRange: customDateRange,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: _ModelCard(models: data.byModel, timeFrame: timeFrame),
                ),
              ],
            )
            : SizedBox(
              height: 320,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _DailyTrendCard(
                      trend: data.dailyTrend,
                      timeFrame: timeFrame,
                      customDateRange: customDateRange,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _ModelCard(
                      models: data.byModel,
                      timeFrame: timeFrame,
                    ),
                  ),
                ],
              ),
            ),
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
    return switch (widget.timeFrame) {
      'Today' => 'Hourly breakdown',
      'This Week' => 'Last 7 days',
      'This Month' => '${widget.trend.length} days this month',
      'This Year' => '${widget.trend.length} days this year',
      'All' => 'All recorded days',
      'Custom' => () {
        final r = widget.customDateRange;
        if (r == null) return '${widget.trend.length} days';
        return '${r.end.difference(r.start).inDays + 1} days selected';
      }(),
      _ => '${widget.trend.length} days',
    };
  }

  String _barLabel(String date, int index) {
    switch (widget.timeFrame) {
      case 'This Week':
        // Show Mon/Tue/etc
        try {
          final dt = DateTime.parse(date);
          return ['M', 'T', 'W', 'Th', 'F', 'S', 'Su'][dt.weekday - 1];
        } catch (_) {
          return date.substring(8);
        }

      case 'Today':
  if (index % 3 != 0) return '';
  if (index == 0) return '12am';
  if (index == 12) return '12pm';
  final h = index % 12;
  final suffix = index < 12 ? 'am' : 'pm';
  return '$h$suffix';

      case 'This Month':
        // Group into 4 weeks
        final day = int.tryParse(date.substring(8)) ?? (index + 1);
        if (day == 1) return 'W1';
        if (day == 8) return 'W2';
        if (day == 15) return 'W3';
        if (day == 22) return 'W4';
        return '';

      case 'This Year':
        // Show Jan/Feb/etc — date = 'yyyy-MM-dd', use month part
        const months = [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D',
        ];
        try {
          final m = int.parse(date.substring(5, 7));
          return months[m - 1];
        } catch (_) {
          return '';
        }

      case 'All':
        // Show year, only on first of each year to avoid clutter
        try {
          final dt = DateTime.parse(date);
          return dt.month == 1 ? '${dt.year}'.substring(2) : '';
        } catch (_) {
          return '';
        }

      case 'Custom':
        final days =
            widget.customDateRange?.end
                .difference(widget.customDateRange!.start)
                .inDays ??
            0;
        if (days == 0) {
          // Single day → hourly
          final h = index % 12 == 0 ? 12 : index % 12;
          return '${h}${index < 12 ? 'a' : 'p'}';
        } else if (days <= 7) {
          try {
            final dt = DateTime.parse(date);
            return ['M', 'T', 'W', 'Th', 'F', 'S', 'Su'][dt.weekday - 1];
          } catch (_) {
            return date.substring(8);
          }
        } else if (days <= 31) {
          final day = int.tryParse(date.substring(8)) ?? (index + 1);
          return day % 5 == 1 ? '$day' : '';
        } else {
          try {
            final m = int.parse(date.substring(5, 7));
            const months = [
              'J',
              'F',
              'M',
              'A',
              'M',
              'J',
              'J',
              'A',
              'S',
              'O',
              'N',
              'D',
            ];
            return months[m - 1];
          } catch (_) {
            return '';
          }
        }

      default:
        return date.length >= 10 ? date.substring(8) : date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final today = _dateStr(DateTime.now());
    final values =
        widget.trend
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
                widget.trend.isEmpty
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
                          children: List.generate(widget.trend.length, (i) {
                            final d = widget.trend[i];
                            final val =
                                _mode == 'cost'
                                    ? d.costUsd
                                    : d.tokens.toDouble();
                            final ratio = maxVal > 0 ? val / maxVal : 0.0;
                            final barH = (ratio * (box.maxHeight - 24)).clamp(
                              2.0,
                              box.maxHeight - 24,
                            );
                            final isToday = d.date == today;

                            return Expanded(
                              child: Tooltip(
                                message:
                                    '${d.date}\n${_mode == 'cost' ? d.formattedCost : '${formatTokenCount(d.tokens)} tokens'}',
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
                                            isToday
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
                                    if (widget.trend.length <= 16)
                                      Text(
                                        _barLabel(d.date, i),
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
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
