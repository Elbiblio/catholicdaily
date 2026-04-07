import 'package:flutter/material.dart';

import '../../data/models/hymn_rich_content.dart';

class RichContentView extends StatelessWidget {
  final RichContentModel? content;
  final List<String> fallbackLines;
  final double fontSize;
  final bool centered;
  final TextStyle? baseStyle;
  final Color? accentColor;

  const RichContentView({
    super.key,
    required this.content,
    required this.fallbackLines,
    required this.fontSize,
    this.centered = true,
    this.baseStyle,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = baseStyle ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final rich = content;
    if (rich == null || !rich.hasBlocks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildFallback(defaultStyle),
      );
    }

    final widgets = <Widget>[];
    for (var index = 0; index < rich.blocks.length; index++) {
      final block = rich.blocks[index];
      if (block.heading != null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: block.plainLines.isEmpty ? 0 : 8),
            child: Text(
              block.label != null ? '${block.heading!}:' : block.heading!,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: defaultStyle.copyWith(
                fontSize: fontSize - 1,
                fontWeight: FontWeight.w700,
                fontStyle: block.isRefrain ? FontStyle.italic : FontStyle.normal,
                color: accentColor,
              ),
            ),
          ),
        );
      }

      for (final line in block.lines.where((line) => !line.isEmpty)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: RichText(
              textAlign: centered ? TextAlign.center : TextAlign.start,
              text: TextSpan(
                style: defaultStyle.copyWith(fontSize: fontSize, height: 1.22),
                children: _buildSpanChildren(line, defaultStyle),
              ),
            ),
          ),
        );
      }

      if (index != rich.blocks.length - 1) {
        widgets.add(SizedBox(height: block.isRefrain ? 16 : 12));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  List<InlineSpan> _buildSpanChildren(RichLineModel line, TextStyle defaultStyle) {
    if (line.spans.isEmpty) {
      return [TextSpan(text: line.text, style: defaultStyle.copyWith(fontSize: fontSize))];
    }

    return line.spans.map((span) {
      return TextSpan(
        text: span.text,
        style: defaultStyle.copyWith(
          fontSize: fontSize,
          fontWeight: span.bold ? FontWeight.w700 : defaultStyle.fontWeight,
          fontStyle: span.italic ? FontStyle.italic : defaultStyle.fontStyle,
          decoration: span.underline ? TextDecoration.underline : TextDecoration.none,
        ),
      );
    }).toList();
  }

  List<Widget> _buildFallback(TextStyle defaultStyle) {
    final widgets = <Widget>[];
    var previousEmpty = false;
    for (final line in fallbackLines) {
      if (line.trim().isEmpty) {
        if (!previousEmpty) {
          widgets.add(const SizedBox(height: 12));
        }
        previousEmpty = true;
        continue;
      }
      previousEmpty = false;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            line,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: defaultStyle.copyWith(fontSize: fontSize, height: 1.22),
          ),
        ),
      );
    }
    return widgets;
  }
}
