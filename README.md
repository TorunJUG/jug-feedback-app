# Feedback App

An offline Flutter app for collecting attendee feedback on talks at Java User Group (JUG) events and meetups. Organizers manage talks and review local results; attendees submit one rating per active talk.

## Requirements

Check your local Flutter and platform setup:

```bash
flutter doctor -v
```

- Flutter SDK compatible with the version specified in `pubspec.yaml`.
- Chrome to run the web app.
- Android Studio with the Android SDK, or an Android phone with USB debugging enabled.
- Xcode on macOS to run on an iPhone or iOS Simulator.

## Project Setup

From the project directory, fetch dependencies:

```bash
flutter pub get
```

List connected devices and available emulators:

```bash
flutter devices
flutter emulators
```

## Run Locally — Web

Run the app in Chrome:

```bash
flutter run -d chrome
```

Flutter prints the local app URL in the terminal. Press `r` to hot reload or `q` to stop the app.

## Run Locally — Android

### Android Emulator

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

### Physical Android Device

1. Enable **Developer options** and **USB debugging** in the phone's settings.
2. Connect the phone over USB and accept the debugging prompt on the device.
3. Find the device ID and launch the app:

```bash
flutter devices
flutter run -d <device_id>
```

If multiple devices are connected, use the ID of the intended phone. Flutter installs the debug build directly on the device. Use `r` in the terminal for hot reload and `q` to stop.

## Run Locally — iOS

On macOS, start an iPhone Simulator from Xcode or connect an iPhone with Developer Mode enabled. Then find the device ID and run:

```bash
flutter devices
flutter run -d <device_id>
```

Running on a physical iPhone may require app signing to be configured in Xcode.

## Tests and Quality Checks

```bash
flutter analyze
flutter test
```

Responsive UI tests cover portrait and landscape voting layouts, small screens, large text scaling, and the organizer form with the keyboard open.

## Mobile Builds

Build a debug APK for manual installation on Android:

```bash
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`; use it for emulator testing and development. Build a standalone release APK for sideloading onto a dedicated phone with:

```bash
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The current Android release build uses the debug signing key; configure a private release key before distributing it beyond testing. Install one build type before provisioning Device Owner and keep using APKs signed with the same key when updating the app. Build iOS with:

```bash
flutter build ios --release --no-codesign
```

Installing an iOS build on an iPhone requires Apple code signing and the appropriate device configuration.

## Android Kiosk: Screen Pinning and Lock Task

Android offers two separate ways to keep Feedback App in front during voting: **screen pinning** and **kiosk mode (Lock Task)**. Screen pinning is configured and controlled using Android's built-in system UI. Feedback App's **Enable kiosk** and **Disable kiosk** controls affect only full Lock Task mode and never start or stop screen pinning.

The app supports both options on **Android only**. The iOS app does not support them or integrate with Guided Access.

### Android Version Compatibility

- The Android app supports **API 24 (Android 7.0) and later**. Android 8.1 is API 27; Android 16 is API 36.
- Screen pinning and Lock Task are Android platform features available on supported Android versions, but Settings labels, navigation gestures, and Device Owner provisioning rules vary by Android release and manufacturer.
- Android 9/API 28 and later let Device Owner apps configure Lock Task system features. On Android 8.1/API 27, Feedback App still starts full Lock Task, but Android does not expose that feature-configuration API; system UI restrictions follow that release's defaults.
- `shared_preferences_android` is held at version `2.4.25` because later plugin versions require Android APIs unavailable on API 27. Keep this compatibility pin unless minimum Android version is raised or plugin compatibility changes.
- Feedback App keeps the display awake while its activity is visible, on both older and newer Android versions. This does not prevent the device from sleeping after the app leaves the foreground or the device is locked. Device power-saving policies can also vary by manufacturer.

### Screen Pinning

Screen pinning is started by the user from Android's **Recent apps** UI and does not require Device Owner or ADB provisioning. It is not a full kiosk: a participant can unpin the app with Android's system gesture and navigate elsewhere. The gesture varies by Android version and navigation mode. On Android 8.1/API 27, the system normally shows an unpin hint and may require the device PIN, depending on system settings. Newer Android releases may use different gesture-based unpin flows and Settings names. Android owns the pin state, so Feedback App cannot reliably dismiss or prevent the system's unpin interface. The app's shake-to-exit prompt does not work while merely screen-pinned.

**Setup:**

1. In Android Settings, find and enable **App pinning** or **Screen pinning**. Common locations include **Security & privacy → More security settings → App pinning**; manufacturers may place it elsewhere. Enable the option to require the device PIN before unpinning, if available.
2. Open Feedback App. Open Android's **Recent apps** view, tap the Feedback App icon, and choose **Pin**. Names and steps can vary by Android version and manufacturer.
3. To stop pinning, use Android's system unpin gesture. Android may request the device PIN if **Require PIN before unpinning** is enabled. This security prompt is controlled by Android, not by Feedback App's kiosk controls.

### Full Lock Task Kiosk Without EMM

**Requirements and limitations:** Feedback App must be provisioned as the device's **Device Owner**. This changes device management; dedicate device to JUG event voting. Android commonly permits Device Owner provisioning only during initial device setup, before accounts or a work profile are added. A factory reset erases all data, but is not automatically required: first check the current device and try provisioning only if appropriate. Some manufacturers restrict ADB provisioning.

While full Lock Task is active, shake the phone to open an emergency exit prompt. Enter the configured organizer password to stop kiosk mode. Cancel the prompt or enter an incorrect password to stay in kiosk mode. This emergency gesture only works in full Lock Task mode; it does not control screen pinning. The app listens for shakes only while Lock Task is active.

**ADB is required for this setup:** connect the device to a computer and use ADB to install the APK and provision Feedback App as Device Owner. Installing the app normally, without the Device Owner provisioning step, does not enable Full Lock Task.

Choose emulator setup for testing, or physical-device setup for a dedicated JUG event device.

#### Emulator Setup

Provisioning on a clean emulator is usually the simplest way to try Full Lock Task:

1. Start a fresh AVD. Install Android SDK Platform-Tools and confirm ADB can see it:

   ```bash
   adb devices -l
   ```

   Use its serial as `<device_id>` below. Its status must be `device`, not `unauthorized` or `offline`.
2. Build and install a debug APK for emulator testing:

   ```bash
   flutter build apk --debug
   adb -s <device_id> install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

3. Set Feedback App as Device Owner:

   ```bash
   adb -s <device_id> shell dpm set-device-owner com.feedbackapp.feedback_app/.FeedbackDeviceAdminReceiver
   ```

4. Continue to **Verify Device Owner and Control Kiosk** below.

#### Physical Device Setup with ADB

ADB provisioning on a physical phone is less predictable than on an emulator. On many Android versions, enabling Developer options and USB debugging requires completing setup first, while Device Owner provisioning may only be allowed before setup is complete. The steps below help identify common blockers but cannot guarantee that the phone will accept provisioning.

1. Back up important data. Do not factory-reset yet. Enable **Developer options → USB debugging**, connect the phone to the computer, and check ADB access:

   ```bash
   adb devices -l
   ```

   Use the phone's serial as `<device_id>`. Its status must be `device`, not `unauthorized` or `offline`.

2. Check Android version, existing device-policy owners, and whether accounts are configured:

   ```bash
   adb -s <device_id> shell getprop ro.build.version.release
   adb -s <device_id> shell getprop ro.build.version.sdk
   adb -s <device_id> shell dumpsys device_policy
   adb -s <device_id> shell dumpsys account
   ```

   An existing Device Owner or Profile Owner cannot be replaced by this procedure. Do not remove existing management unless authorized. The account dump may contain account identifiers; keep its output private. Accounts, a work profile, or completed device setup can cause Android to reject Device Owner provisioning.

3. If no incompatible owner is present, build and install Feedback App. Use debug APK for testing; use release APK for a dedicated phone:

   ```bash
   flutter build apk --debug
   adb -s <device_id> install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

   For a release build, replace `--debug` with `--release` and install `build/app/outputs/flutter-apk/app-release.apk`. Use a stable signing key for release updates.

4. Try assigning Device Owner:

   ```bash
   adb -s <device_id> shell dpm set-device-owner com.feedbackapp.feedback_app/.FeedbackDeviceAdminReceiver
   ```

    This command is the final test; the diagnostic checks above cannot confirm in advance that the device permits provisioning. If it succeeds, continue to **Verify Device Owner and Control Kiosk**. That section describes verification methods, including the API 27 alternative.

5. Continue to **Verify Device Owner and Control Kiosk** below.

If Android rejects provisioning, check for accounts, a work profile, an existing owner, completed setup, or manufacturer restrictions. Only then consider a factory reset—and only after a full backup and if you are willing to erase all phone data. If you do not want to reset the phone, use Android's built-in screen pinning instead.

#### Verify Device Owner and Control Kiosk

Verify that `com.feedbackapp.feedback_app/.FeedbackDeviceAdminReceiver` appears as Device Owner:

```bash
adb -s <device_id> shell dumpsys device_policy
```

On Android releases that support it, `adb -s <device_id> shell dpm list-owners` is a shorter alternative. On Android 8.1/API 27, use `dumpsys device_policy`; `dpm list-owners` is unavailable.

Launch Feedback App, open the **Organizer panel**, sign in, and select **Enable kiosk**. To leave Lock Task mode, select **Disable kiosk** in the organizer panel.

## App Workflows for JUG Events

### First Launch and Event Setup

- The app runs offline and starts with no talks. Attendees see a waiting screen until the organizer adds a JUG talk and starts voting.
- Event details, the initial talk list, and organizer password are read from `assets/config/event.json`. The bundled configuration has an empty talk list. Set JUG event details and an appropriate organizer password in this file before distributing the app.
- Talk details, active voting selection, and submitted ratings are stored locally on each device. They are not synchronized between devices.

### Organizer Workflow

1. Open the `⋮` menu on the voting screen, choose **Organizer panel**, and enter the password.
2. Add, edit, or delete talks. Up to five talks are allowed; changes are saved on the device.
3. Choose **New voting** for a talk. If it already has ratings, the app asks for confirmation before clearing those ratings and starting a new vote.
4. Select **Show results** to open a per-talk breakdown of `Poor`, `Neutral`, `Good`, and `Super` ratings. The button is disabled until talks have ratings.
5. Select **Export results to CSV** to share or save the collected ratings. This button is disabled when there are no talks or ratings.

### Attendee Workflow

1. The voting screen shows the currently active talk. In landscape, it displays the title and speaker, instructions, four rating buttons, and the submit button together.
2. Choose one rating: `Poor`, `Neutral`, `Good`, or `Super`. The selection can be changed before submission.
3. Select **Submit** to save the rating locally. The app shows a three-second handoff countdown, then returns to the same talk for the next attendee.

Each submission is stored as a voting round containing the selected rating for the active talk. If a talk is deleted or its voting is reset, its ratings are removed; ratings for other talks remain. CSV export uses talk details available at export time and falls back to the talk ID if details are no longer available.
