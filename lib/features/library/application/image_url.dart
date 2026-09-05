import 'package:jellyfin_dart/jellyfin_dart.dart';

/// Busca una etiqueta de imagen sin distinguir mayúsculas: la API devuelve
/// claves como 'Primary'/'Logo'/'Thumb' pero `ImageType.name` es minúscula.
String? _imageTag(BaseItemDto item, String typeName) {
  final tags = item.imageTags;
  if (tags == null || tags.isEmpty) return null;
  final wanted = typeName.toLowerCase();
  for (final entry in tags.entries) {
    if (entry.key.toLowerCase() == wanted && entry.value.isNotEmpty) {
      return entry.value;
    }
  }
  return null;
}

/// Construye la URL de la imagen primaria de un item:
/// {server}/Items/{id}/Images/Primary?tag={tag}
String itemImageUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = 300,
}) {
  final tag = _imageTag(item, ImageType.primary.name) ?? '';
  return '$serverUrl/Items/${item.id}/Images/Primary'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}

/// URL del backdrop (fondo) de un item.
/// 1920 = Full HD, resolución nativa habitual de los fanarts de Jellyfin.
String itemBackdropUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = 1920,
}) {
  final tags = item.backdropImageTags ?? const [];
  final tag = tags.isNotEmpty ? tags.first : '';
  return '$serverUrl/Items/${item.id}/Images/Backdrop'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}

/// URL del logo de un item, con respaldo al logo del padre (ej. la serie de
/// un episodio vía `parentLogoItemId`). Devuelve `null` si ni el item ni su
/// padre tienen logo, para no pedir una imagen que devuelve 404.
String? itemLogoUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = 600,
}) {
  final ownTag = _imageTag(item, ImageType.logo.name);
  if (ownTag != null) {
    return '$serverUrl/Items/${item.id}/Images/Logo'
        '?maxWidth=$maxWidth&tag=$ownTag';
  }
  final parentId = item.parentLogoItemId;
  if (parentId != null && parentId.isNotEmpty) {
    final parentTag = item.parentLogoImageTag;
    final tagParam = (parentTag != null && parentTag.isNotEmpty)
        ? '&tag=$parentTag'
        : '';
    return '$serverUrl/Items/$parentId/Images/Logo'
        '?maxWidth=$maxWidth$tagParam';
  }
  return null;
}

/// URL de la imagen de miniatura (Thumb) de un item. Es la imagen de tarjeta
/// panorámica que prefiere el skin estilo Prime en lugar del fondo (Backdrop).
String itemThumbUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = 1920,
}) {
  final tag = _imageTag(item, ImageType.thumb.name) ?? '';
  return '$serverUrl/Items/${item.id}/Images/Thumb'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}
