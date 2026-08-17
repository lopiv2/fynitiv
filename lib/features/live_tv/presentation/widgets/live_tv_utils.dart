import '../../domain/program.dart';

/// Formatea un instante como "HH:mm" (hora local de la UI).
String formatProgramTime(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formatea un rango "HH:mm – HH:mm".
String formatProgramRange(DateTime? start, DateTime? end) =>
    '${formatProgramTime(start)} – ${formatProgramTime(end)}';

/// Primer índice de [programs] (ordenada por startTime) cuyo endTime >= [utc].
int firstProgramAtOrAfter(List<Program> programs, DateTime utc) {
  var lo = 0;
  var hi = programs.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (programs[mid].endTime.isBefore(utc)) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Subconjunto de [programs] que intersectan [start]–[end] (búsqueda binaria).
List<Program> programsInWindow(
  List<Program> programs,
  DateTime start,
  DateTime end,
) {
  final first = firstProgramAtOrAfter(programs, start);
  final out = <Program>[];
  for (var i = first; i < programs.length; i++) {
    if (programs[i].startTime.isAfter(end)) break;
    out.add(programs[i]);
  }
  return out;
}

/// Programa de [programs] que contiene el instante [utc], o null.
Program? programAt(List<Program> programs, DateTime utc) {
  final i = firstProgramAtOrAfter(programs, utc);
  if (i < programs.length && !programs[i].startTime.isAfter(utc)) {
    return programs[i];
  }
  return null;
}
