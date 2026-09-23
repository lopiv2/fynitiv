/// Formatea bytes a legible (B/KB/MB/GB/TB). `—` si no hay dato.
String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  final decimals = size >= 100 ? 0 : size >= 10 ? 1 : 2;
  return '${size.toStringAsFixed(decimals)} ${units[i]}';
}
