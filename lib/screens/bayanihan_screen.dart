import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_models.dart';
import '../data/energy_tips.dart';
import '../services/storage_service.dart';

class BayanihanScreen extends StatefulWidget {
  final StorageService storage;
  const BayanihanScreen({super.key, required this.storage});
  @override
  State<BayanihanScreen> createState() => _BayanihanScreenState();
}

class _BayanihanScreenState extends State<BayanihanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<BayanihanPost> _posts = [];
  bool _nearMeOnly = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    var saved = await widget.storage.getBayanihanPosts();
    if (saved.isEmpty) {
      // Seed with sample posts
      saved = seedBayanihanPosts.map((p) => BayanihanPost(
        id: 'seed_${seedBayanihanPosts.indexOf(p)}',
        category: BayanihanCategory.values.firstWhere((c) => c.name == p['category']),
        title: p['title']!,
        description: p['description']!,
        location: p['location'],
        availability: p['availability'],
        createdAt: DateTime.now().subtract(Duration(hours: seedBayanihanPosts.indexOf(p) * 2 + 1)),
        interestedCount: (seedBayanihanPosts.indexOf(p) * 3 + 2),
        salamatCount: (seedBayanihanPosts.indexOf(p) * 2 + 1),
      )).toList();
      await widget.storage.saveBayanihanPosts(saved);
    }
    setState(() => _posts = saved);
  }

  List<BayanihanPost> _filtered(BayanihanCategory cat) => _posts.where((p) => p.category == cat).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('🤝 ', style: TextStyle(fontSize: 22)), Text('Bayanihan Board')]),
        actions: [
          Row(children: [
            const Text('Near Me', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            Switch(value: _nearMeOnly, onChanged: (v) => setState(() => _nearMeOnly = v)),
          ]),
        ],
        bottom: TabBar(controller: _tabCtrl, isScrollable: true, tabs: const [
          Tab(text: '🔌 Generator'), Tab(text: '⛽ Fuel Pool'), Tab(text: '🔋 Charging'), Tab(text: '🏪 Business'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _postList(BayanihanCategory.generator),
        _postList(BayanihanCategory.fuelPool),
        _postList(BayanihanCategory.charging),
        _postList(BayanihanCategory.businessSos),
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

  Widget _postList(BayanihanCategory cat) {
    final posts = _filtered(cat);
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
      const SizedBox(height: 10),
      Row(children: [
        _reactionBtn('🙋 Interested', p.interestedCount, () => setState(() => p.interestedCount++)),
        const SizedBox(width: 12),
        _reactionBtn('🙏 Salamat', p.salamatCount, () => setState(() => p.salamatCount++)),
        const Spacer(),
        if (p.contactInfo != null) TextButton.icon(icon: const Icon(Icons.chat, size: 14), label: const Text('Contact', style: TextStyle(fontSize: 11)), onPressed: () {}),
      ]),
    ])));
  }

  Widget _reactionBtn(String label, int count, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(20),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Text('$label ($count)', style: const TextStyle(fontSize: 11)),
    ),
  );

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  void _createPost() {
    String title = '', desc = '', location = '', avail = '';
    BayanihanCategory cat = BayanihanCategory.values[_tabCtrl.index];
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
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {
            if (title.isEmpty || desc.isEmpty) return;
            final post = BayanihanPost(id: 'u_${DateTime.now().millisecondsSinceEpoch}', category: cat, title: title, description: desc,
              location: location.isNotEmpty ? location : null, availability: avail.isNotEmpty ? avail : null, createdAt: DateTime.now());
            setState(() => _posts.insert(0, post));
            widget.storage.saveBayanihanPosts(_posts);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Post created! Salamat sa Bayanihan! 🤝')));
          }, icon: const Icon(Icons.send), label: const Text('Post'))),
          const SizedBox(height: 20),
        ])),
      ),
    );
  }
}
