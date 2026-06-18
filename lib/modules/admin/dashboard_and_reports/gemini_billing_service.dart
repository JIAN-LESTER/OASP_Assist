// gemini_billing_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Currency config ───────────────────────────────────────────────
const bool kShowPhp  = true;
const double kUsdToPhp = 56.0; // update as needed

String formatBillingCost(double usd) {
  final amount = kShowPhp ? usd * kUsdToPhp : usd;
  final symbol = kShowPhp ? '₱' : '\$';
  // Costs are tiny — show enough decimal places to be meaningful
  return '$symbol${amount.toStringAsFixed(kShowPhp ? 4 : 6)}';
}

String formatTokenCount(int tokens) {
  if (tokens >= 1_000_000) return '${(tokens / 1_000_000).toStringAsFixed(2)}M';
  if (tokens >= 1_000)     return '${(tokens / 1_000).toStringAsFixed(1)}K';
  return '$tokens';
}

// ── Data models ───────────────────────────────────────────────────

class GeminiDailyPoint {
  final String date;
  final double costUsd;
  final int tokens;
  GeminiDailyPoint({required this.date, required this.costUsd, required this.tokens});

  String get formattedCost => formatBillingCost(costUsd);
}

class GeminiModelStat {
  final String model;
  double costUsd;
  int inputTokens;
  int outputTokens;
  GeminiModelStat({required this.model, this.costUsd = 0, this.inputTokens = 0, this.outputTokens = 0});

  String get formattedCost => formatBillingCost(costUsd);
  int get totalTokens => inputTokens + outputTokens;
}


class GeminiBillingSummary {
  final double totalCostUsd;
  final int totalInputTokens;
  final int totalOutputTokens;
  final List<GeminiDailyPoint> dailyTrend;
  final List<GeminiModelStat> byModel;

  const GeminiBillingSummary({
    required this.totalCostUsd,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.dailyTrend,
    required this.byModel,
  });

  String get formattedTotalCost => formatBillingCost(totalCostUsd);
  int get totalTokens => totalInputTokens + totalOutputTokens;
}

class ExternalToolStat {
  final String name;
  double costUsd;
  int usageCount;
  int readCount;
  int writeCount;
  int deleteCount;

  ExternalToolStat({
    required this.name,
    this.costUsd = 0,
    this.usageCount = 0,
    this.readCount = 0,
    this.writeCount = 0,
    this.deleteCount = 0,
  });

  String get formattedCost => formatBillingCost(costUsd);
}

class ExternalToolsUsageSummary {
  final GeminiBillingSummary gemini;
  final List<ExternalToolStat> tools;

  const ExternalToolsUsageSummary({required this.gemini, required this.tools});

  double get totalCostUsd =>
      gemini.totalCostUsd + tools.fold(0.0, (sum, tool) => sum + tool.costUsd);
  int get totalUsage =>
      gemini.totalTokens + tools.fold(0, (sum, tool) => sum + tool.usageCount);
  int get totalReads => tools.fold(0, (sum, tool) => sum + tool.readCount);
  int get totalWrites => tools.fold(0, (sum, tool) => sum + tool.writeCount);
  int get totalDeletes => tools.fold(0, (sum, tool) => sum + tool.deleteCount);
  String get formattedTotalCost => formatBillingCost(totalCostUsd);
}

// ── Firestore query ───────────────────────────────────────────────

Future<ExternalToolsUsageSummary> fetchExternalToolsUsageFromFirestore({
  required String timeFrame,
  DateTimeRange? customDateRange,
}) async {
  final gemini = await fetchGeminiBillingFromFirestore(
    timeFrame: timeFrame,
    customDateRange: customDateRange,
  );
  final range = _resolveRange(timeFrame, customDateRange);

  final tools = await Future.wait([
    _fetchFirebaseUsage(range.start, range.end),
    _fetchUsageCollection('genkit_usage', 'Genkit', range.start, range.end),
    _fetchUsageCollection('pinecone_usage', 'Pinecone', range.start, range.end),
  ]);

  return ExternalToolsUsageSummary(gemini: gemini, tools: tools);
}

Future<GeminiBillingSummary> fetchGeminiBillingFromFirestore({
  required String timeFrame,
  DateTimeRange? customDateRange,
}) async {
  final range = _resolveRange(timeFrame, customDateRange);
  final rangeStart = range.start;
  final rangeEnd = range.end;

  final startStr = _dateStr(rangeStart);
  final endStr = _dateStr(rangeEnd);

  final snapshot = await FirebaseFirestore.instance
      .collection('gemini_usage')
      .where('date', isGreaterThanOrEqualTo: startStr)
      .where('date', isLessThanOrEqualTo: endStr)
      .orderBy('date', descending: false)
      .get();

  double totalCostUsd = 0;
  int totalIn = 0, totalOut = 0;

  final Map<String, GeminiModelStat> byModel = {};
  final Map<String, double> byDayCost = {};
  final Map<String, int> byDayTok = {};

  for (final doc in snapshot.docs) {
    final d = doc.data();
    final costUsd = (d['costUsd'] ?? 0).toDouble();
    final inTok = (d['inputTokens'] ?? 0) as int;
    final outTok = (d['outputTokens'] ?? 0) as int;
    final model = d['model'] as String? ?? 'unknown';
    final date = d['date'] as String? ?? '';

    totalCostUsd += costUsd;
    totalIn += inTok;
    totalOut += outTok;

    byModel.putIfAbsent(model, () => GeminiModelStat(model: model));
    byModel[model]!.costUsd += costUsd;
    byModel[model]!.inputTokens += inTok;
    byModel[model]!.outputTokens += outTok;

    byDayCost[date] = (byDayCost[date] ?? 0) + costUsd;
    byDayTok[date] = (byDayTok[date] ?? 0) + inTok + outTok;
  }

  // Build daily trend for the range
  final dailyTrend = <GeminiDailyPoint>[];
  final rangeDays = rangeEnd.difference(rangeStart).inDays + 1;
  for (int i = 0; i < rangeDays; i++) {
    final day = rangeStart.add(Duration(days: i));
    final dayStr = _dateStr(day);
    dailyTrend.add(GeminiDailyPoint(
      date: dayStr,
      costUsd: byDayCost[dayStr] ?? 0,
      tokens: byDayTok[dayStr] ?? 0,
    ));
  }

  final sortedModels = byModel.values.toList()
    ..sort((a, b) => b.costUsd.compareTo(a.costUsd));

  return GeminiBillingSummary(
    totalCostUsd: totalCostUsd,
    totalInputTokens: totalIn,
    totalOutputTokens: totalOut,
    dailyTrend: dailyTrend,
    byModel: sortedModels,
  );
}

Future<ExternalToolStat> _fetchUsageCollection(
  String collection,
  String name,
  DateTime start,
  DateTime end,
) async {
  final stat = ExternalToolStat(name: name);
  QuerySnapshot<Map<String, dynamic>> snapshot;
  try {
    snapshot = await FirebaseFirestore.instance.collection(collection).get();
  } catch (_) {
    return stat;
  }
  var matchedDocs = 0;

  for (final doc in snapshot.docs) {
    final d = doc.data();
    if (!_isUsageDocInRange(d, start, end)) continue;
    matchedDocs++;
    stat.costUsd += _numValue(d, ['costUsd', 'cost', 'billingCostUsd']);
    stat.usageCount += _intValue(d, ['usage', 'usageCount', 'requests', 'calls']);
    stat.readCount += _intValue(d, ['reads', 'readCount']);
    stat.writeCount += _intValue(d, ['writes', 'writeCount', 'upserts']);
    stat.deleteCount += _intValue(d, ['deletes', 'deleteCount']);
  }

  if (stat.usageCount == 0) stat.usageCount = matchedDocs;
  return stat;
}

Future<ExternalToolStat> _fetchFirebaseUsage(DateTime start, DateTime end) async {
  final stat = await _fetchUsageCollection('firebase_usage', 'Firebase', start, end);
  QuerySnapshot<Map<String, dynamic>> snapshot;
  try {
    snapshot = await FirebaseFirestore.instance
        .collection('logs')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('time', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
  } catch (_) {
    return stat;
  }

  for (final doc in snapshot.docs) {
    final d = doc.data();
    final action = (d['action'] ?? d['operation'] ?? d['type'] ?? '')
        .toString()
        .toLowerCase();

    if (action.contains('read') || action.contains('view')) stat.readCount++;
    if (action.contains('write') ||
        action.contains('create') ||
        action.contains('add') ||
        action.contains('update')) {
      stat.writeCount++;
    }
    if (action.contains('delete') || action.contains('remove')) stat.deleteCount++;
  }

  stat.usageCount += stat.readCount + stat.writeCount + stat.deleteCount;
  return stat;
}

class _BillingRange {
  final DateTime start;
  final DateTime end;

  const _BillingRange({required this.start, required this.end});
}

_BillingRange _resolveRange(
  String timeFrame,
  DateTimeRange? customDateRange,
) {
  final now = DateTime.now();
  DateTime rangeStart;
  DateTime rangeEnd = now;

  switch (timeFrame) {
    case 'Today':
      rangeStart = DateTime(now.year, now.month, now.day);
      break;
    case 'This Week':
      rangeStart = now.subtract(Duration(days: now.weekday - 1));
      rangeStart = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      break;
    case 'This Year':
      rangeStart = DateTime(now.year, 1, 1);
      break;
    case 'Custom':
      rangeStart = customDateRange?.start ?? DateTime(now.year, now.month, 1);
      rangeEnd = customDateRange?.end ?? now;
      break;
    case 'All':
      rangeStart = DateTime(2000, 1, 1);
      break;
    case 'This Month':
    default:
      rangeStart = DateTime(now.year, now.month, 1);
  }

  return _BillingRange(
    start: DateTime(rangeStart.year, rangeStart.month, rangeStart.day),
    end: DateTime(
      rangeEnd.year,
      rangeEnd.month,
      rangeEnd.day,
      23,
      59,
      59,
      999,
    ),
  );
}

double _numValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

int _intValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _isUsageDocInRange(Map<String, dynamic> data, DateTime start, DateTime end) {
  final value =
      data['time'] ?? data['createdAt'] ?? data['timestamp'] ?? data['date'];

  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  } else if (value != null) {
    date = DateTime.tryParse(value.toString());
  }

  if (date == null) return true;
  return !date.isBefore(start) && !date.isAfter(end);
}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String formatGeminiBottomTitle(String date, String timeFrame, DateTimeRange? customRange) {
  switch (timeFrame) {
    case 'Today':
      // date = 'yyyy-MM-dd', use index-based hour via _barLabel instead
      return date;
    case 'This Week':
      try {
        final dt = DateTime.parse(date);
        return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
      } catch (_) { return date; }
    case 'This Month':
      final day = int.tryParse(date.substring(8)) ?? 0;
      if (day == 1)  return 'W1';
      if (day == 8)  return 'W2';
      if (day == 15) return 'W3';
      if (day == 22) return 'W4';
      return '';
    case 'This Year':
      try {
        final m = int.parse(date.substring(5, 7));
        return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
      } catch (_) { return ''; }
    case 'All':
      try {
        final dt = DateTime.parse(date);
        return dt.month == 1 ? '${dt.year}' : '';
      } catch (_) { return ''; }
    case 'Custom':
      final days = customRange?.end.difference(customRange!.start).inDays ?? 0;
      if (days == 0) return date;
      if (days <= 7) {
        try {
          final dt = DateTime.parse(date);
          return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
        } catch (_) { return date.substring(8); }
      } else if (days <= 31) {
        final day = int.tryParse(date.substring(8)) ?? 0;
        return day % 5 == 1 ? '$day' : '';
      } else {
        try {
          final m = int.parse(date.substring(5, 7));
          return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
        } catch (_) { return ''; }
      }
    default:
      return date.length >= 10 ? date.substring(8) : date;
  }
}
