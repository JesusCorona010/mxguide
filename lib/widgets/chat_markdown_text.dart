import 'package:flutter/material.dart';

/// Muestra el texto del asistente con el formato Markdown que mandan los
/// modelos de IA: **negritas**, ***negritas con cursiva***, *cursivas*,
/// `código`, [enlaces](url), listas con "-", "*" o "1." y títulos con "#".
///
/// Es un parser chico hecho a mano (sin paquetes extra) que solo entiende lo
/// que usan los chatbots; lo demás se muestra tal cual.
class ChatMarkdownText extends StatelessWidget {
  const ChatMarkdownText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  // Orden importante: *** antes que ** antes que *.
  static final _inline = RegExp(
    r'\*\*\*(.+?)\*\*\*' // 1: negrita + cursiva
    r'|\*\*(.+?)\*\*' // 2: negrita
    r'|__(.+?)__' // 3: negrita
    r'|(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])' // 4: cursiva *x*
    r'|(?<![\w_])_(?![\s_])(.+?)(?<![\s_])_(?![\w_])' // 5: cursiva _x_
    r'|`([^`]+)`' // 6: código
    r'|\[([^\]]+)\]\(([^)\s]+)\)', // 7: enlace (se muestra solo el texto)
  );

  static final _bullet = RegExp(r'^(\s*)[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
  static final _heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
  static final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final colors = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];

    final lines = text.replaceAll('\r\n', '\n').trim().split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      if (_rule.hasMatch(line)) continue; // Las líneas "---" no se muestran.

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        spans.addAll(_parseInline(
          heading.group(2)!,
          base.copyWith(fontWeight: FontWeight.w800, fontSize: (base.fontSize ?? 16) + 1),
          colors,
        ));
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        final indent = bullet.group(1)!.length >= 2 ? '      ' : '  ';
        spans.add(TextSpan(text: '$indent•  ', style: base.copyWith(fontWeight: FontWeight.w800, color: colors.primary)));
        spans.addAll(_parseInline(bullet.group(2)!, base, colors));
        continue;
      }

      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        spans.add(TextSpan(
          text: '  ${numbered.group(2)}.  ',
          style: base.copyWith(fontWeight: FontWeight.w800, color: colors.primary),
        ));
        spans.addAll(_parseInline(numbered.group(3)!, base, colors));
        continue;
      }

      spans.addAll(_parseInline(line, base, colors));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }

  static List<InlineSpan> _parseInline(String source, TextStyle style, ColorScheme colors) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(source)) {
      if (m.start > last) spans.add(TextSpan(text: source.substring(last, m.start), style: style));

      final bold = style.copyWith(fontWeight: FontWeight.w800);
      final italic = style.copyWith(fontStyle: FontStyle.italic);
      if (m.group(1) != null) {
        spans.addAll(_parseInline(m.group(1)!, bold.copyWith(fontStyle: FontStyle.italic), colors));
      } else if (m.group(2) != null) {
        spans.addAll(_parseInline(m.group(2)!, bold, colors));
      } else if (m.group(3) != null) {
        spans.addAll(_parseInline(m.group(3)!, bold, colors));
      } else if (m.group(4) != null) {
        spans.addAll(_parseInline(m.group(4)!, italic, colors));
      } else if (m.group(5) != null) {
        spans.addAll(_parseInline(m.group(5)!, italic, colors));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
          text: m.group(6),
          style: style.copyWith(
            fontFamily: 'monospace',
            backgroundColor: colors.onSurface.withAlpha(20),
          ),
        ));
      } else if (m.group(7) != null) {
        spans.add(TextSpan(
          text: m.group(7),
          style: style.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
        ));
      }
      last = m.end;
    }
    if (last < source.length) spans.add(TextSpan(text: source.substring(last), style: style));
    return spans;
  }
}
