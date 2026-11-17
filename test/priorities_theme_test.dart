import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindart/main.dart';

void main() {
  group('Prioridades', () {
    test('legacy task snapshots default to non-priority', () {
      final old = TaskItem.fromJson({
        'title': 'Revisar estoque',
        'project': 'Mercado Progresso',
        'date': '18/11/2026',
        'done': false,
      });
      expect(old.priority, isFalse);
    });

    test('priority is kept when serializing to and from cloud data', () {
      final task = TaskItem('Consultar agenda', 'Pessoal', '18/11/2026',
          priority: true);
      final restored = TaskItem.fromJson(task.toJson());
      expect(restored.priority, isTrue);
      expect(restored.title, 'Consultar agenda');
    });

    test('priorities lead, then nearest deadlines, completed are hidden', () {
      final ordered = rankFocusTasks(
        [
          TaskItem('Sem prioridade', 'Pessoal', '18/11/2026'),
          TaskItem('Prioridade tardia', 'Pessoal', '22/11/2026', priority: true),
          TaskItem('Já concluída', 'Pessoal', '16/11/2026',
              priority: true, done: true),
          TaskItem('Prioridade urgente', 'Pessoal', '17/11/2026', priority: true),
          TaskItem('Outra', 'Pessoal', '17/11/2026'),
        ],
        now: DateTime(2026, 11, 17),
      );
      expect(ordered.map((task) => task.title), [
        'Prioridade urgente',
        'Prioridade tardia',
        'Outra',
        'Sem prioridade',
      ]);
    });
  });

  test('light and dark themes have contrasting surfaces and text', () {
    final light = mindArtThemeData(Brightness.light);
    final dark = mindArtThemeData(Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.cardTheme.color, isNot(dark.cardTheme.color));
    expect(light.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
  });
}
