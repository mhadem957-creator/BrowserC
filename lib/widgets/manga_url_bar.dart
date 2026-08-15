import 'package:flutter/material.dart';

import '../theme/manga_theme.dart';

/// Speech-bubble styled URL / search bar with sharp edges and thick ink lines.
class MangaUrlBar extends StatelessWidget {
  const MangaUrlBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSecure,
    required this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSecure;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: MangaTheme.paper,
        border: Border.all(color: MangaTheme.ink, width: MangaTheme.borderWidth),
        boxShadow: [
          BoxShadow(
            color: MangaTheme.ink,
            offset: MangaTheme.shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Lock / info indicator
          Container(
            width: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: MangaTheme.ink, width: 2.5),
              ),
            ),
            child: Icon(
              isSecure ? Icons.lock : Icons.info_outline,
              size: 18,
              color: isSecure ? MangaTheme.crimson : MangaTheme.ink,
            ),
          ),
          // Text field
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(
                  color: MangaTheme.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Search or enter address…',
                  hintStyle: TextStyle(
                    color: MangaTheme.ink.withOpacity(0.4),
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: onSubmitted,
                onTap: () {
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                },
              ),
            ),
          ),
          // Clear button when focused / has text
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 8);
              return IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: MangaTheme.ink,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
