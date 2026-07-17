import 'package:flutter_test/flutter_test.dart';
import 'package:mmr_cabinets_app/services/source_normalizer.dart';

void main() {
  group('SourceNormalizer', () {
    test('maps Arabic received statuses correctly', () {
      expect(
        SourceNormalizer.normalizeStatus('تم الاستلام').status,
        'confirmed',
      );
      expect(
        SourceNormalizer.normalizeStatus('لم يتم الاستلام').status,
        'pending',
      );
    });

    test('keeps an unusual status as a pending note', () {
      final result = SourceNormalizer.normalizeStatus('Cast 7-9');
      expect(result.status, 'pending');
      expect(result.note, 'Cast 7-9');
    });

    test('normalizes location spelling variations', () {
      expect(SourceNormalizer.normalizeLocation('خارجى'), 'external');
      expect(SourceNormalizer.normalizeLocation('داخلى'), 'internal');
      expect(SourceNormalizer.normalizeLocation('دخلى'), 'internal');
    });

    test('extracts numeric and letter box suffixes', () {
      expect(
        SourceNormalizer.extractBoxNumber('CAB(A-5) BOX 58A', 1),
        '58A',
      );
      expect(SourceNormalizer.extractBoxNumber('BOX 07', 1), '07');
    });
  });
}
