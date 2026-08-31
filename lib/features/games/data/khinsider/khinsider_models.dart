class KhinsiderAlbum {
  const KhinsiderAlbum({
    required this.title,
    required this.albumUrl,
    this.coverThumb,
  });
  final String title;
  final String albumUrl; // absolute https://downloads.khinsider.com/...
  final String? coverThumb;
}

class KhinsiderTrack {
  const KhinsiderTrack({
    required this.name,
    required this.pageUrl, // antes lo llamabas "url", pero es la página, no el audio
    this.duration,
  });
  final String name;
  final String pageUrl;
  final String? duration;
}
