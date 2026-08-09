import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';
import 'package:flutter_whisper_ggml_example/main.dart';

void main() {
  testWidgets('renders the cross-platform smoke test', (tester) async {
    const device = WhisperDevice(
      index: 0,
      gpuIndex: null,
      name: 'Test CPU',
      description: 'Portable test device',
      type: WhisperDeviceType.cpu,
      freeMemory: 0,
      totalMemory: 0,
    );

    await tester.pumpWidget(const WhisperSmokeApp(testDevices: [device]));

    expect(find.text('flutter_whisper_ggml'), findsOneWidget);
    expect(find.textContaining('Test CPU'), findsOneWidget);
    expect(find.text('Selecionar modelo GGML'), findsOneWidget);
    expect(find.text('Selecionar áudio WAV'), findsOneWidget);
    expect(find.text('Transcrever'), findsOneWidget);
  });
}
