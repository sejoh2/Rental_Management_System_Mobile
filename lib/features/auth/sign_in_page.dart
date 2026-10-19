import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/code_boxes.dart';
import '../../widgets/message_box.dart';
import 'auth_layout.dart';

/// Sign-in: the phone number, then the six-digit code sent to it by SMS.
/// On success the app moves on by itself (the router follows the session).
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
      final seconds = await AppScope.read(context).auth.requestCode(phone);

      if (!mounted) return;

      _code.clear();
      setState(() => _sentTo = phone);
      _startCountdown(seconds);
    });
  }

  Future<void> _verify() {
    return _run(
      () => AppScope.read(context).auth.verifyCode(_sentTo!, _code.text.trim()),
    );
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _resendIn = seconds);

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendIn <= 1) timer.cancel();
      if (mounted) {
        setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      }
    });
  }

  void _changeNumber() {
    _countdown?.cancel();
    setState(() {
      _sentTo = null;
      _error = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enteringCode = _sentTo != null;

    return AuthLayout(
      title: enteringCode ? 'Enter the code' : 'Sign in',
      subtitle: enteringCode
          ? 'We sent a six-digit code by SMS to $_sentTo.'
          : 'Use the phone number the property owner registered for you. We will send you a code by SMS.',
      onBack: enteringCode && !_working ? _changeNumber : null,
      children: [
        if (enteringCode) ..._codeStep() else ..._phoneStep(),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.lg),
          ErrorBox(_error!),
        ],
      ],
    );
  }

  List<Widget> _phoneStep() {
    final ready = !_working && _cleanPhone.length >= 9;

    return [
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        ],
        style: AppText.amount.copyWith(
          fontSize: 17,
          color: AppColors.of(context).ink,
        ),
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '0712 345 678',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (ready) _sendCode();
        },
      ),
      const SizedBox(height: AppSpace.lg),
      FilledButton(
        onPressed: ready ? _sendCode : null,
        child: Text(_working ? 'Sending...' : 'Send code'),
      ),
    ];
  }

  List<Widget> _codeStep() {
    final colors = AppColors.of(context);

    return [
      CodeBoxes(
        controller: _code,
        enabled: !_working,
        onChanged: (_) => setState(() {}),
        onCompleted: (_) {
          if (!_working) _verify();
        },
      ),
      const SizedBox(height: AppSpace.lg),
      FilledButton(
        onPressed: _working || _code.text.length != 6 ? null : _verify,
        child: Text(_working ? 'Checking...' : 'Sign in'),
      ),
      const SizedBox(height: AppSpace.sm),
      TextButton(
        onPressed: _working || _resendIn > 0 ? null : _sendCode,
        child: Text(
          _resendIn > 0
              ? 'Send a new code in ${_resendIn}s'
              : 'Send a new code',
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: colors.inkSoft),
        onPressed: _working ? null : _changeNumber,
        child: const Text('Use a different number'),
      ),
    ];
  }
}
