# possible_recovery

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build

Para generar la APK release optimizada para Chainway C72 (arquitectura ARM64, R8 habilitado, ML Kit unbundled y ofuscada):

```bash
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
```

