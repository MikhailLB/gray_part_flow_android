import 'dart:io';

import 'package:image/image.dart' as img;

/// Converts the source `icon.webp` into PNGs used by flutter_launcher_icons:
/// a full 1024 icon and a padded foreground for Android adaptive icons.
void main() {
  const String src =
      'assets/SkywardTowers_additional_assets_webp/icon.webp';
  final File file = File(src);
  if (!file.existsSync()) {
    stderr.writeln('Source icon not found: $src');
    exit(1);
  }

  final img.Image? decoded = img.decodeWebP(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode webp.');
    exit(1);
  }

  final img.Image base = img.copyResize(
    decoded,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );

  Directory('assets/generated').createSync(recursive: true);
  final List<int> pngBytes = img.encodePng(base);
  File('assets/generated/app_icon.png').writeAsBytesSync(pngBytes);

  // Full-bleed adaptive foreground: the source art already fills the square and
  // has its own sky background, so we use it edge-to-edge (no padding). This
  // makes the image cover the whole icon with no background border showing.
  File('assets/generated/app_icon_foreground.png').writeAsBytesSync(pngBytes);

  stdout.writeln('Icons generated in assets/generated/');
}
