import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import 'notes_theme.dart';
import 'time_block_interactions.dart';
import 'time_block_view.dart';

class CalendarBlockDrag {
  const CalendarBlockDrag(this.taskId);
  final String taskId;
}

/// Interactive 24h day lane. Each completed pointer gesture makes exactly
/// one call through LocalStore; position previews do not write to SQLite.
class TimeBlockTimeline extends StatelessWidget {
  const TimeBlockTimeline({
    super.key,
    required this.day,
    required this.tasks,
    required this.onChange,
    this.compact = false,
  });

  final DateTime day;
  final List<LocalTask> tasks;
  final Future<void> Function(String id, TimeBlock value) onChange;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = CalendarDayScale(day);
    final pixelsPerHour = compact ? 38.0 : 54.0;
    final blocks = calendarBlockLayout(tasks, scale, pixelsPerHour);
    final totalHeight = scale.getHeight(pixelsPerHour);
    return LayoutBuilder(builder: (context, constraints) {
      final timelineWidth = constraints.maxWidth;
      const rulerWidth = 44.0;
      final availableWidth = (timelineWidth - rulerWidth).clamp(20.0, double.infinity).toDouble();
      return SizedBox(
        key: Key('calendar-timeline-${day.year}-${day.month}-${day.day}'),
        height: totalHeight,
        child: Stack(clipBehavior: Clip.none, children: [
          for (final mark in scale.hours)
            Positioned(
              top: scale.topFor(mark.instant, pixelsPerHour),
              left: 0, right: 0,
              child: Row(children: [
                SizedBox(width: rulerWidth - 4,
                  child: Text(mark.label, style: const TextStyle(
                    color: NotesPalette.secondaryText, fontSize: 10))),
                Expanded(child: Container(height: 1,
                  color: const Color(0xFF343434))),
              ]),
            ),
          for (final item in blocks)
            _InteractiveBlock(
              key: ValueKey('interactive-${item.task.id}'),
              geometry: item,
              pixelsPerHour: pixelsPerHour,
              left: rulerWidth + item.lane * (availableWidth / item.totalLanes),
              width: (availableWidth / item.totalLanes - 4).clamp(18.0, double.infinity).toDouble(),
              onChange: onChange,
            ),
        ]),
      );
    });
  }
}

class _InteractiveBlock extends StatefulWidget {
  const _InteractiveBlock({
    super.key,
    required this.geometry,
    required this.pixelsPerHour,
    required this.left,
    required this.width,
    required this.onChange,
  });
  final CalendarBlockGeometry geometry;
  final double pixelsPerHour;
  final double left;
  final double width;
  final Future<void> Function(String, TimeBlock) onChange;

  @override
  State<_InteractiveBlock> createState() => _InteractiveBlockState();
}

class _InteractiveBlockState extends State<_InteractiveBlock> {
  double move = 0;
  double resize = 0;
  bool busy = false;

  Future<void> _commit(TimeBlock Function(TimeBlock) update) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onChange(widget.geometry.task.id,
          update(widget.geometry.task.timeBlock!));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(
              'Impossibile modificare il blocco. Nessun dato eliminato.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          move = 0;
          resize = 0;
        });
      }
    }
  }

  void _finishMove() {
    final minutes = calendarGestureMinutes(move, widget.pixelsPerHour);
    setState(() => move = 0);
    if (minutes != 0) {
      _commit((block) => calendarMoveBlock(block, minutes));
    }
  }
  void _finishResize() {
    final minutes = calendarGestureMinutes(resize, widget.pixelsPerHour);
    setState(() => resize = 0);
    if (minutes != 0) {
      _commit((block) => calendarResizeBlock(block, minutes));
    }
  }

  Widget _grip() {
    final icon = MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Tooltip(message: 'Trascina su un altro giorno',
        child: const Icon(Icons.drag_indicator, size: 16)),
    );
    final feedback = Material(
      color: const Color(0xFF303B52),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(widget.geometry.task.title,
          style: const TextStyle(color: Colors.white)),
      ),
    );
    // Mouse desktop starts dragging the day handle immediately.
    // On Android a long press avoids hijacking ordinary scrolling.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return LongPressDraggable<CalendarBlockDrag>(
        data: CalendarBlockDrag(widget.geometry.task.id),
        feedback: feedback, childWhenDragging: Opacity(opacity: 0.4, child: icon),
        child: icon,
      );
    }
    return Draggable<CalendarBlockDrag>(
      data: CalendarBlockDrag(widget.geometry.task.id),
      feedback: feedback, childWhenDragging: Opacity(opacity: 0.4, child: icon),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.geometry.task;
    final height = (widget.geometry.height + resize).clamp(36.0, double.infinity).toDouble();
    final short = height < 54 || widget.width < 130;
    return Positioned(
      top: widget.geometry.top + move,
      left: widget.left,
      width: widget.width,
      height: height,
      child: Container(
        key: Key('calendar-block-${task.id}'),
        decoration: BoxDecoration(
          color: const Color(0xFF24354E),
          border: Border.all(color: NotesPalette.accent.withValues(alpha: 0.65)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: GestureDetector(
            key: Key('calendar-block-move-${task.id}'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: busy ? null : (_) => setState(() => move = 0),
            onVerticalDragUpdate: busy ? null : (details) =>
                setState(() => move += details.delta.dy),
            onVerticalDragEnd: busy ? null : (_) => _finishMove(),
            onVerticalDragCancel: () => setState(() => move = 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _grip(),
                    const SizedBox(width: 3),
                    Expanded(child: Text(task.title, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 11))),
                  ]),
                  if (!short)
                    Text(timeBlockLabel(task.timeBlock),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9,
                          color: NotesPalette.secondaryText)),
                ]),
            ),
          )),
          GestureDetector(
            key: Key('calendar-block-resize-${task.id}'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: busy ? null : (_) => setState(() => resize = 0),
            onVerticalDragUpdate: busy ? null : (details) =>
                setState(() => resize += details.delta.dy),
            onVerticalDragEnd: busy ? null : (_) => _finishResize(),
            onVerticalDragCancel: () => setState(() => resize = 0),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: SizedBox(
                height: 11, width: double.infinity,
                child: Center(child: Container(
                  width: 28, height: 3,
                  decoration: BoxDecoration(
                    color: NotesPalette.accent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2)),
                )),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Drop zone for the day represented by a header or month cell.
/// The task identifier is re-read by the caller to avoid stale-task writes.
class CalendarDayDropZone extends StatelessWidget {
  const CalendarDayDropZone({
    super.key, required this.day, required this.onDrop, required this.child,
  });
  final DateTime day;
  final Future<void> Function(String id, DateTime targetDay) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      DragTarget<CalendarBlockDrag>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) =>
            onDrop(details.data.taskId, day),
        builder: (context, candidates, rejects) => DecoratedBox(
          decoration: BoxDecoration(
            border: candidates.isEmpty ? null : Border.all(
              color: NotesPalette.accent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      );
}
