
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ==================== ENHANCED USER BY YEAR LEVEL CARD ====================
Widget buildUsersByYearCard(Map<String, int> yearData) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;

      // Calculate totals for percentage
      final totalUsers = yearData.values.fold(0, (sum, val) => sum + val);

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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: Colors.indigo[700],
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Users by Year Level',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        'Students who sent messages',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Total count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalUsers',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // Chart
            Expanded(
              child: yearData.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.bar_chart_outlined,
                      message: 'No year level data available',
                      isMobile: isMobile,
                    )
                  : Row(
                      children: [
                        // Bar Chart
                        Expanded(
                          flex: 3,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: yearData.values.isNotEmpty
                                  ? yearData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2
                                  : 10,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipBorderRadius: BorderRadius.circular(8),
                                  tooltipPadding: const EdgeInsets.all(8),
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    String year = yearData.keys.elementAt(group.x.toInt());
                                    double percentage = (rod.toY / totalUsers) * 100;
                                    return BarTooltipItem(
                                      '$year\n${rod.toY.round()} students\n${percentage.toStringAsFixed(1)}%',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 35,
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: isMobile ? 9 : 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() < yearData.length) {
                                        String year = yearData.keys.elementAt(value.toInt());
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            year,
                                            style: TextStyle(
                                              fontSize: isMobile ? 10 : 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey[200]!,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: yearData.entries.map((entry) {
                                int index = yearData.keys.toList().indexOf(entry.key);
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.toDouble(),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.indigo[400]!,
                                          Colors.indigo[600]!,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      width: isMobile ? 20 : 24,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        
                        // Stats sidebar (only on larger screens)
                        if (!isMobile) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildYearLevelStats(yearData, totalUsers, isTablet),
                          ),
                        ],
                      ],
                    ),
            ),
            
            // Mobile stats (below chart)
            if (isMobile && yearData.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildYearLevelStatsMobile(yearData, totalUsers),
            ],
          ],
        ),
      );
    },
  );
}

// Stats sidebar for desktop/tablet
Widget _buildYearLevelStats(Map<String, int> yearData, int totalUsers, bool isTablet) {
  final sortedEntries = yearData.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.indigo[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Years',
          style: TextStyle(
            fontSize: isTablet ? 12 : 13,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: sortedEntries.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final percentage = (entry.value / totalUsers) * 100;
              return _buildStatItem(
                entry.key,
                entry.value,
                percentage,
                Colors.indigo,
                isTablet,
              );
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildYearLevelStatsMobile(Map<String, int> yearData, int totalUsers) {
  final sortedEntries = yearData.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Distribution Summary',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sortedEntries.take(4).map((entry) {
          final percentage = (entry.value / totalUsers) * 100;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${entry.key}: ${entry.value} (${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.indigo[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

// ==================== ENHANCED USER BY PROGRAM CARD ====================
Widget buildUsersByProgramCard(Map<String, int> programData) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;


      final totalUsers = programData.values.fold(0, (sum, val) => sum + val);

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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_tree_outlined,
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
                        'Active Users by Program',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        'Distribution across programs',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalUsers',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // Chart
            Expanded(
              child: programData.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.pie_chart_outline,
                      message: 'No program data available',
                      isMobile: isMobile,
                    )
                  : Row(
                      children: [
                        // Pie Chart
                        Expanded(
                          flex: isMobile ? 1 : 2,
                          child: PieChart(
                            PieChartData(
                              sections: programData.entries.map((entry) {
                                final percentage = (entry.value / totalUsers) * 100;
                                return PieChartSectionData(
                                  color: DashboardWidgets.getProgramColor(entry.key),
                                  value: entry.value.toDouble(),
                                  title: percentage >= 5
                                      ? '${percentage.toStringAsFixed(0)}%'
                                      : '',
                                  radius: isMobile ? 60 : 75,
                                  titleStyle: TextStyle(
                                    fontSize: isMobile ? 11 : 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                
                                );
                              }).toList(),
                              centerSpaceRadius: isMobile ? 25 : 35,
                              sectionsSpace: 2,
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  // Add interaction feedback
                                },
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: isMobile ? 12 : 20),
                        
                        // Legend
                        Expanded(
                          flex: isMobile ? 1 : 1,
                          child: _buildProgramLegend(programData, totalUsers, isMobile),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}



Widget _buildProgramLegend(Map<String, int> programData, int totalUsers, bool isMobile) {
  final sortedEntries = programData.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
    padding: EdgeInsets.all(isMobile ? 8 : 12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Programs',
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: sortedEntries.length,
            separatorBuilder: (_, __) => SizedBox(height: isMobile ? 6 : 8),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final percentage = (entry.value / totalUsers) * 100;
              return Row(
                children: [
                  Container(
                    width: isMobile ? 10 : 12,
                    height: isMobile ? 10 : 12,
                    decoration: BoxDecoration(
                      color: DashboardWidgets.getProgramColor(entry.key),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.length > 25
                              ? '${entry.key.substring(0, 25)}...'
                              : entry.key,
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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

// ==================== ENHANCED SCHOLARSHIP TYPES CARD ====================
Widget buildScholarshipTypesCard(Map<String, int> scholarshipTypes) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;


      final filteredEntries = scholarshipTypes.entries
          .where((entry) => entry.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final totalUsers = filteredEntries.fold(0, (sum, entry) => sum + entry.value);

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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.card_giftcard_outlined,
                    color: Colors.orange[700],
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scholarship Distribution',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        'Active users by scholarship type',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalUsers',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // Chart
            Expanded(
              child: filteredEntries.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.school_outlined,
                      message: 'No scholarship data available',
                      isMobile: isMobile,
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: filteredEntries.first.value.toDouble() * 1.2,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(8),
                            tooltipPadding: const EdgeInsets.all(8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final type = filteredEntries[group.x.toInt()].key;
                              final percentage = (rod.toY / totalUsers) * 100;
                              return BarTooltipItem(
                                '$type\n${rod.toY.round()} users\n${percentage.toStringAsFixed(1)}%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                      style: TextStyle(
                                        fontSize: isMobile ? 9 : 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
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
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: isMobile ? 9 : 10,
                                    color: Colors.grey[600],
                                  ),
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
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: filteredEntries.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.value.toDouble(),
                                gradient: LinearGradient(
                                  colors: [
                                    _getScholarshipTypeColor(entry.key).withOpacity(0.7),
                                    _getScholarshipTypeColor(entry.key),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: isMobile ? 18 : 22,
                                borderRadius: BorderRadius.circular(6),
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
    },
  );
}

// ==================== ENHANCED USER AFFILIATIONS CARD ====================
Widget buildUserAffiliationsCard(Map<String, int> userAffiliations) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      final totalUsers = userAffiliations.values.fold(0, (sum, val) => sum + val);

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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    color: Colors.purple[700],
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Affiliations',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        'Distribution by affiliation type',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalUsers',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // Chart
            Expanded(
              child: userAffiliations.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.people_outline,
                      message: 'No affiliation data available',
                      isMobile: isMobile,
                    )
                  : Row(
                      children: [
                        // Pie Chart
                        Expanded(
                          flex: isMobile ? 1 : 2,
                          child: PieChart(
                            PieChartData(
                              sections: userAffiliations.entries.map((entry) {
                                final percentage = (entry.value / totalUsers) * 100;
                                return PieChartSectionData(
                                  color: _getAffiliationColor(entry.key),
                                  value: entry.value.toDouble(),
                                  title: percentage >= 8
                                      ? '${percentage.toStringAsFixed(0)}%'
                                      : '',
                                  radius: isMobile ? 60 : 75,
                                  titleStyle: TextStyle(
                                    fontSize: isMobile ? 11 : 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                              
                                );
                              }).toList(),
                              centerSpaceRadius: isMobile ? 25 : 35,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        
                        SizedBox(width: isMobile ? 12 : 20),
                        
                        // Legend
                        Expanded(
                          flex: isMobile ? 1 : 1,
                          child: _buildAffiliationLegend(userAffiliations, totalUsers, isMobile),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildAffiliationLegend(Map<String, int> affiliations, int totalUsers, bool isMobile) {
  final sortedEntries = affiliations.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
    padding: EdgeInsets.all(isMobile ? 8 : 12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Affiliations',
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: sortedEntries.length,
            separatorBuilder: (_, __) => SizedBox(height: isMobile ? 6 : 8),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final percentage = (entry.value / totalUsers) * 100;
              return Row(
                children: [
                  Container(
                    width: isMobile ? 10 : 12,
                    height: isMobile ? 10 : 12,
                    decoration: BoxDecoration(
                      color: _getAffiliationColor(entry.key),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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


// ==================== UTILITY FUNCTIONS ====================

Widget _buildStatItem(String label, int value, double percentage, Color color, bool isTablet) {
  return Container(
    padding: EdgeInsets.all(isTablet ? 6 : 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: isTablet ? 9 : 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: isTablet ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyState({
  required IconData icon,
  required String message,
  required bool isMobile,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: isMobile ? 40 : 48,
            color: Colors.grey[400],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          message,
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Color _getScholarshipTypeColor(int index) {
  final colors = [
    Colors.green[600]!,
    Colors.blue[600]!,
    Colors.orange[600]!,
    Colors.purple[600]!,
    Colors.teal[600]!,
    Colors.pink[600]!,
    Colors.indigo[600]!,
  ];
  return colors[index % colors.length];
}

Color _getAffiliationColor(String affiliation) {
  switch (affiliation.toLowerCase()) {
    case 'student':
      return Colors.blue[600]!;
    case 'faculty':
      return Colors.green[600]!;
    case 'staff':
      return Colors.orange[600]!;
    case 'parent':
      return Colors.purple[600]!;
    case 'employer':
      return const Color.fromARGB(255, 170, 36, 36);
    case 'incoming freshman applicant':
      return Colors.teal[600]!;
    default:
      return Colors.grey[600]!;
  }
}

// ============================================================================
// SCHOLARSHIP DISTRIBUTION (WITH VS WITHOUT)
// ============================================================================
Widget buildScholarshipDistributionCard(
  int? usersWithScholarship,
  int? usersWithoutScholarship,
) {
  final withScholarship = usersWithScholarship ?? 0;
  final withoutScholarship = usersWithoutScholarship ?? 0;
  final total = withScholarship + withoutScholarship;
  
  final withPercentage = total > 0 ? (withScholarship / total * 100) : 0.0;
  final withoutPercentage = total > 0 ? (withoutScholarship / total * 100) : 0.0;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff59e0b).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Color(0xfff59e0b),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scholarship Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1a1a1a),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Students with and without scholarships',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: total == 0
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No scholarship data available',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: [
                            PieChartSectionData(
                              color: const Color(0xff10b981),
                              value: withScholarship.toDouble(),
                              title: '${withPercentage.toStringAsFixed(1)}%',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              color: const Color(0xff6b7280),
                              value: withoutScholarship.toDouble(),
                              title: '${withoutPercentage.toStringAsFixed(1)}%',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildScholarshipLegend(
                          'With Scholarship',
                          withScholarship,
                          withPercentage,
                          const Color(0xff10b981),
                        ),
                        const SizedBox(height: 16),
                        _buildScholarshipLegend(
                          'Without Scholarship',
                          withoutScholarship,
                          withoutPercentage,
                          const Color(0xff6b7280),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

Widget _buildScholarshipLegend(
  String label,
  int count,
  double percentage,
  Color color,
) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xff64748b),
            ),
          ),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xff1a1a1a),
            ),
          ),
        ],
      ),
    ],
  );
}


// ============================================================================
// USER GROWTH OVER TIME
// ============================================================================
double _getBottomTitleInterval(int dataLength, String timeFrame, [DateTime? startDate, DateTime? endDate]) {
  // Handle custom date ranges
  if (timeFrame == 'Custom' && startDate != null && endDate != null) {
    final daysDiff = endDate.difference(startDate).inDays;
    
    if (daysDiff == 0) {
      // Hourly: show every 3-4 hours
      return dataLength <= 24 ? 3.0 : 4.0;
    } else if (daysDiff <= 7) {
      // Daily: show all days if 7 or fewer
      return 1.0;
    } else if (daysDiff <= 31) {
      // Weekly: show all weeks
      return 1.0;
    } else {
      // Monthly: show every other month if more than 6 months
      return dataLength <= 6 ? 1.0 : 2.0;
    }
  }

  // Handle predefined time frames
  switch (timeFrame) {
    case 'Today':
      // Hourly data: show every 3-4 hours
      return dataLength <= 12 ? 2.0 : (dataLength <= 18 ? 3.0 : 4.0);
    
    case 'This Week':
      // Daily data: show all 7 days
      return 1.0;
    
    case 'This Month':
      // Daily data: show every 3-4 days
      return dataLength <= 15 ? 2.0 : (dataLength <= 20 ? 3.0 : 4.0);
    
    case 'This Year':
      // Monthly data: show all 12 months or every other month
      return dataLength <= 12 ? 1.0 : 2.0;
    
    case 'All Time':
      // Variable data: adjust based on data length
      if (dataLength <= 12) {
        return 1.0;
      } else if (dataLength <= 24) {
        return 2.0;
      } else if (dataLength <= 36) {
        return 3.0;
      } else {
        return 4.0;
      }
    
    default:
      // Default fallback
      return dataLength <= 10 ? 1.0 : (dataLength / 8).ceilToDouble();
  }
}

Widget buildUserGrowthCard(
  List<ChartData> userGrowthData,
  String timeFrame,
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  double maxY = 0;
  for (var data in userGrowthData) {
    if (data.count > maxY) maxY = data.count.toDouble();
  }
  maxY = maxY * 1.1;

  // Calculate interval for bottom titles
  final bottomTitleInterval = _getBottomTitleInterval(
    userGrowthData.length,
    timeFrame,
    startDate,
    endDate,
  );

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey[50]!],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: Colors.grey[200]!, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff3b82f6),
                    const Color(0xff2563eb),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff3b82f6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Growth Over Time',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0f172a),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cumulative user registration trend',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: userGrowthData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No user growth data available',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: userGrowthData
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                                    entry.key.toDouble(),
                                    entry.value.count.toDouble(),
                                  ))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.4,
                          color: const Color(0xff3b82f6),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: const Color(0xff3b82f6),
                                strokeWidth: 3,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xff3b82f6).withOpacity(0.3),
                                const Color(0xff3b82f6).withOpacity(0.1),
                                const Color(0xff3b82f6).withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                _formatUserCount(value.toInt()),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: bottomTitleInterval,
                            getTitlesWidget: (value, meta) {
                              if (value < 0 || value >= userGrowthData.length) {
                                return const SizedBox.shrink();
                              }
                              
                              // Only show labels at interval positions
                              if (value % bottomTitleInterval != 0) {
                                return const SizedBox.shrink();
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  userGrowthData[value.toInt()].date,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!, width: 1.5),
                          bottom: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBorderRadius: BorderRadius.circular(8),
                          tooltipPadding: const EdgeInsets.all(12),
                          tooltipBorder: BorderSide(color: Colors.grey[300]!, width: 1.5),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${userGrowthData[spot.x.toInt()].date}\n${spot.y.toInt()} users',
                                const TextStyle(
                                  color: Color(0xff3b82f6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: const Color(0xff3b82f6),
                                strokeWidth: 2,
                                dashArray: [5, 5],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 8,
                                    color: const Color(0xff3b82f6),
                                    strokeWidth: 4,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

// ============================================================================
// HELPER METHODS
// ============================================================================



String _formatUserCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}
