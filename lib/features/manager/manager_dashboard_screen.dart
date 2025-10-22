// features/manager/manager_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final List<_DashTileData> managerTiles = [
    _DashTileData(
      label: 'Manager - Farmer Network',
      collectionName: 'farmers_network',
      color: Colors.blue,
      icon: Icons.group,
      route: '/manager-farmer-network',
    ),
    _DashTileData(
      label: 'Manager - Farmer Registrations',
      collectionName: 'farmer_registrations',
      color: Colors.green,
      icon: Icons.person_add,
      route: '/manager-farmer-registrations',
    ),
    _DashTileData(
      label: 'Manager - Field Incharges',
      collectionName: 'field_incharges',
      color: Colors.orange,
      icon: Icons.people,
      route: '/manager-field-incharge-details',
    ),
    _DashTileData(
      label: 'Manager - Daily Logs',
      collectionName: 'daily_logs',
      color: Colors.teal,
      icon: Icons.note,
      route: '/manager-field-incharge-daily-logs',
    ),
    _DashTileData(
      label: 'Manager - Activity Schedule',
      collectionName: 'activity_schedule',
      color: Colors.purple,
      icon: Icons.schedule,
      route: '/manager-activity-schedule',
    ),
    _DashTileData(
      label: 'Manager - Input Activities',
      collectionName: 'input_supplies',
      color: Colors.red,
      icon: Icons.inventory,
      route: '/manager-input-activity',
    ),
    _DashTileData(
      label: 'Manager - Field Observations',
      collectionName: 'field_observations',
      color: Colors.brown,
      icon: Icons.visibility,
      route: '/manager-field-observations',
    ),
    _DashTileData(
      label: 'Manager - Field Diagnostics',
      collectionName: 'field_diagnostics',
      color: Colors.indigo,
      icon: Icons.medical_services,
      route: '/manager-field-diagnostics',
    ),
  ];

  late Future<List<_TileData>> _allTileDataFuture;

  @override
  void initState() {
    super.initState();
    _allTileDataFuture = _loadAllTileData();
  }

  Future<List<_TileData>> _loadAllTileData() async {
    final futures = managerTiles.map((tile) async {
      final snapshot = await FirebaseFirestore.instance.collection(tile.collectionName).get();
      final count = snapshot.size;

      // 7-day trend
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final trend = List<int>.filled(7, 0);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        Timestamp? ts = data['createdAt'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          final dayIndex = dt.difference(startDate).inDays;
          if (dayIndex >= 0 && dayIndex < 7) trend[dayIndex]++;
        }
      }

      return _TileData(tile, count, trend);
    }).toList();

    return await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<_TileData>>(
          future: _allTileDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final tilesData = snapshot.data ?? [];

            return GridView.builder(
              itemCount: tilesData.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final data = tilesData[index];
                return _DashTile(
                  tile: data.tile,
                  count: data.count,
                  trend: data.trend,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DashTileData {
  final String label;
  final String collectionName;
  final Color color;
  final IconData icon;
  final String route;

  const _DashTileData({
    required this.label,
    required this.collectionName,
    required this.color,
    required this.icon,
    required this.route,
  });
}

class _TileData {
  final _DashTileData tile;
  final int count;
  final List<int> trend;

  _TileData(this.tile, this.count, this.trend);
}

class _DashTile extends StatelessWidget {
  final _DashTileData tile;
  final int count;
  final List<int> trend;

  const _DashTile({
    super.key,
    required this.tile,
    this.count = 0,
    this.trend = const [],
  });

  @override
  Widget build(BuildContext context) {
    final spots = trend.asMap().entries.map(
          (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
    ).toList();

    return GestureDetector(
      onTap: () => GoRouter.of(context).push(tile.route),
      child: Container(
        decoration: BoxDecoration(
          color: tile.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 2))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Count displayed on top
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Icon(tile.icon, size: 36, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              tile.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (spots.isNotEmpty)
              SizedBox(
                height: 35,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                    titlesData: FlTitlesData(show: false),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.white,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
