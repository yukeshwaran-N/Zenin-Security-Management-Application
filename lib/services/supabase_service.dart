import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/checkpoint_model.dart';
import '../models/patrol_log_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final supabase = Supabase.instance.client;

  // ==================== AUTH ====================
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userData = await supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();

        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
        },
      );

      if (response.user != null) {
        await supabase.from('users').upsert({
          'id': response.user!.id,
          'name': name,
          'email': email,
          'role': role,
        });

        final userData = await supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();

        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<UserModel?> getCurrentUser() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return null;

    try {
      final userData = await supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return UserModel.fromJson(userData);
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await supabase.from('users').update(updates).eq('id', userId);
  }

  Future<void> updateFCMToken(String userId, String token) async {
    await supabase.from('users').update({'fcm_token': token}).eq('id', userId);
  }

  // ==================== USER MANAGEMENT ====================
  Future<List<UserModel>> getUsers({String? role}) async {
    try {
      var query = supabase.from('users').select();
      if (role != null) {
        query = query.eq('role', role);
      }
      final data = await query.order('name');
      return (data as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      print('Get users error: $e');
      rethrow;
    }
  }

  // Backward compatibility
  Future<List<UserModel>> getAllSupervisors() => getUsers(role: 'supervisor');

  // ==================== REAL-TIME STREAMS ====================
  Stream<List<Map<String, dynamic>>> get supervisorLocationsStream {
    return supabase
        .from('supervisor_locations')
        .stream(primaryKey: ['id'])
        .map((maps) => maps);
  }

  Stream<List<Map<String, dynamic>>> get todayPatrolLogsStream {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return supabase
        .from('patrol_logs')
        .stream(primaryKey: ['id'])
        .map((maps) => maps.where((log) => 
            (log['timestamp'] as String).startsWith(today)).toList());
  }

  Stream<Map<String, dynamic>> get appSettingsStream {
    return supabase
        .from('app_settings')
        .stream(primaryKey: ['id'])
        .limit(1)
        .map((data) => data.isNotEmpty ? data.first : {'min_interval_minutes': 30});
  }

  // ==================== APP SETTINGS ====================
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final data = await supabase.from('app_settings').select().eq('id', 1).single();
      return data;
    } catch (e) {
      return {'min_interval_minutes': 30};
    }
  }

  Future<void> updateMinInterval(int minutes) async {
    await supabase.from('app_settings').upsert({
      'id': 1,
      'min_interval_minutes': minutes,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================== CHECKPOINTS ====================
  Future<List<Checkpoint>> getCheckpoints() async {
    try {
      final data = await supabase.from('checkpoints').select('*, checklist_items(*)');
      return (data as List).map((json) {
        final itemsData = json['checklist_items'] as List? ?? [];
        return Checkpoint(
          id: json['id'],
          name: json['name'],
          description: json['description'] ?? '',
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
          radius: json['radius'] ?? 20,
          checklist: itemsData.map((item) => ChecklistItem(id: item['id'], name: item['item_name'])).toList(),
        );
      }).toList();
    } catch (e) { rethrow; }
  }

  Future<void> saveCheckpoint({
    required String name,
    required String description,
    required double latitude,
    required double longitude,
    required int radius,
    required List<String> checklistItems,
  }) async {
    try {
      final checkpointResponse = await supabase.from('checkpoints').insert({
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'qr_code': 'QR_${name.replaceAll(' ', '_')}',
      }).select().single();
      
      final checkpointId = checkpointResponse['id'];

      if (checklistItems.isNotEmpty) {
        final itemsToInsert = checklistItems.map((item) => {
          'checkpoint_id': checkpointId,
          'item_name': item,
        }).toList();
        await supabase.from('checklist_items').insert(itemsToInsert);
      }
    } catch (e) {
      print('Save checkpoint error: $e');
      rethrow;
    }
  }

  Future<void> updateCheckpoint({
    required String id,
    required String name,
    required String description,
    required double latitude,
    required double longitude,
    required int radius,
    required List<String> checklistItems,
  }) async {
    try {
      await supabase.from('checkpoints').update({
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      }).eq('id', id);

      await supabase.from('checklist_items').delete().eq('checkpoint_id', id);
      
      if (checklistItems.isNotEmpty) {
        final itemsToInsert = checklistItems.map((item) => {
          'checkpoint_id': id,
          'item_name': item,
        }).toList();
        await supabase.from('checklist_items').insert(itemsToInsert);
      }
    } catch (e) {
      print('Update checkpoint error: $e');
      rethrow;
    }
  }

  Future<void> deleteCheckpoint(String id) async {
    try {
      await supabase.from('checklist_items').delete().eq('checkpoint_id', id);
      await supabase.from('checkpoints').delete().eq('id', id);
    } catch (e) {
      print('Delete checkpoint error: $e');
      rethrow;
    }
  }

  // ==================== PATROL LOGS ====================
  Future<List<PatrolLog>> getPatrolLogs({String? supervisorId, String? shiftName}) async {
    var query = supabase.from('patrol_logs').select();
    if (supervisorId != null) query = query.eq('supervisor_id', supervisorId);
    if (shiftName != null) query = query.eq('shift_name', shiftName);
    final data = await query.order('timestamp', ascending: false);
    return (data as List).map((json) => PatrolLog.fromJson(json)).toList();
  }

  Future<void> savePatrolLog(Map<String, dynamic> logData) async {
    await supabase.from('patrol_logs').insert(logData);
  }

  Future<void> deletePatrolLog(String logId, String? photoUrl, String? voiceUrl) async {
    try {
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await _deleteFileFromStorage(photoUrl, 'patrol-images');
      }
      if (voiceUrl != null && voiceUrl.isNotEmpty) {
        await _deleteFileFromStorage(voiceUrl, 'patrol-images');
      }
      await supabase.from('patrol_logs').delete().eq('id', logId);
    } catch (e) {
      print('Delete log error: $e');
      rethrow;
    }
  }

  Future<void> _deleteFileFromStorage(String fileUrl, String bucket) async {
    try {
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final storageIndex = pathSegments.indexOf(bucket);
      if (storageIndex != -1 && storageIndex + 1 < pathSegments.length) {
        final filePath = pathSegments.sublist(storageIndex + 1).join('/');
        await supabase.storage.from(bucket).remove([filePath]);
      }
    } catch (e) {
      print('Error deleting file from $bucket: $e');
    }
  }

  // ==================== STORAGE UPLOADS ====================
  Future<String> uploadPhoto(File image, String checkpointId) async {
    try {
      final fileName = 'photo_${checkpointId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('patrol-images').upload(
        fileName,
        image,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return supabase.storage.from('patrol-images').getPublicUrl(fileName);
    } catch (e) {
      print('Upload photo error: $e');
      rethrow;
    }
  }

  Future<String> uploadVoice(File audioFile, String checkpointId) async {
    try {
      final fileName = 'voice_${checkpointId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await supabase.storage.from('patrol-images').upload(
        fileName,
        audioFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return supabase.storage.from('patrol-images').getPublicUrl(fileName);
    } catch (e) {
      print('Upload voice error: $e');
      rethrow;
    }
  }

  // ==================== LOCATION ====================
  Future<void> updateSupervisorLocation({required String supervisorId, required double latitude, required double longitude}) async {
    await supabase.from('supervisor_locations').upsert({
      'supervisor_id': supervisorId, 
      'latitude': latitude, 
      'longitude': longitude, 
      'last_update': DateTime.now().toIso8601String(),
    });
  }

  // ==================== NOTIFICATIONS ====================
  Future<void> clearReadNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await supabase
          .from('notifications')
          .delete()
          .eq('is_read', true);
    }
  }
}
