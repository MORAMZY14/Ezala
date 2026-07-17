class NormalizedStatus {
  const NormalizedStatus({required this.status, this.note});

  final String status;
  final String? note;
}

abstract final class SourceNormalizer {
  static String clean(Object? value) {
    return (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String normalizeLocation(Object? value) {
    final source = clean(value);
    return source.contains('خارج') ? 'external' : 'internal';
  }

  static NormalizedStatus normalizeStatus(Object? value) {
    final source = clean(value);
    if (source.contains('لم يتم الاستلام')) {
      return const NormalizedStatus(status: 'pending');
    }
    if (source.contains('تم الاستلام')) {
      return const NormalizedStatus(status: 'confirmed');
    }
    return NormalizedStatus(
      status: 'pending',
      note: source.isEmpty ? null : source,
    );
  }

  static String extractBoxNumber(String displayName, int fallback) {
    final match = RegExp(
      r'BOX\s*([0-9]+\s*[A-Z]?)',
      caseSensitive: false,
    ).firstMatch(displayName);
    return match == null
        ? fallback.toString()
        : match.group(1)!.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  static String safeDocumentId(String value, int fallback) {
    final safe = value
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_-]'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return safe.isEmpty ? 'row-$fallback' : safe;
  }
}
