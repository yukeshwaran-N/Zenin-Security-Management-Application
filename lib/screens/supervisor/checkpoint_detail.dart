import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checkpoint_model.dart';
import '../../providers/patrol_provider.dart';
import '../../utils/translation_helper.dart';
import 'checklist_screen.dart';

class CheckpointDetail extends StatefulWidget {
  final Checkpoint checkpoint;

  const CheckpointDetail({super.key, required this.checkpoint});

  @override
  State<CheckpointDetail> createState() => _CheckpointDetailState();
}

class _CheckpointDetailState extends State<CheckpointDetail> with SingleTickerProviderStateMixin {
  bool _isVerifying = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PatrolProvider>(context, listen: false).clearError();
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Consumer<PatrolProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(TranslationHelper.translate('checkpoint_details')),
                        const SizedBox(height: 16),
                        _buildDetailCard(provider),
                        const SizedBox(height: 32),
                        if (provider.error != null) ...[
                          _buildErrorBanner(provider.error!),
                          const SizedBox(height: 24),
                        ],
                        _buildStartButton(provider),
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
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.checkpoint.name,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 18),
        ),
        centerTitle: true,
        background: Container(
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded, size: 48, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 30),
            ],
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDetailCard(PatrolProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoItem(Icons.description_outlined, TranslationHelper.translate('description'), widget.checkpoint.description),
          _buildDivider(),
          _buildInfoItem(Icons.radar_rounded, TranslationHelper.translate('radius'), '${widget.checkpoint.radius} ${TranslationHelper.translate('meters')}'),
          _buildDivider(),
          _buildInfoItem(Icons.playlist_add_check_rounded, TranslationHelper.translate('tasks'), '${widget.checkpoint.checklist.length} ${TranslationHelper.translate('checkpoint_items')}'),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 65, endIndent: 20, color: Colors.grey.shade100);
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.blue.shade800, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(PatrolProvider provider) {
    bool loading = _isVerifying || provider.isLoading;
    
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!loading)
            BoxShadow(
              color: Colors.blue.shade700.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading
            ? null
            : () async {
                setState(() => _isVerifying = true);
                final success = await provider.verifyLocation(widget.checkpoint);
                setState(() => _isVerifying = false);
                if (success && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChecklistScreen(checkpoint: widget.checkpoint)),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : Text(
                TranslationHelper.translate('start_patrol').toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
      ),
    );
  }
}
