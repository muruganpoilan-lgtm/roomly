import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

const _typeOptions = <MapEntry<String, String>>[
  MapEntry('hotel', 'Hotel'),
  MapEntry('homestay', 'Homestay'),
  MapEntry('apartment', 'Apartment'),
  MapEntry('resort', 'Resort'),
];

// Add a property, or edit one (pass `initial`, the property as the server sent it).
// Pops with the property's id when saved.
class PropertyFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const PropertyFormScreen({super.key, this.initial});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _description;
  String _type = 'hotel';
  final Set<int> _amenityIds = {};
  List<Map<String, dynamic>> _amenities = [];
  bool _busy = false;
  String _error = '';

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i == null ? '' : '${i['name'] ?? ''}');
    _city = TextEditingController(text: i == null ? '' : '${i['city'] ?? ''}');
    _address = TextEditingController(text: i == null || i['address'] == null ? '' : '${i['address']}');
    _description = TextEditingController(text: i == null || i['description'] == null ? '' : '${i['description']}');
    if (i != null) {
      _type = '${i['type'] ?? 'hotel'}';
      final ids = i['amenity_ids'];
      if (ids is List) {
        for (final v in ids) {
          _amenityIds.add((v as num).toInt());
        }
      }
    }
    _loadAmenities();
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadAmenities() async {
    final res = await Api.get('/amenities');
    if (!mounted || !res.ok) return;
    setState(() => _amenities = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _city.text.trim().isEmpty) {
      setState(() => _error = 'Enter the property name and the city.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type,
      'city': _city.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'amenity_ids': _amenityIds.toList(),
    };
    final ApiResult res;
    if (_editing) {
      res = await Api.patch('/owner/properties/${widget.initial!['id']}', body: body);
    } else {
      res = await Api.post('/owner/properties', body: body);
    }
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _busy = false;
        _error = res.error;
      });
      return;
    }
    final id = _editing ? '${widget.initial!['id']}' : '${res.data['id']}';
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit details' : 'Add a property', style: display(20))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: fieldDeco('Property name')),
          const SizedBox(height: 14),
          const Text('Type of place', style: TextStyle(fontWeight: FontWeight.w700, color: C.soft)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final t in _typeOptions)
                ChoiceChip(label: Text(t.value), selected: _type == t.key, onSelected: (_) => setState(() => _type = t.key)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: fieldDeco('City')),
          const SizedBox(height: 14),
          TextField(controller: _address, textCapitalization: TextCapitalization.words, decoration: fieldDeco('Address')),
          const SizedBox(height: 14),
          TextField(controller: _description, minLines: 4, maxLines: 8, textCapitalization: TextCapitalization.sentences, decoration: fieldDeco('Description')),
          if (_amenities.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w700, color: C.soft)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final a in _amenities)
                  FilterChip(
                    label: Text('${a['name']}'),
                    selected: _amenityIds.contains((a['id'] as num).toInt()),
                    onSelected: (on) => setState(() {
                      final id = (a['id'] as num).toInt();
                      if (on) {
                        _amenityIds.add(id);
                      } else {
                        _amenityIds.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ],
          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error, style: const TextStyle(color: C.brick, fontWeight: FontWeight.w600))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : (_editing ? 'Save details' : 'Save and continue'))),
        ],
      ),
    );
  }
}
