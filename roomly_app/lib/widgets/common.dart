import 'package:flutter/material.dart';

import '../config.dart';
import '../format.dart';
import '../theme.dart';
import 'ridge.dart';

// A price with the marigold highlighter under it.
class Price extends StatelessWidget {
  final num amount;
  final double size;
  const Price(this.amount, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.62, 0.62],
          colors: [Color(0x00000000), Color(0xB3F4B000)],
        ),
      ),
      child: Text(money(amount), style: display(size)),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final String text;
  const ScoreBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

// A property photo, or the drawn ridge when the owner hasn't added one.
class PhotoOrRidge extends StatelessWidget {
  final String? url;
  final String seed;
  const PhotoOrRidge({super.key, required this.url, required this.seed});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return Ridge(seed: seed);
    return Image.network(
      fixUrl(u),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Ridge(seed: seed),
    );
  }
}

class ErrorBox extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const ErrorBox({super.key, required this.title, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: display(20)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: C.soft)),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
