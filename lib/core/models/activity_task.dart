class ActivityTask {
  final String stage;         // e.g. "Presowing", "Vegetative"
  final String activity;      // e.g. "Soil Testing/Basal fertilizer"
  final DateTime plannedDate; // planned target date
  final String assignee;      // e.g. "FIC", "FIC/CIC"
  final String dependencies;  // e.g. "Sowing recorded"

  ActivityTask({
    required this.stage,
    required this.activity,
    required this.plannedDate,
    required this.assignee,
    required this.dependencies,
  });
}
