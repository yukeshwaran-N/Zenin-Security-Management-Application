class Checkpoint {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final int radius;
  final List<ChecklistItem> checklist;
  bool isCompleted;
  DateTime? completedAt;

  Checkpoint({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.radius = 20,
    required this.checklist,
    this.isCompleted = false,
    this.completedAt,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: json['radius'] ?? 20,
      checklist: (json['checklist'] as List?)
              ?.map((item) => ChecklistItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'checklist': checklist.map((item) => item.toJson()).toList(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

class ChecklistItem {
  final String id;
  final String name;
  bool isChecked;
  String? notes;

  ChecklistItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.notes,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      name: json['item_name'] ?? json['name'] ?? '',
      isChecked: json['is_checked'] ?? false,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_checked': isChecked,
      'notes': notes,
    };
  }
}
