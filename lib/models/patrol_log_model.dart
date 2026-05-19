class PatrolLog {
  final String id;
  final String supervisorId;
  final String supervisorName;
  final String checkpointId;
  final String checkpointName;
  final String? shiftName;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final List<String> photoUrls; // Changed from photoUrl to photoUrls
  final String? voiceUrl;
  final String? notes;
  final Map<String, dynamic> checklistResults;
  final bool synced;

  PatrolLog({
    required this.id,
    required this.supervisorId,
    required this.supervisorName,
    required this.checkpointId,
    required this.checkpointName,
    this.shiftName,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.photoUrls,
    this.voiceUrl,
    this.notes,
    required this.checklistResults,
    this.synced = false,
  });

  factory PatrolLog.fromJson(Map<String, dynamic> json) {
    // Handle photo_url as either a single string (old) or a list (new)
    List<String> photos = [];
    if (json['photo_url'] != null) {
      if (json['photo_url'] is List) {
        photos = List<String>.from(json['photo_url']);
      } else if (json['photo_url'] is String) {
        // Handle legacy single string or JSON string
        if (json['photo_url'].toString().startsWith('[')) {
          // It's a JSON string array
          try {
            // Very basic manual parse if it looks like a JSON array
            // Better to use dart:convert but keeping it simple for now
            photos = [json['photo_url']]; 
          } catch (_) {
            photos = [json['photo_url']];
          }
        } else {
          photos = [json['photo_url']];
        }
      }
    }

    return PatrolLog(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      supervisorId: json['supervisor_id'],
      supervisorName: json['supervisor_name'],
      checkpointId: json['checkpoint_id'],
      checkpointName: json['checkpoint_name'],
      shiftName: json['shift_name'],
      timestamp: DateTime.parse(json['timestamp']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      photoUrls: photos,
      voiceUrl: json['voice_url'],
      notes: json['notes'],
      checklistResults: json['checklist_results'] ?? {},
      synced: json['synced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'checkpoint_id': checkpointId,
      'checkpoint_name': checkpointName,
      'shift_name': shiftName,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrls, // Supabase handles list/jsonb automatically
      'voice_url': voiceUrl,
      'notes': notes,
      'checklist_results': checklistResults,
      'synced': synced,
    };
  }
}
