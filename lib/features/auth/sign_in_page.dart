import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/app_theme.dart';
import '../../widgets/message_box.dart';

/// Sign-in: the phone number, then the six-digit code sent to it by SMS.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  /// The number the code was sent to; null while the number is being entered.
  String? _sentTo;
  bool _working = false;
  String? _error;

  /// Seconds until another code may be asked for.
  int _resendIn = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _cleanPhone => _phone.text.replaceAll(RegExp(r'\s'), '');

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendCode() {
    final phone = _cleanPhone;

    return _run(() async {
      final seconds = await AppScope.of(context).auth.requestCode(phone);

      if (!mounted) return;

      _code.clear();
      setState(() => _sentTo = phone);
      _startCountdown(seconds);
    });
  }

  Future<void> _verify() {
    // On success the app moves on by itself: the session has changed.
    return _run(() => AppScope.of(context).auth.verifyCode(_sentTo!, _code.text.trim()));
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _resendIn = seconds);

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendIn <= 1) timer.cancel();
      if (mounted) setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enteringCode = _sentTo != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    appName,
                    style: TextStyle(color: colors.accentInk, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    enteringCode ? 'Enter the code' : 'Sign in',
                    style: TextStyle(color: colors.ink, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    enteringCode
                        ? 'We sent a six-digit code by SMS to $_sentTo.'
                        : 'Enter the phone number the property owner registered for you. We will send you a code by SMS.',
                    style: TextStyle(color: colors.inkSoft, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (enteringCode) ..._codeStep(colors) else ..._phoneStep(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    ErrorBox(_error!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep() {
    return [
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
        decoration: const InputDecoration(labelText: 'Phone number', hintText: '0712 345 678'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (!_working && _cleanPhone.length >= 9) _sendCode();
        },
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _working || _cleanPhone.length < 9 ? null : _sendCode,
        child: Text(_working ? 'Sending...' : 'Send code'),
      ),
    ];
  }

  List<Widget> _codeStep(AppColors colors) {
    return [
      TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: '', hintText: '------'),
        onChanged: (value) {
          setState(() {});

          if (value.length == 6 && !_working) _verify();
        },
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _working || _code.text.length != 6 ? null : _verify,
        child: Text(_working ? 'Checking...' : 'Sign in'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _working || _resendIn > 0 ? null : _sendCode,
        child: Text(_resendIn > 0 ? 'Send a new code in $_resendIn s' : 'Send a new code'),
      ),
      TextButton(
        onPressed: _working
            ? null
            : () {
                _countdown?.cancel();
                setState(() {
                  _sentTo = null;
                  _error = null;
                  _resendIn = 0;
                });
              },
        child: const Text('Use a different number'),
      ),
    ];
  }
}
