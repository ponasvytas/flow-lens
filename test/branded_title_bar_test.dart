import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/theme/flow_theme.dart';
import 'package:flow_lens/widgets/branded_title_bar.dart';
import 'package:flow_lens/widgets/dockable_panel.dart';
import 'package:flow_lens/widgets/video_picker.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'compact app bar preserves home and menu targets at $width / $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var home = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: FlowTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: BrandedTitleBar(
                  onGoHome: () => home++,
                  onShowShortcuts: () {},
                  showShortcuts: false,
                  currentMode: AppMode.record,
                  onModeChanged: (_) {},
                  onShowTools: () {},
                  onExitPresentation: () {},
                ),
              ),
            ),
          );
          final bar = tester.getRect(find.byType(BrandedTitleBar));
          expect(bar.height, kAppTitleBarHeight);
          expect(bar.height, 56);
          for (final target in [
            find.byTooltip('Go to start page'),
            find.byTooltip('App menu'),
          ]) {
            final rect = tester.getRect(target);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(bar.left));
            expect(rect.right, lessThanOrEqualTo(bar.right));
            expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
          }
          await tester.tap(find.byTooltip('Go to start page'));
          expect(home, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('start page offers resume alongside sport and video selection', (
    tester,
  ) async {
    var resumed = 0;
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoPicker(
              onResume: () => resumed++,
              onPickVideo: () {},
              onLoadUrl: (_) {},
              onSportSelected: (_) => selected++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Resume analysis'));
    expect(resumed, 1);
    expect(selected, 0);
    await tester.tap(find.text('Ice Hockey'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.text('Select Game Video'), findsOneWidget);
    expect(find.text('Resume analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
