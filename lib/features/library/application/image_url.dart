import 'package:jellyfin_dart/jellyfin_dart.dart';

/// Construye la URL de la imagen primaria de un item:
/// {server}/Items/{id}/Images/Primary?tag={tag}
String itemImageUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = 300,
}) {
  final tag = item.imageTags?[ImageType.primary.name] ?? '';
  return '$serverUrl/Items/${item.id}/Images/Primary'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}

/// URL del backdrop (fondo) de un item.
String itemBackdropUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = 1280,
}) {
  final tags = item.backdropImageTags ?? const [];
  final tag = tags.isNotEmpty ? tags.first : '';
  return '$serverUrl/Items/${item.id}/Images/Backdrop'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}
