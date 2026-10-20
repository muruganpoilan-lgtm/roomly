import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../config.dart';
import '../theme.dart';
import 'common.dart';

// Shows a property's or room's photos, with buttons to add more from the gallery and to remove one.
// `base` is e.g. /owner/properties/ID or /owner/room-types/ID. `onChanged` runs after every add or remove.
class PhotoStrip extends StatefulWidget {
  final String base;
  final List<Map<String, dynamic>> photos;
  final VoidCallback onChanged;
  const PhotoStrip({super.key, required this.base, required this.photos, required this.onChanged});

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  bool _busy = false;

  Future<void> _add() async {
    List<XFile> picked;
    try {
      // Shrinking to 2200 px keeps phone photos well under the 5 MB limit.
      picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2200, maxHeight: 2200);
    } catch (_) {
      if (mounted) snack(context, "Couldn't open your photos. Allow photo access in the phone settings and try again.");
      return;
    }
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    final files = <MapEntry<String, List<int>>>[];
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      files.add(MapEntry(x.name, bytes));
    }
    final res = await Api.uploadFiles('${widget.base}/photos', files);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      snack(context, res.error);
      return;
    }
    widget.onChanged();
  }

  Future<void> _remove(Map<String, dynamic> photo) async {
    final yes = await askYesNo(context, 'Remove this photo?', 'Guests will no longer see it.', 'Remove');
    if (!yes || !mounted) return;
    final res = await Api.delete('${widget.base}/photos/${photo['id']}');
    if (!mounted) return;
    if (!res.ok) {
      snack(context, res.error);
      return;
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = photos[i];
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      fixUrl('${p['url']}'),
                      width: 144,
                      height: 108,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 144, height: 108, color: C.line, child: const Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _remove(p),
                        child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.close, size: 18, color: C.brick)),
                      ),
                    ),
                  ),
                  if (i == 0)
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Cover', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]);
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _add,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(_busy ? 'Uploading…' : (photos.isEmpty ? 'Add photos' : 'Add more photos')),
        ),
        const SizedBox(height: 4),
        const Text('JPG, PNG or WebP. The first photo is the cover.', style: TextStyle(color: C.soft, fontSize: 13)),
      ],
    );
  }
}
