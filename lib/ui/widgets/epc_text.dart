import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class EpcText extends StatelessWidget {
  final String epc;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;

  const EpcText(
    this.epc, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  static const String thinSpace = '\u2009';

  static String formatEpc(String epc) {
    final clean = epc.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return '';

    final chunks = <String>[];
    for (var i = 0; i < clean.length; i += 4) {
      final end = (i + 4 < clean.length) ? i + 4 : clean.length;
      chunks.add(clean.substring(i, end));
    }

    if (clean.length == 32 && chunks.length == 8) {
      final line1 = chunks.sublist(0, 4).join(thinSpace);
      final line2 = chunks.sublist(4, 8).join(thinSpace);
      return '$line1\n$line2';
    }

    return chunks.join(thinSpace);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = formatEpc(epc);
    final isTwoLines = formatted.contains('\n');

    return Text(
      formatted,
      textAlign: textAlign,
      maxLines: maxLines ?? (isTwoLines ? 2 : 1),
      overflow: TextOverflow.ellipsis,
      style: style ?? AppTypography.epc,
    );
  }
}
