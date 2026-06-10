# laporan_keuangan_rt

Laporan keuangan RT 3 / RW 21, Bukit Permai, Sumbersari, Jember.

A small, offline-first Flutter app that shows the neighbourhood's monthly financial
report (Laporan Keuangan) pulled live from a Google Sheet, and — for signed-in
users with edit rights — lets them change the income/expense tabs and push the
changes back to the sheet.

## How it works

1. The app fetches the configured Google Sheet (as `.xlsx`), parses the monthly
   recap tabs, and displays the report for the current month. The last fetch is
   cached locally (SQLite) so it still works offline.
2. When a user **signs in** with Google and that account has permission to edit
   the sheet, they can open the editor, change the `+<month>` (income) or
   `-<month>` (expense) tab, and tap **Simpan / Save** to write the changes back
   to the sheet via the Google Sheets API.

## Features

- Live data from a Google Sheet (configurable via `.env`), offline cache fallback.
- Monthly recap: Penerimaan, Pengeluaran, Saldo akhir, Rincian Pos.
- Localised UI: Bahasa Indonesia (default) + English, choice persisted.
- Google sign-in + in-app editing that pushes back to the sheet (formula cells
  are locked so they're never overwritten).

## Architecture

- **State management:** `flutter_bloc` — `RecapBloc` (data + month selection),
  `EditCubit` (tab load/save), `AuthCubit` (sign-in), `LocaleCubit` (language).
- **Data source:** `SheetFetcher` downloads the `.xlsx` export; `XlsxReader` +
  `RecapExtractor` parse the cached computed values (mirrors `openpyxl
  data_only=True`). `AppDatabase` (SQLite) caches the result.
- **Editing:** `SheetEditor` reads a tab (unformatted values + a formula mask)
  and writes changed cells via the Sheets API `values.batchUpdate`.
- **Auth:** `AuthService` with two backends — `MobileAuthService`
  (`google_sign_in`, Android/iOS) and `DesktopAuthService` (`googleapis_auth`
  loopback, for Windows/macOS/Linux dev).

## Prerequisites

- Flutter (stable). Confirm with `flutter doctor`.
- For Android builds: Android SDK + an emulator or a device.
- For Windows desktop dev: Visual Studio with the "Desktop development with C++"
  workload.
- iOS builds require a Mac.

## Setup

1. **Config / data source.** Copy `.env.example` to `.env` and set `SUMBER_DATA`
   to your Google Sheet URL (must be shared at least as *Anyone with the link can
   view*). `.env` is gitignored — never commit it.

   ```sh
   cp .env.example .env
   ```

2. **Google OAuth (only needed for the edit/sign-in feature).** Full step-by-step
   instructions live at the top of [`.env.example`](.env.example). In short:
   enable the Google Sheets API, configure the OAuth consent screen with the
   `.../auth/spreadsheets` scope, and create the OAuth clients you need:
   - **Android** (package `aditya.wibisana.rt3rw21` + signing SHA-1) — matched
     automatically, no value in `.env`.
   - **Web application** — its client ID goes in `GOOGLE_SERVER_CLIENT_ID`.
   - **Desktop app** — for editing on Windows; goes in
     `GOOGLE_DESKTOP_CLIENT_ID` / `GOOGLE_DESKTOP_CLIENT_SECRET`.

   To actually **save** edits, the signed-in account needs **Editor** access on
   the sheet.

   > Note: `google_sign_in` is intentionally pinned to **v6**. v7's Credential
   > Manager flow hangs on some OEM ROMs (e.g. Vivo/FuntouchOS); the v6 classic
   > flow is broadly compatible.

3. **Install dependencies.**

   ```sh
   flutter pub get
   ```

## Running

```sh
flutter devices                  # list available targets
flutter run -d windows           # desktop (fast dev; UI is framed to a phone size)
flutter run -d <device-id>       # a connected Android phone (see flutter devices)
flutter emulators --launch <id>  # launch an Android emulator (flutter emulators to list)
flutter build apk                # produce an installable Android APK
```

Notes:
- On desktop the app runs inside a phone-sized frame so the layout matches mobile.
- The local database uses `sqflite`, which only runs on Android/iOS and (via the
  FFI backend) desktop — not web.
- After editing `.env`, do a **full restart** (not hot reload) — it's a bundled
  asset.

## Testing

```sh
flutter analyze
flutter test
```

`test/recap_extractor_test.dart` parses the bundled `source_data.xlsx` and asserts
the extracted figures, verifying the whole download-and-parse pipeline.

## Going public (checklist)

- Submit the OAuth consent screen for **verification** (the Sheets scope is
  "sensitive") and move it out of Testing mode.
- Add Android OAuth clients for your **release** keystore SHA-1 and, if shipping
  via Play, the **Play App Signing** SHA-1.
- Keep `.env`, `*.keystore`, and `key.properties` out of version control (already
  gitignored).
