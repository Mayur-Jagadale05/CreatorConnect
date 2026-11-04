# creatorconnect

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

## Gemini AI setup

The Gemini API key is stored as a Firebase Functions secret and is never bundled
with the Flutter app. Revoke any key that has been shared publicly, then create
a replacement in Google AI Studio and configure it locally:

```shell
firebase functions:secrets:set GEMINI_API_KEY --project creatorconnect-auth
firebase deploy --only functions:creatorConnectAI --project creatorconnect-auth
flutter run
```

The first command prompts for the secret value. The app calls the deployed
`creatorConnectAI` function by default. To use a different function URL, pass
`--dart-define=AI_BACKEND_URL=https://...` when running Flutter.
