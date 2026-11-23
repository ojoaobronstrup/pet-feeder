import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_feeder/main.dart';

void main() {
  testWidgets('Apresenta autenticação Google', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PetFeederApp());
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Cuidado que está sempre por perto.'), findsOneWidget);
    expect(find.text('CONTROLE  /  CONEXÃO  /  CUIDADO'), findsNothing);
    expect(find.text('PROTÓTIPO DE VALIDAÇÃO'), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Continuar com Google');
    expect(tester.getBottomRight(button).dy, 820);
    expect(tester.getTopLeft(find.byType(BrandHeader)).dy, 16);
  });

  testWidgets('Login permite rolar em telas baixas', (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PetFeederApp());
    await tester.ensureVisible(find.text('Continuar com Google'));
    expect(tester.takeException(), isNull);
    expect(find.text('Continuar com Google'), findsOneWidget);
  });

  testWidgets('Histórico distingue estados e filtra eventos por origem', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: FeedingHistoryView(
            events: [
              FeedingEvent.fromJson({
                'id': 'confirmed',
                'occurredAt': '2026-11-22T13:00:02Z',
                'origin': 'scheduled',
                'scheduledAt': '2026-11-22T13:00:00Z',
                'status': 'confirmed',
                'active': true,
              }),
              FeedingEvent.fromJson({
                'id': 'requested',
                'occurredAt': '2026-11-22T12:05:00Z',
                'origin': 'manual',
                'status': 'requested',
                'active': false,
              }),
            ],
            loading: false,
            unavailable: false,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.textContaining(' · Programada'), findsOneWidget);
    expect(find.textContaining('Agendada para'), findsOneWidget);
    expect(find.text('Comando confirmado'), findsOneWidget);
    await tester.tap(find.text('Origem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(find.textContaining(' · Programada'), findsNothing);
    expect(find.textContaining(' · Manual'), findsOneWidget);
    expect(find.text('Comando solicitado'), findsOneWidget);
    await tester.tap(find.textContaining(' · Manual'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do evento'), findsOneWidget);
    expect(find.text('Origem: Manual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Histórico oferece nova tentativa depois de falha', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedingHistoryView(
            events: null,
            loading: false,
            unavailable: true,
            onRefresh: () async => refreshes++,
          ),
        ),
      ),
    );

    expect(find.text('Não foi possível carregar o histórico.'), findsOneWidget);
    expect(find.text('Nenhum evento registrado.'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    expect(refreshes, 1);
  });
}
