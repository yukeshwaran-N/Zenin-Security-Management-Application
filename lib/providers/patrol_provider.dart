import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/offline_service.dart';
import '../models/checkpoint_model.dart';
import '../models/patrol_log_model.dart';
import '../models/user_model.dart';
import '../models/shift_model.dart';
import 'auth_provider.dart';
import 'dart:io';
import '../utils/translation_helper.dart';

class PatrolProvider extends ChangeNotifier {
  List<Checkpoint> _checkpoints = [];
  List<PatrolLog> _patrolLogs = [];
  List<UserModel> _supervisors = [];
  List<Map<String, dynamic>> _supervisorStats = [];
  bool _isLoading = false;
  String? _error;
  Checkpoint? _currentCheckpoint;
  
  Shift? _selectedShift;
  Map<String, int> _checkpointVisitCount = {}; 

  int _minIntervalMinutes = 20;
  bool _debugMode = false;

  StreamSubscription? _locationSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _personalLogSubscription;
  StreamSubscription? _settingsSubscription;
  
  List<Map<String, dynamic>> _currentLocations = [];
  List<Map<String, dynamic>> _todayLogs = [];

  List<Checkpoint> get checkpoints => _checkpoints;
  List<PatrolLog> get patrolLogs => _patrolLogs;
  List<UserModel> get supervisors => _supervisors;
  List<Map<String, dynamic>> get supervisorStats => _supervisorStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Checkpoint? get currentCheckpoint => _currentCheckpoint;
  bool get debugMode => _debugMode;
  Shift? get selectedShift => _selectedShift;
  int get minIntervalMinutes => _minIntervalMinutes;

  DateTime _toIST(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  set debugMode(bool value) {
    _debugMode = value;
    notifyListeners();
  }

  void setSelectedShift(Shift? shift) {
    _selectedShift = shift;
    _calculateVisitCounts();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _logSubscription?.cancel();
    _personalLogSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  void startRealtimeUpdates(String? currentUserId) {
    _locationSubscription?.cancel();
    _logSubscription?.cancel();
    _personalLogSubscription?.cancel();
    _settingsSubscription?.cancel();

    _locationSubscription = SupabaseService().supervisorLocationsStream.listen((locations) {
      _currentLocations = locations;
      _calculateStats();
    });

    _logSubscription = SupabaseService().todayPatrolLogsStream.listen((logs) {
      _todayLogs = logs;
      _calculateStats();
    });

    if (currentUserId != null) {
      _personalLogSubscription = SupabaseService().supabase
          .from('patrol_logs')
          .stream(primaryKey: ['id'])
          .eq('supervisor_id', currentUserId)
          .listen((data) {
            _patrolLogs = data.map((json) => PatrolLog.fromJson(json)).toList();
            _calculateVisitCounts();
            notifyListeners();
          });
    }

    _settingsSubscription = SupabaseService().appSettingsStream.listen((settings) {
      _minIntervalMinutes = settings['min_interval_minutes'] ?? 20;
      notifyListeners();
    });
  }

  void _calculateStats() {
    if (_supervisors.isEmpty) return;
    
    _supervisorStats = _supervisors.map((user) {
      if (user.role == 'SO') return null;

      final userLogs = _todayLogs.where((log) => log['supervisor_id'] == user.id).toList();
      final uniqueCheckpointsReached = userLogs.map((log) => log['checkpoint_id']).toSet().length;
      
      final userLocs = _currentLocations.where((loc) => loc['supervisor_id'] == user.id);
      final location = userLocs.isNotEmpty ? userLocs.first : null;

      String displayStatus = TranslationHelper.translate('pending_first_patrol');

      if (location != null) {
        final lastUpdate = DateTime.parse(location['last_update']).toLocal();
        final diff = DateTime.now().difference(lastUpdate);
        if (diff.inMinutes < 15) {
          displayStatus = 'Active: ${_formatLastActive(diff)}';
        } else {
          displayStatus = 'Last seen: ${_formatLastActive(diff)}';
        }
      } else if (userLogs.isNotEmpty) {
        userLogs.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        final lastLog = userLogs.first;
        displayStatus = 'Last: ${lastLog['checkpoint_name']}';
      }

      return {
        'user': user,
        'completed': uniqueCheckpointsReached,
        'total': _checkpoints.length,
        'lastActive': displayStatus,
        'lastLocation': location,
      };
    }).whereType<Map<String, dynamic>>().toList();

    notifyListeners();
  }

  String _formatLastActive(Duration diff) {
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _calculateVisitCounts() {
    if (_selectedShift == null) return;
    _checkpointVisitCount.clear();
    final nowIST = _toIST(DateTime.now());
    for (var log in _patrolLogs) {
      if (log.shiftName == _selectedShift!.name) {
        final logIST = _toIST(log.timestamp);
        bool isSameSession = logIST.year == nowIST.year && logIST.month == nowIST.month && logIST.day == nowIST.day;
        if (isSameSession) _checkpointVisitCount[log.checkpointId] = (_checkpointVisitCount[log.checkpointId] ?? 0) + 1;
      }
    }
    notifyListeners();
  }

   int getVisitCount(String checkpointId) => _checkpointVisitCount[checkpointId] ?? 0;
 
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadAllCheckpoints() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _checkpoints = await SupabaseService().getCheckpoints();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCheckpoint({
    required String name,
    required String description,
    required double latitude,
    required double longitude,
    required int radius,
    required List<String> checklistItems,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService().saveCheckpoint(
        name: name,
        description: description,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        checklistItems: checklistItems,
      );
      _checkpoints = await SupabaseService().getCheckpoints();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editCheckpoint({
    required String id,
    required String name,
    required String description,
    required double latitude,
    required double longitude,
    required int radius,
    required List<String> checklistItems,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService().updateCheckpoint(
        id: id,
        name: name,
        description: description,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        checklistItems: checklistItems,
      );
      _checkpoints = await SupabaseService().getCheckpoints();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeCheckpoint(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService().deleteCheckpoint(id);
      _checkpoints = await SupabaseService().getCheckpoints();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCheckpoints(String supervisorId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _checkpoints = await SupabaseService().getCheckpoints();
      _patrolLogs = await SupabaseService().getPatrolLogs(supervisorId: supervisorId);
      startRealtimeUpdates(supervisorId);
      _calculateVisitCounts();
    } catch (e) { _error = e.toString(); }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPatrolLogs({String? supervisorId}) async {
    try {
      _patrolLogs = await SupabaseService().getPatrolLogs(supervisorId: supervisorId);
      _calculateVisitCounts();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadSupervisorStats() async {
    _isLoading = true;
    notifyListeners();
    try {
      _checkpoints = await SupabaseService().getCheckpoints();
      _supervisors = await SupabaseService().getUsers();
      startRealtimeUpdates(null);
    } catch (e) { _error = e.toString(); }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> verifyLocation(Checkpoint checkpoint) async {
    _error = null;
    notifyListeners();
    if (_debugMode) return true;
    try {
      final position = await LocationService().getCurrentLocation();
      double distance = LocationService().calculateDistance(position.latitude, position.longitude, checkpoint.latitude, checkpoint.longitude);
      if (distance > checkpoint.radius) throw Exception('Too far: ${distance.toInt()}m');
      return true;
    } catch (e) { 
      _error = e.toString(); 
      notifyListeners();
      return false; 
    }
  }

  Future<void> submitPatrol({
    required Checkpoint checkpoint,
    required Map<String, dynamic> checklistResults,
    List<File> photos = const [], // Changed to List<File>
    File? voice,
    String? notes,
    required AuthProvider auth,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      List<String> photoUrls = [];
      for (var file in photos) {
        final url = await SupabaseService().uploadPhoto(file, checkpoint.id);
        photoUrls.add(url);
      }
      
      String? voiceUrl = voice != null ? await SupabaseService().uploadVoice(voice, checkpoint.id) : null;
      final position = await LocationService().getCurrentLocation();
      await SupabaseService().savePatrolLog({
        'supervisor_id': auth.currentUser!.id,
        'supervisor_name': auth.currentUser!.name,
        'checkpoint_id': checkpoint.id,
        'checkpoint_name': checkpoint.name,
        'shift_name': _selectedShift?.name,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'photo_url': photoUrls, // Send list of URLs
        'voice_url': voiceUrl,
        'notes': notes,
        'checklist_results': checklistResults,
      });
    } catch (e) { 
      _error = e.toString(); 
      print('Submit patrol error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateGlobalInterval(int minutes) async {
    await SupabaseService().updateMinInterval(minutes);
    _minIntervalMinutes = minutes;
    notifyListeners();
  }
}
