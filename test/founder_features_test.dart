import 'package:flutter_test/flutter_test.dart';
import 'package:mindart/founder_features.dart';

void main() {
  group('MindArt Founder Edition records', () {
    test('voice entry keeps text, classification and timestamp', () {
      final createdAt = DateTime(2026, 11, 27, 12, 30);
      final entry = VoiceEntry('Marcar consulta', 'Saúde', createdAt: createdAt);
      final restored = VoiceEntry.fromJson(entry.toJson());

      expect(restored.text, 'Marcar consulta');
      expect(restored.category, 'Saúde');
      expect(restored.createdAt, createdAt);
    });

    test('health entry keeps kind, notes and scheduled time', () {
      final scheduledAt = DateTime(2026, 12, 3, 8, 15);
      final entry = HealthEntry(
        'Consulta de rotina',
        'Consulta',
        'Levar exames',
        scheduledAt,
      );
      final restored = HealthEntry.fromJson(entry.toJson());

      expect(restored.title, 'Consulta de rotina');
      expect(restored.kind, 'Consulta');
      expect(restored.details, 'Levar exames');
      expect(restored.scheduledAt, scheduledAt);
    });

    test('older voice data without a category remains readable', () {
      final restored = VoiceEntry.fromJson({
        'text': 'Anotação antiga',
        'createdAt': '2026-11-26T10:00:00.000',
      });

      expect(restored.category, 'Nota');
    });
  });
}
