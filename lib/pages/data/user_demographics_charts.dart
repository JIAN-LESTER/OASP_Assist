import 'package:capstone_project/pages/data/charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';



Color _getScholarshipTypeColor(int index) {
  final colors = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];
  return colors[index % colors.length];
}

Color _getAffiliationColor(String affiliation) {
  switch (affiliation.toLowerCase()) {
    case 'user':
      return Colors.blue[600]!;
    case 'faculty':
      return Colors.green[600]!;
    case 'staff':
      return Colors.orange[600]!;
    case 'alumni':
      return Colors.purple[600]!;
    default:
      return Colors.grey[600]!;
  }
}



String _shortenAffiliation(String affiliation) {
  final words = affiliation.split(' ');
  if (words.length > 1) {
    return words.map((word) => word[0].toUpperCase()).join();
  }
  return affiliation.length > 8
      ? '${affiliation.substring(0, 8)}...'
      : affiliation;
}



Widget buildScholarshipTypesCard(Map<String, int> scholarshipTypes) {
  final filteredEntries = scholarshipTypes.entries
      .where((entry) => entry.value > 0)
      .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  
  return Container(
    padding: const EdgeInsets.all(16),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scholarship Types',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Distribution by scholarship categories',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredEntries.isEmpty
              ? Center(
                  child: Text(
                    'No scholarship type data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: filteredEntries.isNotEmpty 
                        ? filteredEntries.first.value.toDouble() + 5
                        : 10,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
           
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final type = filteredEntries[group.x.toInt()].key;
                          return BarTooltipItem(
                            '$type\n${rod.toY.round()} users',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < filteredEntries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  filteredEntries[value.toInt()].key,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: true),
                    barGroups: filteredEntries.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: _getScholarshipTypeColor(entry.key),
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    ),
  );
}

Widget buildUserAffiliationsCard(Map<String, int> userAffiliations) {
  return Container(
    padding: const EdgeInsets.all(16),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Affiliations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Distribution by affiliation type',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              userAffiliations.isEmpty
                  ? Center(
                    child: Text(
                      'No affiliation data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          userAffiliations.entries.map((entry) {
                            return PieChartSectionData(
                              color: _getAffiliationColor(entry.key),
                              value: entry.value.toDouble(),
                              title:
                                  '${_shortenAffiliation(entry.key)}\n${entry.value}',
                              radius: 70,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    ),
                  ),
        ),
        // Legend
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children:
              userAffiliations.keys.map((key) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getAffiliationColor(key),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      key,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                );
              }).toList(),
        ),
      ],
    ),
  );
}


Widget buildUsersByYearCard(Map<String, int> yearData) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Users by Year Level',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Students who sent messages',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              yearData.isEmpty
                  ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          yearData.values.isNotEmpty
                              ? yearData.values
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble() *
                                  1.2
                              : 10,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String year = yearData.keys.elementAt(
                              group.x.toInt(),
                            );
                            return BarTooltipItem(
                              '$year\n${rod.toY.round()} students',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget:
                                (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < yearData.length) {
                                String year = yearData.keys.elementAt(
                                  value.toInt(),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    year,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups:
                          yearData.entries.map((entry) {
                            int index = yearData.keys.toList().indexOf(
                              entry.key,
                            );
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.toDouble(),
                                  color: Colors.indigo,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
        ),
      ],
    ),
  );
}

// NEW: Widget for Users by Program
Widget buildUsersByProgramCard(Map<String, int> programData) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Users by Program',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Students who sent messages',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Expanded(
          child:
              programData.isEmpty
                  ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          programData.entries.map((entry) {
                            return PieChartSectionData(
                              color: DashboardWidgets.getProgramColor(
                                entry.key,
                              ),
                              value: entry.value.toDouble(),
                              title:
                                  '${DashboardWidgets.shortenProgram(entry.key)}\n${entry.value}',
                              radius: 70,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
        ),
      ],
    ),
  );
}

