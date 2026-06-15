# iZiiApp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Version Update Process

When bumping the application version, update these files:

- `pubspec.yaml`: change `version: 1.0.0+1` to `version: 1.0.1+1`
- `lib/modules/supply_chain/manifest.dart`: change `version: '1.0.0'` to `version: '1.0.1'`
- `lib/modules/services/manifest.dart`: change `version: '1.0.0'` to `version: '1.0.1'`
- `lib/modules/sales_crm/manifest.dart`: change `version: '1.0.0'` to `version: '1.0.1'`
- `windows/runner/Runner.rc`: update fallback `VERSION_AS_STRING` from `"1.0.0"` to `"1.0.1"`

Then use Git to save the change:

```bash
git add .
git commit -m "Bump version to 1.0.1"
```

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
