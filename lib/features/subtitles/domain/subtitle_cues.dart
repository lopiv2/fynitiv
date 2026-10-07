/// Parseo de subtítulos (SRT/WebVTT/ASS/SSA) a líneas con tiempos, para la
/// sincronización manual por texto.
library;

/// Una línea de subtítulo con su intervalo de tiempo.
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// Parsea el contenido de un subtítulo y devuelve sus líneas ordenadas por
/// tiempo de inicio. Soporta SRT, WebVTT, ASS y SSA. Devuelve lista vacía si
/// no reconoce el formato.
List<SubtitleCue> parseSubtitleCues(String content) {
  if (content.trim().isEmpty) return const [];
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final isAss = RegExp(
    r'^\s*Dialogue\s*:',
    multiLine: true,
  ).hasMatch(normalized);
  final cues = isAss ? _parseAss(normalized) : _parseSrtVtt(normalized);
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

/// `HH:MM:SS,mmm --> HH:MM:SS,mmm` (SRT) o `[HH:]MM:SS.mmm --> …` (VTT).
final RegExp _timeRe = RegExp(
  r'(?:(\d{1,3}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->\s*'
  r'(?:(\d{1,3}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})',
);

List<SubtitleCue> _parseSrtVtt(String content) {
  final cues = <SubtitleCue>[];
  final lines = content.split('\n');
  var i = 0;
  while (i < lines.length) {
    final match = _timeRe.firstMatch(lines[i]);
    if (match == null) {
      i++;
      continue;
    }
    final start = _timeFromMatch(match, 1);
    final end = _timeFromMatch(match, 5);
    i++;
    final buffer = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      buffer.add(lines[i]);
      i++;
    }
    final text = _cleanText(buffer.join('\n'));
    if (start != null && end != null && text.isNotEmpty) {
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }
  }
  return cues;
}

Duration? _timeFromMatch(RegExpMatch match, int offset) {
  final hours = int.tryParse(match.group(offset) ?? '0') ?? 0;
  final minutes = int.tryParse(match.group(offset + 1) ?? '0') ?? 0;
  final seconds = int.tryParse(match.group(offset + 2) ?? '0') ?? 0;
  final msRaw = match.group(offset + 3) ?? '0';
  final millis = int.tryParse(msRaw.padRight(3, '0').substring(0, 3)) ?? 0;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: millis,
  );
}

final RegExp _assTimeRe = RegExp(r'(\d+):(\d{2}):(\d{2})[.](\d{1,2})');

Duration? _assTime(String value) {
  final match = _assTimeRe.firstMatch(value.trim());
  if (match == null) return null;
  final cs = int.tryParse(match.group(4)!.padRight(2, '0').substring(0, 2)) ?? 0;
  return Duration(
    hours: int.tryParse(match.group(1)!) ?? 0,
    minutes: int.tryParse(match.group(2)!) ?? 0,
    seconds: int.tryParse(match.group(3)!) ?? 0,
    milliseconds: cs * 10,
  );
}

const List<String> _kDefaultAssFormat = [
  'layer',
  'start',
  'end',
  'style',
  'name',
  'marginl',
  'marginr',
  'marginv',
  'effect',
  'text',
];

List<SubtitleCue> _parseAss(String content) {
  final cues = <SubtitleCue>[];
  final lines = content.split('\n');
  var inEvents = false;
  var format = _kDefaultAssFormat;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      inEvents = line.toLowerCase() == '[events]';
      continue;
    }
    if (!inEvents) continue;
    if (line.startsWith('Format:')) {
      format = line
          .substring(7)
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();
      continue;
    }
    if (!line.startsWith('Dialogue:')) continue;
    final parts = line.substring(9).split(',');
    final startIdx = format.indexOf('start');
    final endIdx = format.indexOf('end');
    final textIdx = format.indexOf('text');
    if (startIdx < 0 || endIdx < 0 || textIdx < 0) continue;
    if (parts.length <= textIdx) continue;
    final start = _assTime(parts[startIdx]);
    final end = _assTime(parts[endIdx]);
    // El texto puede contener comas: se recompone desde `text` hasta el final.
    final text = _cleanText(parts.sublist(textIdx).join(','));
    if (start != null && end != null && text.isNotEmpty) {
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }
  }
  return cues;
}

final RegExp _tagRe = RegExp(r'<[^>]+>');
final RegExp _assTagRe = RegExp(r'\{[^}]*\}');
final RegExp _assBreakRe = RegExp(r'\\[Nn]');

/// Limpia el texto: quita etiquetas HTML/ASS y convierte saltos ASS (`\N`).
String _cleanText(String value) {
  var text = value.replaceAll(_tagRe, '');
  text = text.replaceAll(_assTagRe, '');
  text = text.replaceAll(_assBreakRe, '\n');
  return text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}
