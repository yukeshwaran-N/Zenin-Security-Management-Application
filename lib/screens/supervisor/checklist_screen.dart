import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/checkpoint_model.dart';
import '../../providers/patrol_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/translation_helper.dart';
import 'photo_upload_screen.dart';

class ChecklistScreen extends StatefulWidget {
  final Checkpoint checkpoint;

  const ChecklistScreen({super.key, required this.checkpoint});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> with SingleTickerProviderStateMixin {
  final Map<String, dynamic> _results = {};
  String _equipmentStatus = 'OK';
  final List<File> _photos = [];
  File? _voiceFile;
  String? _notes;
  bool _isSubmitting = false;
  
  // Audio
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    
    for (var item in widget.checkpoint.checklist) {
      _results[item.id] = {
        'checked': false,
        'notes': '',
      };
    }
    _fadeController.forward();
    
    // Check permission on start
    _audioRecorder.hasPermission();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final isRecording = await _audioRecorder.isRecording();
        if (isRecording) return;

        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // Using a simpler config to avoid issues
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
          _voiceFile = null;
        });
        debugPrint('Recording started: $path');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required')));
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final isRecording = await _audioRecorder.isRecording();
      if (!isRecording) return;

      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _voiceFile = File(path);
        });
        debugPrint('Recording stopped, saved to: $path');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _playRecording() async {
    if (_voiceFile == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_voiceFile!.path));
        setState(() => _isPlaying = true);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Consumer2<PatrolProvider, AuthProvider>(
                  builder: (context, patrolProvider, authProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(TranslationHelper.translate('status_check')),
                        const SizedBox(height: 16),
                        _buildStatusGrid(),
                        
                        const SizedBox(height: 32),

                        if (_equipmentStatus != 'OK') ...[
                          _buildSectionTitle(TranslationHelper.translate('report_issue')),
                          const SizedBox(height: 16),
                          _buildNotesField(),
                          const SizedBox(height: 24),
                          _buildVoiceSection(),
                          const SizedBox(height: 32),
                        ],

                        _buildSectionTitle(TranslationHelper.translate('photo_evidence')),
                        const SizedBox(height: 16),
                        _buildMultiplePhotoSelector(),

                        const SizedBox(height: 48),

                        _buildSubmitButton(patrolProvider, authProvider),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade800,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              TranslationHelper.translate('inspection_checklist'),
              style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.checkpoint.name,
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.blue.shade900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatusGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          _buildStatusItem('OK', Icons.check_circle_rounded, Colors.green),
          _buildStatusItem('Needs Maintenance', Icons.engineering_rounded, Colors.orange),
          _buildStatusItem('Damaged', Icons.warning_rounded, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String status, IconData icon, Color color) {
    final isSelected = _equipmentStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _equipmentStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected ? [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
            ] : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 28),
              const SizedBox(height: 8),
              Text(
                status == 'OK' ? TranslationHelper.translate('ok') : (status == 'Damaged' ? TranslationHelper.translate('damaged') : TranslationHelper.translate('support')),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: TranslationHelper.translate('enter_details'),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
        ),
        maxLines: 3,
        onChanged: (val) => setState(() => _notes = val),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRecorderButton(),
              if (_voiceFile != null && !_isRecording) _buildPlayButton(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording 
              ? TranslationHelper.translate('recording_active') 
              : (_voiceFile != null ? TranslationHelper.translate('release_to_send') : TranslationHelper.translate('hold_to_record')),
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.bold,
              color: _isRecording ? Colors.red : Colors.blue.shade800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorderButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.all(_isRecording ? 25 : 20),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : Colors.blue.shade800,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.red : Colors.blue.shade800).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: _isRecording ? 5 : 0,
            )
          ],
        ),
        child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 34),
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _playRecording,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.blue.shade800, size: 34),
      ),
    );
  }

  Widget _buildMultiplePhotoSelector() {
    return Column(
      children: [
        if (_photos.isNotEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                        image: DecorationImage(image: FileImage(_photos[index]), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 20,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(index)),
                        child: const CircleAvatar(
                          radius: 12, 
                          backgroundColor: Colors.black54, 
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 14)
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        InkWell(
          onTap: () async {
            final photo = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoUploadScreen()));
            if (photo != null) setState(() => _photos.add(photo as File));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade50, style: BorderStyle.solid),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, color: Colors.blue.shade800),
                const SizedBox(width: 12),
                Text(
                  TranslationHelper.translate('photo_evidence').toUpperCase(), 
                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.1)
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(PatrolProvider patrolProvider, AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!_isSubmitting)
            BoxShadow(
              color: Colors.blue.shade800.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitPatrol,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : Text(
                TranslationHelper.translate('submit').toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
      ),
    );
  }

  Future<void> _submitPatrol() async {
    setState(() => _isSubmitting = true);
    try {
      final patrolProvider = Provider.of<PatrolProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      await patrolProvider.submitPatrol(
        checkpoint: widget.checkpoint,
        checklistResults: {'items': _results, 'equipment_status': _equipmentStatus},
        photos: _photos, // Sending the list of photos
        voice: _voiceFile,
        notes: _notes,
        auth: authProvider,
      );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
