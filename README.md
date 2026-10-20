<p align="center">
  <img src="assets/images/Logo_fynitiv.png" alt="Fynitiv logo" width="180" />
</p>

<h1 align="center">Fynitiv</h1>

<p align="center">
  <strong>Your media, games, books, and karaoke — all in one supercharged hub.</strong>
</p>

<p align="center">
  One app for your favorite platforms. No need to install a different client for every screen.
</p>

Fynitiv is a cross-platform **Jellyfin client** built with Flutter. It brings your movies, TV
shows, music, books, radio, and game library together, with a flexible interface that you can
make your own.

## Why Fynitiv?

- **One media hub:** browse and play your Jellyfin movies and shows, listen to music and radio,
  and read books and comics.
- **Make it yours:** choose a skin inspired by your favorite streaming platforms, or customize
  the layout and appearance to suit you.
- **Karaoke mode:** sing along with synchronized lyrics. No one else had this? We wanted it, so
  we made it — with visual effects that make your music move.
- **Subtitles on your terms:** adjust subtitle timing to match the audio, and use the available
  subtitle tools to get the dialogue back in sync.
- **Your game library:** connect ROMM to browse your collection and play supported games with
  the available in-browser emulation options.
- **Looking for something?** Connect Seerr to discover and request movies or shows from your
  usual request service. It can handle the hunt; you can handle the popcorn.
- **Ready for the big screen:** navigate the interface and player controls with a keyboard or
  TV remote / D-pad.
- **Seasonal splash presentations:** Halloween and Christmas get their own music and animated
  scenes. Because even starting an app can have a little drama.

### No extra Jellyfin plugins required

Fynitiv's core Jellyfin features work with a standard Jellyfin server — **you don't need to
install additional Jellyfin plugins just to use the app**. ROMM and Seerr are optional
integrations and require their own services if you want to use those features.

## Platforms

Fynitiv targets **Android, Linux, and Windows**. Availability of ready-to-install builds may
vary by release.

## Getting started

1. Set up a Jellyfin server and add your media libraries.
2. Install or run Fynitiv on a supported platform.
3. Connect to your Jellyfin server and sign in.
4. Pick a skin and start watching, listening, reading, or singing.

ROMM and Seerr are optional; configure them only if you want to use the games or media-request
features.

## Run from source

Fynitiv is a Flutter project. With Flutter installed, from the repository root run:

```bash
flutter pub get
flutter run
```

Choose a target device supported by your Flutter installation. Some optional features also
need a reachable Jellyfin, ROMM, or Seerr service.

## Something missing?

If you notice a feature that's missing, just ask the creator. He's a really nice guy. 🙂

Feature requests and bug reports are welcome through GitHub Issues.

---

Fynitiv is an independent Jellyfin client. Jellyfin and third-party product names and logos
belong to their respective owners.
