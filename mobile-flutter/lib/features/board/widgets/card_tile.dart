import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/board_card.dart';
import '../../../models/board_list.dart';
import '../../../widgets/initials_avatar.dart';
import '../board_controller.dart';
import 'card_editor_sheet.dart';

/// One card within a [ListColumn] - title, optional description, optional
/// assignee chip, and (when [canManage]) edit/delete icon buttons plus the
/// up/down reorder + "Move to…" controls. Mirrors the reference web app's
/// `CardItem.tsx` + `MoveCardControl.tsx` combined, using a `PopupMenuButton`
/// in place of the web's `<Select>` dropdown - the natural touch-UI
/// equivalent of "pick one of the other columns" on mobile.
class CardTile extends ConsumerStatefulWidget {
  const CardTile({
    required this.card,
    required this.list,
    required this.otherLists,
    required this.prevCard,
    required this.nextCard,
    required this.canManage,
    super.key,
  });

  final BoardCard card;
  final BoardList list;
  final List<BoardList> otherLists;
  final BoardCard? prevCard;
  final BoardCard? nextCard;
  final bool canManage;

  @override
  ConsumerState<CardTile> createState() => _CardTileState();
}

class _CardTileState extends ConsumerState<CardTile> {
  bool _confirmDelete = false;
  bool _busy = false;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _delete() async {
    setState(() {
      _confirmDelete = false;
      _busy = true;
    });
    try {
      await ref
          .read(boardControllerProvider.notifier)
          .deleteCard(widget.card, widget.list.name);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveTo(BoardList target) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(boardControllerProvider.notifier)
          .moveCardToList(
            card: widget.card,
            fromListName: widget.list.name,
            toList: target,
          );
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(BoardCard neighbor) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(boardControllerProvider.notifier)
          .reorderCardInList(
            card: widget.card,
            neighbor: neighbor,
            listName: widget.list.name,
          );
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    card.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.canManage) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit card',
                    onPressed: _busy
                        ? null
                        : () => showCardEditorSheet(
                            context,
                            list: widget.list,
                            editingCard: card,
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete card',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _confirmDelete = true),
                  ),
                ],
              ],
            ),
            if (card.description != null && card.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                card.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (card.assigneeName != null && card.assigneeName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  InitialsAvatar(name: card.assigneeName!, radius: 10),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      card.assigneeName!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (_confirmDelete)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delete this card?',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(onPressed: _delete, child: const Text('Delete')),
                    TextButton(
                      onPressed: () => setState(() => _confirmDelete = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            if (widget.canManage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Move up',
                      onPressed: (_busy || widget.prevCard == null)
                          ? null
                          : () => _reorder(widget.prevCard!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Move down',
                      onPressed: (_busy || widget.nextCard == null)
                          ? null
                          : () => _reorder(widget.nextCard!),
                    ),
                    const Spacer(),
                    if (widget.otherLists.isNotEmpty)
                      PopupMenuButton<BoardList>(
                        tooltip: 'Move to…',
                        enabled: !_busy,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        onSelected: _moveTo,
                        itemBuilder: (context) => widget.otherLists
                            .map(
                              (l) =>
                                  PopupMenuItem(value: l, child: Text(l.name)),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
