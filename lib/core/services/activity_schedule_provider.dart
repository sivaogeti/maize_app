import 'package:flutter/foundation.dart';
import '../models/activity_task.dart';

class ActivityScheduleProvider extends ChangeNotifier {
  final List<ActivityTask> _items = [
    // Sample rows – like your screenshot
    ActivityTask(
      stage: 'Presowing',
      activity: 'Soil Testing/Basal fertilizer',
      plannedDate: DateTime(2025, 5, 1),
      assignee: 'FIC',
      dependencies: '-',
    ),
    ActivityTask(
      stage: 'Vegetative',
      activity: 'Rouging Round 1',
      plannedDate: DateTime(2025, 5, 10),
      assignee: 'FIC',
      dependencies: 'Sowing recorded',
    ),
    ActivityTask(
      stage: 'Flowering',
      activity: 'Detasseling audit',
      plannedDate: DateTime(2025, 5, 20),
      assignee: 'FIC/CIC',
      dependencies: 'Male tassel emerger',
    ),
    ActivityTask(
      stage: 'Post Flowering',
      activity: 'Moisture Check',
      plannedDate: DateTime(2025, 6, 1),
      assignee: 'FIC',
      dependencies: 'Weather Window',
    ),
  ];

  List<ActivityTask> get items => List.unmodifiable(_items);

  void add(ActivityTask t) {
    _items.add(t);
    notifyListeners();
  }
}
