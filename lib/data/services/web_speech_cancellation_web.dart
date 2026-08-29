import 'dart:js_interop';

@JS('speechSynthesis')
external _SpeechSynthesis get _speechSynthesis;

extension type _SpeechSynthesis(JSObject _) implements JSObject {
  external void cancel();
}

void cancelActiveWebSpeech() => _speechSynthesis.cancel();
