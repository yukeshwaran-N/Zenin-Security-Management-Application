import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patrol_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/translation_helper.dart';
import 'supervisor_list.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'manage_checkpoints_screen.dart';

class SODashboard extends StatefulWidget {
  const SODashboard({super.key});

  @override
  State<SODashboard> createState() => _SODashboardState();
}

class _SODashboardState extends State<SODashboard> {
  int _selectedIndex = 0;
  String? _highlightLogId;
  final PageController _pageController = PageController();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return TranslationHelper.translate('good_morning');
    if (hour < 17) return TranslationHelper.translate('good_afternoon');
    return TranslationHelper.translate('good_evening');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 2) _highlightLogId = null;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final List<Widget> _screens = [
      const SupervisorListScreen(),
      const ManageCheckpointsScreen(),
      ReportsScreen(highlightLogId: _highlightLogId),
      const SOProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade800, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade900.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _buildTopProfileIcon(context),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), letterSpacing: 1.2, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.name ?? TranslationHelper.translate('admin'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildLanguageToggle(),
                  const SizedBox(width: 8),
                  _buildSettingsButton(context),
                  const SizedBox(width: 8),
                  _buildNotificationIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 2) _highlightLogId = null;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildLanguageToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          TranslationHelper.isHindi = !TranslationHelper.isHindi;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              TranslationHelper.isHindi ? 'HI' : 'EN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SOSettingsScreen())),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.settings_outlined, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.people_alt_rounded, TranslationHelper.translate('supervisors'), 0),
            _buildNavItem(Icons.pin_drop_rounded, TranslationHelper.translate('points'), 1),
            _buildNavItem(Icons.assessment_rounded, TranslationHelper.translate('reports'), 2),
            _buildNavItem(Icons.person_rounded, TranslationHelper.translate('profile'), 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade800 : Colors.grey.shade400,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData 
            ? snapshot.data!.where((n) => n['is_read'] == false).length 
            : 0;
        final hasRead = snapshot.hasData && snapshot.data!.any((n) => n['is_read'] == true);

        return PopupMenuButton<dynamic>(
          offset: const Offset(0, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 12,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue.shade800, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onSelected: (value) async {
            if (value == 'clear_read') {
              await SupabaseService().clearReadNotifications();
            } else if (value is Map<String, dynamic>) {
              final note = value;
              await SupabaseService().supabase
                  .from('notifications')
                  .update({'is_read': true})
                  .eq('id', note['id']);
              
              _onItemTapped(2);
              setState(() {
                _highlightLogId = note['related_id'];
              });
            }
          },
          itemBuilder: (context) {
            List<PopupMenuEntry<dynamic>> items = [];
            
            if (hasRead) {
              items.add(
                PopupMenuItem<String>(
                  value: 'clear_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      const Text('Clear Read Notifications', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              );
              items.add(const PopupMenuDivider());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              items.add(const PopupMenuItem(enabled: false, child: Center(child: Text('No new alerts'))));
            } else {
              items.addAll(snapshot.data!.map((note) => PopupMenuItem<Map<String, dynamic>>(
                value: note,
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: note['is_read'] ? Colors.grey.shade100 : Colors.blue.shade50,
                        child: Icon(Icons.security_rounded, size: 18, color: note['is_read'] ? Colors.grey : Colors.blue.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note['title'], style: TextStyle(fontWeight: note['is_read'] ? FontWeight.normal : FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            Text(note['message'], style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )));
            }
            return items;
          },
        );
      },
    );
  }

  Widget _buildTopProfileIcon(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return PopupMenuButton<String>(
      offset: const Offset(0, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Hero(
        tag: 'profile_pic',
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Text(
              user?.name[0].toUpperCase() ?? 'S',
              style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
      ),
      onSelected: (value) async {
        if (value == 'logout') {
          await auth.logout();
        } else if (value == 'settings') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SOSettingsScreen()));
        } else if (value == 'lang') {
          setState(() {
            TranslationHelper.isHindi = !TranslationHelper.isHindi;
          });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade50,
                child: Text(user?.name[0].toUpperCase() ?? 'S', style: TextStyle(fontSize: 14, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user?.name ?? 'SO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                    Text(user?.role ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            title: Text(TranslationHelper.translate('logout'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
