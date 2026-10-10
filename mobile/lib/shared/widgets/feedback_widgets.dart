import 'package:flutter/material.dart';

/// Confirmation d'action irréversible (J24 §6) avec bouton destructif.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Saisie de texte dans une boîte de dialogue. Renvoie le texte saisi (non
/// vide) lorsque l'utilisateur valide, sinon `null`.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Valider',
  int maxLines = 3,
  int maxLength = 255,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextPromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
      maxLength: maxLength,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.maxLines,
    required this.maxLength,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final int maxLines;
  final int maxLength;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.of(context).pop(text.isEmpty ? null : text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Toast simple (SnackBar) — J24 §2.
void showToast(BuildContext context, String message, {bool isError = false}) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    behavior: SnackBarBehavior.floating,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}