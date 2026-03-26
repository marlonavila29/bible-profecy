// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Compresses an image to JPEG using the browser Canvas API.
/// [maxDimension] - max width or height in pixels (default 1024).
/// [quality] - JPEG quality 0.0–1.0 (default 0.85).
Future<Uint8List> compressImageWeb(
  Uint8List bytes, {
  int maxDimension = 1024,
  double quality = 0.85,
}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final img = html.ImageElement()..src = url;
  await img.onLoad.first;

  int w = img.naturalWidth;
  int h = img.naturalHeight;

  // Scale down proportionally
  if (w > maxDimension || h > maxDimension) {
    if (w >= h) {
      h = (h * maxDimension / w).round();
      w = maxDimension;
    } else {
      w = (w * maxDimension / h).round();
      h = maxDimension;
    }
  }

  final canvas = html.CanvasElement(width: w, height: h);
  final ctx = canvas.context2D;
  ctx.drawImageScaled(img, 0, 0, w, h);
  html.Url.revokeObjectUrl(url);

  final completer = Completer<Uint8List>();
  canvas.toBlob('image/jpeg', quality).then((blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;
    completer.complete(Uint8List.fromList(reader.result as List<int>));
  });

  return completer.future;
}
