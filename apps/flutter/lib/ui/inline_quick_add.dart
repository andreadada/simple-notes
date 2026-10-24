import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'notes_theme.dart';

/// Compact, directly editable creation row. Enter commits to SQLite/outbox
/// through [onAdd]; a failed write keeps the draft for retry.
class InlineQuickAdd extends StatefulWidget {
  const InlineQuickAdd({
    super.key,
    required this.onAdd,
    this.hint = 'Aggiungi...',
    this.maxLength = 255,
  });

  final Future<void> Function(String) onAdd;
  final String hint;
  final int maxLength;

  @override
  State<InlineQuickAdd> createState() => _InlineQuickAddState();
}

class _InlineQuickAddState extends State<InlineQuickAdd> {
  final _controller = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (_busy || text.isEmpty || text.length > widget.maxLength) return;
    setState(() => _busy = true);
    try {
      await widget.onAdd(text);
      if (mounted && _controller.text.trim() == text) _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Impossibile aggiungere. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: TextField(
      key: const Key('inline-quick-add-input'),
      controller: _controller,
      maxLength: widget.maxLength,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: widget.hint,
        counterText: '',
        isDense: true,
        prefixIcon: const Icon(Icons.add, size: 18),
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(vertical: 9),
        border: NotesTheme.inlineBorder,
        enabledBorder: NotesTheme.inlineBorder,
        focusedBorder: NotesTheme.inlineFocusedBorder,
      ),
    )),
    FButton.icon(
      key: const Key('inline-quick-add-submit'),
      variant: FButtonVariant.ghost,
      onPress: _busy ? null : _submit,
      child: const Icon(Icons.add, size: 18),
    ),
  ]);
}
