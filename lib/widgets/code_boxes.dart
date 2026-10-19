import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';

/// The sign-in code as six boxes, one digit each, as on the web sign-in
/// page. Under the boxes is one ordinary text field, so the phone's
/// "fill code from SMS", pasting and backspace all work as usual; the
/// boxes only show what is in it, with the next box to fill outlined.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.autofocus = true,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Called once all the boxes are filled.
  final ValueChanged<String>? onCompleted;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(CodeBoxes old) {
    super.didUpdateWidget(old);

    if (old.controller != widget.controller) {
      old.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final code = widget.controller.text;
    // The box the next digit goes in (the last one once all are filled).
    final current = code.length < widget.length
        ? code.length
        : widget.length - 1;

    return Semantics(
      label: 'Sign-in code, ${widget.length} digits',
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _focus.requestFocus : null,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: _Box(
                      digit: i < code.length ? code[i] : '',
                      active: _focus.hasFocus && widget.enabled && i == current,
                      colors: colors,
                    ),
                  ),
                ],
              ],
            ),
            // The real field: invisible, over the boxes, so taps and the
            // keyboard reach it.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    widget.onChanged?.call(value);

                    if (value.length == widget.length) {
                      widget.onCompleted?.call(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.colors});

  final String digit;
  final bool active;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active ? colors.accent : colors.line,
          width: active ? 1.6 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: colors.accentSoft, spreadRadius: 2)]
            : null,
      ),
      child: Text(
        digit,
        style: AppText.figure.copyWith(fontSize: 20, color: colors.ink),
      ),
    );
  }
}
