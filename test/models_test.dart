import 'package:flutter_test/flutter_test.dart';
import 'package:mindart/main.dart';

void main() {
  group('MindArt persistence models', () {
    test('task round trip retains completion and project', () {
      final original = TaskItem('Pagar conta', 'Pessoal', '2026-11-16',
          done: true);
      final restored = TaskItem.fromJson(original.toJson());
      expect(restored.title, 'Pagar conta');
      expect(restored.project, 'Pessoal');
      expect(restored.date, '2026-11-16');
      expect(restored.done, isTrue);
    });

    test('expense and debt values survive round trip', () {
      final expense = ExpenseItem('Internet', 'Casa', 99.90);
      final parsedExpense = ExpenseItem.fromJson(expense.toJson());
      expect(parsedExpense.value, closeTo(99.90, 0.001));
      final debt = DebtItem('Empréstimo', 3000, paid: 500);
      final parsedDebt = DebtItem.fromJson(debt.toJson());
      expect(parsedDebt.remaining, 2500);
    });

    test('routine event date and savings target round trip', () {
      final date = DateTime(2026, 11, 17, 8, 30);
      final event = RoutineEvent('Oração', date);
      expect(RoutineEvent.fromJson(event.toJson()).startsAt, date);
      final goal = SavingsGoal('Reserva', 1000, saved: 250);
      expect(SavingsGoal.fromJson(goal.toJson()).progress, 0.25);
    });

    test('ideas remain distinct from projects', () {
      final idea = ProjectItem('Novo negócio', 'Análise inicial', isIdea: true);
      final restored = ProjectItem.fromJson(idea.toJson());
      expect(restored.isIdea, isTrue);
      expect(restored.description, 'Análise inicial');
    });
  });
}
