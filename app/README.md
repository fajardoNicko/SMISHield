# SMISHield app

The Flutter (Dart) Android app. It classifies a pasted SMS on the device with
the model exported by `ml/train.py`, explains the result, and keeps a history
per local account. It has no internet permission and never reads the SMS
inbox.

## Layout

| Path | What it is |
|---|---|
| `lib/ml/` | Preprocessing and Naive Bayes inference (identical to the Python pipeline), warning-sign rules, explanations in English and Filipino |
| `lib/data/` | Local accounts (PBKDF2-hashed passwords and recovery codes), per-account history and settings, stored as JSON files in the app's private folder |
| `lib/app/` | App state (`AppController`) and the screen text in English and Filipino (`strings.dart`) |
| `lib/ui/` | Screens and widgets following the research plan's mock-ups (Figures 1-18) |
| `assets/model/` | The exported model |
| `assets/fonts/` | Poppins (SIL Open Font License, `OFL.txt`) |

## Accounts

Accounts exist only on the phone. Because there is no server to send a reset
e-mail, sign-up shows a one-time **recovery code**; "Forgot password?" asks for
the e-mail and that code, sets a new password and issues a new code.

## Commands

```
flutter test                                   # unit and widget tests
dart run tool/analyze.dart "Your message"     # analyse one message in the terminal
flutter build apk --release                    # build/app/outputs/flutter-apk/app-release.apk
flutter test --update-goldens screenshots/screens_test.dart   # screen previews -> screenshots/shots/
```

The release APK is signed with the debug key, which is fine for sharing test
builds but not for the Play Store.
