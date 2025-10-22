import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

enum ChartType { line, bar, pie }

class ManagerAnalyticsScreen extends StatelessWidget {
  final String title;
  final String collectionName;
  final List<String> summaryFields; // Fields to show in top cards
  final ChartType chartType;
  final List<String> listFields; // Fields to show in list
  final Color color;

  const ManagerAnalyticsScreen({
    super.key,
    required this.title,
    required this.collectionName,
    required this.summaryFields,
    required this.chartType,
    required this.listFields,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Build summary cards data
          final summaryData = <String, int>{};
          for (var field in summaryFields) {
            int count = 0;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data[field] != null) count++;
            }
            summaryData[field] = count;
          }

          // Prepare last 7 days data for chart
          final now = DateTime.now();
          final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          final counts = List<int>.filled(7, 0);
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            Timestamp? ts = data['createdAt'] as Timestamp?;
            if (ts != null) {
              final dt = ts.toDate();
              final dayIndex = dt.difference(startDate).inDays;
              if (dayIndex >= 0 && dayIndex < 7) counts[dayIndex]++;
            }
          }
          final weekdayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
          final labels = List.generate(7, (i) => weekdayNames[startDate.add(Duration(days: i)).weekday - 1]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: summaryData.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final key = summaryData.keys.elementAt(i);
                      return Container(
                        width: 160,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(key, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(summaryData[key].toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Chart
                SizedBox(
                  height: 250,
                  child: _buildChart(counts, labels),
                ),

                const SizedBox(height: 24),

                // List of recent docs
                Text('Recent Entries', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...docs.reversed.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text(listFields.map((f) => data[f]?.toString() ?? '').join(' | ')),
                      subtitle: Text(data['createdAt'] != null
                          ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                          : ''),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(List<int> counts, List<String> labels) {
    switch (chartType) {
      case ChartType.bar:
        return BarChart(
          BarChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < labels.length) return Text(labels[idx]);
                  return const SizedBox.shrink();
                }),
              ),
            ),
            barGroups: List.generate(counts.length,
                    (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: counts[i].toDouble(), color: color)])),
          ),
        );
      case ChartType.pie:
        return PieChart(
          PieChartData(
            sections: counts.asMap().entries.map((e) => PieChartSectionData(
              value: e.value.toDouble(),
              title: labels[e.key],
              color: color.withOpacity(0.7),
            )).toList(),
          ),
        );
      case ChartType.line:
      default:
        return LineChart(
          LineChartData(
            minY: 0,
            maxY: counts.reduce((a,b) => a>b?a:b).toDouble() + 2,
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx >=0 && idx< labels.length) return Text(labels[idx]);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(counts.length, (i) => FlSpot(i.toDouble(), counts[i].toDouble())),
                isCurved: true,
                barWidth: 3,
                color: color,
                dotData: FlDotData(show: true),
              )
            ],
          ),
        );
    }
  }
}
