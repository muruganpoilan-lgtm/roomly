import 'package:flutter/material.dart';

import '../api.dart';
import '../session.dart';
import '../theme.dart';

// Log in or create a guest account. Pops with `true` once the person is logged in.
class LoginScreen extends StatefulWidget {
  final bool startOnSignUp;
  const LoginScreen({super.key, this.startOnSignUp = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _signUp;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  bool _owner = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _signUp = widget.startOnSignUp;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    if (_signUp && _name.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (_signUp && password.length < 8) {
      setState(() => _error = 'Your password needs at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final ApiResult res;
    if (_signUp) {
      final phone = _phone.text.trim();
      res = await Api.post('/auth/register', body: {
        'name': _name.text.trim(),
        'email': email,
        'phone': phone.isEmpty ? null : phone,
        'password': password,
        'role': _owner ? 'owner' : 'guest',
      });
    } else {
      res = await Api.post('/auth/login', body: {'email': email, 'password': password});
    }
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _busy = false;
        _error = res.error;
      });
      return;
    }
    await session.login(res.data['token'] as String, res.data['role'] as String);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(_signUp ? 'Create your account' : 'Log in', style: display(30)),
          const SizedBox(height: 20),
          if (_signUp) ...[
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: fieldDeco('Full name')),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: fieldDeco('Email'),
          ),
          if (_signUp) ...[
            const SizedBox(height: 14),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: fieldDeco('Mobile number (optional)')),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _owner,
              onChanged: (v) => setState(() => _owner = v ?? false),
              title: const Text('I want to list my property'),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _hide,
            onSubmitted: (_) => _submit(),
            decoration: fieldDeco(
              'Password',
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _hide ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error, style: const TextStyle(color: C.brick, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? (_signUp ? 'Creating your account…' : 'Logging in…') : (_signUp ? 'Create account' : 'Log in')),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() {
              _signUp = !_signUp;
              _error = '';
            }),
            child: Text(_signUp ? 'Already have an account? Log in' : 'New here? Create an account'),
          ),
        ],
      ),
    );
  }
}
