# Lakwatsapp

A Flutter application with Supabase authentication.

## Features

- Email/Password Authentication
- Google Sign-In
- Session Management

## Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Create `.env` file with your Supabase credentials:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

3. Update `web/index.html` with your Google Client ID

4. Run the app:
   ```bash
   flutter run -d chrome --web-port=3000
   ```

## Project Structure

```
lib/
├── config/          # Configuration files
├── services/        # Authentication service
├── screens/         # UI screens
├── utils/           # Utility functions
└── main.dart        # App entry point
```
