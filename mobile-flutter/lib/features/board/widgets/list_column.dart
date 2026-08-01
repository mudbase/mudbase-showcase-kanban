import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/board_card.dart';
import '../../../models/board_list.dart';
import '../board_controller.dart';
import 'card_editor_sheet.dart';
import 'card_tile.dart';

/// One board column: header (name + card count + owner-only rename/delete/
/// reorder controls), the vertical list of [CardTile]s, and (when
/// [canManageCards]) an "Add card" affordance. Mirrors the reference web
/// app's `ListColumn.tsx`.
class ListColumn extends ConsumerStatefulWidget {
  const ListColumn({
    required this.list,
    required this.cards,
    required this.otherLists,
    required this.prevList,
    required this.nextList,
    required this.canManageLists,
    required this.canManageCards,
    super.key,
  });

  final BoardList list;
  final List<BoardCard> cards;
  final List<BoardList> otherLists;
  final BoardList? prevList;
  final BoardList? nextList;
  final bool canManageLists;
  final bool canManageCards;

  @override
  ConsumerState<ListColumn> createState() => _ListColumnState();
}

class _ListColumnState extends ConsumerState<ListColumn> {
  bool _renaming = false;
  bool _confirmDelete = false;
  bool _busy = false;
  late final TextEditingController _nameController;
  String? _renameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _saveRename() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _renameError = 'Name is required');
      return;
    }
    if (trimmed.length > 60) {
      setState(() => _renameError = 'Keep the name under 60 characters');
      return;
    }
    if (trimmed == widget.list.name) {
      setState(() => _renaming = false);
      return;
    }
    setState(() {
      _busy = true;
      _renameError = null;
    });
    try {
      await ref
          .read(boardControllerProvider.notifier)
          .renameList(list: widget.list, newName: trimmed);
      if (mounted) setState(() => _renaming = false);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorderList(BoardList neighbor) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(boardControllerProvider.notifier)
          .reorderList(list: widget.list, neighbor: neighbor);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteList() async {
    setState(() {
      _confirmDelete = false;
      _busy = true;
    });
    try {
      await ref.read(boardControllerProvider.notifier).deleteList(widget.list);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: _renaming ? _renameField() : _header(colorScheme),
            ),
            if (_confirmDelete) _deleteConfirm(colorScheme),
            const Divider(height: 1),
            Expanded(
              child: widget.cards.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No cards yet',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.cards.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final card = widget.cards[index];
                        return CardTile(
                          card: card,
                          list: widget.list,
                          otherLists: widget.otherLists,
                          prevCard: index > 0 ? widget.cards[index - 1] : null,
                          nextCard: index < widget.cards.length - 1
                              ? widget.cards[index + 1]
                              : null,
                          canManage: widget.canManageCards,
                        );
                      },
                    ),
            ),
            if (widget.canManageCards)
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: () =>
                      showCardEditorSheet(context, list: widget.list),
                  icon: const Icon(Icons.add),
                  label: const Text('Add card'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${widget.list.name} (${widget.cards.length})',
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.canManageLists) ...[
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Move list left',
            onPressed: (_busy || widget.prevList == null)
                ? null
                : () => _reorderList(widget.prevList!),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Move list right',
            onPressed: (_busy || widget.nextList == null)
                ? null
                : () => _reorderList(widget.nextList!),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Rename list',
            onPressed: _busy ? null : () => setState(() => _renaming = true),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: colorScheme.error,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete list',
            onPressed: _busy
                ? null
                : () => setState(() => _confirmDelete = true),
          ),
        ],
      ],
    );
  }

  Widget _renameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (_) => _saveRename(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.check, size: 18),
              tooltip: 'Save',
              onPressed: _busy ? null : _saveRename,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Cancel',
              onPressed: () => setState(() {
                _renaming = false;
                _renameError = null;
              }),
            ),
          ],
        ),
        if (_renameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _renameError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _deleteConfirm(ColorScheme colorScheme) {
    final count = widget.cards.length;
    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete "${widget.list.name}"'
            '${count > 0 ? ' and its $count card(s)' : ''}?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : _deleteList,
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => setState(() => _confirmDelete = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
