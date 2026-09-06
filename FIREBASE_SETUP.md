# Firebase Setup Guide for Metamorphosis

## Overview
This app uses Firebase for cloud user profiles and anonymous authentication. The guide below follows the current Firebase console flow.

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Click **Create a project** or **Add project**.
3. Enter a project name like `metamorphosis`.
4. Accept the terms and continue.
5. Skip Google Analytics unless you want analytics data.

## Step 2: Enable Firestore Database

1. Open **Firestore Database** from the left menu.
2. Click **Create database**.
3. Choose **Standard edition**.
4. Choose **Native mode** when prompted.
5. Select your region.
6. Click **Create**.

## Step 3: Configure Firestore Security Rules

1. Open **Firestore Database** → **Rules**.
2. Replace the existing rules with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

3. Click **Publish**.

## Step 4: Enable Authentication

1. Open **Authentication** in Firebase Console.
2. Click **Get started** if needed.
3. Go to the **Sign-in method** tab.
4. Enable **Anonymous** sign-in.
5. Click **Save**.

## Step 5: Register Your App and Download Credentials

### Android

1. Open **Project settings** (gear icon) → **General**.
2. Click **Add app** and choose **Android**.
3. Enter your package name, for example `com.example.metamorphosis`.
4. Register the app.
5. Download `google-services.json`.
6. Place `google-services.json` in `android/app/`.

### iOS

1. In **Project settings** → **General**, click **Add app** and choose **iOS**.
2. Enter your bundle ID, for example `com.example.metamorphosis`.
3. Register the app.
4. Download `GoogleService-Info.plist`.
5. Place `GoogleService-Info.plist` in `ios/Runner/`.
6. Add the file in Xcode if required.

### Web (optional)

1. In **Project settings** → **General**, click **Add app** and choose **Web**.
2. Register the web app.
3. Copy the Firebase config values.
4. Add the values to `lib/firebase_options.dart` if using web.

## Step 6: Update `lib/firebase_options.dart`

After registering your apps, put your credentials into `lib/firebase_options.dart`.

### Android example

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',
  appId: 'YOUR_ANDROID_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
);
```

### iOS example

```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'YOUR_IOS_API_KEY',
  appId: 'YOUR_IOS_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
);
```

### Web example

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_WEB_API_KEY',
  authDomain: 'YOUR_PROJECT.firebaseapp.com',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_PROJECT.appspot.com',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  appId: 'YOUR_WEB_APP_ID',
);
```

## Step 7: Install dependencies and run

Run:

```bash
flutter pub get
flutter run
```

## Firestore Data Structure

The app stores each profile under `users/{userId}` with fields:

- `username`
- `age`
- `biologicalSex`
- `heightCm`
- `weightKg`
- `activityLevel`
- `useMetric`
- `createdAt`

## First-time Launch Behavior

- First launch: app shows onboarding.
- After onboarding: app saves profile and loads home screen.
- On future launches: app goes directly to home screen.

## Notes

- Choose **Standard edition** for normal app use.
- Choose **Native mode** for Firestore.
- Use **Enterprise** only if you need enterprise support or compliance.
- If you want cloud syncing without a custom backend, Firebase is the right choice.

