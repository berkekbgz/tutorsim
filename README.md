# tutorsim

A new Flutter project.

## 42 OAuth Setup

Do not put the 42 client secret in Flutter code. Run the local proxy with the
secret in environment variables, and register the same redirect URI in the 42 app
settings.

```bash
export FT_CLIENT_ID="your-42-client-uid"
export FT_CLIENT_SECRET="your-42-client-secret"
export FT_REDIRECT_URI="http://localhost:8080/"
dart run bin/forty_two_oauth_proxy.dart
```

In another terminal, run Flutter on the matching redirect port:

```bash
flutter run -d chrome --web-port 8080 \
  --dart-define=FT_CLIENT_ID="$FT_CLIENT_ID" \
  --dart-define=FT_REDIRECT_URI="$FT_REDIRECT_URI" \
  --dart-define=FT_BACKEND_URL="http://127.0.0.1:8787"
```

For your current 42 application, change the redirect URI from Google to
`http://localhost:8080/` while developing locally.

After login, the app fetches 42 campus user records through the local proxy and
uses their `login` values as NPC labels in the room. The logged-in user's login
is also shown above the player character.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
