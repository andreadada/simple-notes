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
    this.onTap,
    this.allowEmpty = false,
    this.maxLength = 255,
  });

  final String value;
  final Future<void> Function(String) onSave;
  final TextStyle style;
  final String semanticsLabel;
  final String hint;
  final VoidCallback? onTap;
  final bool allowEmpty;
  final int maxLength;

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
    if ((!widget.allowEmpty && next.isEmpty) || next == widget.value) {
      if (next.isEmpty && !widget.allowEmpty) _controller.text = widget.value;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // A heading should look like its own text, not a full-width form row.
      final text = _controller.text.isEmpty ? widget.hint : _controller.text;
      final limit = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width * 0.75;
      final glyphWidth = InlineTextMetrics.fieldWidth(
        context, text: text, style: widget.style, maxWidth: limit);
      final fieldWidth = InlineTextMetrics.inputWidth(
        glyphWidth: glyphWidth, maxWidth: limit);
      // Align loosens even a tight Expanded/Row constraint for the input.
      // Only the text, not the whole row, owns the underline.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: SizedBox(
        width: fieldWidth,
        child: InlineGlyphUnderline(
          glyphWidth: glyphWidth,
          focusNode: _focusNode,
          child: Focus(
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
              inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
              onTap: widget.onTap,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _focusNode.unfocus(),
              onTapOutside: (_) => _focusNode.unfocus(),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                hintText: widget.hint,
                hintStyle: widget.style.copyWith(
                  color: NotesPalette.placeholder),
                contentPadding: const EdgeInsets.symmetric(vertical: 3),
                border: NotesTheme.invisibleInlineBorder,
                enabledBorder: NotesTheme.invisibleInlineBorder,
                focusedBorder: NotesTheme.invisibleInlineBorder,
              ),
            ),
          ),
        ),
        ),
        ),
      );
    },
  );
}
