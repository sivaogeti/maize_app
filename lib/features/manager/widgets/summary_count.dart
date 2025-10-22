import 'package:flutter/material.dart';

class SummaryCount extends StatelessWidget {
  final String collectionLabel;
  final Future<int> futureCount;

  const SummaryCount({
    super.key,
    required this.collectionLabel,
    required this.futureCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<int>(
        future: futureCount,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final count = snapshot.data ?? 0;
          return Column(
            children: [
              Card(
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '$collectionLabel: $count',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: Center(
                  child: Text(
                    'Detailed list or UI content goes here...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
