import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const apiKey = 'AIzaSyAA3rgg7CCR_hpD6ocpcq-NcnGcvGzdF2Q';
  final models = [
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
    'gemini-1.5-flash-latest'
  ];

  for (final modelName in models) {
    print('Testing model: $modelName');
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
      );
      final response = await model.generateContent([Content.text('Hello')]);
      print('  Success: ${response.text}');
    } catch (e) {
      print('  Failed: $e');
    }
  }
  exit(0);
}
