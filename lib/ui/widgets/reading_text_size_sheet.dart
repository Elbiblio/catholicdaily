import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/reading_text_size_preference.dart';

class ReadingTextSizeSheet extends StatelessWidget {
  const ReadingTextSizeSheet({super.key, required this.preference});

  final ReadingTextSizePreference preference;

  static Future<void> show(
    BuildContext context, {
    required ReadingTextSizePreference preference,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ReadingTextSizeSheet(preference: preference),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: preference,
      builder: (context, child) {
        final selected = preference.currentSize;
        final baseFontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reading Text Size',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Reading text preview',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'The Lord is my shepherd; I shall not want.',
                    key: const ValueKey<String>('reading-text-size-preview'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: baseFontSize * selected.scale,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<ReadingTextSize>(
                groupValue: selected,
                onChanged: (size) {
                  if (size != null) unawaited(preference.setSize(size));
                },
                child: Column(
                  children: ReadingTextSize.values
                      .map(
                        (size) => ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: RadioListTile<ReadingTextSize>(
                            value: size,
                            selected: size == selected,
                            contentPadding: EdgeInsets.zero,
                            title: Text(size.label),
                            secondary: Text(
                              size.percentageLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (selected != ReadingTextSize.standard) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        unawaited(preference.setSize(ReadingTextSize.standard)),
                    child: const Text('Reset to Standard'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
