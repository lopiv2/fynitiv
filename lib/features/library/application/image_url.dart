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

/// Anchos de petición afinados para scrolls (opción A):
/// póster ~500px (tarjetas de 150-300 lógicos + hover x1.3),
/// panorámica ~800px (tarjetas 16:9 pequeñas). El banner pide 1280 explícito.
const int kPosterMaxWidth = 500;
const int kLandscapeMaxWidth = 800;

/// Construye la URL de la imagen primaria de un item:
/// {server}/Items/{id}/Images/Primary?tag={tag}
String itemImageUrl(String serverUrl, BaseItemDto item, {int maxWidth = 300}) {
  final tag = _imageTag(item, ImageType.primary.name) ?? '';
  return '$serverUrl/Items/${item.id}/Images/Primary'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}

/// URL del backdrop (fondo) de un item.
/// 800 = ancho afinado para tarjetas de scroll (el banner pide 1280 explícito).
String itemBackdropUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = kLandscapeMaxWidth,
}) {
  final tags = item.backdropImageTags ?? const [];
  final tag = tags.isNotEmpty ? tags.first : '';
  return '$serverUrl/Items/${item.id}/Images/Backdrop'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}

/// URL del logo de un item, con respaldo al logo del padre (ej. la serie de
/// un episodio vía `parentLogoItemId`). Devuelve `null` si ni el item ni su
/// padre tienen logo, para no pedir una imagen que devuelve 404.
String? itemLogoUrl(String serverUrl, BaseItemDto item, {int maxWidth = 600}) {
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
  int maxWidth = kLandscapeMaxWidth,
}) {
  final tag = _imageTag(item, ImageType.thumb.name) ?? '';
  return '$serverUrl/Items/${item.id}/Images/Thumb'
      '?maxWidth=$maxWidth${tag.isNotEmpty ? '&tag=$tag' : ''}';
}

/// Devuelve la mejor imagen panorámica disponible (backdrop → thumb → primary).
String? bestLandscapeImageUrl(
  String serverUrl,
  BaseItemDto item, {
  int maxWidth = kLandscapeMaxWidth,
  int primaryMaxWidth = kPosterMaxWidth,
}) {
  if ((item.backdropImageTags ?? const []).isNotEmpty) {
    return itemBackdropUrl(serverUrl, item, maxWidth: maxWidth);
  }

  final imageTags = item.imageTags;
  if (imageTags == null) return null;
  final imageTypes = imageTags.keys.map((type) => type.toLowerCase()).toSet();
  if (imageTypes.contains(ImageType.thumb.name)) {
    return itemThumbUrl(serverUrl, item, maxWidth: maxWidth);
  }
  if (imageTypes.contains(ImageType.primary.name)) {
    return itemImageUrl(serverUrl, item, maxWidth: primaryMaxWidth);
  }
  return null;
}

/// Tipo de imagen preferida para resolver la URL única de una tarjeta.
/// Espejo mínimo de `RowImageSource` sin depender del skin (este archivo
/// lo usan también providers y precache).
enum CardImageKind { primary, thumb, backdrop }

bool _hasTag(BaseItemDto item, String typeName) =>
    _imageTag(item, typeName) != null;

bool _hasBackdrop(BaseItemDto item) =>
    (item.backdropImageTags ?? const []).isNotEmpty;

/// Resuelve UNA sola URL para la tarjeta según los tags ya presentes en el
/// DTO, sin peticiones de prueba en red. Orden:
/// - `thumb`: thumb → backdrop → primary.
/// - `backdrop`: backdrop → thumb → primary.
/// - `primary`: primary → thumb → backdrop.
/// Devuelve `null` si el item no trae ningún tag, para pintar el fallback
/// local directamente en vez de provocar un 404.
String? singleCardImageUrl(
  String serverUrl,
  BaseItemDto item,
  CardImageKind kind, {
  int landscapeWidth = kLandscapeMaxWidth,
  int posterWidth = kPosterMaxWidth,
}) {
  final hasThumb = _hasTag(item, ImageType.thumb.name);
  final hasBackdrop = _hasBackdrop(item);
  final hasPrimary = _hasTag(item, ImageType.primary.name);
  switch (kind) {
    case CardImageKind.thumb:
      if (hasThumb) return itemThumbUrl(serverUrl, item, maxWidth: landscapeWidth);
      if (hasBackdrop) {
        return itemBackdropUrl(serverUrl, item, maxWidth: landscapeWidth);
      }
      if (hasPrimary) return itemImageUrl(serverUrl, item, maxWidth: posterWidth);
      return null;
    case CardImageKind.backdrop:
      if (hasBackdrop) {
        return itemBackdropUrl(serverUrl, item, maxWidth: landscapeWidth);
      }
      if (hasThumb) return itemThumbUrl(serverUrl, item, maxWidth: landscapeWidth);
      if (hasPrimary) return itemImageUrl(serverUrl, item, maxWidth: posterWidth);
      return null;
    case CardImageKind.primary:
      if (hasPrimary) return itemImageUrl(serverUrl, item, maxWidth: posterWidth);
      if (hasThumb) return itemThumbUrl(serverUrl, item, maxWidth: landscapeWidth);
      if (hasBackdrop) {
        return itemBackdropUrl(serverUrl, item, maxWidth: landscapeWidth);
      }
      return null;
  }
}

/// URL del póster de la serie para un episodio, o `null` si no hay serie.
String? seriesPosterUrl(
  String serverUrl,
  BaseItemDto episode, {
  int maxWidth = kPosterMaxWidth,
}) {
  if (episode.type != BaseItemKind.episode) return null;
  final seriesId = episode.seriesId;
  if (seriesId == null || seriesId.isEmpty) return null;
  final tag = episode.seriesPrimaryImageTag;
  return tag != null && tag.isNotEmpty
      ? '$serverUrl/Items/$seriesId/Images/Primary?maxWidth=$maxWidth&tag=$tag'
      : '$serverUrl/Items/$seriesId/Images/Primary?maxWidth=$maxWidth';
}
