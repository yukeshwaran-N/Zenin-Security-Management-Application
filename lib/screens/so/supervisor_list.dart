import 'package:flutter/material.dart';
import '../../utils/translation_helper.dart';
import 'package:provider/provider.dart';
import '../../utils/translation_helper.dart';
import '../../providers/patrol_provider.dart';
import 'supervisor_details.dart';
import 'add_supervisor_screen.dart';

class SupervisorListScreen extends StatefulWidget {
  const SupervisorListScreen({super.key});

  @override
  State<SupervisorListScreen> createState() => _SupervisorListScreenState();
}

class _SupervisorListScreenState extends State<SupervisorListScreen> with SingleTickerProviderStateMixin {
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
    await provider.loadSupervisorStats();
    if (mounted) _fadeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Important for SODashboard layout
      body: Consumer<PatrolProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.supervisorStats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue.shade800, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(TranslationHelper.translate('loading_supervisors'), style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w500)),
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
                    const Text('Connection Issue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(provider.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.supervisorStats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  Text(TranslationHelper.translate('no_supervisors'), style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh List'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: Colors.blue.shade800,
            child: FadeTransition(
              opacity: _fadeController,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Increased bottom padding to avoid FAB/Nav overlap
                itemCount: provider.supervisorStats.length,
                itemBuilder: (context, index) {
                  final stats = provider.supervisorStats[index];
                  final supervisor = stats['user'];
                  final bool isActive = stats['lastActive'] == 'Just now';
                  
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 50 + (index * 20)),
                    curve: Curves.easeOutQuad,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupervisorDetailsScreen(
                              supervisor: {
                                'id': supervisor.id,
                                'name': supervisor.name,
                                'status': isActive ? 'Active' : 'Offline',
                                'completed': stats['completed'],
                                'total': stats['total'],
                                'lastActive': stats['lastActive'],
                                'photo': supervisor.photoUrl,
                              },
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Hero(
                                  tag: 'sv_avatar_${supervisor.id}',
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isActive ? Colors.green.shade400 : Colors.grey.shade200,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.blue.shade50,
                                      backgroundImage: supervisor.photoUrl != null 
                                          ? NetworkImage(supervisor.photoUrl!) 
                                          : null,
                                      child: supervisor.photoUrl == null
                                          ? Text(
                                              supervisor.name[0].toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    supervisor.name,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        stats['lastActive'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: stats['completed'] == stats['total'] && stats['total'] > 0
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${stats['completed']}/${stats['total']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: stats['completed'] == stats['total'] && stats['total'] > 0
                                          ? Colors.green.shade700
                                          : Colors.blue.shade800,
                                    ),
                                  ),
                                  Text(TranslationHelper.translate('done'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AddSupervisorScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(Tween(begin: const Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic))),
                  child: child,
                );
              },
            ),
          );
        },
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(TranslationHelper.translate('new_supervisor'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }
}
