import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notes_theme.dart';

/// Inline-first title: looks like a heading while remaining a real editable
/// text field. Enter or focus loss persists; Escape cancels without writing.
/// Useful for lists, note titles and other short displayed attributes.
class InlineEditableTitle extends StatefulWidget {
  const InlineEditableTitle({
    super.key,
    required this.value,
    required this.onSave,
    required this.style,
    required this.semanticsLabel,
    this.hint = 'Senza titolo',
  });

  final String value;
  final Future<void> Function(String) onSave;
  final TextStyle style;
  final String semanticsLabel;
  final String hint;

  @override
  State<InlineEditableTitle> createState() => _InlineEditableTitleState();
}

class _InlineEditableTitleState extends State<InlineEditableTitle> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _cancelNextBlur = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode(debugLabel: 'inline-editable-title');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant InlineEditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A remote update may arrive while the user is typing: never erase their
    // draft mid-edit. The normal optimistic version check handles conflicts.
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    if (_cancelNextBlur) {
      _cancelNextBlur = false;
      return;
    }
    _save();
  }

  Future<void> _save() async {
    if (_saving || !mounted) return;
    final next = _controller.text.trim();
    if (next.isEmpty || next == widget.value) {
      if (next.isEmpty) _controller.text = widget.value;
      return;
    }
    _saving = true;
    try {
      await widget.onSave(next);
    } catch (_) {
      if (!mounted) return;
      _controller.text = widget.value;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Impossibile salvare il titolo. Riprova.')),
      );
    } finally {
      _saving = false;
    }
  }

  void _cancel() {
    _cancelNextBlur = true;
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _cancel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Semantics(
      label: widget.semanticsLabel,
      textField: true,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: widget.style,
        cursorColor: NotesPalette.accent,
        textInputAction: TextInputAction.done,
        maxLines: 1,
        inputFormatters: [LengthLimitingTextInputFormatter(255)],
        onSubmitted: (_) => _focusNode.unfocus(),
        onTapOutside: (_) => _focusNode.unfocus(),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 3),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: NotesPalette.accent, width: 1.5),
          ),
        ),
      ),
    ),
  );
}
