import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notes_theme.dart';

/// Inline multi-line editing with text-like chrome, Esc cancel and
/// Ctrl+Enter / focus loss save. Uses caller's offline-first write method.
class InlineEditableBody extends StatefulWidget {
  const InlineEditableBody({
    super.key,
    required this.value,
    required this.onSave,
    required this.semanticsLabel,
    this.hint = 'Scrivi qui...',
    this.maxLength = 50000,
    this.minLines = 1,
    this.maxLines = 6,
  });

  final String value;
  final Future<void> Function(String) onSave;
  final String semanticsLabel;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;

  @override
  State<InlineEditableBody> createState() => _InlineEditableBodyState();
}

class _InlineEditableBodyState extends State<InlineEditableBody> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _cancelBlur = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode(debugLabel: 'inline-body');
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant InlineEditableBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus && !_saving) {
      _controller.text = widget.value;
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) return;
    if (_cancelBlur) {
      _cancelBlur = false;
      return;
    }
    _save();
  }

  Future<void> _save() async {
    if (_saving || !mounted || _controller.text == widget.value) return;
    _saving = true;
    try {
      await widget.onSave(_controller.text);
    } catch (_) {
      if (!mounted) return;
      _controller.text = widget.value;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Salvataggio non riuscito. Riprova.')),
      );
    } finally {
      _saving = false;
    }
  }

  void _cancel() {
    _cancelBlur = true;
    _controller.text = widget.value;
    _focus.unfocus();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Align the underline to the text, not to the whole detail panel.
      final maxWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width * 0.75;
      final label = _controller.text.isEmpty ? widget.hint : _controller.text;
      final width = InlineTextMetrics.fieldWidth(
        context,
        text: label,
        style: const TextStyle(fontSize: 14, height: 1.45),
        maxWidth: maxWidth,
      );
      // A parent may demand full width; the editable child does not.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: SizedBox(
        width: width,
        child: Focus(
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancel();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed)) {
        _focus.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Semantics(
      label: widget.semanticsLabel,
      textField: true,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontSize: 14, height: 1.45),
        cursorColor: NotesPalette.accent,
        onTapOutside: (_) => _focus.unfocus(),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(
            fontSize: 14, height: 1.45, color: NotesPalette.placeholder),
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
          border: NotesTheme.inlineBorder,
          enabledBorder: NotesTheme.inlineBorder,
          focusedBorder: NotesTheme.inlineFocusedBorder,
        ),
      ),
    ),
      ),
      ),
    );
    },
  );
}
