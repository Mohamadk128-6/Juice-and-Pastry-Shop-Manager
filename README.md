# Sweet Sip — Juice and Pastry Shop Manager

A Flutter point-of-sale and shop-management application for Sweet Sip. It gives workers a fast menu-based order screen and gives the owner a synchronized view of orders, products, categories, sales statistics, and smart recommendations.

## Key Features

- Full Sweet Sip menu with searchable categories and multi-product selection
- Add, edit, and remove products and custom categories
- Fast multi-item sales cart with worker name and optional order notes
- Owner orders view with real-time Firebase Firestore synchronization
- Reliable offline-first sales queue and automatic synchronization
- Local backup and recovery support when changing phones
- Daily sales history, transaction details, and LBP reporting
- Improved sales statistics and visual charts
- Smart local suggestions plus optional Firebase AI Logic/Gemini suggestions
- Firebase App Check and anonymous authentication support
- Arabic and English interface
- Sweet Sip branding, launcher icon, and splash screen

## Worker orders and owner view

Each device stores the name of the staff member using it. The name and an
optional order note are saved with every transaction in Firestore. The owner
can open **Staff Orders** from the menu to see every order in real time and
filter the list by worker.

Firestore rules are included in `firestore.rules`. Review the authorized-device
policy before adding a new phone, and deploy updated rules whenever access
requirements change.

## Smart suggestions

The statistics screen always provides fast local recommendations without an
internet connection. Optional cloud suggestions use Firebase AI Logic/Gemini.
The `functions/` directory also contains a server-side Gemini-to-Groq fallback
implementation; provider keys must be stored as Firebase secrets and must never
be committed to this repository.

## Technology Stack

- Flutter and Dart
- Firebase Firestore
- Firebase Authentication
- Provider and ChangeNotifier
- Syncfusion Flutter Charts
- Material 3

## Project Structure

```text
lib/
  models/       Products, menu items, sales, and transactions
  providers/    Local-first state and Firestore synchronization providers
  screens/      Menu, ordering, owner orders, products, and analytics screens
  services/     Firebase, authentication, backup, and recovery services
  widgets/      Shared interface components
```

## Firebase Setup

This repository does not include private Firebase credentials or
`android/app/google-services.json`. Before running the application, create a
Firebase project, enable Anonymous Authentication and Cloud Firestore, and add
the appropriate Firebase configuration files for your target platform.

## Run Locally

```bash
flutter pub get
flutter run
```

## Author

Mohamad Kamel Ibrahim

## Firebase setup

The app is prepared for realtime Firestore sync. Before running it on Android:

1. Create a Firebase project and add an Android app with package
   `com.example.flutter_application_1`.
2. Download `google-services.json` and place it at
   `android/app/google-services.json`.
3. Enable **Authentication > Sign-in method > Anonymous**.
4. Create a Firestore database and deploy `firestore.rules`.
5. If cloud AI suggestions are required, enable Firebase AI Logic and App Check
   for the Android app. Store any server-side provider keys with Firebase
   Secret Manager rather than in Dart or JavaScript source files.

Both worker and owner phones can use the same app. Every saved order is written
to the `transactions` collection and appears in real time on the owner screen.
