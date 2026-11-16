import 'package:diapo/core/after_build.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outside a frame the update runs at once', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    var ran = false;
    runOutsideBuild(() => ran = true);
    expect(ran, isTrue);
  });

  testWidgets('during a build the update waits for the end of the frame', (
    tester,
  ) async {
    final counter = GlobalKey<_CounterState>();
    var callDuringBuild = false;
    var ranDuringBuild = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            _Counter(key: counter),
            StatefulBuilder(
              builder: (context, setState) {
                if (callDuringBuild) {
                  // Like a provider listener firing while another widget
                  // builds: a setState on a widget that is not building.
                  runOutsideBuild(() => counter.currentState!.bump());
                  ranDuringBuild = counter.currentState!.value == 1;
                }
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    expect(counter.currentState!.value, 0);

    callDuringBuild = true;
    tester.element(find.byType(StatefulBuilder)).markNeedsBuild();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(ranDuringBuild, isFalse);
    expect(counter.currentState!.value, 1);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;

  void bump() => setState(() => value++);

  @override
  Widget build(BuildContext context) => Text('$value');
}
