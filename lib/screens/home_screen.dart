import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ridge.dart';
import 'results_screen.dart';

// What the guest is searching for. Passed from screen to screen.
class StayQuery {
  final String city;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  const StayQuery({required this.city, required this.checkIn, required this.checkOut, required this.guests});

  int get nights => nightsBetween(checkIn, checkOut);
  String get dates => '${prettyDay(checkIn)} to ${prettyDay(checkOut)}';
}

// Roughly how high each place sits above the sea, in metres.
const _places = <MapEntry<String, int>>[
  MapEntry('Ooty', 2240),
  MapEntry('Kodaikanal', 2130),
  MapEntry('Munnar', 1530),
  MapEntry('Yercaud', 1500),
  MapEntry('Coorg', 1150),
  MapEntry('Valparai', 1050),
  MapEntry('Thekkady', 900),
  MapEntry('Wayanad', 800),
  MapEntry('Alleppey', 0),
  MapEntry('Kovalam', 0),
  MapEntry('Varkala', 0),
  MapEntry('Pondicherry', 0),
  MapEntry('Goa', 0),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _city = TextEditingController();
  late DateTime _checkIn;
  late DateTime _checkOut;
  int _guests = 2;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final t = today();
    _checkIn = t.add(const Duration(days: 1));
    _checkOut = t.add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickIn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: today(),
      lastDate: today().add(const Duration(days: 365)),
      helpText: 'Check-in',
    );
    if (picked == null) return;
    setState(() {
      _checkIn = picked;
      if (!_checkOut.isAfter(picked)) _checkOut = picked.add(const Duration(days: 1));
    });
  }

  Future<void> _pickOut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: today().add(const Duration(days: 400)),
      helpText: 'Check-out',
    );
    if (picked != null) setState(() => _checkOut = picked);
  }

  void _search(String city) {
    if (!_checkOut.isAfter(_checkIn)) {
      setState(() => _error = 'Check-out must be after check-in.');
      return;
    }
    setState(() => _error = '');
    final q = StayQuery(city: city.trim(), checkIn: _checkIn, checkOut: _checkOut, guests: _guests);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultsScreen(query: q)));
  }

  @override
  Widget build(BuildContext context) {
    final nights = nightsBetween(_checkIn, _checkOut);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header: green sky, a marigold sun and three ridgelines.
        SizedBox(
          height: 250,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: C.green)),
              Positioned(
                right: 34,
                top: 126,
                child: Container(width: 62, height: 62, decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle)),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 104,
                child: Ridge(seed: 'western-ghats', sky: false, layers: [Color(0xFF1D7F69), Color(0xFF14604F), C.chalk]),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Roomly', style: display(18, color: Colors.white)),
                        const SizedBox(height: 14),
                        SizedBox(width: 270, child: Text('A room for every night of your stay', style: display(30, color: Colors.white))),
                        const SizedBox(height: 8),
                        const SizedBox(
                          width: 260,
                          child: Text('Only rooms that are free on all your nights.', style: TextStyle(color: Color(0xFFDCECE6), fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The booking slip and the list of places sit slightly over the header.
        Transform.translate(
          offset: const Offset(0, -30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _slip(nights),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 2),
                child: Text('Browse by city, from the hills down to the sea', style: display(20)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Height above sea level, roughly. Tap a place to search it.', style: TextStyle(color: C.soft)),
              ),
              for (final p in _places) _ladderRow(p.key, p.value),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slip(int nights) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.ink, width: 2),
        boxShadow: const [BoxShadow(color: C.gold, offset: Offset(5, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _city,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: fieldDeco('City', hint: 'Valparai, Ooty, Goa', prefix: const Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateTile('Check-in', _checkIn, _pickIn)),
              const SizedBox(width: 10),
              Expanded(child: _dateTile('Check-out', _checkOut, _pickOut)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Guests', style: TextStyle(fontWeight: FontWeight.w700, color: C.soft)),
              const Spacer(),
              IconButton(
                onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Fewer guests',
              ),
              SizedBox(width: 24, child: Text('$_guests', textAlign: TextAlign.center, style: display(18))),
              IconButton(
                onPressed: _guests < 20 ? () => setState(() => _guests++) : null,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'More guests',
              ),
            ],
          ),
          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(_error, style: const TextStyle(color: C.brick, fontWeight: FontWeight.w600))),
          FilledButton(onPressed: () => _search(_city.text), child: const Text('Search rooms')),
          const SizedBox(height: 8),
          Text(
            '${plural(nights < 1 ? 1 : nights, 'night')}. We only show rooms that are free on every night.',
            style: const TextStyle(color: C.soft, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFAAB5AC)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.soft)),
            const SizedBox(height: 2),
            Text(prettyDayYear(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _ladderRow(String city, int metres) {
    final factor = metres == 0 ? 0.015 : metres / 2240;
    return InkWell(
      onTap: () => _search(city),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Row(
          children: [
            SizedBox(width: 98, child: Text(city, style: display(16))),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: factor,
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      color: C.green,
                      border: Border(right: BorderSide(color: C.gold, width: 6)),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 76,
              child: Text(
                metres == 0 ? 'Sea level' : '${money(metres).substring(1)} m',
                textAlign: TextAlign.right,
                style: const TextStyle(color: C.soft, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
