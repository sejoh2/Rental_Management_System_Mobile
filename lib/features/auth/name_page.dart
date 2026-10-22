import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/message_box.dart';
import 'auth_layout.dart';

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
      await AppScope.read(context).auth.saveName(_name.text.trim());
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _name.text.trim().length >= 2 && !_saving;

    return AuthLayout(
      title: 'What is your name?',
      subtitle:
          'It is shown beside the readings, maintenance and payments you record.',
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            labelText: 'Full names',
            hintText: 'e.g. Mary Wanjiku',
            prefixIcon: Icon(Icons.person_outline),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (ready) _save();
          },
        ),
        const SizedBox(height: AppSpace.lg),
        FilledButton(
          onPressed: ready ? _save : null,
          child: Text(_saving ? 'Saving...' : 'Continue'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.lg),
          ErrorBox(_error!),
        ],
      ],
    );
  }
}
