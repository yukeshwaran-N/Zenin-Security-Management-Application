import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/patrol_provider.dart';
import '../../utils/translation_helper.dart';

class SupervisorDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> supervisor;

  const SupervisorDetailsScreen({super.key, required this.supervisor});

  @override
  State<SupervisorDetailsScreen> createState() => _SupervisorDetailsScreenState();
}

class _SupervisorDetailsScreenState extends State<SupervisorDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatrols();
    });
  }

  Future<void> _loadPatrols() async {
    final provider = Provider.of<PatrolProvider>(context, listen: false);
    await provider.loadPatrolLogs(supervisorId: widget.supervisor['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supervisor['name']),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PatrolProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.supervisor['name'][0],
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.supervisor['name'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${TranslationHelper.translate('last_active')}: ${widget.supervisor['lastActive']}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TranslationHelper.translate('todays_patrols'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.patrolLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  TranslationHelper.translate('no_patrols_recorded_yet'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.patrolLogs.length,
                            itemBuilder: (context, index) {
                              final log = provider.patrolLogs[index];
                              final hasPhotos = log.photoUrls.isNotEmpty;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: hasPhotos
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    child: Icon(
                                      hasPhotos
                                          ? Icons.check
                                          : Icons.pending,
                                      color: hasPhotos
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  title: Text(log.checkpointName),
                                  subtitle: Text(
                                    DateFormat('hh:mm a').format(log.timestamp),
                                  ),
                                  trailing: hasPhotos
                                      ? const Icon(Icons.image, color: Colors.blue)
                                      : null,
                                  onTap: () {
                                    _showPatrolDetails(log);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPatrolDetails(dynamic log) {
    final checklistData = log.checklistResults['items'] as Map<String, dynamic>? ?? {};
    final equipStatus = log.checklistResults['equipment_status'] ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  TranslationHelper.translate('patrol_details'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow(TranslationHelper.translate('checkpoint'), log.checkpointName),
                _buildDetailRow(
                  TranslationHelper.translate('time'),
                  DateFormat('hh:mm a, dd MMM yyyy').format(log.timestamp),
                ),
                _buildDetailRow(
                  TranslationHelper.translate('location'),
                  '${log.latitude.toStringAsFixed(6)}, ${log.longitude.toStringAsFixed(6)}',
                ),
                _buildDetailRow(TranslationHelper.translate('status'), equipStatus),
                const SizedBox(height: 16),
                
                if (log.photoUrls.isNotEmpty) ...[
                  Text(TranslationHelper.translate('photo_evidence'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: log.photoUrls.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            log.photoUrls[index],
                            height: 200,
                            width: 300,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  TranslationHelper.translate('checklist_results'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: checklistData.isEmpty
                      ? Center(child: Text(TranslationHelper.translate('no_checklist_items')))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: checklistData.length,
                          itemBuilder: (context, index) {
                            final key = checklistData.keys.elementAt(index);
                            final val = checklistData[key] as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  val['checked'] == true
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: val['checked'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                title: Text('Item $key'),
                                subtitle: val['notes']?.isNotEmpty == true
                                    ? Text(val['notes'])
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
