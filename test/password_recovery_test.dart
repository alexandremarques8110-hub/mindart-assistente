import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindart/main.dart';

void main() {
  testWidgets('Recovery screen requires a sufficiently strong password',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PasswordRecoveryPage(onComplete: () {}),
    ));
    expect(find.text('Definir nova senha'), findsOneWidget);
    expect(find.text('Confirmar nova senha'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'abc');
    await tester.enterText(fields.at(1), 'abc');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(find.textContaining('pelo menos 8 caracteres'), findsWidgets);
  });

  testWidgets('Recovery screen requires matching passwords',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PasswordRecoveryPage(onComplete: () {}),
    ));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'strongPassword123!');
    await tester.enterText(fields.at(1), 'differentPassword123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(find.text('As senhas digitadas são diferentes.'), findsOneWidget);
  });
}
