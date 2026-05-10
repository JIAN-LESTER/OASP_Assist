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

// ── Firestore query ───────────────────────────────────────────────

Future<GeminiBillingSummary> fetchGeminiBillingFromFirestore({
  required String timeFrame,
  DateTimeRange? customDateRange,
}) async {
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

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';