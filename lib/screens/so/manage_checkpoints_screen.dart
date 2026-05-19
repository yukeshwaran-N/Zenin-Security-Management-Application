import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patrol_provider.dart';
import '../../models/checkpoint_model.dart';
import '../../services/location_service.dart';
import '../../utils/translation_helper.dart';

class ManageCheckpointsScreen extends StatefulWidget {
  const ManageCheckpointsScreen({super.key});

  @override
  State<ManageCheckpointsScreen> createState() => _ManageCheckpointsScreenState();
}

class _ManageCheckpointsScreenState extends State<ManageCheckpointsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<PatrolProvider>(context, listen: false);
    await provider.loadAllCheckpoints();
    if (mounted) _fadeController.forward(from: 0.0);
  }

  // Deletes checkpoint with confirmation dialog
  Future<void> _deleteCheckpoint(Checkpoint checkpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(TranslationHelper.translate('delete_checkpoint'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(TranslationHelper.translate('delete_confirm_prefix') + checkpoint.name + TranslationHelper.translate('delete_confirm_suffix')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationHelper.translate('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(TranslationHelper.translate('delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<PatrolProvider>(context, listen: false);
      final success = await provider.removeCheckpoint(checkpoint.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? TranslationHelper.translate('checkpoint_deleted') : TranslationHelper.translate('checkpoint_delete_failed')),
            backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Opens form to add or edit checkpoint
  void _openCheckpointForm({Checkpoint? checkpoint}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CheckpointFormSheet(
        checkpoint: checkpoint,
        onSave: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<PatrolProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.checkpoints.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue.shade800, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(TranslationHelper.translate('loading_checkpoints'), style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                    ),
                    const SizedBox(height: 24),
                    Text(TranslationHelper.translate('error_loading'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(provider.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: Text(TranslationHelper.translate('retry')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }

          if (provider.checkpoints.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pin_drop_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  Text(TranslationHelper.translate('no_checkpoints'), style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          // Group checkpoints by Block (first part of name e.g. "C4 - Entry" -> "C4")
          final Map<String, List<Checkpoint>> groupedCheckpoints = {};
          for (var cp in provider.checkpoints) {
            final block = cp.name.contains('-') ? cp.name.split('-')[0].trim() : 'Other';
            if (!groupedCheckpoints.containsKey(block)) {
              groupedCheckpoints[block] = [];
            }
            groupedCheckpoints[block]!.add(cp);
          }

          final blocks = groupedCheckpoints.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: _loadData,
            color: Colors.blue.shade800,
            child: FadeTransition(
              opacity: _fadeController,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: blocks.length,
                itemBuilder: (context, index) {
                  final block = blocks[index];
                  final blockPoints = groupedCheckpoints[block]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 8.0),
                        child: Text(
                          (TranslationHelper.translate('block_prefix') + block).toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue.shade800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...blockPoints.map((cp) {
                        final displayName = cp.name.contains('-') 
                            ? cp.name.split('-')[1].trim() 
                            : cp.name;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(Icons.location_on, color: Colors.blue.shade800, size: 24),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  cp.description.isNotEmpty ? cp.description : TranslationHelper.translate('no_description'),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.radar_rounded, size: 14, color: Colors.blue.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      TranslationHelper.translate('radius_prefix') + '${cp.radius}m',
                                      style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.checklist_rounded, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${cp.checklist.length}' + TranslationHelper.translate('items_suffix'),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                                  onPressed: () => _openCheckpointForm(checkpoint: cp),
                                  tooltip: TranslationHelper.translate('edit_point'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                                  onPressed: () => _deleteCheckpoint(cp),
                                  tooltip: TranslationHelper.translate('delete_point'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCheckpointForm(),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text(TranslationHelper.translate('add_point'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }
}

class CheckpointFormSheet extends StatefulWidget {
  final Checkpoint? checkpoint;
  final VoidCallback onSave;

  const CheckpointFormSheet({super.key, this.checkpoint, required this.onSave});

  @override
  State<CheckpointFormSheet> createState() => _CheckpointFormSheetState();
}

class _CheckpointFormSheetState extends State<CheckpointFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _blockController;
  late TextEditingController _pointController;
  late TextEditingController _descController;
  late TextEditingController _latController;
  late TextEditingController _lonController;
  
  double _radius = 15;
  bool _isGettingLocation = false;
  bool _isSaving = false;

  final List<TextEditingController> _checklistControllers = [];

  @override
  void initState() {
    super.initState();
    final cp = widget.checkpoint;

    String blockVal = '';
    String pointVal = '';
    if (cp != null) {
      if (cp.name.contains('-')) {
        final parts = cp.name.split('-');
        blockVal = parts[0].trim();
        pointVal = parts[1].trim();
      } else {
        pointVal = cp.name;
      }
    }

    _blockController = TextEditingController(text: blockVal);
    _pointController = TextEditingController(text: pointVal);
    _descController = TextEditingController(text: cp?.description ?? '');
    _latController = TextEditingController(text: cp?.latitude.toString() ?? '');
    _lonController = TextEditingController(text: cp?.longitude.toString() ?? '');
    _radius = cp?.radius.toDouble() ?? 15.0;

    // Load checklist items
    if (cp != null) {
      for (var item in cp.checklist) {
        _checklistControllers.add(TextEditingController(text: item.name));
      }
    } else {
      // Add 2 blank default items to make it friendly
      _checklistControllers.add(TextEditingController(text: 'Check locks and entryways'));
      _checklistControllers.add(TextEditingController(text: 'Check safety and utility equipment'));
    }
  }

  @override
  void dispose() {
    _blockController.dispose();
    _pointController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lonController.dispose();
    for (var controller in _checklistControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final position = await LocationService().getCurrentLocation();
      setState(() {
        _latController.text = position.latitude.toString();
        _lonController.text = position.longitude.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationHelper.translate('fetch_location_success')),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationHelper.translate('fetch_location_failed') + e.toString()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final block = _blockController.text.trim();
    final point = _pointController.text.trim();
    final name = block.isNotEmpty ? '$block - $point' : point;

    final desc = _descController.text.trim();
    final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
    final lon = double.tryParse(_lonController.text.trim()) ?? 0.0;
    final rad = _radius.toInt();

    final List<String> checklist = _checklistControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    setState(() => _isSaving = true);
    final provider = Provider.of<PatrolProvider>(context, listen: false);

    bool success;
    if (widget.checkpoint != null) {
      success = await provider.editCheckpoint(
        id: widget.checkpoint!.id,
        name: name,
        description: desc,
        latitude: lat,
        longitude: lon,
        radius: rad,
        checklistItems: checklist,
      );
    } else {
      success = await provider.addCheckpoint(
        name: name,
        description: desc,
        latitude: lat,
        longitude: lon,
        radius: rad,
        checklistItems: checklist,
      );
    }

    setState(() => _isSaving = false);

    if (success && mounted) {
      widget.onSave();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.checkpoint != null 
              ? TranslationHelper.translate('checkpoint_updated') 
              : TranslationHelper.translate('checkpoint_added')),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? TranslationHelper.translate('error_occurred')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isEdit = widget.checkpoint != null;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom sheet handle & title
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? TranslationHelper.translate('edit_patrol_point') : TranslationHelper.translate('add_patrol_point'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    // Block and Point Inputs
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _blockController,
                            decoration: InputDecoration(
                              labelText: TranslationHelper.translate('block_area'),
                              hintText: TranslationHelper.translate('eg_c4'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              prefixIcon: const Icon(Icons.business_rounded),
                            ),
                            validator: (v) => v!.isEmpty ? TranslationHelper.translate('required') : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _pointController,
                            decoration: InputDecoration(
                              labelText: TranslationHelper.translate('point_location'),
                              hintText: TranslationHelper.translate('eg_basement'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              prefixIcon: const Icon(Icons.pin_drop_rounded),
                            ),
                            validator: (v) => v!.isEmpty ? TranslationHelper.translate('required') : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: TranslationHelper.translate('description'),
                        hintText: TranslationHelper.translate('description_hint'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Coordinates Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(TranslationHelper.translate('coordinates_gps'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
                        ),
                        _isGettingLocation
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade800),
                              )
                            : TextButton.icon(
                                onPressed: _fetchCurrentLocation,
                                icon: const Icon(Icons.my_location_rounded, size: 16),
                                label: Text(TranslationHelper.translate('get_my_location'), style: TextStyle(fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(foregroundColor: Colors.blue.shade800),
                              ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: TranslationHelper.translate('latitude'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              prefixIcon: const Icon(Icons.navigation_outlined),
                            ),
                            validator: (v) => v!.isEmpty ? TranslationHelper.translate('required') : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lonController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: TranslationHelper.translate('longitude'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              prefixIcon: const Icon(Icons.navigation_outlined),
                            ),
                            validator: (v) => v!.isEmpty ? TranslationHelper.translate('required') : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Radius setting option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(TranslationHelper.translate('validation_radius'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
                        ),
                        Text(
                          "${_radius.round()}" + TranslationHelper.translate('meters'),
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blue.shade800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blue.shade700,
                        inactiveTrackColor: Colors.blue.shade50,
                        thumbColor: Colors.blue.shade800,
                        overlayColor: Colors.blue.shade800.withOpacity(0.12),
                      ),
                      child: Slider(
                        value: _radius,
                        min: 5.0,
                        max: 100.0,
                        divisions: 19, // Division steps of 5m
                        onChanged: (val) {
                          setState(() => _radius = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Checklist Items Editor
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(TranslationHelper.translate('checklist_tasks'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: Colors.blue.shade800),
                          onPressed: () {
                            setState(() {
                              _checklistControllers.add(TextEditingController());
                            });
                          },
                          tooltip: TranslationHelper.translate('add_checklist_task'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_checklistControllers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            TranslationHelper.translate('no_items_add_task'),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ...List.generate(_checklistControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _checklistControllers[index],
                                decoration: InputDecoration(
                                  labelText: TranslationHelper.translate('task_hash') + '${index + 1}',
                                  hintText: TranslationHelper.translate('eg_check_leakage'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.check_box_outlined),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _checklistControllers[index].dispose();
                                  _checklistControllers.removeAt(index);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              
              // Save button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEdit ? TranslationHelper.translate('save_changes_caps') : TranslationHelper.translate('create_point'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
