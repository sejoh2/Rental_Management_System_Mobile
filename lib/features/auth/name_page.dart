import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/app_theme.dart';
import '../../widgets/message_box.dart';

/// Asked once, right after the first sign-in: the person's name.
class NamePage extends StatefulWidget {
  const NamePage({super.key});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AppScope.of(context).auth.saveName(_name.text.trim());
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ready = _name.text.trim().length >= 2;

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
                    'What is your name?',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'It is shown beside the readings, repairs and payments you record.',
                    style: TextStyle(
                      color: colors.inkSoft,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full names',
                      hintText: 'e.g. Mary Wanjiku',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (ready && !_saving) _save();
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: ready && !_saving ? _save : null,
                    child: Text(_saving ? 'Saving...' : 'Continue'),
                  ),
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
}
