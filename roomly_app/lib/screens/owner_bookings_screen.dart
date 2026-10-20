import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

// Confirmed and cancelled bookings for the owner's properties (every property, for an admin).
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  List<Map<String, dynamic>>? _rows;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/owner/bookings');
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _error = res.error);
      return;
    }
    setState(() {
      _error = '';
      _rows = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text('Bookings', style: display(20))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_error.isNotEmpty) ErrorBox(title: "We couldn't load bookings", message: _error, onRetry: _load),
            if (rows == null && _error.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: C.green))),
            if (rows != null && rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No confirmed bookings yet.', style: TextStyle(color: C.soft, fontSize: 15))),
            if (rows != null) for (final b in rows) _card(b),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    final status = '${b['status']}';
    final checkIn = parseDay('${b['check_in']}');
    final checkOut = parseDay('${b['check_out']}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${b['guest']}', style: display(17)),
            const SizedBox(height: 2),
            Text('${b['property']} · ${b['room_type']}', style: const TextStyle(color: C.soft)),
            Text('${plural(toNum(b['rooms']).toInt(), 'room')}, ${plural(toNum(b['guests']).toInt(), 'guest')}', style: const TextStyle(color: C.soft)),
            const SizedBox(height: 4),
            Text('${prettyDayYear(checkIn)} to ${prettyDayYear(checkOut)}'),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Price(toNum(b['total_amount']), size: 17),
          const SizedBox(height: 6),
          Pill(status == 'confirmed' ? 'Confirmed' : 'Cancelled', status == 'confirmed' ? C.green : C.soft),
        ]),
      ]),
    );
  }
}
