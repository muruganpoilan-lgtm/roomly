import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../api.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

const _statusLabel = {
  'held': 'Waiting for payment',
  'confirmed': 'Confirmed',
  'cancelled': 'Cancelled',
  'expired': 'Hold expired',
};

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>>? _rows;
  String _error = '';
  String _busy = '';
  Timer? _timer;
  bool _reloadedAfterExpiry = false;
  bool _payOn = false;
  String _notice = '';
  late final Razorpay _rzp;
  String _payingId = '';

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    _rzp = Razorpay();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaid);
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError);
    _rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    _loadConfig();
    if (session.token != null) _load();
    // Ticks every second so the 10-minute hold countdown moves.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final held = (_rows ?? []).where((b) => b['status'] == 'held').toList();
      var anyExpired = false;
      for (final b in held) {
        final until = _until(b);
        if (until != null && !until.isAfter(DateTime.now())) anyExpired = true;
      }
      if (anyExpired && !_reloadedAfterExpiry) {
        _reloadedAfterExpiry = true;
        _load();
      }
      if (held.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rzp.clear();
    session.removeListener(_onSession);
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final res = await Api.get('/payments/config');
    if (!mounted) return;
    if (res.ok && res.data is Map) setState(() => _payOn = res.data['enabled'] == true);
  }

  // Opens Razorpay's payment sheet for a held booking.
  Future<void> _pay(Map<String, dynamic> b) async {
    final id = b['id'].toString();
    setState(() {
      _busy = id;
      _notice = '';
    });
    final res = await Api.post('/payments/bookings/$id/order');
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _busy = '');
      snack(context, res.error);
      _load();
      return;
    }
    final d = res.data as Map;
    _payingId = id;
    try {
      _rzp.open({
        'key': d['key_id'],
        'order_id': d['order_id'],
        'amount': d['amount'],
        'currency': d['currency'],
        'name': 'Roomly',
        'description': '${b['property']}, ${b['room_type']}',
        'theme': {'color': '#0E6B58'},
      });
    } catch (_) {
      setState(() => _busy = '');
      snack(context, "Couldn't open the payment sheet. Try again.");
    }
  }

  // Razorpay says the payment went through. The server checks the signature before confirming.
  Future<void> _onPaid(PaymentSuccessResponse r) async {
    final res = await Api.post('/payments/verify', body: {
      'razorpay_order_id': r.orderId,
      'razorpay_payment_id': r.paymentId,
      'razorpay_signature': r.signature,
    });
    if (!mounted) return;
    setState(() {
      _busy = '';
      if (!res.ok) {
        _error = res.error;
      } else if (res.data['status'] == 'refunded') {
        _notice = 'Your payment arrived after the room was released, and the room was gone. Your money is being refunded in full.';
      } else {
        _notice = 'Payment received. Your booking is confirmed.';
      }
    });
    _load();
  }

  void _onPayError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() => _busy = '');
    final msg = (r.message ?? '').isEmpty ? 'The payment did not go through.' : r.message!;
    snack(context, msg);
  }

  void _onWallet(ExternalWalletResponse r) {
    if (mounted) setState(() => _busy = '');
  }

  void _onSession() {
    if (!mounted) return;
    if (session.token != null) {
      _load();
    } else {
      setState(() => _rows = null);
    }
  }

  DateTime? _until(Map<String, dynamic> b) {
    final v = b['hold_expires_at'];
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  Future<void> _load() async {
    final res = await Api.get('/bookings/mine');
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _error = res.error);
      return;
    }
    _reloadedAfterExpiry = false;
    setState(() {
      _error = '';
      _rows = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  Future<void> _act(String id, String action) async {
    setState(() => _busy = id);
    final res = await Api.post('/bookings/$id/$action');
    if (!mounted) return;
    setState(() => _busy = '');
    if (!res.ok) {
      snack(context, res.error);
    } else if (action == 'cancel' && res.data is Map && res.data['refund'] is Map) {
      final r = res.data['refund'] as Map;
      final amount = toNum(r['amount']);
      var text = '';
      if (r['status'] == 'refunded') {
        text = 'Cancelled. ${money(amount)} is being refunded to your original payment method. It usually takes 5 to 7 working days.';
      } else if (r['status'] == 'pending') {
        text = "Cancelled. Your refund couldn't be sent automatically. We'll process it by hand and email you.";
      } else if (r['reason'] == 'too_late') {
        text = 'Cancelled. This was inside the no-refund window, so no money is returned.';
      }
      setState(() => _notice = text);
    }
    _load();
  }

  Future<void> _confirmCancel(String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text('Your rooms will go back on sale.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep booking')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancel booking', style: TextStyle(color: C.brick))),
        ],
      ),
    );
    if (yes == true) _act(id, 'cancel');
  }

  @override
  Widget build(BuildContext context) {
    if (session.token == null) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text('My bookings', style: display(30)),
        const SizedBox(height: 14),
        const Text('Log in to see your bookings.', style: TextStyle(color: C.soft, fontSize: 15)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text('Log in'),
        ),
      ]);
    }
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text('My bookings', style: display(30)),
          const SizedBox(height: 14),
          if (_notice.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: C.gold, width: 4))),
              child: Text(_notice),
            ),
          if (_error.isNotEmpty) ErrorBox(title: "We couldn't load your bookings", message: _error, onRetry: _load),
          if (rows == null && _error.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: C.green))),
          if (rows != null && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No bookings yet. Search for a room and reserve it here.', style: TextStyle(color: C.soft, fontSize: 15)),
            ),
          if (rows != null) for (final b in rows) _card(b),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color = C.soft;
    if (status == 'confirmed') color = C.green;
    if (status == 'held') color = C.goldText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(99)),
      child: Text(_statusLabel[status] ?? status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    final id = b['id'].toString();
    final status = b['status'].toString();
    final checkIn = parseDay(b['check_in'].toString());
    final checkOut = parseDay(b['check_out'].toString());
    final nights = nightsBetween(checkIn, checkOut);
    final rooms = toNum(b['rooms']).toInt();
    final guests = toNum(b['guests']).toInt();
    final until = _until(b);
    var left = Duration.zero;
    if (status == 'held' && until != null) {
      left = until.difference(DateTime.now());
      if (left.isNegative) left = Duration.zero;
    }
    final mins = left.inMinutes;
    final secs = two(left.inSeconds % 60);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusPill(status),
          const SizedBox(height: 8),
          Text('${b['property']}', style: display(19)),
          const SizedBox(height: 2),
          Text('${b['room_type']}, ${plural(rooms, 'room')}, ${plural(guests, 'guest')} · ${b['city']}', style: const TextStyle(color: C.soft)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('${prettyDayYear(checkIn)} to ${prettyDayYear(checkOut)} (${plural(nights, 'night')})')),
            Price(toNum(b['total_amount']), size: 18),
          ]),
          if (status == 'held' && until != null) ...[
            const SizedBox(height: 10),
            Text(left == Duration.zero ? 'Hold ended' : 'Room held for $mins:$secs', style: const TextStyle(color: C.goldText, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            if (!_payOn)
              const Text("Payments aren't switched on yet. The button below confirms the booking for testing only.", style: TextStyle(color: C.soft, fontSize: 13)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy == id || left == Duration.zero ? null : (_payOn ? () => _pay(b) : () => _act(id, 'confirm')),
                  child: Text(_busy == id ? 'Opening payment…' : (_payOn ? 'Pay ${money(toNum(b['total_amount']))}' : 'Confirm booking (test)')),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _busy == id ? null : () => _act(id, 'cancel'),
                style: OutlinedButton.styleFrom(foregroundColor: C.brick, side: const BorderSide(color: C.brick, width: 1.8)),
                child: const Text('Release room'),
              ),
            ]),
          ],
          if (status == 'confirmed') ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy == id ? null : () => _confirmCancel(id),
              style: OutlinedButton.styleFrom(foregroundColor: C.brick, side: const BorderSide(color: C.brick, width: 1.8)),
              child: const Text('Cancel booking'),
            ),
            const SizedBox(height: 6),
            const Text('Cancel at least 2 days before check-in for a full refund. After that there is no refund.', style: TextStyle(color: C.soft, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
