import 'package:hive/hive.dart';
import '../models/patrol_log_model.dart';
import 'supabase_service.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final Box patrolCache = Hive.box('patrol_cache');

  Future<void> savePatrolOffline(PatrolLog log) async {
    await patrolCache.add({
      'data': log.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPatrols() async {
    return patrolCache.values
        .where((item) => !item['synced'])
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> syncPendingPatrols() async {
    final pending = await getPendingPatrols();
    
    for (var patrol in pending) {
      try {
        // Updated to pass the Map directly since SupabaseService.savePatrolLog expects a Map
        await SupabaseService().savePatrolLog(
          patrol['data'],
        );
        
        final key = patrolCache.keys.firstWhere(
          (k) => patrolCache.get(k) == patrol,
        );
        patrol['synced'] = true;
        await patrolCache.put(key, patrol);
      } catch (e) {
        print('Sync failed for patrol: $e');
      }
    }
  }

  Future<void> clearSyncedPatrols() async {
    final keysToDelete = <dynamic>[];
    
    for (var key in patrolCache.keys) {
      final item = patrolCache.get(key);
      if (item['synced'] == true) {
        keysToDelete.add(key);
      }
    }
    
    for (var key in keysToDelete) {
      await patrolCache.delete(key);
    }
  }
}
