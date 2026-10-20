import 'package:flutter/material.dart';

import '../api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'owner_bookings_screen.dart';
import 'property_form_screen.dart';
import 'property_manage_screen.dart';

String propertyStatusLabel(String s) {
  if (s == 'approved') return 'Live';
  if (s == 'pending') return 'Waiting for approval';
  return 'Not approved';
}

Color propertyStatusColor(String s) {
  if (s == 'approved') return C.green;
  if (s == 'pending') return C.goldText;
  return C.soft;
}

// The owner's (or admin's) list of properties. Admins also see what is waiting for approval.
class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  List<Map<String, dynamic>>? _props;
  List<Map<String, dynamic>> _pending = [];
  String _error = '';

  bool get _isAdmin => session.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/owner/properties');
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _error = res.error);
      return;
    }
    var pending = <Map<String, dynamic>>[];
    if (_isAdmin) {
      final p = await Api.get('/admin/properties/pending');
      if (p.ok) pending = (p.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (!mounted) return;
    setState(() {
      _error = '';
      _props = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _pending = pending;
    });
  }

  Future<void> _decide(String id, String action) async {
    final res = await Api.post('/admin/properties/$id/$action');
    if (!mounted) return;
    if (!res.ok) snack(context, res.error);
    _load();
  }

  Future<void> _add() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const PropertyFormScreen()));
    if (!mounted) return;
    if (id != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyManageScreen(propertyId: id)));
    }
    if (mounted) _load();
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyManageScreen(propertyId: id)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final props = _props;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'All properties' : 'Your properties', style: display(20)),
        actions: [
          IconButton(
            tooltip: 'Bookings',
            icon: const Icon(Icons.confirmation_number_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerBookingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add a property'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (_error.isNotEmpty) ErrorBox(title: "We couldn't load your properties", message: _error, onRetry: _load),
            if (_pending.isNotEmpty) ...[
              Text('Waiting for your approval', style: display(18)),
              const SizedBox(height: 8),
              for (final p in _pending) _pendingCard(p),
              const SizedBox(height: 16),
            ],
            if (props == null && _error.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: C.green))),
            if (props != null && props.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No properties yet. Add your first one, then its rooms, photos and open dates.', style: TextStyle(color: C.soft, fontSize: 15)),
              ),
            if (props != null) for (final p in props) _card(p),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> p) {
    final id = p['id'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.gold, width: 2), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(onTap: () => _open(id), child: Text('${p['name']}', style: display(17))),
          const SizedBox(height: 2),
          Text('${p['city']} · ${p['owner']} (${p['owner_email']})', style: const TextStyle(color: C.soft, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton(onPressed: () => _decide(id, 'approve'), child: const Text('Approve'))),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _decide(id, 'reject'),
              style: OutlinedButton.styleFrom(foregroundColor: C.brick, side: const BorderSide(color: C.brick, width: 1.8)),
              child: const Text('Reject'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final status = '${p['status']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _open(p['id'].toString()),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}', style: display(18)),
                  const SizedBox(height: 2),
                  Text('${p['type']} in ${p['city']}', style: const TextStyle(color: C.soft)),
                  const SizedBox(height: 8),
                  Pill(propertyStatusLabel(status), propertyStatusColor(status)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.soft),
            ]),
          ),
        ),
      ),
    );
  }
}
