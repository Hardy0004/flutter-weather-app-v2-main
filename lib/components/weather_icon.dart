import 'package:flutter/material.dart';

/// Maps a WeatherAPI condition text (e.g. "Patchy rain possible") to the
/// matching asset file name (e.g. "patchyrainpossible.png").
String weatherIconFile(String conditionText) {
  final name = conditionText.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return '$name.png';
}

/// Image.asset that falls back to a generic icon when a condition has no
/// bundled picture, instead of throwing an exception.
class WeatherIcon extends StatelessWidget {
  final String file;
  final double? width;

  const WeatherIcon({super.key, required this.file, this.width});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/$file',
      width: width,
      errorBuilder: (context, error, stackTrace) =>
          Image.asset('assets/cloud.png', width: width),
    );
  }
}
