import 'package:flutter/material.dart';

import '../app/theme/neo_theme.dart';

void showNeoMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
}

Future<bool> confirmNeoAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Lanjutkan',
  bool destructive = false,
}) async {
  final palette = NeoPalette.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: palette.border, width: 2.5),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: palette.secondary)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

String friendlyError(Object error) => switch (error) {
      ArgumentError() => error.message?.toString() ?? 'Input belum valid.',
      FormatException() => error.message,
      StateError() => error.message,
      _ => 'Operasi belum berhasil. Periksa izin dan coba lagi.',
    };

Future<T?> guardNeoAction<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
}) async {
  try {
    final result = await action();
    if (success != null && context.mounted) showNeoMessage(context, success);
    return result;
  } catch (error) {
    if (context.mounted) showNeoMessage(context, friendlyError(error));
    return null;
  }
}
