import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_models.dart';
import '../data/energy_tips.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../models/outage_report.dart';
import '../models/fuel_station.dart';
import '../app.dart';
import 'package:intl/intl.dart';

class BayanihanScreen extends StatefulWidget {
  final StorageService storage;
  const BayanihanScreen({super.key, required this.storage});
  @override
  State<BayanihanScreen> createState() => _BayanihanScreenState();
}

class _BayanihanScreenState extends State<BayanihanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _firebaseService = FirebaseService();
  List<BayanihanPost> _posts = [];
  bool _nearMeOnly = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    var saved = await widget.storage.getBayanihanPosts();
    // Logic for loading/seeding omitted for brevity in write_to_file if same, 
    // but I'll keep the full file structure to be safe.
    setState(() => _posts = saved);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BayanihanPost>>(
      stream: _firebaseService.getBayanihanPostsStream(),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        
        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Image.asset('assets/kuryentahin.png', height: 28),
              const SizedBox(width: 8),
              const Text('Bayanihan Board'),
            ]),
            actions: [
              Row(children: [
                const Text('Near Me', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                Switch(value: _nearMeOnly, onChanged: (v) => setState(() => _nearMeOnly = v)),
              ]),
            ],
            bottom: TabBar(controller: _tabCtrl, isScrollable: true, tabs: const [
              Tab(text: '📡 Live Feed'), Tab(text: '🔌 Generator'), Tab(text: '⛽ Fuel Pool'), Tab(text: '🔋 Charging'), Tab(text: '🏪 Business'),
            ]),
          ),
          body: TabBarView(controller: _tabCtrl, children: [
            _buildLiveFeedTab(posts),
            _postList(BayanihanCategory.generator, posts),
            _postList(BayanihanCategory.fuelPool, posts),
            _postList(BayanihanCategory.charging, posts),
            _postList(BayanihanCategory.businessSos, posts),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createPost,
            icon: const Icon(Icons.add),
            label: const Text('Post'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
          ),
        );
      }
    );
  }

  Widget _postList(BayanihanCategory cat, List<BayanihanPost> allPosts) {
    final posts = allPosts.where((p) => p.category == cat).toList();
    if (posts.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(cat == BayanihanCategory.generator ? '🔌' : cat == BayanihanCategory.fuelPool ? '⛽' : cat == BayanihanCategory.charging ? '🔋' : '🏪', style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Wala pang post dito', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
      const Text('Maging una! Tap + to post.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]));

    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: posts.length, itemBuilder: (_, i) => _postCard(posts[i]));
  }

  Widget _postCard(BayanihanPost p) {
    final timeAgo = _timeAgo(p.createdAt);
    final uid = _firebaseService.currentUser?.uid;
    final isInterested = p.interestedUserIds.contains(uid);
    final isSalamat = p.salamatUserIds.contains(uid);

    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: Text('${p.categoryEmoji} ${p.categoryLabel}', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600))),
        const Spacer(),
        Text(timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 8),
      Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 4),
      Text(p.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
      if (p.location != null) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
        const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(p.location!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ])),
      if (p.availability != null) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
        const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(p.availability!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ])),
      const SizedBox(height: 12),
      Row(children: [
        _reactionBtn('🙋 Interested', p.interestedCount, isInterested, 
          onTap: () => _firebaseService.reactToBayanihanPost(p, 'interested'),
          onCountTap: () => _showReactedUsers(p.interestedUserIds, 'Interested Bayanis'),
        ),
        const SizedBox(width: 12),
        _reactionBtn('🙏 Salamat', p.salamatCount, isSalamat, 
          onTap: () => _firebaseService.reactToBayanihanPost(p, 'salamat'),
          onCountTap: () => _showReactedUsers(p.salamatUserIds, 'Salamat from...'),
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.comment_outlined, size: 14), 
          label: Text('Comments ${p.commentCount > 0 ? "(${p.commentCount})" : ""}', style: const TextStyle(fontSize: 11)), 
          onPressed: () => _showComments(p),
        ),
      ]),
    ])));
  }

  Widget _reactionBtn(String label, int count, bool isActive, {required VoidCallback onTap, required VoidCallback onCountTap}) => Container(
    decoration: BoxDecoration(
      color: isActive ? AppColors.primary.withAlpha(30) : AppColors.surfaceLight, 
      borderRadius: BorderRadius.circular(20), 
      border: Border.all(color: isActive ? AppColors.primary : AppColors.border)
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap, 
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
            child: Text(label, style: TextStyle(fontSize: 11, color: isActive ? AppColors.primary : AppColors.textPrimary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        InkWell(
          onTap: onCountTap,
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 12, top: 6, bottom: 6),
            child: Text('$count', style: TextStyle(fontSize: 11, color: isActive ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );

  void _showReactedUsers(List<String> uids, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, String>>>(
              future: _firebaseService.getUserNames(uids),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final users = snap.data ?? [];
                if (users.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('No reactions yet.'));
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                    title: Text(users[i]['name']!, style: const TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComments(BayanihanPost p) {
    final TextEditingController commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Comments on "${p.title}"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                child: StreamBuilder<List<BayanihanComment>>(
                  stream: _firebaseService.getCommentsStream(p.id),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('No comments yet. Be the first!', style: TextStyle(color: AppColors.textMuted)));
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          subtitle: Text(c.content, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          trailing: Text(_timeAgo(c.createdAt), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                        );
                      },
                    );
                  }
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: AppColors.background, size: 20),
                        onPressed: () async {
                          if (commentCtrl.text.trim().isEmpty) return;
                          await _firebaseService.addCommentToPost(p, commentCtrl.text.trim());
                          commentCtrl.clear();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Widget _buildLiveFeedTab(List<BayanihanPost> allPosts) {
    return StreamBuilder<List<OutageReport>>(
      stream: _firebaseService.getOutagesStream(),
      builder: (context, outageSnap) {
        return StreamBuilder<List<FuelStation>>(
          stream: _firebaseService.getFuelStationsStream(),
          builder: (context, fuelSnap) {
            final outages = outageSnap.data ?? [];
            final fuels = (fuelSnap.data ?? []).where((s) => s.status != StationStatus.unknown).toList();
            
            final List<Map<String, dynamic>> activities = [];
            
            for (var o in outages) {
              activities.add({
                'type': 'brownout',
                'title': 'Reported: ${o.status.name.toUpperCase()}',
                'subtitle': o.barangay,
                'time': o.reportedAt,
                'data': o,
              });
            }
            
            for (var f in fuels) {
              activities.add({
                'type': 'fuel',
                'title': '${f.brand} is ${f.status.name.toUpperCase()}',
                'subtitle': '${f.name} • ${f.reportCount} reports',
                'time': f.lastUpdated,
                'data': f,
              });
            }

            for (var p in allPosts) {
              activities.add({
                'type': 'post',
                'title': p.title,
                'subtitle': '${p.categoryLabel} • ${p.location ?? "Nearby"}',
                'time': p.createdAt,
                'data': p,
              });
            }

            activities.sort((a, b) {
              final aTime = a['time'] is DateTime ? a['time'] : (a['time'] as dynamic).toDate();
              final bTime = b['time'] is DateTime ? b['time'] : (b['time'] as dynamic).toDate();
              return bTime.compareTo(aTime);
            });

            if (activities.isEmpty) return const Center(child: Text('Wala pang live updates...', style: TextStyle(color: AppColors.textMuted)));

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final act = activities[index];
                final time = act['time'] is DateTime ? act['time'] : (act['time'] as dynamic).toDate();
                return _liveActivityCard(act, time);
              },
            );
          },
        );
      },
    );
  }

  Widget _liveActivityCard(Map<String, dynamic> act, DateTime time) {
    final IconData icon = act['type'] == 'brownout' ? Icons.power_off : act['type'] == 'fuel' ? Icons.local_gas_station : Icons.handshake;
    final Color color = act['type'] == 'brownout' ? AppColors.danger : act['type'] == 'fuel' ? AppColors.primary : AppColors.success;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withAlpha(20), child: Icon(icon, color: color, size: 20)),
        title: Text(act['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${act['subtitle']} • ${_timeAgo(time)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () {
          if (act['type'] == 'brownout') {
             AppShell.shellKey.currentState?.jumpToReport(act['data']);
          } else if (act['type'] == 'post') {
             // Handle navigation
          }
        },
      ),
    );
  }

  void _createPost() {
    String title = '', desc = '', location = '', avail = '';
    BayanihanCategory cat = BayanihanCategory.values[_tabCtrl.index > 0 ? _tabCtrl.index - 1 : 0];
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('🤝 New Bayanihan Post', style: Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<BayanihanCategory>(value: cat, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category, size: 18)),
            items: BayanihanCategory.values.map((c) => DropdownMenuItem(value: c, child: Text('${c == BayanihanCategory.generator ? "🔌" : c == BayanihanCategory.fuelPool ? "⛽" : c == BayanihanCategory.charging ? "🔋" : "🏪"} ${c.name}'))).toList(),
            onChanged: (v) => cat = v ?? cat),
          const SizedBox(height: 10),
          TextField(decoration: const InputDecoration(hintText: 'Title', prefixIcon: Icon(Icons.title, size: 18)), onChanged: (v) => title = v),
          const SizedBox(height: 10),
          TextField(decoration: const InputDecoration(hintText: 'Description', prefixIcon: Icon(Icons.description, size: 18)), onChanged: (v) => desc = v, maxLines: 3),
          const SizedBox(height: 10),
          TextField(decoration: const InputDecoration(hintText: 'Location', prefixIcon: Icon(Icons.location_on, size: 18)), onChanged: (v) => location = v),
          const SizedBox(height: 10),
          TextField(decoration: const InputDecoration(hintText: 'Availability (e.g., 8AM-5PM)', prefixIcon: Icon(Icons.schedule, size: 18)), onChanged: (v) => avail = v),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, 
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (title.isEmpty || desc.isEmpty) return;
                final post = BayanihanPost(
                  id: '', 
                  category: cat, 
                  title: title, 
                  description: desc,
                  location: location.isNotEmpty ? location : null, 
                  availability: avail.isNotEmpty ? avail : null, 
                  createdAt: DateTime.now(),
                  authorId: _firebaseService.currentUser?.uid ?? 'unknown',
                  authorName: _firebaseService.currentUser?.displayName ?? 'Bayani',
                );
                await _firebaseService.submitBayanihanPost(post);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Post created! Salamat sa Bayanihan! 🤝')));
                }
              }, 
              icon: const Icon(Icons.send), 
              label: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ])),
      ),
    );
  }
}
