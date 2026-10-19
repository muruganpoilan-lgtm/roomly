import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'property_screen.dart';

const _types = <MapEntry<String, String>>[
  MapEntry('', 'Any'),
  MapEntry('homestay', 'Homestay'),
  MapEntry('hotel', 'Hotel'),
  MapEntry('resort', 'Resort'),
  MapEntry('apartment', 'Apartment'),
];

String typeLabel(String t) {
  for (final e in _types) {
    if (e.key == t) return e.value;
  }
  return t;
}

class ResultsScreen extends StatefulWidget {
  final StayQuery query;
  const ResultsScreen({super.key, required this.query});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String _type = '';
  String _sort = 'price';
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = widget.query;
    setState(() {
      _loading = true;
      _error = '';
    });
    final params = <String, String>{
      'check_in': isoDate(q.checkIn),
      'check_out': isoDate(q.checkOut),
      'guests': '${q.guests}',
      'sort': _sort,
    };
    if (q.city.isNotEmpty) params['city'] = q.city;
    if (_type.isNotEmpty) params['property_type'] = _type;
    final res = await Api.get('/search', query: params);
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _loading = false;
        _error = res.error;
      });
      return;
    }
    final list = (res.data['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      _loading = false;
      _results = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    return Scaffold(
      appBar: AppBar(
        title: Text(q.city.isEmpty ? 'Stays across India' : 'Stays in ${q.city}', style: display(20)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '${q.dates} · ${plural(q.nights, 'night')} · ${plural(q.guests, 'guest')}',
              style: const TextStyle(color: C.soft),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in _types)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(t.value),
                      selected: _type == t.key,
                      onSelected: (_) {
                        setState(() => _type = t.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                const Text('Sort by', style: TextStyle(color: C.soft, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Lowest price'),
                  selected: _sort == 'price',
                  onSelected: (_) {
                    setState(() => _sort = 'price');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Best rated'),
                  selected: _sort == 'rating',
                  onSelected: (_) {
                    setState(() => _sort = 'rating');
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.green));
    if (_error.isNotEmpty) {
      return SingleChildScrollView(child: ErrorBox(title: "We couldn't load results", message: _error, onRetry: _load));
    }
    if (_results.isEmpty) {
      return SingleChildScrollView(
        child: ErrorBox(
          title: 'No rooms free for all ${plural(widget.query.nights, 'night')}',
          message: 'Try other dates, a shorter stay, or another type of place. Rooms only show up when they are free on every night.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _results.length,
        itemBuilder: (context, i) => _card(_results[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final perNight = toNum(p['price_per_night']);
    final count = toNum(p['rating_count']).toInt();
    final id = p['id'].toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyScreen(propertyId: id, query: widget.query))),
          child: Ink(
            decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(aspectRatio: 16 / 10, child: PhotoOrRidge(url: p['photo'] as String?, seed: id)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${typeLabel('${p['type']}')} in ${p['city']}', style: const TextStyle(color: C.soft, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${p['name']}', style: display(19)),
                      const SizedBox(height: 6),
                      if (count > 0)
                        Row(children: [
                          ScoreBadge(toNum(p['rating_avg']).toStringAsFixed(1)),
                          const SizedBox(width: 6),
                          Text('from ${plural(count, 'review')}', style: const TextStyle(color: C.soft)),
                        ])
                      else
                        const Text('New on Roomly', style: TextStyle(color: C.soft)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${money(perNight * widget.query.nights)} for ${plural(widget.query.nights, 'night')}', style: const TextStyle(color: C.soft)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Price(perNight, size: 22),
                              const Text(' a night', style: TextStyle(color: C.soft, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
