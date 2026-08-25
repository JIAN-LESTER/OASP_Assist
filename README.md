# OASP Assist

OASP Assist is a Flutter application for admission, scholarship, and placement support. It provides a conversational assistant for users, operational tools for staff, and administration tools for managing users, programmes, FAQs, announcements, escalations, and reports.

The application uses Firebase for authentication, Firestore, Cloud Storage, Cloud Messaging, Cloud Functions, and web hosting. Its retrieval-augmented chat and document workflows use Gemini, Cohere, and Pinecone.

## Features

- Role-based experiences for users, staff, and administrators
- Conversational FAQ and document-assisted chat
- Human escalation from users to staff
- FAQ, programme, affiliation, and document management
- Announcements, notifications, and Facebook synchronisation
- User administration and account activity logs
- Dashboards and reports
- File upload and document processing
- Firebase Cloud Messaging notifications
- Flutter targets for Android, iOS, web, Windows, macOS, and Linux

## Technology stack

- Flutter and Dart (`^3.7.2`)
- Firebase Authentication, Firestore, Storage, Cloud Functions, and Messaging
- Firebase Functions with TypeScript and Node.js 22
- Gemini for generation and embeddings
- Cohere for chat/embedding workflows
- Pinecone for vector search
- Provider for application state management

## Prerequisites

Install the following before starting:

- Flutter SDK compatible with Dart 3.7.2 or newer
- Node.js 22
- npm
- Firebase CLI
- Access to the Firebase project `cmu-oasp-assist`

Verify the local toolchain:

```bash
flutter doctor
node --version
npm --version
npx -y firebase-tools@latest --version
```

## Getting started

### 1. Install dependencies

From the repository root:

```bash
flutter pub get
cd functions
npm install
cd ..
```

### 2. Configure Firebase

The repository is configured for `cmu-oasp-assist` in `.firebaserc` and `lib/firebase_options.dart`. If using another Firebase project, regenerate the Flutter configuration with FlutterFire and update the Firebase CLI project selection.

```bash
firebase login
firebase use cmu-oasp-assist
```

Do not commit service-account keys or local environment files. Server-side credentials belong in Firebase Functions secrets.

### 3. Configure Functions secrets

The AI and vector-search functions read these secrets:

- `GEMINI_API_KEY`
- `COHERE_API_KEY`
- `PINECONE_API_KEY`
- `PINECONE_HOST`

Set them using the Firebase CLI:

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set COHERE_API_KEY
firebase functions:secrets:set PINECONE_API_KEY
firebase functions:secrets:set PINECONE_HOST
```

The Pinecone index must support 768-dimensional Gemini embeddings.

### 4. Run the app

```bash
flutter devices
flutter run -d chrome
```

Replace `chrome` with a mobile or desktop device identifier as needed. Firebase Functions are configured for the `asia-southeast1` region.

## Cloud Functions commands

Run these commands from `functions/`:

```bash
npm run build       # Compile TypeScript to functions/lib
npm run build:watch # Compile continuously during development
npm run seed:faqs   # Build and seed predefined FAQs
npm run serve       # Build and start the Functions emulator
npm run shell       # Build and open the Functions shell
npm run deploy      # Deploy Functions
npm run logs        # View production Function logs
```

To deploy the web app and Firebase configuration from the repository root:

```bash
flutter build web
firebase deploy
```

Firebase Hosting serves `build/web` and rewrites application routes to `index.html`. The Functions deployment is compiled automatically by the `predeploy` hook in `firebase.json`.

## Seed initial FAQs

The seed script writes predefined admission, scholarship, and placement FAQs to the Firestore `faqs` collection:

```bash
cd functions
npm run seed:faqs
```

Review `functions/src/scripts/seedFaqs.ts` before running it in a production project if the seed content needs to change.

## Project structure

```text
lib/
  modules/          User, staff, admin, and authentication screens
  services/         Firebase, AI, notifications, files, and retrieval services
  provider/          Provider-based application state
  models/            Firestore and application data models
  widgets/           Reusable UI widgets
  firebase_options.dart
  main.dart
functions/
  src/               TypeScript Cloud Functions
  src/scripts/       Administrative scripts such as FAQ seeding
firebase.json        Firebase Hosting, Functions, Firestore, and Storage setup
firestore.indexes.json
storage.rules
test/                Flutter widget tests
```

## Firebase services and data

The app uses Firebase Authentication for accounts and roles, Firestore for application data, Cloud Storage for uploaded files and announcement media, and Cloud Messaging for notifications. Firestore indexes are defined in `firestore.indexes.json`, while Storage access rules are defined in `storage.rules`.

Important backend areas include:

- `users` for account profiles and roles
- `faqs` for predefined and managed FAQ content
- `messages` and conversations for chat history
- `escalations` for user-to-staff support requests
- `announcements` for published notices
- `logs` for administrative activity

Review and test Firebase security rules before deploying changes to a shared or production project.

## Testing

Run the Flutter tests with:

```bash
flutter test
```

The current test directory contains the default widget smoke test and can be expanded with coverage for authentication, role-based navigation, chat, and Firebase-backed workflows.

## Deployment notes

- Verify Firebase Authentication, Firestore indexes, Storage rules, Functions secrets, and Pinecone connectivity before deployment.
- Keep API keys out of source control and client-distributed files whenever possible.
- Cloud Functions use Node.js 22 and the `asia-southeast1` region.
- Web builds are deployed from `build/web` through Firebase Hosting.

## License

This project is configured as a private application (`publish_to: 'none'`). No open-source license has been declared.
