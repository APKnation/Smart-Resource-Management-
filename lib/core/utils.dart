import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared formatting + misc helpers.

String formatDate(DateTime? dt) =>
    dt == null ? '—' : DateFormat.yMMMd().add_jm().format(dt.toLocal());

String formatDateOnly(DateTime? dt) =>
    dt == null ? '—' : DateFormat.yMMMd().format(dt.toLocal());

String formatBytes(int? bytes) {
  if (bytes == null || bytes < 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  double v = bytes.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.length == 1
      ? parts.first.substring(0, 1).toUpperCase()
      : (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Maps a file extension to a rough resource type label for icons/colors.
IconData iconForType(String? type, String? fileName) {
  final ext = (fileName ?? '').split('.').last.toLowerCase();
  switch ((type ?? '').toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'video':
      return Icons.movie_outlined;
    case 'audio':
      return Icons.audiotrack_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'presentation':
      return Icons.slideshow_outlined;
    case 'link':
      return Icons.link_outlined;
    case 'document':
      return Icons.description_outlined;
    default:
      switch (ext) {
        case 'pdf':
          return Icons.picture_as_pdf_outlined;
        case 'mp4':
        case 'webm':
          return Icons.movie_outlined;
        case 'mp3':
          return Icons.audiotrack_outlined;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow_outlined;
        case 'jpg':
        case 'jpeg':
        case 'png':
          return Icons.image_outlined;
        default:
          return Icons.description_outlined;
      }
  }
}

Color colorForType(BuildContext context, String? type) {
  switch ((type ?? '').toLowerCase()) {
    case 'pdf':
      return Colors.red.shade400;
    case 'video':
      return Colors.purple.shade400;
    case 'audio':
      return Colors.orange.shade400;
    case 'image':
      return Colors.green.shade400;
    case 'presentation':
      return Colors.amber.shade700;
    case 'link':
      return Colors.blue.shade400;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
