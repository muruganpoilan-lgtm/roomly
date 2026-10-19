import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'results_screen.dart' show typeLabel;

class PropertyScreen extends StatefulWidget {
  final String propertyId;
  final StayQuery query;
  const PropertyScreen({super.key, required this.propertyId, required this.query});

  @override
  State<PropertyScreen> createState() => _PropertyScreenState();
}

class _PropertyScreenState extends State<PropertyScreen> {
  late StayQuery _q;
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _p;
  final Map<String, int> _qty = {};
  String _busy = '';
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _q = widget.query;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final res = await Api.get('/properties/${widget.propertyId}', query: {
      'check_in': isoDate(_q.checkIn),
      'check_out': isoDate(_q.checkOut),
    });
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _loading = false;
        _error = res.status == 404 ? "This place isn't available any more." : res.error;
      });
      return;
    }
    setState(() {
      _loading = false;
      _p = Map<String, dynamic>.from(res.data as Map);
    });
  }

  Future<void> _changeDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today(),
      lastDate: today().add(const Duration(days: 400)),
      initialDateRange: DateTimeRange(start: _q.checkIn, end: _q.checkOut),
      helpText: 'Choose your nights',
    );
    if (picked == null) return;
    var end = picked.end;
    if (!end.isAfter(picked.start)) end = picked.start.add(const Duration(days: 1));
    setState(() => _q = StayQuery(city: _q.city, checkIn: picked.start, checkOut: end, guests: _q.guests));
    _load();
  }

  Future<void> _reserve(Map<String, dynamic> room) async {
    if (session.token == null) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok != true || !mounted) return;
    }
    final id = room['id'].toString();
    setState(() => _busy = id);
    final res = await Api.post('/bookings', body: {
      'room_type_id': id,
      'check_in': isoDate(_q.checkIn),
      'check_out': isoDate(_q.checkOut),
      'rooms': _qty[id] ?? 1,
      'guests': _q.guests,
    });
    if (!mounted) return;
    setState(() => _busy = '');
    if (!res.ok) {
      snack(context, res.error);
      if (res.status == 409) _load();
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    tabIndex.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_p == null ? '' : '${_p!['name']}', style: display(18))),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _p == null) return const Center(child: CircularProgressIndicator(color: C.green));
    if (_error.isNotEmpty && _p == null) {
      return SingleChildScrollView(child: ErrorBox(title: "We couldn't load this place", message: _error, onRetry: _load));
    }
    final p = _p!;
    final photos = (p['photos'] as List).map((e) => e.toString()).toList();
    final amenities = (p['amenities'] as List).map((e) => e.toString()).toList();
    final rooms = (p['room_types'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final count = toNum(p['rating_count']).toInt();
    final desc = p['description'];

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _gallery(photos, p['id'].toString()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${typeLabel('${p['type']}')} in ${p['city']}', style: const TextStyle(color: C.soft)),
              const SizedBox(height: 2),
              Text('${p['name']}', style: display(26)),
              const SizedBox(height: 8),
              Row(children: [
                if (count > 0) ...[
                  ScoreBadge(toNum(p['rating_avg']).toStringAsFixed(1)),
                  const SizedBox(width: 6),
                  Text('from ${plural(count, 'review')}', style: const TextStyle(color: C.soft)),
                ] else
                  const Text('New on Roomly', style: TextStyle(color: C.soft)),
              ]),
              if (p['address'] != null && '${p['address']}'.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('${p['address']}', style: const TextStyle(color: C.soft))),
              if (desc != null && '$desc'.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('About this place', style: display(19)),
                const SizedBox(height: 6),
                Text('$desc', style: const TextStyle(height: 1.45)),
              ],
              if (amenities.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text("What's included", style: display(19)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in amenities)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(99), color: Colors.white),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check, size: 16, color: C.green),
                          const SizedBox(width: 4),
                          Text(a),
                        ]),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Text('Rooms', style: display(19)),
              const SizedBox(height: 8),
              _datesBar(),
              const SizedBox(height: 4),
              if (rooms.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("The owner hasn't added rooms yet.", style: TextStyle(color: C.soft))),
              for (final r in rooms) _room(r),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gallery(List<String> photos, String seed) {
    if (photos.isEmpty) {
      return SizedBox(
        height: 220,
        child: Stack(children: [
          Positioned.fill(child: PhotoOrRidge(url: null, seed: seed)),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: const Text("The owner hasn't added photos yet", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
    }
    return SizedBox(
      height: 250,
      child: Stack(children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _photoIndex = i),
          itemBuilder: (_, i) => Image.network(
            fixUrl(photos[i]),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => PhotoOrRidge(url: null, seed: '$seed$i'),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.ink, width: 1.5)),
            child: Text('${_photoIndex + 1} / ${photos.length}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  Widget _datesBar() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _changeDates,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined, color: C.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_q.dates} · ${plural(_q.nights, 'night')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(plural(_q.guests, 'guest'), style: const TextStyle(color: C.soft, fontSize: 13)),
              ]),
            ),
            const Text('Change', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _room(Map<String, dynamic> r) {
    final id = r['id'].toString();
    final bookable = r['bookable'] == true;
    final left = toNum(r['rooms_left']).toInt();
    final photos = (r['photos'] as List).map((e) => e.toString()).toList();
    final qty = _qty[id] ?? 1;
    final maxQty = left < 5 ? left : 5;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 92, height: 72, child: PhotoOrRidge(url: photos.isEmpty ? null : photos.first, seed: id)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['name']}', style: display(17)),
                  Text('Sleeps ${r['max_guests']}', style: const TextStyle(color: C.soft)),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Price(toNum(r['base_price']), size: 18),
                    const Text(' a night', style: TextStyle(color: C.soft, fontSize: 13)),
                  ]),
                  if (bookable && r['stay_total'] != null)
                    Text('${money(toNum(r['stay_total']))} for ${plural(_q.nights, 'night')}${qty > 1 ? ' per room' : ''}', style: const TextStyle(color: C.soft)),
                  if (bookable && left <= 2)
                    Text('Only $left left for these dates', style: const TextStyle(color: C.goldText, fontWeight: FontWeight.w700))
                  else if (!bookable)
                    const Text('Not free on all of these dates', style: TextStyle(color: C.soft)),
                ]),
              ),
            ],
          ),
          if (bookable) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (left > 1) ...[
                const Text('Rooms', style: TextStyle(fontWeight: FontWeight.w700, color: C.soft)),
                IconButton(
                  onPressed: qty > 1 ? () => setState(() => _qty[id] = qty - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Fewer rooms',
                ),
                Text('$qty', style: display(17)),
                IconButton(
                  onPressed: qty < maxQty ? () => setState(() => _qty[id] = qty + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'More rooms',
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy == id ? null : () => _reserve(r),
                child: Text(_busy == id ? 'Holding your room…' : (session.token == null ? 'Log in to reserve' : 'Reserve')),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
