import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/patrol_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/translation_helper.dart';

class SVHistoryScreen extends StatefulWidget {
  const SVHistoryScreen({super.key});

  @override
  State<SVHistoryScreen> createState() => _SVHistoryScreenState();
}

class _SVHistoryScreenState extends State<SVHistoryScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingUrl;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _playVoice(String url) async {
    try {
      if (_playingUrl == url) {
        await _audioPlayer.stop();
        setState(() => _playingUrl = null);
      } else {
        await _audioPlayer.play(UrlSource(url));
        setState(() => _playingUrl = url);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playingUrl = null);
        });
      }
    } catch (e) {
      debugPrint('Error playing voice: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.currentUser?.id;

    if (userId == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationHelper.translate('my_work_history'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService().supabase
                  .from('patrol_logs')
                  .stream(primaryKey: ['id'])
                  .eq('supervisor_id', userId)
                  .order('timestamp', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(TranslationHelper.translate('no_history_found'), style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return FadeTransition(
                  opacity: _fadeController,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildHistoryCard(log);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> log) {
    final status = log['checklist_results']['equipment_status'] ?? 'OK';
    final timestamp = DateTime.parse(log['timestamp']).toLocal();
    final voiceUrl = log['voice_url'];
    
    // Explicitly cast to List<String> to fix the type error
    List<String> photos = [];
    if (log['photo_url'] != null) {
      if (log['photo_url'] is List) {
        photos = List<String>.from(log['photo_url']);
      } else {
        photos = [log['photo_url'].toString()];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 22),
        ),
        title: Text(
          log['checkpoint_name'] ?? 'Unknown Point',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          DateFormat('dd MMM, hh:mm a').format(timestamp),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photos.isNotEmpty) ...[
                  Text(TranslationHelper.translate('photos_caps'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _buildPhotoRow(photos),
                  const SizedBox(height: 16),
                ],
                if (voiceUrl != null) ...[
                  Text(TranslationHelper.translate('voice_report_caps'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _buildVoicePlayer(voiceUrl.toString()),
                  const SizedBox(height: 16),
                ],
                if (log['notes'] != null && log['notes'].toString().isNotEmpty) ...[
                  Text(TranslationHelper.translate('notes_caps'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(log['notes'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 16),
                ],
                Text(TranslationHelper.translate('checklist_caps'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                _buildChecklistMini(log['checklist_results']['items'] ?? {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoRow(List<String> urls) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(right: 10),
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: NetworkImage(urls[index]), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildVoicePlayer(String url) {
    final isPlaying = _playingUrl == url;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.blue.shade800),
            onPressed: () => _playVoice(url),
          ),
          Text(TranslationHelper.translate('play_voice_update'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChecklistMini(Map<String, dynamic> items) {
    return Column(
      children: items.values.map((val) {
        bool isOk = val['checked'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(isOk ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 14, color: isOk ? Colors.green : Colors.grey.shade300),
              const SizedBox(width: 8),
              Text(val['name'] ?? 'Task', style: TextStyle(fontSize: 12, color: isOk ? Colors.black87 : Colors.grey)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'OK') return Colors.green;
    if (status == 'Needs Maintenance') return Colors.orange;
    return Colors.red;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'OK') return Icons.check_circle_rounded;
    if (status == 'Needs Maintenance') return Icons.engineering_rounded;
    return Icons.warning_rounded;
  }
}
