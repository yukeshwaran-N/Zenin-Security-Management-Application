import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher to pubspec if not there
import '../../providers/patrol_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/translation_helper.dart';

class ReportsScreen extends StatefulWidget {
  final String? highlightLogId;

  const ReportsScreen({super.key, this.highlightLogId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'today';
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingUrl;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  
  Stream<List<Map<String, dynamic>>>? _logsStream;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _logsStream = SupabaseService().supabase
        .from('patrol_logs')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false);
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  DateTime _toIST(DateTime utcTime) {
    return utcTime.add(const Duration(hours: 5, minutes: 30));
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

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _logsStream,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          final filteredLogs = _filterLogs(logs);
          
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildFilterSection()),
              SliverToBoxAdapter(child: _buildSummaryCards(filteredLogs)),
              
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (filteredLogs.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final log = filteredLogs[index];
                        final isHighlighted = log['id'] == widget.highlightLogId;
                        return FadeTransition(
                          opacity: _fadeController,
                          child: _buildReportCard(log, isHighlighted: isHighlighted),
                        );
                      },
                      childCount: filteredLogs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterLogs(List<Map<String, dynamic>> logs) {
    final now = DateTime.now();
    return logs.where((log) {
      final logDate = DateTime.parse(log['timestamp']);
      if (_selectedFilter == 'today') {
        return logDate.day == now.day && logDate.month == now.month && logDate.year == now.year;
      } else if (_selectedFilter == 'week') {
        return now.difference(logDate).inDays <= 7;
      } else if (_selectedFilter == 'month') {
        return now.difference(logDate).inDays <= 30;
      }
      return true;
    }).toList();
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildCustomFilterChip('today', Icons.today_rounded),
            _buildCustomFilterChip('week', Icons.date_range_rounded),
            _buildCustomFilterChip('month', Icons.calendar_month_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFilterChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                ? Colors.blue.shade800.withOpacity(0.3) 
                : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.blue.shade800),
            const SizedBox(width: 10),
            Text(
              TranslationHelper.translate(label),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue.shade800,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> logs) {
    final alerts = logs.where((l) => l['checklist_results']['equipment_status'] != 'OK').length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: [
          _buildStatCard(TranslationHelper.translate('total_logs'), logs.length.toString(), Colors.blue.shade800, Icons.assignment_rounded),
          const SizedBox(width: 16),
          _buildStatCard(TranslationHelper.translate('issues'), alerts.toString(), alerts > 0 ? Colors.red.shade600 : Colors.green.shade600, Icons.warning_rounded),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> log, {bool isHighlighted = false}) {
    final status = log['checklist_results']['equipment_status'] ?? 'OK';
    final color = _getStatusColor(status);
    final timestamp = DateTime.parse(log['timestamp']);
    final istTime = _toIST(timestamp);
    final voiceUrl = log['voice_url'];
    
    List<String> photoUrls = [];
    if (log['photo_url'] != null) {
      if (log['photo_url'] is List) {
        photoUrls = List<String>.from(log['photo_url']);
      } else if (log['photo_url'] is String) {
        photoUrls = [log['photo_url'].toString()];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: isHighlighted ? Colors.blue.shade300 : Colors.transparent, width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isHighlighted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_getStatusIcon(status), color: color, size: 24),
          ),
          title: Text(
            log['supervisor_name'] ?? 'Supervisor',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
          ),
          subtitle: Text(
            '${log['checkpoint_name']} • ${DateFormat('hh:mm a').format(istTime)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrls.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Photo Evidence'),
                        TextButton.icon(
                          onPressed: () => _downloadFile(photoUrls.first),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Save All', style: TextStyle(fontSize: 11)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoGallery(photoUrls),
                    const SizedBox(height: 20),
                  ],
                  
                  if (voiceUrl != null && voiceUrl.toString().isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Voice Report'),
                        IconButton(
                          onPressed: () => _downloadFile(voiceUrl.toString()),
                          icon: const Icon(Icons.download_for_offline_rounded, color: Colors.blue),
                          iconSize: 20,
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildVoicePlayer(voiceUrl.toString()),
                    const SizedBox(height: 20),
                  ],

                  _buildDetailBox(istTime, log),
                  
                  const SizedBox(height: 20),
                  _buildSectionHeader('Inspection Checklist'),
                  const SizedBox(height: 12),
                  _buildChecklistMini(log['checklist_results']['items'] ?? {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade900, letterSpacing: 1.5),
    );
  }

  Widget _buildDetailBox(DateTime time, Map<String, dynamic> log) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildDetailItem(Icons.event_note_rounded, 'Full Date', DateFormat('dd MMM yyyy, hh:mm a').format(time)),
          const Divider(height: 24),
          _buildDetailItem(Icons.schedule_rounded, 'Shift Name', log['shift_name'] ?? 'N/A'),
          if (log['notes'] != null && log['notes'].toString().isNotEmpty) ...[
            const Divider(height: 24),
            _buildDetailItem(Icons.notes_rounded, 'Supervisor Notes', log['notes']),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade800),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoGallery(List<String> urls) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showZoomableImage(urls[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 15),
              width: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(image: NetworkImage(urls[index]), fit: BoxFit.cover),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent]),
                ),
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showZoomableImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(url))),
            Positioned(
              top: 40, 
              right: 20, 
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 30), 
                    onPressed: () => _downloadFile(url)
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30), 
                    onPressed: () => Navigator.pop(context)
                  ),
                ],
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoicePlayer(String url) {
    final isPlaying = _playingUrl == url;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 40),
            onPressed: () => _playVoice(url),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Recorded by supervisor', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistMini(Map<String, dynamic> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: items.values.map((val) {
          bool isChecked = val['checked'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: isChecked ? Colors.green : Colors.grey.shade300),
                const SizedBox(width: 12),
                Text(val['name'] ?? 'Task completed', style: TextStyle(fontSize: 13, color: isChecked ? Colors.black87 : Colors.grey, fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
            child: Icon(Icons.assignment_late_rounded, size: 64, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(TranslationHelper.translate('no_reports_found'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(TranslationHelper.translate('try_changing_filter'), style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'OK') return Colors.green.shade600;
    if (status == 'Needs Maintenance') return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'OK') return Icons.verified_user_rounded;
    if (status == 'Needs Maintenance') return Icons.engineering_rounded;
    return Icons.warning_amber_rounded;
  }
}
