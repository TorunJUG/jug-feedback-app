# Feedback App

An offline Flutter app for collecting feedback on conference presentations.

## Requirements

Check your local Flutter and platform setup:

```bash
flutter doctor -v
```

- Flutter SDK compatible with the version specified in `pubspec.yaml`.
- Chrome to run the web app.
- Android Studio with the Android SDK, or an Android phone with USB debugging enabled.
- Xcode on macOS to run on an iPhone or iOS Simulator.

## Project setup

From the project directory, fetch dependencies:

```bash
flutter pub get
```

List connected devices and available emulators:

```bash
flutter devices
flutter emulators
```

## Run locally — Web

Run the app in Chrome:

```bash
flutter run -d chrome
```

Flutter prints the local app URL in the terminal. Press `r` to hot reload or `q` to stop the app.

## Run locally — Android

### Emulator

Start an emulator from Android Studio (**Device Manager**) or from the terminal:

```bash
flutter emulators
flutter emulators --launch <emulator_id>
flutter devices
flutter run -d <device_id>
```

For example, if the emulator ID is `emulator-5554`:

```bash
flutter run -d emulator-5554
```

### Android phone

1. Enable **Developer options** and **USB debugging** in the phone's settings.
2. Connect the phone over USB and accept the debugging prompt on the device.
3. Find the device ID and launch the app:

```bash
flutter devices
flutter run -d <device_id>
```

If multiple devices are connected, use the ID of the intended phone. Flutter installs the debug build directly on the device. Use `r` in the terminal for hot reload and `q` to stop.

## Run locally — iOS

On macOS, start an iPhone Simulator from Xcode or connect an iPhone with Developer Mode enabled. Then find the device ID and run:

```bash
flutter devices
flutter run -d <device_id>
```

Running on a physical iPhone may require app signing to be configured in Xcode.

## Tests and quality checks

```bash
flutter analyze
flutter test
```

Responsive UI tests cover portrait and landscape voting layouts, small screens, large text scaling, and the organizer form with the keyboard open.

## Mobile builds

Build a debug APK for manual installation on Android:

```bash
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Release builds:

```bash
flutter build apk --release
flutter build ios --release --no-codesign
```

Installing an iOS build on an iPhone requires Apple code signing and the appropriate device configuration.

## How the app works

### First launch and setup

- The app runs offline and starts with no presentations. Voters see a waiting screen until the organizer creates a presentation and starts voting.
- Event details, the initial presentation list, and organizer PIN are read from `assets/config/event.json`. The bundled configuration has an empty presentation list. Set an appropriate organizer PIN in this file before distributing the app.
- Presentation edits, active voting selection, and submitted ratings are stored locally on each device. They are not synchronized between devices.

### Organizer workflow

1. Open the `⋮` menu on the voting screen, choose **Organizer panel**, and enter the PIN.
2. Add, edit, or delete presentations. Up to five presentations are allowed; changes are saved on the device.
3. Choose **New voting** for a presentation. If it already has ratings, the app asks for confirmation before clearing those ratings and starting a new vote.
4. View collected rating counts in the organizer panel. Export results to CSV when ratings exist; the app opens the platform's sharing or save dialog.

### Voter workflow

1. The voting screen shows the currently active presentation. In landscape, it displays the title and speaker, instructions, four rating buttons, and the submit button together.
2. Choose one rating: `Słabo`, `Neutralnie`, `Dobrze`, or `Super`. The selection can be changed before submission.
3. Select **Zatwierdź** to save the rating locally. The app shows a five-second handoff countdown, then returns to the same presentation for the next voter.

Each submission is stored as a voting round containing the selected rating for the active presentation. If a presentation is deleted or its voting is reset, its ratings are removed; unrelated presentation ratings remain. CSV export uses the presentation details available at export time and falls back to the presentation ID if details are no longer available.
