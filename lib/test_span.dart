import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  final editor = AppFlowyEditor(
    editorState: EditorState.blank(),
    customBuilders: const {"test": null},
    customTextDecorations: const [],
  );
}
