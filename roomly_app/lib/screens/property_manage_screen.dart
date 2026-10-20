import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/photo_strip.dart';
import 'owner_home_screen.dart';
import 'property_form_screen.dart';
import 'room_manage_screen.dart';

// One property: its details, photos and rooms.
class PropertyManageScreen extends StatefulWidget {
  final String propertyId;
  const PropertyManageScreen({super.key, required this.propertyId});

  @override
  State<PropertyManageScreen> createState() => _PropertyManageScreenState();
}

class _PropertyManageScreenState extends State<PropertyManageScreen> {
  Map<String, dynamic>? _p;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/owner/properties/${widget.propertyId}');
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _error = res.error);
      return;
    }
    setState(() {
      _error = '';
      _p = Map<String, dynamic>.from(res.data as Map);
    });
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];

  Future<void> _edit() async {
    final p = _p;
    if (p == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyFormScreen(initial: p)));
    if (mounted) _load();
  }

  Future<void> _openRoom({Map<String, dynamic>? room}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomManageScreen(propertyId: widget.propertyId, room: room)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(p == null ? 'Property' : '${p['name']}', style: display(20)),
        actions: [if (p != null) IconButton(tooltip: 'Edit details', icon: const Icon(Icons.edit_outlined), onPressed: _edit)],
      ),
      body: _error.isNotEmpty
          ? ErrorBox(title: "We couldn't load this property", message: _error, onRetry: _load)
          : p == null
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : RefreshIndicator(onRefresh: _load, child: _body(p)),
    );
  }

  Widget _body(Map<String, dynamic> p) {
    final status = '${p['status']}';
    final rooms = _list(p['room_types']);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(children: [
          Pill(propertyStatusLabel(status), propertyStatusColor(status)),
          const SizedBox(width: 10),
          Expanded(child: Text('${p['type']} in ${p['city']}', style: const TextStyle(color: C.soft))),
        ]),
        if (status == 'pending')
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Guests can find this place once it is approved. You can keep adding rooms and photos meanwhile.', style: TextStyle(color: C.soft)),
          ),
        if (status == 'rejected')
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('This place was not approved, so guests cannot see it.', style: TextStyle(color: C.brick)),
          ),
        const SizedBox(height: 20),
        Text('Photos of the place', style: display(18)),
        const SizedBox(height: 8),
        PhotoStrip(base: '/owner/properties/${widget.propertyId}', photos: _list(p['photos']), onChanged: _load),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Text('Rooms', style: display(18))),
          FilledButton.icon(onPressed: () => _openRoom(), icon: const Icon(Icons.add, size: 18), label: const Text('Add a room')),
        ]),
        const SizedBox(height: 8),
        if (rooms.isEmpty)
          const Text('No rooms yet. Add a room type with its price, then open dates so guests can book it.', style: TextStyle(color: C.soft)),
        for (final r in rooms) _roomCard(r),
      ],
    );
  }

  Widget _roomCard(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openRoom(room: r),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['name']}', style: display(17)),
                  const SizedBox(height: 2),
                  Text(
                    '${plural(toNum(r['total_rooms']).toInt(), 'room')} · up to ${plural(toNum(r['max_guests']).toInt(), 'guest')}',
                    style: const TextStyle(color: C.soft),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Price(toNum(r['base_price']), size: 17),
                const Text('a night', style: TextStyle(color: C.soft, fontSize: 12)),
              ]),
              const Icon(Icons.chevron_right, color: C.soft),
            ]),
          ),
        ),
      ),
    );
  }
}
