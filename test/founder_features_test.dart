import 'package:flutter_test/flutter_test.dart';
import 'package:mindart/founder_features.dart';

void main() {
  group('MindArt Founder Edition records', () {
    test('voice segments append and remove duplicated boundary words', () {
      expect(
        mergeVoiceTranscript(
          'Preciso marcar a consulta',
          'consulta amanhã',
        ),
        'Preciso marcar a consulta amanhã',
      );
    });

    test('a corrected recognition replaces its matching prefix', () {
      expect(
        mergeVoiceTranscript('Preciso marcar', 'Preciso marcar consulta'),
        'Preciso marcar consulta',
      );
    });

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

    test('voice routes a spoken gym action to a priority task', () {
      final intent = classifyVoiceIntent('Ir à academia');

      expect(intent.category, 'Tarefa');
      expect(intent.scheduledAt, isNull);
    });

    test('voice detects a financial amount without losing its category', () {
      final intent = classifyVoiceIntent('Paguei o almoço R\$ 32,50');

      expect(intent.category, 'Finanças');
      expect(intent.expenseAmount, 32.5);
    });

    test('voice captures an explicit time for an appointment reminder', () {
      final now = DateTime(2026, 11, 27, 10);
      final intent = classifyVoiceIntent(
        'Ir à academia amanhã às 18',
        now: now,
      );

      expect(intent.category, 'Tarefa');
      expect(intent.scheduledAt, DateTime(2026, 11, 28, 18));
      expect(intent.dueDate, DateTime(2026, 11, 28));
    });

    test('voice keeps a finance note out of expense totals without an amount', () {
      final intent = classifyVoiceIntent('Gastos do almoço');

      expect(intent.category, 'Finanças');
      expect(intent.expenseAmount, isNull);
    });

    test('voice understands a weekday and an afternoon time', () {
      final now = DateTime(2026, 11, 27, 10); // Friday
      final intent = classifyVoiceIntent(
        'Academia na terça às 6 da tarde',
        now: now,
      );

      expect(intent.scheduledAt, DateTime(2026, 12, 1, 18));
    });
  });
}
