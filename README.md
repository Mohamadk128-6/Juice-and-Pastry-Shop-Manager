# Juice and Pastry Shop Manager

A Flutter point-of-sale and inventory application designed for a juice and pastry shop. The application helps staff manage products and stock, record multi-item sales, review daily transactions, and monitor sales performance in one mobile interface.

## Key Features

- Product and category management for juices and pastries
- Inventory quantities, stock adjustments, and inventory value tracking
- Multi-item sales cart and transaction recording
- Daily sales history and transaction details
- USD and LBP revenue calculations
- Sales analytics with pie and column charts
- Arabic and English localization
- Real-time Firebase Firestore synchronization
- Firestore offline persistence
- Anonymous Firebase Authentication

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
  providers/    Application state and Firestore data providers
  screens/      Product, sales, inventory, banking, and analytics screens
  services/     Firebase initialization and authentication services
  widgets/      Shared interface components
```

## Firebase Setup

This repository does not include private Firebase credentials. Before running the application, create a Firebase project, enable Anonymous Authentication and Cloud Firestore, and add the appropriate Firebase configuration files for your target platform.

## Run Locally

```bash
flutter pub get
flutter run
```

## Author

Mohamad Kamel Ibrahim
