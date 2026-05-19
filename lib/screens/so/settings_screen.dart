import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patrol_provider.dart';
import '../../utils/translation_helper.dart';

class SOSettingsScreen extends StatefulWidget {
  const SOSettingsScreen({super.key});

  @override
  State<SOSettingsScreen> createState() => _SOSettingsScreenState();
}

class _SOSettingsScreenState extends State<SOSettingsScreen> {
  final TextEditingController _intervalController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PatrolProvider>(context, listen: false);
    _intervalController.text = provider.minIntervalMinutes.toString();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final minutes = int.tryParse(_intervalController.text);
    if (minutes == null || minutes < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationHelper.translate('invalid_minutes'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<PatrolProvider>(context, listen: false);
      await provider.updateGlobalInterval(minutes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationHelper.translate('settings_updated')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationHelper.translate('app_settings')),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationHelper.translate('patrol_frequency'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              TranslationHelper.translate('patrol_frequency_desc'),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: TranslationHelper.translate('minimum_interval_mins'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.timer),
                suffixText: TranslationHelper.translate('mins'),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(TranslationHelper.translate('save_changes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
