import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trusttunnel/common/theme/light_theme.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';
import 'package:trusttunnel/widgets/menu/custom_dropdown_menu.dart';

void main() {
  for (final hasChanges in [false, true]) {
    testWidgets('Back closes the menu before a form with hasChanges=$hasChanges', (tester) async {
      final selections = <String?>[];
      await _openForm(tester, hasChanges: hasChanges, onChanged: selections.add);
      await _openMenu(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('QUIC').hitTestable(), findsNothing);
      expect(find.text('Edit server'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(selections, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      if (hasChanges) {
        expect(find.text('Discard changes?'), findsOneWidget);
      } else {
        expect(find.text('Open form'), findsOneWidget);
        expect(find.text('Edit server'), findsNothing);
      }
    });
  }

  testWidgets('Back closes the menu before its enclosing dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme().data,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CustomAlertDialog(
                  title: 'Choose protocol',
                  content: _menu(onChanged: (_) {}),
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await _openMenu(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('QUIC').hitTestable(), findsNothing);
    expect(find.text('Choose protocol'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Choose protocol'), findsNothing);
  });

  testWidgets('selection updates the value and leaves the form Back guard active', (tester) async {
    final selections = <String?>[];
    await _openForm(tester, hasChanges: true, onChanged: selections.add);
    await _openMenu(tester);
    await tester.tap(find.text('QUIC').hitTestable());
    await tester.pumpAndSettle();

    expect(selections, ['QUIC']);
    expect(find.text('QUIC').hitTestable(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('tapping outside cancels the menu without consuming the next Back', (tester) async {
    final selections = <String?>[];
    await _openForm(tester, hasChanges: true, onChanged: selections.add);
    await _openMenu(tester);
    await tester.tapAt(const Offset(10, 550));
    await tester.pumpAndSettle();

    expect(find.text('QUIC').hitTestable(), findsNothing);
    expect(selections, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('hovering a popup item provides a visible highlight', (tester) async {
    final selections = <String?>[];
    await _openForm(tester, hasChanges: true, onChanged: selections.add);
    await _openMenu(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    try {
      await mouse.moveTo(tester.getCenter(find.text('QUIC').hitTestable()));
      await tester.pumpAndSettle();

      expect(_menuItemHighlightColor(tester, WidgetState.hovered).a, greaterThan(0));
      expect(selections, isEmpty);
    } finally {
      await mouse.removePointer();
    }
  });

  testWidgets('keyboard navigation visibly highlights the item that Enter selects', (tester) async {
    final previousStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    try {
      final selections = <String?>[];
      await _openForm(tester, hasChanges: true, onChanged: selections.add);
      await _openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(Focus.of(tester.element(find.text('QUIC').hitTestable())).hasFocus, isTrue);
      expect(_menuItemHighlightColor(tester, WidgetState.focused).a, greaterThan(0));
      expect(selections, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selections, ['QUIC']);
    } finally {
      FocusManager.instance.highlightStrategy = previousStrategy;
    }
  });

  testWidgets('external value changes retain plain labels and custom menu entries', (tester) async {
    final selected = ValueNotifier('HTTP/2');
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme().data,
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: selected,
            builder: (_, value, _) => CustomDropdownMenu<String>.expanded(
              value: value,
              values: const ['HTTP/2', 'QUIC'],
              toText: (value) => value,
              toWidget: (value) => Text('Option: $value'),
              labelText: 'Protocol',
              onChanged: (value) => selected.value = value!,
            ),
          ),
        ),
      ),
    );

    selected.value = 'QUIC';
    await tester.pumpAndSettle();
    expect(find.text('QUIC').hitTestable(), findsOneWidget);
    expect(find.text('Option: QUIC').hitTestable(), findsNothing);

    await tester.tap(find.byType(CustomDropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option: HTTP/2').hitTestable());
    await tester.pumpAndSettle();
    expect(selected.value, 'HTTP/2');
    expect(find.text('HTTP/2').hitTestable(), findsOneWidget);
  });

  testWidgets('disabled menu retains its selected label and error without opening', (tester) async {
    final selections = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme().data,
        home: Scaffold(
          body: CustomDropdownMenu<String>.expanded(
            value: 'HTTP/2',
            values: const ['HTTP/2', 'QUIC'],
            toText: (value) => value,
            labelText: 'Protocol',
            errorText: 'Choose a protocol',
            enabled: false,
            onChanged: selections.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CustomDropdownMenu<String>));
    await tester.pumpAndSettle();
    expect(find.text('HTTP/2').hitTestable(), findsOneWidget);
    expect(find.text('Choose a protocol'), findsOneWidget);
    expect(find.text('QUIC').hitTestable(), findsNothing);
    expect(selections, isEmpty);
  });

  testWidgets('long profile names fit a narrow screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longName = 'A routing profile with a name that needs multiple lines on a phone';
    final selections = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme().data,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CustomDropdownMenu<String>.expanded(
              value: longName,
              values: const [longName, 'Default profile'],
              toText: (value) => value,
              labelText: 'Routing profile',
              onChanged: selections.add,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CustomDropdownMenu<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Default profile').hitTestable());
    await tester.pumpAndSettle();
    expect(selections, ['Default profile']);
    expect(tester.takeException(), isNull);
  });
}

Widget _menu({String value = 'HTTP/2', required ValueChanged<String?> onChanged}) =>
    CustomDropdownMenu<String>.expanded(
      value: value,
      values: const ['HTTP/2', 'QUIC'],
      toText: (value) => value,
      labelText: 'Protocol',
      onChanged: onChanged,
    );

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(CustomDropdownMenu<String>));
  await tester.pumpAndSettle();
  expect(find.text('QUIC').hitTestable(), findsOneWidget);
}

Color _menuItemHighlightColor(WidgetTester tester, WidgetState state) {
  final item = find.ancestor(of: find.text('QUIC').hitTestable(), matching: find.byType(InkWell)).first;
  final ink = tester.widget<InkWell>(item);
  final theme = Theme.of(tester.element(item));
  return ink.overlayColor?.resolve({state}) ??
      (state == WidgetState.hovered ? ink.hoverColor ?? theme.hoverColor : ink.focusColor ?? theme.focusColor);
}

Future<void> _openForm(
  WidgetTester tester, {
  required bool hasChanges,
  required ValueChanged<String?> onChanged,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  var value = 'HTTP/2';
  await tester.pumpWidget(
    MaterialApp(
      theme: LightTheme().data,
      home: NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => navigatorKey.currentState!.maybePop(),
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => PopScope<void>(
                      canPop: !hasChanges,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) {
                          showDialog<void>(
                            context: context,
                            builder: (_) => const AlertDialog(title: Text('Discard changes?')),
                          );
                        }
                      },
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Edit server')),
                        body: Padding(
                          padding: const EdgeInsets.all(16),
                          child: StatefulBuilder(
                            builder: (_, setState) => _menu(
                              value: value,
                              onChanged: (selection) {
                                onChanged(selection);
                                if (selection != null) setState(() => value = selection);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}
