# Lakwatsapp — Phase Tasks Tracker

> Detailed task tracking for each project phase. Update checkboxes as tasks are completed.

---

## Progress Overview

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 0 — Foundation | ✅ Complete | 7/7 |
| Phase 1 — MVP Core Features | ✅ Complete | 88/88 |
| Phase 2 — Social & Sharing | ⏳ Not Started | 0/5 |
| Phase 3 — Bookings & AI | 🔄 In Progress | 24/28 |
| Phase 4 — Polish & Launch | ⏳ Not Started | 0/6 |

**Legend:** ✅ Complete | 🔄 In Progress | ⏳ Not Started

---

## Phase 0 — Foundation

> **Goal:** Establish the core architecture and authentication flow.

### Project Setup
- [x] Initialize Flutter project
- [x] Configure Supabase connection
- [x] Set up environment variables (.env)
- [x] Configure flutter_dotenv

### Authentication
- [x] Email/Password sign up
- [x] Email/Password sign in
- [x] Google Sign-In (OAuth)
- [x] Sign out functionality
- [x] Session persistence
- [x] Auth state management (StreamBuilder)

### Data Layer
- [x] Define UserProfile model
- [x] Define Trip model
- [x] Define TripMember model
- [x] Define Destination model
- [x] Define TripDestination model
- [x] Define ItineraryItem model
- [x] Define Expense model
- [x] Define ExpenseSplit model
- [x] Define Post model
- [x] Create models barrel export

### Database Schema
- [x] Create user_profiles table
- [x] Create trips table
- [x] Create trip_members table
- [x] Create destinations table
- [x] Create trip_destinations table
- [x] Create itinerary_items table
- [x] Create expenses table
- [x] Create expense_splits table
- [x] Create posts table
- [x] Set up RLS policies
- [x] Create updated_at triggers
- [x] Create auto-profile trigger on signup

### Navigation
- [x] Create main navigation shell
- [x] Implement bottom navigation bar
- [x] Create placeholder screens (Explore, Trips, Feed, Profile)
- [ ] Set up named routes (optional, deferred to Phase 1)

### Documentation
- [x] PROJECT_PLAN.md
- [x] DATA_MODELS.md
- [x] DATABASE_SCHEMA.md
- [x] PHASE_TASKS.md (this file)

---

## Phase 1 — MVP Core Features

> **Goal:** A working app users can actually use to plan a trip.

### User Profiles
- [x] Profile screen UI
- [x] Display user info (name, avatar, bio, location)
- [x] Edit profile screen
- [x] Avatar upload (Supabase Storage)
- [x] Profile service (CRUD operations)

### Trip Management
- [x] Trips list screen
- [x] Create trip screen/modal
- [x] Trip detail screen
- [x] Edit trip functionality
- [x] Delete trip (with confirmation)
- [x] Trip status management (planning → ongoing → completed)
- [x] Trip cover image upload
- [x] Trip service (CRUD operations)

### Group Trips
- [x] Invite members to trip (from friends list)
- [x] Member list on trip detail
- [x] Role management (owner for special actions; all members can edit)
- [x] Remove member functionality
- [x] Leave trip functionality

### Friends System
- [x] Friendships database table with RLS
- [x] Friendship model and service
- [x] Friends screen with tabs (Friends / Requests)
- [x] Add friend sheet (search by name/email)
- [x] Send friend request
- [x] Accept/reject friend requests
- [x] Remove friend functionality
- [x] Invite trip members from friends list only

### Itinerary Builder
- [x] Day-by-day itinerary view
- [x] Add itinerary item
- [x] Edit itinerary item
- [x] Delete itinerary item
- [x] Reorder items (drag & drop)
- [x] Time picker for activities
- [x] Category selection with icons

### UI/UX Enhancements
- [x] Skeleton loading screens (shimmer effect for all loading states)

### Real-Time Data Synchronization
- [x] RealtimeService for managing Supabase WebSocket subscriptions
- [x] Real-time updates for trips, expenses, itineraries, activity logs, drafts
- [x] Proper subscription lifecycle management (subscribe/unsubscribe)
- [x] Tab refresh on navigation for IndexedStack screens

### Budget & Expenses
- [x] Set trip budget
- [x] Expense list for trip
- [x] Add expense screen
- [x] Edit/delete expense
- [x] Category selection
- [x] Expense service (CRUD)
- [x] Link expense to itinerary item (auto-sets date)
- [x] Live currency conversion (ExchangeRate API)
- [x] Convert expense totals to trip currency
- [x] Show converted amounts on individual expenses

### Expense Splitting
- [x] Split expense among members
- [x] Equal split calculation
- [x] Percentage split
- [x] Custom amount split
- [x] Balance summary per member
- [x] "Who owes whom" view
- [x] Mark split as settled
- [x] Settlement suggestions algorithm

### Receipt Scanning (MVP)
- [x] Camera integration
- [x] Image picker (gallery)
- [x] OCR integration (Google ML Kit + OpenAI Vision hybrid)
- [x] Extract amount, date, merchant
- [x] Auto-categorize expense
- [x] Expense split selection before saving
- [x] Confirmation UI before saving

### Text Quick Add (MVP)
- [x] Natural language input field
- [x] AI parsing integration (Claude via Supabase Edge Function)
- [x] Pre-fill expense form from parsed data
- [x] Expense split selection before saving
- [x] One-tap confirm

### Voice Input
- [x] Speech-to-text using iOS 26+ native SpeechAnalyzer API (liquid_speech)
- [x] Fallback to speech_to_text for Android and older iOS
- [x] Full-screen recording overlay with animated microphone
- [x] Real-time transcript display
- [x] Integrated into Quick Add screens (expenses and itinerary)

### AI Quick Add for Itinerary (MVP)
- [x] Natural language input for activities
- [x] AI parsing via Supabase Edge Function (Claude)
- [x] Extract title, time, location, category, estimated cost
- [x] QuickAddItineraryScreen UI with parsed preview
- [x] One-tap confirm to add activity

### Explore & Discover
- [x] Destinations list screen
- [x] Destination detail screen
- [x] Search destinations
- [x] Filter by category
- [x] Filter by location
- [x] Add destination to trip

### Maps & Location
- [x] Map view integration (Google Maps / Mapbox)
- [x] Display trip destinations on map
- [x] Pin destinations
- [x] Current location marker
- [x] Map in itinerary item detail

---

## Phase 2 — Social & Sharing

> **Goal:** Let users share their travels and discover others'.

### Social Feed
- [ ] Feed screen (timeline)
- [ ] Post card component
- [ ] Create post screen
- [ ] Multi-photo upload
- [ ] Link post to trip/destination

### Interactions
- [ ] Like post
- [ ] Unlike post
- [ ] Comment on post
- [ ] View comments
- [ ] Delete own comment

### Following
- [ ] Follow user
- [ ] Unfollow user
- [ ] Followers list
- [ ] Following list
- [ ] Feed filtered by following

### Sharing
- [ ] Toggle trip public/private
- [ ] Share trip link
- [ ] Public trip view (read-only)
- [ ] Trip summary/recap generation

### Email Forwarding (Receipts)
- [x] Generate unique trip email address
- [x] Inbound email setup (AWS SES / SendGrid)
- [x] Email parsing with AI
- [x] Sender validation
- [x] Date validation
- [x] Auto-add expense from email
- [x] Regenerate email address

---

## Phase 3 — Bookings & AI

> **Goal:** Close the loop from planning to booking, enhanced by AI.

### Bookings / Reservations
- [x] Add booking reference to trip
- [x] Booking detail view
- [x] Link booking to itinerary item
- [x] Import bookings from email (flights, hotels)

### Packing Lists
- [x] Packing list per trip
- [x] Personal list (items assigned to current user)
- [x] Assign items to trip members
- [x] In-app notification when item assigned to another member
- [x] Add items (manual + assignee picker)
- [x] Edit items (name, category, reassign)
- [x] Delete items (menu, swipe, edit sheet)
- [x] Check off items (assignee only)
- [x] "My list" / "I assigned" tabs
- [x] AI-generated packing suggestions (`generate-packing-suggestions` Edge Function)
- [x] Seed packing suggestions from AI trip planning

### In-App Notifications
- [x] `user_notifications` table + RLS + realtime
- [x] DB trigger on packing assignment
- [x] Notifications screen (Profile → Notifications)
- [x] Realtime snackbar via `NotificationListenerScope` on main shell

### AI Features
- [ ] Destination recommendations
- [x] Itinerary suggestions ("3 days in Siargao") — AI Trip Planning from Destination
- [x] Draft itinerary review flow (accept/edit/skip activities before saving)
- [x] Draft persistence (resume review after leaving or closing app)
- [x] Transport mode-aware itinerary generation (car/public transport/plane/mixed)
- [x] Flight & hotel booking details in trip preferences
- [ ] AI chat for travel tips
- [x] Smart packing list based on destination/weather — season-aware via Claude (no external weather API)
- [ ] Budget assistant (cost estimates, warnings)

---

## Phase 4 — Polish & Launch

> **Goal:** Production-ready quality.

### Offline Support
- [ ] Cache trips locally
- [ ] Cache itineraries locally
- [ ] Offline indicator
- [ ] Sync when back online

### Notifications
- [x] In-app notifications (packing assignments — see Phase 3)
- [ ] Push notification setup (FCM)
- [ ] Trip reminder notifications
- [ ] Expense added notification
- [ ] Social interaction notifications

### Localization
- [ ] English strings
- [ ] Filipino (Tagalog) strings
- [ ] Language switcher

### Performance
- [ ] Image optimization
- [ ] Lazy loading
- [ ] Pagination for lists
- [ ] Performance profiling

### Launch
- [ ] App icon & splash screen
- [ ] App Store assets (screenshots, description)
- [ ] Play Store assets
- [ ] iOS submission
- [ ] Android submission
- [ ] Web deployment

---

## Changelog

| Date | Phase | Tasks Completed |
|------|-------|-----------------|
| 2026-03-17 | 0 | Project setup, authentication (email + Google), session management |
| 2026-03-21 | 0 | Data models (9 models), database schema, RLS policies, documentation |
| 2026-03-21 | 0 | Main navigation shell, bottom nav bar, placeholder screens (Explore, Trips, Feed, Profile) |
| 2026-03-21 | 1 | User Profiles: Profile service, profile screen with real data, edit profile screen |
| 2026-03-21 | 1 | Avatar upload: Storage service, image picker, Supabase Storage buckets |
| 2026-03-21 | 1 | Trip Management: Trip service, trips list, create/edit/delete trip, trip detail, status management, cover image upload |
| 2026-03-22 | 1 | Group Trips: Invite members, member list, role management (owner/editor/viewer), remove/leave trip |
| 2026-03-22 | 1 | Friends System: Mutual friendships, friend requests, friends screen, invite from friends only |
| 2026-03-22 | 1 | Itinerary Builder: Day-by-day view, add/edit/delete items, drag & drop reorder, time picker, categories |
| 2026-03-22 | 1 | Collaborative Editing: All trip members can now edit (not just owner/editor) |
| 2026-03-22 | 1 | Activity Log: Track user actions on trips (audit trail for collaboration) |
| 2026-03-22 | 1 | Skeleton Loading: Shimmer effect for all loading states (trips, profile, friends, trip detail, itinerary, members, activity log) |
| 2026-03-23 | 1 | Budget & Expenses: Expense service (CRUD), expenses list screen, add/edit expense screen, category selection, trip detail integration |
| 2026-03-23 | 1 | Expense Enhancements: Link expense to itinerary item (auto-sets date), live currency conversion using ExchangeRate API with fallback, convert totals to trip currency, show converted amounts on individual expenses |
| 2026-03-26 | 1 | Expense Splitting: ExpenseSplitService (CRUD), split UI in add/edit expense, equal/percentage/custom splits, balance summary with currency conversion, "who owes whom" screen, settlement suggestions algorithm, mark split as settled |
| 2026-04-05 | 1 | Receipt Scanning: Google ML Kit OCR + OpenAI Vision hybrid, camera/gallery picker, ScanReceiptScreen UI, auto-extract merchant/amount/date/category, pre-fill expense form, Supabase Edge Function for AI parsing |
| 2026-04-06 | 1 | Text Quick Add: Natural language expense input, AI parsing via Supabase Edge Function (Claude), QuickAddExpenseScreen UI, pre-fill and one-tap confirm, integrated with expenses screen. Voice input attempted but deferred due to iOS 26 compatibility issues with speech_to_text package |
| 2026-04-07 | 1 | Expense Split in Quick Add: Added expense split selector to QuickAddExpenseScreen and ScanReceiptScreen for seamless split configuration before saving |
| 2026-04-07 | 1 | AI Quick Add for Itinerary: Natural language activity input, AI parsing via Supabase Edge Function (Claude), QuickAddItineraryScreen UI, extract title/time/location/category/cost, one-tap confirm |
| 2026-04-10 | 1 | Voice Input: Speech-to-text using liquid_speech (iOS 26+ SpeechAnalyzer) with speech_to_text fallback for Android/older iOS, full-screen recording overlay, real-time transcript, integrated into Quick Add screens |
| 2026-04-16 | 1 | Explore & Discover: DestinationService (search, filter, CRUD), ExploreScreen with real data, DestinationDetailScreen, DestinationsListScreen with category/location filters, TripDestinationService for adding destinations to trips, AddToTripSheet UI, seed data for 28 Philippine destinations |
| 2026-04-16 | 3 | AI Trip Planning: TripPreferences model (dates, travelers, budget, travel styles, pace, interests, accommodation, special requests), PlanTripScreen multi-step wizard, generate-itinerary Edge Function (Claude), TripPlanningService for orchestrating AI generation + trip creation, integrated into DestinationDetailScreen with "Plan a Trip" flow |
| 2026-04-16 | 3 | Transport Mode: Added transport mode selection (car/public/plane/mixed) with flight booking details and hotel reservation info to trip preferences, updated AI prompt to generate transport-specific itineraries |
| 2026-04-16 | 3 | Draft Itinerary Review: ReviewItineraryScreen with accept/edit/skip flow for each AI-generated activity, DraftItinerary model and DraftItineraryService, draft_itineraries database table with auto-save and persistence, resume drafts from Trips screen |
| 2026-04-27 | 1 | Maps & Location: `google_maps_flutter` + `LakwaMapView`, trip map (pins + my location) from trip detail, `SingleLocationMapScreen` for destination detail and itinerary edit, Android `local.properties` / iOS `Info.plist` API keys, location permissions |
| 2026-04-27 | 2 | Email Forwarding (Receipts): per-trip forwarding alias RPC + regenerate, inbound `process-forwarded-email` Edge Function webhook, sender/date validation, AI parsing reuse (`parse-expense-text`), auto-create expenses, Expenses screen email forwarding UI with copy/regenerate |
| 2026-05-18 | 3 | Bookings / Reservations: `trip_bookings` table + RLS, Booking model/service, Bookings list/detail/add-edit screens, itinerary link, trip detail section, `parse-booking-email` Edge Function, email import via `process-forwarded-email` booking path |
| 2026-05-18 | 3 | Packing Lists: `trip_packing_items` table + RLS/realtime, PackingItem model, PackingListService, PackingListScreen (check off, add/remove, swipe delete), AI `generate-packing-suggestions` Edge Function, trip detail section, seed from AI trip planning |
| 2026-05-18 | 3 | Personal packing + assignments: `assigned_to_user_id` / `assigned_by_user_id` (migration 019), per-user "My list" + "I assigned" tabs, assignee picker, RLS scoped to assignee or creator |
| 2026-05-18 | 3 | Packing edit/delete: edit sheet (name, category, assignee), popup menu + swipe delete, delete from edit sheet |
| 2026-05-18 | 3 | In-app notifications: `user_notifications` table, trigger on packing assignment, NotificationsScreen, realtime snackbar, unread badge on Profile |
| 2026-06-02 | 3 | Weather-aware packing: `generate-packing-suggestions` now reasons about each destination's typical seasonal climate for the travel month(s) — season-aware via Claude, no external weather API. PackingListService sends structured destination context (city/province/country/lat-long) + derived travel months; PackingListScreen passes full destinations |

---

*Last updated: June 2, 2026*
