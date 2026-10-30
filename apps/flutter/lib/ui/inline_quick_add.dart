import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'notes_theme.dart';

/// One-line inline creator: the underline grows with text/placeholder, not
/// the available width of the parent Row. The right-hand action stays aligned.
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
  final _focusNode = FocusNode();
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
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, draft, _) {
        const textStyle = TextStyle(fontSize: 13);
        final available = bounds.maxWidth.isFinite
            ? bounds.maxWidth - 80
            : MediaQuery.sizeOf(context).width * 0.5;
        final glyphWidth = InlineTextMetrics.fieldWidth(
          context,
          text: draft.text.isEmpty ? widget.hint : draft.text,
          style: textStyle,
          maxWidth: available,
        );
        final fieldWidth = InlineTextMetrics.inputWidth(
          glyphWidth: glyphWidth, maxWidth: available);
        return Row(children: [
          Icon(Icons.add, size: 17,
            color: NotesPalette.of(context).secondaryText),
          const SizedBox(width: 7),
          SizedBox(width: fieldWidth, child: InlineGlyphUnderline(
            glyphWidth: glyphWidth,
            focusNode: _focusNode,
            child: TextField(
            key: const Key('inline-quick-add-input'),
            controller: _controller,
            focusNode: _focusNode,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: textStyle,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 13, color: NotesPalette.of(context).placeholder),
              counterText: '',
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: NotesTheme.invisibleInlineBorder,
              enabledBorder: NotesTheme.invisibleInlineBorder,
              focusedBorder: NotesTheme.invisibleInlineBorder,
            ),
          ))),
          const Spacer(),
          FButton.icon(
            key: const Key('inline-quick-add-submit'),
            variant: FButtonVariant.ghost,
            onPress: _busy ? null : _submit,
            child: const Icon(Icons.add, size: 18),
          ),
        ]);
      },
    ),
  );
}
