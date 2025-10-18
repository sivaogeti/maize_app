
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/farmers_provider.dart';
import '../../core/services/auth_service.dart';

class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _Thread {
  final String title;
  final String lastMessage;
  final DateTime time;
  final int unread;
  final List<String> participants;
  final String tag;
  final bool hasMention;

  const _Thread({
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.participants,
    required this.tag,
    this.hasMention = false,
  });
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  final _search = TextEditingController();
  String _filter = 'all'; // all | unread | mentions

  final _threads = <_Thread>[
    _Thread(
      title: 'Ramu (F1-A) • Irrigation',
      lastMessage: 'Scheduled irrigation for 05-May',
      time: DateTime.now().subtract(const Duration(minutes: 15)),
      unread: 2,
      participants: const ['You', 'Ramu'],
      tag: 'farmer',
    ),
    _Thread(
      title: 'Cluster: Narasaraopet',
      lastMessage: '@You share SOP for top-dressing',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      unread: 0,
      participants: const ['FICs', 'CIC'],
      tag: 'cluster',
      hasMention: true,
    ),
    _Thread(
      title: 'Input delivery • L23-A',
      lastMessage: 'Lot L23-A delivered (100 kg)',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      unread: 0,
      participants: const ['J. Rao', 'You'],
      tag: 'inputs',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Thread> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _threads.where((t) {
      if (_filter == 'unread' && t.unread == 0) return false;
      if (_filter == 'mentions' && !t.hasMention) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.lastMessage.toLowerCase().contains(q);
    }).toList();
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd MMM').format(dt);
    // ignore: dead_code
  }

  void _logout() {
    try {
      // logout() is synchronous (returns void), so don't await it
      context.read<AuthService>().logout();
    } catch (_) {
      // ignore
    }
    if (!mounted) return;

    // If you use go_router:
    // context.go('/welcome');

    // Otherwise, plain Navigator:
    context.go('/welcome');   // replaces “removeUntil” semantics in a router app
  }


  void _smartBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    context.go('/');        // or context.goNamed('home');    
  }

  Widget _chip(String key, String label, IconData icon) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: selected,
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communications'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _smartBack(context),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search messages, farmers, clusters...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                _chip('all', 'All', Icons.inbox_outlined),
                _chip('unread', 'Unread', Icons.mark_email_unread_outlined),
                _chip('mentions', 'Mentions', Icons.alternate_email),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No messages'))
                : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96, top: 4),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final t = items[i];
                return ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    t.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: CircleAvatar(
                    child: Text(t.title.isNotEmpty ? t.title[0] : '?'),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_ago(t.time),
                          style: Theme.of(context).textTheme.bodySmall),
                      if (t.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${t.unread}',
                            style: TextStyle(
                              color:
                              Theme.of(context).colorScheme.onPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCompose() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final toCtrl = TextEditingController();
        final msgCtrl = TextEditingController();

        bool _loaded = false;
        List<String> _farmerIds = <String>[];
        String? _selectedFarmerId;

        Future<void> _load() async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final cached =
                prefs.getStringList('farmers_cache_ids') ?? <String>[];
            List<String> prov = const [];
            try {
              prov = ctx
                  .read<FarmersProvider>()
                  .farmers
                  .map((f) => f.id)
                  .toList(growable: false);
            } catch (_) {}
            final setIds = <String>{...cached, ...prov};
            _farmerIds = setIds.toList()..sort();
          } catch (_) {}
        }

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            if (!_loaded) {
              _loaded = true;
              Future.microtask(() async {
                await _load();
                setModalState(() {});
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'New Message',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: (_selectedFarmerId != null &&
                        _selectedFarmerId!.isNotEmpty)
                        ? _selectedFarmerId
                        : (toCtrl.text.isNotEmpty ? toCtrl.text : null),
                    decoration: const InputDecoration(
                      labelText: 'Farmer / Field ID',
                      prefixIcon: Icon(Icons.agriculture),
                      border: OutlineInputBorder(),
                    ),
                    items: _farmerIds
                        .map((id) => DropdownMenuItem<String>(
                      value: id,
                      child: Text(id),
                    ))
                        .toList(),
                    onChanged: (id) {
                      setModalState(() => _selectedFarmerId = id);
                      toCtrl.text = id ?? '';
                    },
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: toCtrl,
                    decoration: const InputDecoration(
                      labelText: 'To (farmer/cluster/role)',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: msgCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message queued')),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
