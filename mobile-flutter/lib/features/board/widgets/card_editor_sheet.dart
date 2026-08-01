import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/board_card.dart';
import '../../../models/board_list.dart';
import '../board_controller.dart';

/// Create-or-edit modal for a card. Which mode it's in is determined by
/// whether [editingCard] is present - both modes share the same form and
/// validation, mirroring the reference web app's `CardDialog.tsx`.
Future<void> showCardEditorSheet(
  BuildContext context, {
  required BoardList list,
  BoardCard? editingCard,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CardEditorSheet(list: list, editingCard: editingCard),
  );
}

class CardEditorSheet extends ConsumerStatefulWidget {
  const CardEditorSheet({required this.list, this.editingCard, super.key});

  final BoardList list;
  final BoardCard? editingCard;

  @override
  ConsumerState<CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends ConsumerState<CardEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _assigneeController;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.editingCard != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.editingCard?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.editingCard?.description ?? '',
    );
    _assigneeController = TextEditingController(
      text: widget.editingCard?.assigneeName ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final assigneeName = _assigneeController.text.trim();
    try {
      final controller = ref.read(boardControllerProvider.notifier);
      if (_isEditing) {
        await controller.updateCard(
          card: widget.editingCard!,
          title: title,
          description: description.isEmpty ? null : description,
          assigneeName: assigneeName.isEmpty ? null : assigneeName,
        );
      } else {
        await controller.createCard(
          listId: widget.list.id,
          listName: widget.list.name,
          title: title,
          description: description.isEmpty ? null : description,
          assigneeName: assigneeName.isEmpty ? null : assigneeName,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit card' : 'New card in ${widget.list.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: 120,
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                  ? 'Title is required'
                  : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLength: 2000,
              maxLines: 3,
            ),
            TextFormField(
              controller: _assigneeController,
              decoration: const InputDecoration(
                labelText: 'Assignee (optional)',
              ),
              maxLength: 80,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create card'),
            ),
          ],
        ),
      ),
    );
  }
}
