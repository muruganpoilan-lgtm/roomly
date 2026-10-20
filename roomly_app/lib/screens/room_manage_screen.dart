import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/photo_strip.dart';

// Add a room type, or edit one (pass `room`, as listed on the property). Editing also shows
// photos, a form to open dates for sale, and the coming nights.
class RoomManageScreen extends StatefulWidget {
  final String propertyId;
  final Map<String, dynamic>? room;
  const RoomManageScreen({super.key, required this.propertyId, this.room});

  @override
  State<RoomManageScreen> createState() => _RoomManageScreenState();
}

class _RoomManageScreenState extends State<RoomManageScreen> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _rooms;
  late final TextEditingController _guests;
  late final TextEditingController _openRooms;
  late final TextEditingController _openPrice;

  String? _roomId;
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _nights = [];
  DateTime _start = today().add(const Duration(days: 1));
  DateTime _end = today().add(const Duration(days: 30));
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _roomId = r == null ? null : '${r['id']}';
    _name = TextEditingController(text: r == null ? '' : '${r['name']}');
    _price = TextEditingController(text: r == null ? '' : toNum(r['base_price']).round().toString());
    _rooms = TextEditingController(text: r == null ? '1' : toNum(r['total_rooms']).toInt().toString());
    _guests = TextEditingController(text: r == null ? '2' : toNum(r['max_guests']).toInt().toString());
    _openRooms = TextEditingController(text: _rooms.text);
    _openPrice = TextEditingController();
    if (r != null && r['photos'] is List) {
      _photos = (r['photos'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (_roomId != null) _loadNights();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _rooms.dispose();
    _guests.dispose();
    _openRooms.dispose();
    _openPrice.dispose();
    super.dispose();
  }

  Future<void> _loadNights() async {
    final res = await Api.get('/owner/room-types/$_roomId/inventory?days=60');
    if (!mounted || !res.ok) return;
    setState(() => _nights = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
  }

  // The photo list lives on the property fetch, so ask for it again after an upload or removal.
  Future<void> _reloadPhotos() async {
    final res = await Api.get('/owner/properties/${widget.propertyId}');
    if (!mounted || !res.ok) return;
    for (final e in (res.data['room_types'] as List)) {
      final m = Map<String, dynamic>.from(e as Map);
      if ('${m['id']}' == _roomId) {
        setState(() => _photos = (m['photos'] as List).map((x) => Map<String, dynamic>.from(x as Map)).toList());
      }
    }
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    final rooms = int.tryParse(_rooms.text.trim());
    final guests = int.tryParse(_guests.text.trim());
    if (_name.text.trim().isEmpty || price == null || price < 0 || rooms == null || rooms < 1 || guests == null || guests < 1) {
      setState(() => _error = 'Enter a name, a price, how many rooms you have and how many guests fit.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = {'name': _name.text.trim(), 'max_guests': guests, 'base_price': price, 'total_rooms': rooms};
    final ApiResult res;
    if (_roomId == null) {
      res = await Api.post('/owner/properties/${widget.propertyId}/room-types', body: body);
    } else {
      res = await Api.patch('/owner/room-types/$_roomId', body: body);
    }
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _busy = false;
        _error = res.error;
      });
      return;
    }
    if (_roomId == null) {
      // Stay on the screen so photos and dates can be added straight away.
      setState(() {
        _roomId = '${res.data['id']}';
        _busy = false;
        _openRooms.text = '$rooms';
      });
      snack(context, 'Room saved. Now add photos and open some dates.');
    } else {
      setState(() => _busy = false);
      snack(context, 'Saved.');
    }
  }

  Future<void> _delete() async {
    final ok = await askYesNo(context, 'Delete this room?', 'Rooms that already have bookings cannot be deleted. Its photos and open dates are removed.', 'Delete');
    if (!ok || !mounted) return;
    final res = await Api.delete('/owner/room-types/$_roomId');
    if (!mounted) return;
    if (!res.ok) {
      snack(context, res.error);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate(bool start) async {
    final first = today();
    final initial = start ? _start : _end;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 730)),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = d;
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  Future<void> _openDates() async {
    final open = int.tryParse(_openRooms.text.trim());
    final priceText = _openPrice.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    if (open == null || open < 0 || (priceText.isNotEmpty && price == null)) {
      setState(() => _error = 'Enter how many rooms to open each night, and a valid price or leave it empty.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final res = await Api.put('/owner/room-types/$_roomId/inventory', body: {
      'start': isoDate(_start),
      'end': isoDate(_end),
      'rooms_open': open,
      'price': price,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() => _error = res.error);
      return;
    }
    snack(context, '${plural(toNum(res.data['nights_updated']).toInt(), 'night')} updated.');
    _loadNights();
  }

  @override
  Widget build(BuildContext context) {
    final saved = _roomId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(saved ? 'Edit room' : 'Add a room', style: display(20)),
        actions: [if (saved) IconButton(tooltip: 'Delete room', icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: fieldDeco('Room name', hint: 'Deluxe double')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: fieldDeco('Price a night (₹)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _rooms, keyboardType: TextInputType.number, decoration: fieldDeco('Rooms you have'))),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _guests, keyboardType: TextInputType.number, decoration: fieldDeco('Guests that fit')),
          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error, style: const TextStyle(color: C.brick, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : (saved ? 'Save room' : 'Save room'))),
          if (saved) ...[
            const SizedBox(height: 28),
            Text('Photos of this room', style: display(18)),
            const SizedBox(height: 8),
            PhotoStrip(base: '/owner/room-types/$_roomId', photos: _photos, onChanged: _reloadPhotos),
            const SizedBox(height: 28),
            Text('Open dates for booking', style: display(18)),
            const SizedBox(height: 4),
            const Text('Guests can only book nights you have opened. Opening again changes the numbers; rooms already booked are kept.', style: TextStyle(color: C.soft)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateButton('From', _start, true)),
              const SizedBox(width: 12),
              Expanded(child: _dateButton('Last night', _end, false)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _openRooms, keyboardType: TextInputType.number, decoration: fieldDeco('Rooms to open'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _openPrice, keyboardType: TextInputType.number, decoration: fieldDeco('Price (optional)', hint: 'Usual price'))),
            ]),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _busy ? null : _openDates, child: const Text('Open these nights')),
            const SizedBox(height: 24),
            Text('Next 60 nights', style: display(18)),
            const SizedBox(height: 8),
            if (_nights.isEmpty) const Text('No nights are open yet.', style: TextStyle(color: C.soft)),
            if (_nights.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final n in _nights) _nightChip(n)],
              ),
          ],
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime d, bool start) {
    return OutlinedButton(
      onPressed: () => _pickDate(start),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: C.soft)),
        Text(prettyDayYear(d), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _nightChip(Map<String, dynamic> n) {
    final d = parseDay('${n['day']}'.substring(0, 10));
    final left = toNum(n['available']).toInt();
    final hasPrice = n['price'] != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: left > 0 ? Colors.white : C.chalk,
        border: Border.all(color: left > 0 ? C.green : C.line, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(prettyDay(d), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(left > 0 ? '$left free' : 'full', style: TextStyle(color: left > 0 ? C.green : C.soft, fontSize: 12)),
        if (hasPrice) Text(money(toNum(n['price'])), style: const TextStyle(fontSize: 11, color: C.soft)),
      ]),
    );
  }
}
