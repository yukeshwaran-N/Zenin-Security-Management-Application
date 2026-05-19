import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patrol_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/checkpoint_model.dart';
import '../../models/shift_model.dart';
import '../../utils/translation_helper.dart';
import '../../services/supabase_service.dart';
import 'checkpoint_detail.dart';
import '../so/profile_screen.dart';
import 'history_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _fadeController;
  final Map<String, bool> _expandedBlocks = {
    'C4': true,
    'C2': false,
    'C1': false,
  };

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return TranslationHelper.translate('good_morning');
    if (hour < 17) return TranslationHelper.translate('good_afternoon');
    return TranslationHelper.translate('good_evening');
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        Provider.of<PatrolProvider>(context, listen: false).loadCheckpoints(auth.currentUser!.id);
      }
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
    final provider = Provider.of<PatrolProvider>(context);
    
    final List<Widget> _screens = [
      _buildDutyView(provider, auth),
      const SVHistoryScreen(),
      const SOProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
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
                          user?.name ?? 'Supervisor',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildLanguageToggle(),
                  const SizedBox(width: 10),
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
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDutyView(PatrolProvider provider, AuthProvider auth) {
    return Column(
      children: [
        _buildHeader(provider),
        Expanded(
          child: provider.isLoading && provider.checkpoints.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.loadCheckpoints(auth.currentUser!.id),
                  color: Colors.blue.shade800,
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _buildGroupedCheckpointList(provider),
                  ),
                ),
        ),
      ],
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
            _buildNavItem(Icons.assignment_rounded, TranslationHelper.translate('duty'), 0),
            _buildNavItem(Icons.history_rounded, TranslationHelper.translate('history'), 1),
            _buildNavItem(Icons.person_rounded, TranslationHelper.translate('profile'), 2),
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


  Widget _buildLanguageToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          TranslationHelper.isHindi = !TranslationHelper.isHindi;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              TranslationHelper.isHindi ? 'HI' : 'EN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProfileIcon(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return GestureDetector(
      onTap: () => _onItemTapped(2), // Switch to profile tab
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
    );
  }

  Widget _buildHeader(PatrolProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              TranslationHelper.translate('duty_session').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
              ],
              border: Border.all(color: Colors.blue.shade50),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Shift>(
                value: provider.selectedShift,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue.shade800),
                hint: Text(
                  TranslationHelper.translate('select_shift'),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
                items: Shift.allShifts.map((shift) {
                  String translationKey = shift.name.replaceAll('-', '_').replaceAll(' ', '_').toLowerCase();
                  return DropdownMenuItem(
                    value: shift,
                    child: Text(
                      '${TranslationHelper.translate(translationKey)} (${shift.startTime.format(context)})',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (shift) => provider.setSelectedShift(shift),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCheckpointList(PatrolProvider provider) {
    if (provider.checkpoints.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  TranslationHelper.translate('no_checkpoints'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final Map<String, List<Checkpoint>> grouped = {};
    for (var cp in provider.checkpoints) {
      final block = cp.name.contains('-') ? cp.name.split('-')[0].trim() : 'Other';
      grouped.putIfAbsent(block, () => []).add(cp);
    }

    final blocks = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        final checkpoints = grouped[block]!;
        final isExpanded = _expandedBlocks[block] ?? false;
        
        final completedInBlock = checkpoints.where((cp) => provider.getVisitCount(cp.id) >= 2).length;
        final totalInBlock = checkpoints.length;

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedBlocks[block] = !isExpanded;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: isExpanded 
                    ? LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600])
                    : null,
                  color: isExpanded ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: isExpanded ? null : Border.all(color: Colors.blue.shade50),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.business_rounded, 
                      color: isExpanded ? Colors.white : Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${TranslationHelper.translate('block_prefix')} $block',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExpanded ? Colors.white24 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$completedInBlock/$totalInBlock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? Colors.white : Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? Colors.white70 : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...checkpoints.map((cp) => _buildCheckpointCard(cp, provider)).toList(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildCheckpointCard(Checkpoint checkpoint, PatrolProvider provider) {
    final visitCount = provider.getVisitCount(checkpoint.id);
    final isFullyCompleted = visitCount >= 2;
    final displayName = checkpoint.name.contains('-') ? checkpoint.name.split('-')[1].trim() : checkpoint.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
        border: Border.all(
          color: isFullyCompleted ? Colors.green.shade100 : Colors.blue.shade50,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (provider.selectedShift == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TranslationHelper.translate('select_shift')),
                  backgroundColor: Colors.orange.shade800,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CheckpointDetail(checkpoint: checkpoint)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isFullyCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFullyCompleted ? Icons.verified_rounded : Icons.location_on_rounded,
                    color: isFullyCompleted ? Colors.green.shade600 : Colors.blue.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildStepIndicator(visitCount >= 1),
                          const SizedBox(width: 4),
                          _buildStepIndicator(visitCount >= 2),
                          const SizedBox(width: 10),
                          Text(
                            isFullyCompleted ? TranslationHelper.translate('done') : '$visitCount/2',
                            style: TextStyle(
                              color: isFullyCompleted ? Colors.green.shade700 : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool filled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 20,
      height: 6,
      decoration: BoxDecoration(
        color: filled ? Colors.green.shade500 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(3),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 24, color: Colors.white),
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
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(note['title']), behavior: SnackBarBehavior.floating),
              );
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
                      Text(TranslationHelper.translate('clear_read_notifications'), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              );
              items.add(const PopupMenuDivider());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              items.add(PopupMenuItem(enabled: false, child: Center(child: Text(TranslationHelper.translate('no_new_alerts'), style: const TextStyle(fontSize: 13)))));
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
}
