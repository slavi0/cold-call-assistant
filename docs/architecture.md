# Architecture — Cold Call Assistant

## Overview

Cold Call Assistant is a Flutter CRM app for salespeople managing prospects.
It follows a **feature-based MVVM architecture** using Views, Providers, Services, and Models.

---

## Folder Structure

```
lib/
  core/
    exceptions/
      app_exception.dart       # Typed exception hierarchy
  features/
    contacts/
      models/
        contact_status.dart    # Enum: CRM pipeline stages
        contact_model.dart     # ContactModel + Hive adapter
        contact_model.g.dart   # Hive adapter (hand-written)
      providers/
        contact_provider.dart  # Loads/seeds contact list state
      services/
        contact_service.dart   # All contact persistence + dummy seed
      views/
        contacts_screen.dart   # Contact list + "Start Calling" button
        contact_detail_screen.dart  # Contact info + "Call" button + sequence auto-advance
    calls/
      models/
        call_direction.dart    # Enum: outgoing / incoming
        call_outcome.dart      # Enum: completed / noAnswer / etc.
        call_model.dart        # CallModel + Hive adapter
        call_model.g.dart      # Hive adapters
      providers/
        phone_call_provider.dart        # Telephony state (loading, error, active)
        calling_sequence_provider.dart  # Workflow state (index, auto-advance)
      services/
        call_service.dart      # All call persistence operations
        phone_call_service.dart # Telephony intents (ACTION_CALL / ACTION_DIAL)
      views/
        home_screen.dart       # App entry point — navigates to contacts
    recordings/
      models/
        transcript_status.dart # Enum: none / pending / completed / failed
        recording_model.dart   # RecordingModel + Hive adapter
        recording_model.g.dart # Hive adapters
      services/
        recording_service.dart # All recording persistence operations
    excel_import/
      models/
        excel_table_model.dart   # ExcelTableModel + Hive adapter
        excel_table_model.g.dart # Hive adapter
      services/
        excel_table_service.dart # All import record operations
  shared/                        # (future reusable widgets)
  main.dart                      # Hive init + adapter registration + named routes
```

---

## Data Model Relationships

```
ExcelTableModel (1) ──── (*) ContactModel
ContactModel    (1) ──── (*) CallModel
CallModel       (1) ──── (0..1) RecordingModel
```

- A **Contact** is imported from an **ExcelTable** (or created manually).
- A **Contact** has zero or more **Calls**.
- A **Call** has zero or one **Recording**.
- A **Recording** has an optional AI **transcript**.

---

## Local Persistence: Hive

**Why Hive over alternatives:**

| Option | Status | Reason |
|---|---|---|
| SharedPreferences | ❌ | Not designed for structured objects |
| SQLite (sqflite) | Viable | Requires manual SQL + migrations |
| Isar | Viable | Excellent but adds code-gen overhead |
| **Hive** | ✅ Chosen | Lightweight, fast, no migrations at this stage |

### Hive TypeId Allocation

| TypeId | Class |
|---|---|
| 0 | ContactModel |
| 1 | CallModel |
| 2 | RecordingModel |
| 3 | ExcelTableModel |
| 10 | ContactStatus (enum) |
| 11 | CallDirection (enum) |
| 12 | CallOutcome (enum) |
| 13 | TranscriptStatus (enum) |

**Never reuse a TypeId** — Hive uses them to look up stored objects. If a type is removed, retire its TypeId permanently.

---

## Persistence Abstraction

All Hive operations are **isolated inside service classes**.

```
View → Provider → Service → Hive
```

Providers **never** import or call Hive directly.  
This means migrating to Supabase = rewriting service classes only. Views and providers are untouched.

---

## Model Design Decisions

### Contact
- `recordings` removed from Contact — recordings belong to a `Call`, not directly to a `Contact`
- `company` added — essential for cold-call CRM use cases
- `status` (enum) added — enables pipeline tracking without querying call history
- `createdAt` / `updatedAt` added — for sorting and future sync
- `importedFromTableId` added — links contacts back to their import batch

### Call
- `contactId` added — explicit foreign key; avoids orphaned records
- `outcome` (enum) added — core CRM value for call analytics
- `direction` (enum) added — distinguishes outgoing cold calls from inbound callbacks
- `notes` added — call-specific notes (contact-level notes are on ContactModel)
- `endTime` replaces `duration` — duration is computed via getter; stored duration can go stale

### Recording
- `mp3File` renamed to `filePath` — format-agnostic (iOS: `.m4a`, Android: `.aac`)
- `callId` added — explicit back-reference for loading recordings independently
- `transcript` kept as `String?` — null until transcription completes
- `transcriptStatus` (enum) added — lifecycle: none → pending → completed / failed
- `transcribedAt` added — audit timestamp + display ("transcribed 2h ago")

### ExcelTable
- `link` renamed to `filePath`, made nullable — local path may not exist if file was deleted
- `importedAt` added — required for sorting import history
- `rowCount` added — summary metadata without loading all contacts

---

## Error Handling

All service methods throw typed exceptions from `core/exceptions/app_exception.dart`:

| Exception | When thrown |
|---|---|
| `StorageException` | A Hive read/write fails |
| `NotFoundException` | A record does not exist in storage |
| `DeviceException` | A system service or device intent fails (e.g. dialer unavailable) |

---

## Telephony & Call Launcher Services

### Direct Phone Calling & Intent Handling
- **Service**: `PhoneCallService` (`lib/features/calls/services/phone_call_service.dart`)
- **Provider**: `PhoneCallProvider` (`lib/features/calls/providers/phone_call_provider.dart`)
- **View**: `ContactDetailScreen` (`lib/features/contacts/views/contact_detail_screen.dart`) — replaced the deleted `PhoneCallScreen`; hosts the `WidgetsBindingObserver` and Call button.
- **Direct Calling (`Intent.ACTION_CALL`)**: Uses `flutter_phone_direct_caller` and `permission_handler` to initiate calls immediately without dialer confirmation when runtime `CALL_PHONE` permission is granted.
- **Dialer Fallback (`Intent.ACTION_DIAL`)**: Uses `url_launcher` as fallback if permission is denied.
- **Android Manifest Configuration**: Added `<uses-permission android:name="android.permission.CALL_PHONE" />` and `<queries>` filter for `android.intent.action.DIAL` with `tel` scheme in `android/app/src/main/AndroidManifest.xml`.
- **App Lifecycle Auto-Return**: `ContactDetailScreen` implements `WidgetsBindingObserver`. On `AppLifecycleState.resumed`, it calls `PhoneCallProvider.handleAppResumed()` and `CallingSequenceProvider.advanceToNext()` (if in sequence mode).

### Android Rendering: Black Screen Root Cause & Fix

**Root cause**: Flutter's default renderer uses `FlutterSurfaceView` (Android `SurfaceView`). A `SurfaceView`'s GPU buffer has an **independent lifecycle** — it is created in `onStart` and destroyed in `onStop`. When a call is cancelled before it connects, Android may skip the full `onStop → onStart` cycle and go directly `onPause → onResume`. In this shortcut path, Impeller's GPU pipeline loses its frame-scheduling lock during the rapid transition, resulting in a permanent black screen.

**Fix 1 — Switch to `FlutterTextureView`** (`RenderMode.texture` in `MainActivity.kt`):  
`TextureView` renders *inside* the View hierarchy rather than behind it. It participates in the normal View draw cycle and does not have an independent surface lifecycle, so there is no GPU pipeline stall during a rapid pause/resume.

**Fix 2 — Disable Impeller** (`io.flutter.embedding.android.EnableImpeller = false` in `AndroidManifest.xml`):  
Impeller has documented surface-lifecycle bugs with rapid foreground/background transitions on Android. Disabling it reverts to the stable Skia renderer. Combined with `RenderMode.texture`, this provides belt-and-suspenders protection.

**Temporary lifecycle logging** (`Log.d("CCA_LIFECYCLE", …)` in `MainActivity.kt`):  
Overrides of `onCreate`, `onStart`, `onResume`, `onPause`, `onStop`, `onRestart` allow `adb logcat -s CCA_LIFECYCLE` to confirm exactly which callbacks fire during each call scenario. Remove these log statements once the fix is confirmed stable in production.

---

## Contact Calling Workflow

### Navigation
Named routes via `MaterialApp.routes`:

| Route | Screen | Purpose |
|---|---|---|
| `/` | `HomeScreen` | App entry point |
| `/contacts` | `ContactsScreen` | Contact list + Start Calling |
| `/contact-detail` | `ContactDetailScreen` | Contact info + Call button |

### Calling Sequence State Machine

```
ContactsScreen — "Start Calling" pressed
    │
    ▼  CallingSequenceProvider.startSequence(contacts)
    │
    ▼  Navigate to /contact-detail (contact[0])
    │
ContactDetailScreen — user presses "Call"
    │
    ▼  PhoneCallProvider.initiateCall(phoneNumber)
    │
    ▼  (app goes to background — system Phone app in foreground)
    │
    ▼  Call ends — app returns to foreground
    │
    ▼  didChangeAppLifecycleState(resumed)
    │   ├─ PhoneCallProvider.handleAppResumed()  (reset telephony state)
    │   └─ CallingSequenceProvider.advanceToNext()
    │       ├─ nextContact exists → Navigator.pushReplacementNamed('/contact-detail', args: next)
    │       └─ sequence complete  → Navigator.popUntil('/contacts')
```

### Provider Responsibilities

| Provider | Responsibility |
|---|---|
| `PhoneCallProvider` | Telephony state only (loading, error, fallback result) |
| `CallingSequenceProvider` | Workflow state (index, active flag, advance logic) |
| `ContactProvider` | Contact list data (loaded from `ContactService`) |

The two call-related providers are deliberately separate: neither knows about the other, and the view coordinates them via `context.read<>()`.

### Dummy Data Seeding
`ContactService.seedDummyContactsIfEmpty()` creates 10 named contacts on first launch if the Hive box is empty. `ContactProvider.seedAndLoad()` triggers this at startup. The seed is idempotent — it no-ops if any contacts already exist.

---

## Future Migration to Supabase

1. Replace each service's Hive box calls with `supabase.from('table').select()/insert()/update()/delete()`.
2. Remove Hive adapter registrations from `main.dart`.
3. The `toMap()` method on every model is already Supabase-ready (snake_case keys matching PostgreSQL column conventions).
4. UUID IDs ensure no ID remapping is needed on migration.
5. Providers and views require zero changes.
