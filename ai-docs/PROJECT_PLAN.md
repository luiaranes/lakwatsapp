# Lakwatsapp — Project Plan

> **"Lakwatsero"** (Filipino) — someone who loves to travel and wander.  
> Lakwatsapp is a travel companion app that combines trip planning, destination discovery, social sharing, and AI-powered recommendations into one seamless experience.  
> **Built for barkadas** — group trip planning with built-in budget tracking and expense splitting.

---

## Vision

Build a mobile-first (iOS & Android) and web travel app that empowers Filipino travelers — and travelers everywhere — to plan trips, explore destinations, share experiences, and book with confidence, all in one place.

---

## Target Platforms

| Platform | Priority |
|----------|----------|
| Mobile (iOS & Android) | Primary |
| Web | Secondary |

Built with **Flutter** (Dart) for cross-platform coverage and **Supabase** as the backend (auth, database, storage, realtime).

---

## Project Phases

### Phase 0 — Foundation ✅
> Goal: Establish the core architecture and authentication flow.

- [x] Project setup (Flutter + Supabase)
- [x] Email/Password authentication
- [x] Google Sign-In
- [x] Session management
- [x] Define data models (users, trips, destinations, posts)
- [x] Set up Supabase database schema
- [x] Basic navigation shell (bottom nav)

---

### Phase 1 — MVP Core Features *(Current)*
> Goal: A working app users can actually use to plan a trip.

#### Authentication & Profiles ✅
- [x] User profile creation (display name, avatar, bio, home location)
- [x] Profile editing
- [x] Avatar upload to Supabase Storage

#### Trip Planning ✅
- [x] Create / edit / delete trips
- [x] Trip cover image upload
- [x] Trip status: Planning → Ongoing → Completed
- [x] **Group trips** — invite friends to collaborate on a shared itinerary
- [x] **Collaborative editing** — all trip members can edit (not role-restricted)

#### Itinerary Builder ✅
- [x] Day-by-day itinerary view with tabs
- [x] Add / edit / delete activities
- [x] Drag & drop reordering
- [x] Time picker for start/end times
- [x] Category selection with icons (transport, food, activity, sightseeing, etc.)
- [x] Estimated cost per activity
- [x] **AI Quick Add** — describe activity in natural language, AI parses and fills form

#### Friends System ✅
> To invite someone to a trip, they must first be in your friends list.

- [x] **Mutual friendships** — send friend requests, accept/reject
- [x] **Search by name or email** — find users to add as friends
- [x] **Friends management** — view friends list, pending requests, remove friends
- [x] **Trip invitations** — select from friends list when inviting to a trip
- [x] **Privacy by design** — only friends can be invited, no open search

#### Activity Log ✅
> Track who made changes for transparency in collaborative trips.

- [x] **Audit trail** — log all trip/itinerary changes with user attribution
- [x] **Activity feed** — view recent activity on trip detail screen
- [x] **Full activity history** — paginated activity log screen
- [x] **Flexible system** — designed to extend to expenses, posts, etc.

#### Budget Planning ✅
> One of the biggest pain points for group travel is managing shared expenses. Lakwatsapp makes this seamless.

- [x] **Trip budget setup** — set an overall budget or per-day budget
- [x] **Expense tracking** — log expenses with category (transport, food, accommodation, activities, etc.)
- [x] **Group expense splitting**
  - Add who paid and who owes
  - Split equally, by percentage, or custom amounts
  - Running balance per member ("You owe ₱1,200 to Juan")
- [x] **Settlement suggestions** — minimize transactions to settle up at the end
- [x] **Currency support** — handle multiple currencies for international trips
- [x] **Budget insights** — see spending breakdown by category, per day, per person

#### Expense Automation *(Key Feature)*
> Make adding expenses effortless — no manual data entry.

**Receipt Scanning (MVP) ✅**
- [x] Capture receipt with camera or gallery
- [x] AI extracts merchant, date, amount, line items (Claude Vision API)
- [x] AI auto-categorizes expense (food, transport, accommodation, etc.)
- [x] User confirms and assigns to trip/split
- [x] Receipt image stored and viewable
- [x] Line items saved and displayed on expense cards

**Text Quick Add (MVP) ✅**
- [x] Natural language input: *"Grab to Tagaytay ₱2,500 paid by Juan, split with Maria"*
- [x] AI parses and fills the expense form (Claude via Supabase Edge Function)
- [x] Expense split selection before saving
- [x] One-tap confirm

**Voice Input ✅**
- [x] Speech-to-text voice input using iOS 26+ native SpeechAnalyzer API (`liquid_speech`)
- [x] Fallback to `speech_to_text` for Android and older iOS versions
- [x] Integrated into Quick Add screens (expenses and itinerary)

**AI Quick Add for Itinerary ✅**
- [x] Natural language input: *"9am flight to Boracay 3500 php"*
- [x] AI extracts title, time, location, category, estimated cost
- [x] Parsed preview with confidence score
- [x] One-tap confirm to add activity

**Email Forwarding (Phase 2)**
> Forward digital receipts (airlines, hotels, Grab, Agoda, etc.) directly to the trip.

Each trip gets a unique email address:
```
siargao-x7k2m9p4@receipts.lakwatsapp.ph
```

*Security model:*
- **Sender whitelist** — only accept emails from registered trip members
- **Random address** — hard to guess, acts like a shared secret
- **Auto-attribution** — sender email identifies who paid
- **Date validation** — AI checks if receipt date matches trip dates; asks for confirmation if not
- **Regenerate address** — trip owner can reset if compromised
- **Optional confirmation** — require in-app approval for high-value expenses

*Processing flow:*
```
Email received → Sender in trip? → Parse with AI → Date matches? → Add expense → Notify members
                      ↓ No                              ↓ No
                   Reject                         Ask user to confirm
```

*Tech stack:*
| Component | Options |
|-----------|---------|
| Inbound email | AWS SES, SendGrid Inbound Parse, Postmark |
| Receipt parsing | OpenAI Vision API, Google Document AI |
| Notifications | Supabase Realtime + Push |

#### Explore & Discover
- Browse destinations (cities, landmarks, nature spots)
- Destination detail pages (photos, description, tips)
- Search & filter by category or location

#### Maps & Location
- Interactive map view of trips and destinations
- Pin destinations on a map
- Current location support

---

### Phase 2 — Social & Sharing
> Goal: Let users share their travels and discover others'.

- Travel feed / timeline (posts with photos & captions)
- Like, comment, and save posts
- Follow other travelers
- Share trips publicly or keep them private
- Trip summary / recap generation

---

### Phase 3 — Bookings & AI
> Goal: Close the loop from planning to booking, enhanced by AI.

#### Bookings / Reservations ✅ (shipped)
- Trip bookings table + manual add/edit, detail view, itinerary link
- Import bookings from forwarded email (flights, hotels) via `parse-booking-email`

#### Packing Lists ✅ (shipped)
- Per-member packing lists (`assigned_to_user_id`)
- Assign items to trip members; in-app notification on assignment
- Add / edit / delete items; check off when packed
- AI suggestions via `generate-packing-suggestions`; seed from AI trip planning

#### In-App Notifications ✅ (partial — push deferred to Phase 4)
- `user_notifications` inbox, realtime snackbar, Profile screen

#### AI-Powered Features (partial)
- ✅ Itinerary suggestions + draft review + transport-aware planning
- ⏳ Destination recommendations
- ⏳ Smart packing (weather-aware) — basic AI suggestions done; weather not yet
- ⏳ Travel tips via AI chat
- ⏳ Budget assistant

---

### Phase 4 — Polish & Launch
> Goal: Production-ready quality.

- Offline support for saved trips and itineraries
- Push notifications (FCM — in-app notifications for packing assignments already live)
- Localization (English + Filipino)
- Performance optimization
- App Store & Play Store submission
- Web deployment

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend / Auth | Supabase |
| Database | PostgreSQL (via Supabase) |
| Storage | Supabase Storage |
| Maps | Google Maps / Mapbox |
| AI / OCR | Claude Vision API |
| Inbound Email | AWS SES / SendGrid / Postmark |
| State Management | TBD (Riverpod / Bloc) |
| Environment Config | flutter_dotenv |

---

## Current File Structure

```
lakwatsapp/
├── ai-docs/              # Project documentation & AI context
│   ├── PROJECT_PLAN.md   # Project overview & roadmap
│   ├── PHASE_TASKS.md    # Detailed task tracker
│   ├── DATA_MODELS.md    # Dart model documentation
│   ├── DATABASE_SCHEMA.md # Supabase schema documentation
│   └── RUNNING_THE_APP.md # How to run on iOS/Android/Web
├── supabase/             # Database migrations & Edge Functions
│   ├── migrations/
│   │   ├── 001_initial_schema.sql
│   │   ├── 002_rls_policies.sql
│   │   ├── 003_storage_buckets.sql
│   │   ├── 004_create_profile_trigger.sql
│   │   ├── 005_user_search_functions.sql
│   │   ├── 006_friendships.sql
│   │   ├── 007_all_members_can_edit.sql
│   │   ├── 008_activity_logs.sql
│   │   ├── 012_receipts_storage.sql
│   │   ├── 013_expense_line_items.sql
│   │   ├── 014_draft_itineraries.sql
│   │   └── 015_enable_realtime.sql
│   ├── functions/
│   │   ├── parse-receipt/index.ts        # Claude Vision API for receipt parsing
│   │   ├── parse-expense-text/index.ts   # Claude API for expense text parsing
│   │   └── parse-itinerary-text/index.ts # Claude API for itinerary text parsing
│   └── README.md
└── lakwatsapp/           # Flutter project
    └── lib/
        ├── config/       # Supabase configuration
        ├── models/       # Data models (User, Trip, Itinerary, Expense, ExpenseSplit, ParsedReceipt, ParsedExpense, ParsedItinerary, etc.)
        ├── services/     # Business logic (auth, trip, itinerary, expense, receipt_scanning, quick_add, quick_add_itinerary, realtime, etc.)
        ├── screens/      # UI screens (trips, itinerary, profile, expenses, scan_receipt, etc.)
        ├── widgets/      # Reusable UI components (expense_split_selector, skeleton_widgets, etc.)
        ├── utils/        # Utility helpers (snackbar_utils)
        └── main.dart     # App entry point
```

---

## Key Principles

1. **Mobile-first** — design and build for mobile; adapt for web.
2. **Offline-capable** — core planning features should work without internet.
3. **Filipino context** — highlight local destinations, use familiar language.
4. **Simple by default** — don't overwhelm; reveal complexity progressively.
5. **AI as a helper, not a gimmick** — AI features should save real time.
6. **No awkward money talks** — make group expense tracking transparent and fair so friends stay friends.

---

*Last updated: May 18, 2026*
