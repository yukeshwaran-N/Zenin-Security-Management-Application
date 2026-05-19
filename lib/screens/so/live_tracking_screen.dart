import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../providers/patrol_provider.dart';
import '../../providers/auth_provider.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  
  // Manyata Tech Park, Bengaluru Coordinates
  final LatLng _manyataPark = const LatLng(13.0451, 77.6266);
  late LatLng _mapCenter;
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    _mapCenter = _manyataPark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<PatrolProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (auth.currentUser != null) {
      await provider.loadCheckpoints(auth.currentUser!.id);
    }
    await provider.loadSupervisorStats();
    
    if (provider.checkpoints.isNotEmpty) {
      final firstCp = provider.checkpoints.firstWhere((cp) => cp.latitude != 0, orElse: () => provider.checkpoints.first);
      if (firstCp.latitude != 0.0) {
        setState(() {
          _mapCenter = LatLng(firstCp.latitude, firstCp.longitude);
        });
        _mapController.move(_mapCenter, 17);
      } else {
        _mapController.move(_manyataPark, 16);
      }
    } else {
      _mapController.move(_manyataPark, 16);
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 110, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatrolProvider>(
      builder: (context, provider, child) {
        final checkpointMarkers = provider.checkpoints.where((cp) => cp.latitude != 0).map((cp) {
          return Marker(
            point: LatLng(cp.latitude, cp.longitude),
            width: 45,
            height: 45,
            child: GestureDetector(
              onTap: () => _showInfo('Checkpoint: ${cp.name}'),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.security_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          );
        }).toList();

        return Scaffold(
          body: Stack(
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: SupabaseService().supervisorLocationsStream,
                builder: (context, snapshot) {
                  List<Marker> supervisorMarkers = [];
                  if (snapshot.hasData) {
                    supervisorMarkers = snapshot.data!.map((loc) {
                      final statsList = provider.supervisorStats.where(
                        (s) => s['user'].id == loc['supervisor_id'],
                      );
                      final name = statsList.isNotEmpty ? statsList.first['user'].name : 'Unknown';

                      return Marker(
                        point: LatLng(loc['latitude'], loc['longitude']),
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showInfo('Supervisor: $name'),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white,
                                  child: Text(name[0].toUpperCase(), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList();
                  }

                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _mapCenter,
                      zoom: 16,
                      maxZoom: 19,
                      minZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.embassy_patrol',
                      ),
                      CircleLayer(
                        circles: provider.checkpoints.where((cp) => cp.latitude != 0).map((cp) {
                          return CircleMarker(
                            point: LatLng(cp.latitude, cp.longitude),
                            radius: cp.radius.toDouble(),
                            useRadiusInMeter: true,
                            color: Colors.blue.withOpacity(0.1),
                            borderColor: Colors.blue.shade800,
                            borderStrokeWidth: 1.5,
                          );
                        }).toList(),
                      ),
                      MarkerLayer(markers: checkpointMarkers),
                      MarkerLayer(markers: supervisorMarkers),
                    ],
                  );
                },
              ),
              
              // Floating Stats Bar at Top
              Positioned(
                top: 15,
                left: 15,
                right: 15,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  child: _showStats 
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Row(
                          children: [
                            _buildTopStat(
                              'ACTIVE', 
                              '${provider.supervisorStats.where((s) => s['lastActive'].toString().contains('now')).length}',
                              Colors.green.shade700
                            ),
                            _buildVerticalDivider(),
                            _buildTopStat(
                              'POINTS', 
                              '${provider.checkpoints.length}', 
                              Colors.blue.shade800
                            ),
                            _buildVerticalDivider(),
                            _buildTopStat(
                              'VISITS', 
                              '${provider.supervisorStats.fold<int>(0, (sum, item) => sum + (item['completed'] as int))}', 
                              Colors.orange.shade800
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_fullscreen_rounded, size: 18, color: Colors.grey),
                              onPressed: () => setState(() => _showStats = false),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => setState(() => _showStats = true),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                            ),
                            child: Icon(Icons.bar_chart_rounded, color: Colors.blue.shade800),
                          ),
                        ),
                      ),
                ),
              ),

              // Legend
              Positioned(
                top: 80,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Point', Colors.blue.shade800),
                      const SizedBox(height: 4),
                      _buildLegendItem('Live', Colors.green.shade600),
                    ],
                  ),
                ),
              ),

              // Map Controls
              Positioned(
                bottom: 110,
                right: 15,
                child: Column(
                  children: [
                    _buildMapAction(
                      icon: Icons.my_location_rounded,
                      onTap: () => _mapController.move(_mapCenter, 17),
                    ),
                    const SizedBox(height: 12),
                    _buildMapAction(
                      icon: Icons.layers_rounded,
                      onTap: () => _showInfo('Layer settings coming soon'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 25,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.grey.shade200,
    );
  }

  Widget _buildTopStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, height: 1)),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildMapAction({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: Colors.blue.shade800, size: 22),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }
}
