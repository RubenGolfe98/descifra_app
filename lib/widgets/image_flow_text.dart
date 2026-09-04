import 'package:flutter/material.dart';

/// Texto que fluye alrededor de una imagen flotante a la izquierda
/// (equivalente a `float: left` en CSS).
class ImageFlowText extends StatelessWidget {
  const ImageFlowText({
    super.key,
    required this.image,
    required this.title,
    required this.titleStyle,
    required this.description,
    required this.descriptionStyle,
    this.imageWidth = 100,
    this.imageHeight = 80,
    this.gap = 12,
    this.titleGap = 4,
    this.textAlign = TextAlign.start,
  });

  final Widget image;
  final String title;
  final TextStyle titleStyle;
  final String description;
  final TextStyle descriptionStyle;
  final double imageWidth;
  final double imageHeight;
  final double gap;
  final double titleGap;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    final justify = textAlign == TextAlign.justify;

    final chunks = <_Chunk>[
      _Chunk('$title\n', base.merge(titleStyle)),
      _Chunk('\u200B\n', base.merge(TextStyle(fontSize: titleGap, height: 1))),
      _Chunk(description, base.merge(descriptionStyle)),
    ];
    final totalChars = chunks.fold<int>(0, (a, c) => a + c.text.length);
    final fullSpan = _spanOf(chunks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final sideWidth = totalWidth - imageWidth - gap;

        int? splitOffset;
        int lastLineStart = 0;

        if (sideWidth > 48) {
          final painter = TextPainter(
            text: fullSpan,
            textDirection: direction,
            textAlign: textAlign,
            textScaler: scaler,
          )..layout(maxWidth: sideWidth);

          final lines = painter.computeLineMetrics();
          final x = direction == TextDirection.rtl ? sideWidth : 0.0;
          double top = 0;
          double prevTop = 0;

          for (var i = 0; i < lines.length; i++) {
            if (i > 0 && top + 0.5 >= imageHeight) {
              final o = painter.getPositionForOffset(Offset(x, top + 1)).offset;
              if (o > 0 && o < totalChars) {
                splitOffset = o;
                lastLineStart =
                    painter.getPositionForOffset(Offset(x, prevTop + 1)).offset;
              }
              break;
            }
            prevTop = top;
            top += lines[i].height;
          }
          painter.dispose();
        }

        if (splitOffset == null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: imageWidth, height: imageHeight, child: image),
              SizedBox(width: gap),
              Expanded(
                child: RichText(
                  text: fullSpan,
                  textAlign: textAlign,
                  textScaler: scaler,
                  textDirection: direction,
                ),
              ),
            ],
          );
        }

        // Cabecera = todo lo que va al lado de la imagen. Su última línea se
        // estira a mano porque Flutter no justifica finales de párrafo.
        final headTop = _slice(chunks, 0, lastLineStart);
        var headLast = _slice(chunks, lastLineStart, splitOffset);
        if (justify) {
          headLast = _stretch(headLast, sideWidth, direction, scaler);
        }
        final head = _spanOf([...headTop, ...headLast]);
        final tail = _spanOf(_slice(chunks, splitOffset, totalChars));

        return Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              width: imageWidth,
              height: imageHeight,
              child: image,
            ),
            ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: totalWidth, minHeight: imageHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.only(start: imageWidth + gap),
                    child: RichText(
                      text: head,
                      textAlign: textAlign,
                      textScaler: scaler,
                      textDirection: direction,
                    ),
                  ),
                  RichText(
                    text: tail,
                    textAlign: textAlign,
                    textScaler: scaler,
                    textDirection: direction,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Chunk {
  const _Chunk(this.text, this.style);
  final String text;
  final TextStyle style;
}

TextSpan _spanOf(List<_Chunk> chunks) => TextSpan(
      children: [
        for (final c in chunks) TextSpan(text: c.text, style: c.style)
      ],
    );

List<_Chunk> _slice(List<_Chunk> chunks, int start, int end) {
  final out = <_Chunk>[];
  var pos = 0;
  for (final c in chunks) {
    final s = pos;
    final e = pos + c.text.length;
    pos = e;
    final from = start.clamp(s, e).toInt() - s;
    final to = end.clamp(s, e).toInt() - s;
    if (to > from) out.add(_Chunk(c.text.substring(from, to), c.style));
  }
  return out;
}

/// Reparte el espacio sobrante de una línea entre sus espacios, imitando
/// lo que hace `TextAlign.justify` con las líneas no finales.
List<_Chunk> _stretch(
  List<_Chunk> line,
  double width,
  TextDirection direction,
  TextScaler scaler,
) {
  final raw = line.map((c) => c.text).join();
  if (raw.contains('\n')) return line; // salto duro: no se justifica

  // Fuera el espacio de wrap final, si lo hay.
  final trimmed = <_Chunk>[...line];
  while (trimmed.isNotEmpty) {
    final last = trimmed.last;
    final t = last.text.replaceFirst(RegExp(r'\s+$'), '');
    if (t == last.text) break;
    if (t.isEmpty) {
      trimmed.removeLast();
    } else {
      trimmed[trimmed.length - 1] = _Chunk(t, last.style);
      break;
    }
  }
  if (trimmed.isEmpty) return line;

  final text = trimmed.map((c) => c.text).join();
  final spaces = ' '.allMatches(text).length;
  if (spaces == 0) return line;

  final painter = TextPainter(
    text: _spanOf(trimmed),
    textDirection: direction,
    textScaler: scaler,
  )..layout();
  final natural = painter.width;
  painter.dispose();

  final extra = width - natural - 0.5; // margen anti-rewrap
  if (extra <= 0) return line;

  final ws = extra / spaces;
  return [
    for (final c in trimmed)
      _Chunk(c.text,
          c.style.copyWith(wordSpacing: (c.style.wordSpacing ?? 0) + ws)),
  ];
}
