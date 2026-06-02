# Lakwatsapp — Data Models

> This document describes the Dart data models used in the Flutter app. All models are located in `lakwatsapp/lib/models/`.

---

## Overview

| Model | File | Description |
|-------|------|-------------|
| `UserProfile` | `user_profile.dart` | Extended user profile data |
| `Trip` | `trip.dart` | Trip/vacation records |
| `TripMember` | `trip_member.dart` | Group trip membership |
| `Destination` | `destination.dart` | Places/locations catalog |
| `TripDestination` | `trip_destination.dart` | Links trips to destinations |
| `ItineraryItem` | `itinerary_item.dart` | Daily activity planning |
| `Expense` | `expense.dart` | Expense tracking |
| `ExpenseSplit` | `expense_split.dart` | Expense splitting among members |
| `Post` | `post.dart` | Social feed posts |
| `Friendship` | `friendship.dart` | Friend relationships between users |
| `ActivityLog` | `activity_log.dart` | Activity tracking/audit log |
| `ParsedReceipt` | `parsed_receipt.dart` | AI-parsed receipt data |
| `ParsedExpense` | `parsed_expense.dart` | AI-parsed expense from text |
| `ParsedItinerary` | `parsed_itinerary.dart` | AI-parsed itinerary activity from text |
| `TripPreferences` | `trip_preferences.dart` | User preferences for AI trip generation |
| `DraftItinerary` | `draft_itinerary.dart` | AI-generated draft itinerary awaiting review |
| `Booking` | `booking.dart` | Trip bookings/reservations (flights, hotels, etc.) |
| `PackingItem` | `packing_item.dart` | Personal packing list item (per assignee) |
| `UserNotification` | `user_notification.dart` | In-app notification inbox row |

Import all models via:
```dart
import 'package:larga/models/models.dart';
```

---

## UserProfile

Extends Supabase `auth.users` with app-specific profile data. Auto-created on signup via database trigger.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` (UUID) | ✓ | Primary key |
| `authId` | `String` (UUID) | ✓ | References `auth.users.id` |
| `displayName` | `String?` | | User's display name |
| `avatarUrl` | `String?` | | Profile photo URL |
| `bio` | `String?` | | Short bio/description |
| `homeCity` | `String?` | | User's home city |
| `homeCountry` | `String?` | | User's home country |
| `createdAt` | `DateTime` | ✓ | Record creation timestamp |
| `updatedAt` | `DateTime` | ✓ | Last update timestamp |

---

## Trip

Core entity for trip planning. Owned by a user, can have multiple members for group trips.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `ownerId` | `String` (UUID) | ✓ | | Trip creator/owner |
| `title` | `String` | ✓ | | Trip name |
| `description` | `String?` | | | Trip description |
| `startDate` | `DateTime?` | | | Trip start date |
| `endDate` | `DateTime?` | | | Trip end date |
| `status` | `TripStatus` | | `planning` | Current status |
| `coverImageUrl` | `String?` | | | Cover photo URL |
| `budget` | `double?` | | | Total budget |
| `currency` | `String` | | `'PHP'` | Budget currency |
| `isPublic` | `bool` | | `false` | Public visibility |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |
| `updatedAt` | `DateTime` | ✓ | | Last update timestamp |

### TripStatus Enum

```dart
enum TripStatus {
  planning,   // Trip is being planned
  ongoing,    // Trip is currently happening
  completed   // Trip has ended
}
```

### Helper Methods

- `tripDurationDays` — Returns number of days (null if dates not set)

---

## TripMember

Junction table for group trips. Links users to trips with ownership tracking.

> **Note:** All members can edit the trip (itinerary, expenses, details). Only the owner has special privileges like deleting the trip or transferring ownership.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `tripId` | `String` (UUID) | ✓ | | References trip |
| `userId` | `String` (UUID) | ✓ | | References user |
| `role` | `MemberRole` | | `viewer` | Membership type |
| `joinedAt` | `DateTime` | ✓ | | When user joined |

### MemberRole Enum

```dart
enum MemberRole {
  owner,    // Trip creator (can delete trip, transfer ownership)
  editor,   // Legacy role (same edit permissions as all members)
  viewer    // Legacy role (same edit permissions as all members)
}
```

### Helper Methods

- `canEdit` — Returns `true` for all members (everyone can edit)
- `isOwner` — Returns `true` if role is owner (for ownership-specific actions)

---

## Destination

Places/locations catalog. Shared across trips (not duplicated per trip).

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `name` | `String` | ✓ | | Destination name |
| `description` | `String?` | | | Description/overview |
| `latitude` | `double?` | | | GPS latitude |
| `longitude` | `double?` | | | GPS longitude |
| `address` | `String?` | | | Street address |
| `city` | `String?` | | | City name |
| `province` | `String?` | | | Province/state |
| `country` | `String` | | `'Philippines'` | Country |
| `category` | `DestinationCategory` | | `other` | Type of place |
| `photos` | `List<String>` | | `[]` | Photo URLs |
| `tips` | `String?` | | | Travel tips |
| `averageRating` | `double?` | | | Avg user rating |
| `reviewCount` | `int` | | `0` | Number of reviews |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |
| `updatedAt` | `DateTime` | ✓ | | Last update timestamp |

### DestinationCategory Enum

```dart
enum DestinationCategory {
  city,          // City
  beach,         // Beach
  mountain,      // Mountain
  island,        // Island
  historicSite,  // Historic Site
  naturalWonder, // Natural Wonder
  park,          // Park
  resort,        // Resort
  other          // Other
}
```

### Helper Methods

- `fullLocation` — Returns formatted "City, Province, Country"
- `hasCoordinates` — Returns `true` if lat/lng are set
- `displayName` (on enum) — Human-readable category name

---

## TripDestination

Links destinations to trips with trip-specific details (which day, notes, etc.).

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `tripId` | `String` (UUID) | ✓ | | References trip |
| `destinationId` | `String` (UUID) | ✓ | | References destination |
| `dayNumber` | `int?` | | | Which day of the trip |
| `sortOrder` | `int` | | `0` | Display order |
| `notes` | `String?` | | | Trip-specific notes |
| `plannedDate` | `DateTime?` | | | Specific planned date |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |

---

## ItineraryItem

Daily activity/event within a trip itinerary.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `tripId` | `String` (UUID) | ✓ | | References trip |
| `dayNumber` | `int` | ✓ | | Which day (1, 2, 3...) |
| `sortOrder` | `int` | | `0` | Order within day |
| `title` | `String` | ✓ | | Activity name |
| `description` | `String?` | | | Details |
| `startTime` | `String?` | | | Start time (HH:mm) |
| `endTime` | `String?` | | | End time (HH:mm) |
| `location` | `String?` | | | Location name |
| `latitude` | `double?` | | | GPS latitude |
| `longitude` | `double?` | | | GPS longitude |
| `category` | `ItineraryCategory` | | `other` | Activity type |
| `estimatedCost` | `double?` | | | Estimated cost |
| `currency` | `String?` | | | Cost currency |
| `notes` | `String?` | | | Additional notes |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |
| `updatedAt` | `DateTime` | ✓ | | Last update timestamp |

### ItineraryCategory Enum

```dart
enum ItineraryCategory {
  transport,      // 🚗 Transport
  accommodation,  // 🏨 Accommodation
  food,           // 🍽️ Food & Dining
  activity,       // 🎯 Activity
  sightseeing,    // 📸 Sightseeing
  shopping,       // 🛍️ Shopping
  rest,           // 😴 Rest
  other           // 📌 Other
}
```

### Helper Methods

- `hasTime` — Returns `true` if startTime is set
- `hasLocation` — Returns `true` if lat/lng are set
- `icon` (on enum) — Returns emoji for category
- `displayName` (on enum) — Human-readable name

---

## Expense

Tracks spending during a trip. Supports group expense splitting.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `tripId` | `String` (UUID) | ✓ | | References trip |
| `paidByUserId` | `String` (UUID) | ✓ | | Who paid |
| `amount` | `double` | ✓ | | Total amount |
| `currency` | `String` | | `'PHP'` | Currency code |
| `category` | `ExpenseCategory` | | `other` | Expense type |
| `description` | `String` | ✓ | | What was purchased |
| `expenseDate` | `DateTime` | ✓ | | Date of expense |
| `receiptUrl` | `String?` | | | Receipt photo URL |
| `notes` | `String?` | | | Additional notes |
| `itineraryItemId` | `String?` (UUID) | | | Linked itinerary item |
| `isSettled` | `bool` | | `false` | All splits settled? |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |
| `updatedAt` | `DateTime` | ✓ | | Last update timestamp |

### ExpenseCategory Enum

```dart
enum ExpenseCategory {
  transport,      // 🚗 Transport
  accommodation,  // 🏨 Accommodation
  food,           // 🍽️ Food & Drinks
  activities,     // 🎯 Activities
  shopping,       // 🛍️ Shopping
  fees,           // 🎟️ Fees & Tickets
  tips,           // 💵 Tips
  other           // 📝 Other
}
```

### Helper Methods

- `formattedAmount` — Returns "PHP 1,234.56" format
- `icon` (on enum) — Returns emoji for category
- `displayName` (on enum) — Human-readable name

---

## ExpenseSplit

How an expense is divided among trip members.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `expenseId` | `String` (UUID) | ✓ | | References expense |
| `userId` | `String` (UUID) | ✓ | | Who owes |
| `amount` | `double` | ✓ | | Amount owed |
| `percentage` | `double?` | | | Percentage (if split by %) |
| `splitType` | `SplitType` | | `equal` | How it was split |
| `isSettled` | `bool` | | `false` | Has this been paid? |
| `settledAt` | `DateTime?` | | | When it was settled |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |

### SplitType Enum

```dart
enum SplitType {
  equal,       // Split equally among members
  percentage,  // Split by percentage
  exact        // Exact amounts specified
}
```

---

## Post

Social feed posts for sharing travel experiences (Phase 2 feature, model defined for schema completeness).

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `userId` | `String` (UUID) | ✓ | | Post author |
| `tripId` | `String?` (UUID) | | | Related trip (optional) |
| `destinationId` | `String?` (UUID) | | | Related destination (optional) |
| `content` | `String?` | | | Post text/caption |
| `photos` | `List<String>` | | `[]` | Photo URLs |
| `likesCount` | `int` | | `0` | Number of likes |
| `commentsCount` | `int` | | `0` | Number of comments |
| `isPublic` | `bool` | | `true` | Public visibility |
| `createdAt` | `DateTime` | ✓ | | Record creation timestamp |
| `updatedAt` | `DateTime` | ✓ | | Last update timestamp |

### Helper Methods

- `hasPhotos` — Returns `true` if photos array is not empty
- `hasContent` — Returns `true` if content is not null/empty

---

## Friendship

Represents a friend relationship between two users. Friendships are mutual and require acceptance.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `requesterId` | `String` (UUID) | ✓ | | User who sent the request |
| `addresseeId` | `String` (UUID) | ✓ | | User who received the request |
| `status` | `FriendshipStatus` | | `pending` | Current status |
| `createdAt` | `DateTime` | ✓ | | Request timestamp |
| `respondedAt` | `DateTime?` | | | When request was responded to |

### FriendshipStatus Enum

```dart
enum FriendshipStatus {
  pending,   // Awaiting response
  accepted,  // Friends
  rejected,  // Request declined
  blocked    // User blocked
}
```

### Helper Methods

- `isPending` — Returns `true` if status is pending
- `isAccepted` — Returns `true` if status is accepted (friends)
- `isRejected` — Returns `true` if status is rejected
- `isBlocked` — Returns `true` if status is blocked
- `isRequester(userId)` — Returns `true` if userId is the requester
- `isAddressee(userId)` — Returns `true` if userId is the addressee
- `getOtherUserId(currentUserId)` — Returns the other user's ID in the friendship

---

## ActivityLog

Tracks user activities across the application for audit trail and collaboration visibility.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` (UUID) | ✓ | | Primary key |
| `entityType` | `ActivityEntityType` | ✓ | | Type of entity being tracked |
| `entityId` | `String` (UUID) | ✓ | | ID of the entity |
| `tripId` | `String` (UUID) | | | Associated trip (for filtering) |
| `userId` | `String` (UUID) | ✓ | | Who performed the action |
| `action` | `ActivityAction` | ✓ | | What action was performed |
| `details` | `Map<String, dynamic>` | | `{}` | Additional metadata (JSONB) |
| `createdAt` | `DateTime` | ✓ | | When the action occurred |

### ActivityEntityType Enum

```dart
enum ActivityEntityType {
  trip,            // Trip-level changes
  itineraryItem,   // Itinerary activities
  expense,         // Expense tracking
  tripMember,      // Member changes
  tripDestination, // Destination changes
  other            // Other/generic
}
```

### ActivityAction Enum

```dart
enum ActivityAction {
  created,    // Item was created
  updated,    // Item was modified
  deleted,    // Item was removed
  joined,     // User joined trip
  left,       // User left trip
  invited,    // User invited someone
  removed,    // User removed someone
  reordered,  // Items were reordered
  other       // Other action
}
```

### Helper Methods

- `itemTitle` — Get title from details (for display)
- `itemName` — Get name from details
- `targetUserName` — Get target user name (for invite/remove actions)
- `changedFields` — Get list of changed field names
- `getDescription(actorName)` — Generate human-readable description

### Usage

Activity logs are automatically created by services when:
- Trips are created or updated
- Itinerary items are added, edited, deleted, or reordered
- Members join, leave, are invited, or removed

---

## ParsedReceipt

Result from AI-powered receipt scanning (Claude Vision API). Used to pre-fill expense forms.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `merchant` | `String?` | | Detected merchant/store name |
| `amount` | `double?` | | Total amount |
| `currency` | `String?` | | Detected currency code |
| `date` | `DateTime?` | | Receipt date |
| `suggestedCategory` | `ExpenseCategory?` | | AI-suggested category |
| `lineItems` | `List<ReceiptLineItem>?` | | Individual items on receipt |
| `receiptUrl` | `String?` | | Uploaded receipt image URL |
| `confidence` | `double` | ✓ | AI confidence score (0.0-1.0) |
| `rawText` | `String?` | | Raw OCR text |

### Helper Methods

- `hasValidAmount` — Returns `true` if amount is not null
- `hasValidMerchant` — Returns `true` if merchant is not null/empty
- `hasValidDate` — Returns `true` if date is not null
- `displayAmount` — Returns formatted amount with currency symbol

---

## ParsedExpense

Result from AI-powered text parsing for quick expense entry (Claude API).

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | `String?` | | Expense description/what was purchased |
| `amount` | `double?` | | Expense amount |
| `currency` | `String?` | | Currency code |
| `suggestedCategory` | `ExpenseCategory?` | | AI-suggested category |
| `date` | `DateTime?` | | Expense date (if mentioned) |
| `splitWith` | `List<String>?` | | Names of people to split with |
| `notes` | `String?` | | Additional notes |
| `confidence` | `double` | ✓ | AI confidence score (0.0-1.0) |
| `rawText` | `String` | ✓ | Original input text |

### Helper Methods

- `hasValidAmount` — Returns `true` if amount is not null and > 0
- `hasValidDescription` — Returns `true` if description is not null/empty
- `hasSplitInfo` — Returns `true` if splitWith is not null/empty
- `displayAmount` — Returns formatted amount with currency symbol

---

## ParsedItinerary

Result from AI-powered text parsing for quick itinerary entry (Claude API).

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | `String?` | | Activity title |
| `description` | `String?` | | Activity description |
| `startTime` | `String?` | | Start time (HH:MM format) |
| `endTime` | `String?` | | End time (HH:MM format) |
| `location` | `String?` | | Location/place name |
| `suggestedCategory` | `ItineraryCategory?` | | AI-suggested category |
| `estimatedCost` | `double?` | | Estimated cost |
| `currency` | `String?` | | Currency code |
| `notes` | `String?` | | Additional notes |
| `confidence` | `double` | ✓ | AI confidence score (0.0-1.0) |
| `rawText` | `String` | ✓ | Original input text |

### Helper Methods

- `hasValidTitle` — Returns `true` if title is not null/empty
- `hasValidTime` — Returns `true` if startTime is not null/empty
- `hasValidLocation` — Returns `true` if location is not null/empty
- `hasValidCost` — Returns `true` if estimatedCost is not null and > 0
- `displayCost` — Returns formatted cost with currency symbol

---

## TripPreferences

User preferences for AI-powered trip itinerary generation. Used by the `generate-itinerary` Edge Function.

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `startDate` | `DateTime` | ✓ | | Trip start date |
| `endDate` | `DateTime` | ✓ | | Trip end date |
| `adults` | `int` | | `1` | Number of adult travelers |
| `children` | `int` | | `0` | Number of children |
| `infants` | `int` | | `0` | Number of infants |
| `budgetLevel` | `BudgetLevel` | | `moderate` | Budget tier |
| `specificBudget` | `double?` | | | Specific budget amount |
| `currency` | `String` | | `'PHP'` | Budget currency |
| `travelStyles` | `List<TravelStyle>` | | `[]` | Preferred travel styles |
| `pace` | `TravelPace` | | `moderate` | Travel pace |
| `interests` | `List<TravelInterest>` | | `[]` | Activity interests |
| `accommodation` | `AccommodationType?` | | | Preferred accommodation |
| `specialRequests` | `String?` | | | Custom requests |
| `transportMode` | `TransportMode` | | `publicTransport` | How traveling to destination |
| `flightBooking` | `FlightBooking?` | | | Outbound flight details |
| `returnFlightBooking` | `FlightBooking?` | | | Return flight details |
| `hasHotelBooking` | `bool` | | `false` | Has hotel reserved? |
| `hotelBooking` | `HotelBooking?` | | | Hotel booking details |

### Related Enums

```dart
enum TravelStyle { adventure, relaxation, cultural, foodie, nature, photography, familyFriendly, romantic }
enum TravelPace { relaxed, moderate, packed }
enum BudgetLevel { budget, moderate, luxury }
enum TravelInterest { beach, hiking, divingSnorkeling, historicSites, localFood, nightlife, shopping, wildlife, waterfalls, islands, sunsetViews, photography, wellness, watersports }
enum AccommodationType { hostel, hotel, resort, airbnb, glamping }
enum TransportMode { car, publicTransport, plane, mixed }
```

### FlightBooking

| Field | Type | Description |
|-------|------|-------------|
| `airline` | `String?` | Airline name |
| `flightNumber` | `String?` | Flight number |
| `departureTime` | `String?` | Departure time |
| `arrivalTime` | `String?` | Arrival time |
| `departureAirport` | `String?` | Departure airport |
| `arrivalAirport` | `String?` | Arrival airport |

### HotelBooking

| Field | Type | Description |
|-------|------|-------------|
| `hotelName` | `String?` | Hotel name |
| `address` | `String?` | Hotel address |
| `checkInTime` | `String?` | Check-in time |
| `checkOutTime` | `String?` | Check-out time |

### Helper Methods

- `totalTravelers` — Sum of adults + children + infants
- `tripDays` — Number of days in the trip

---

## DraftItinerary

AI-generated draft itinerary awaiting user review. Persisted to database for resumable review flow.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` (UUID) | ✓ | Primary key |
| `visitorId` | `String` (UUID) | ✓ | User who created the draft |
| `destinationId` | `String` (UUID) | ✓ | Target destination |
| `preferences` | `TripPreferences` | ✓ | User's trip preferences |
| `generatedItinerary` | `GeneratedItinerary` | ✓ | AI-generated itinerary |
| `reviewState` | `Map<String, Map<int, ActivityReviewStatus>>` | ✓ | Review status per activity |
| `editedActivities` | `Map<String, GeneratedActivity>` | ✓ | User-modified activities |
| `createdAt` | `DateTime` | ✓ | Draft creation time |
| `updatedAt` | `DateTime` | ✓ | Last update time |
| `expiresAt` | `DateTime` | ✓ | Auto-expiry (30 days) |
| `destination` | `Destination?` | | Joined destination data |

### ActivityReviewStatus Enum

```dart
enum ActivityReviewStatus {
  pending,   // Not yet reviewed
  accepted,  // Will be included in trip
  skipped,   // Will not be included
  edited     // Modified and accepted
}
```

### Helper Methods

- `totalActivities` — Total number of activities across all days
- `reviewedActivities` — Number of activities reviewed (not pending)
- `acceptedActivities` — Number of accepted/edited activities
- `reviewProgress` — Progress percentage (0.0 to 1.0)
- `isFullyReviewed` — True if all activities have been reviewed

---

## Booking

Trip reservation (flight, hotel, activity, transport). Stored in `trip_bookings`.

### Related Enums

- `BookingType` — `flight`, `hotel`, `activity`, `transport`, `other`
- `BookingSource` — `manual`, `email`

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `tripId` | `String` | Parent trip |
| `title` | `String` | Display name |
| `confirmationNumber` | `String?` | Booking reference |
| `itineraryItemId` | `String?` | Linked itinerary activity |
| `details` | `Map<String, dynamic>` | Type-specific JSON (airline, airports, etc.) |

**Service:** `BookingService` — CRUD, realtime, activity log

---

## PackingItem

Checklist row on a trip, assigned to one trip member. Users see items where they are the assignee ("My list") or that they created for others ("I assigned").

### Related Enums

- `PackingCategory` — `clothing`, `toiletries`, `electronics`, `documents`, `health`, `gear`, `other`
- `PackingItemSource` — `manual`, `ai`

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `assignedToUserId` | `String` | Member who should pack this |
| `assignedByUserId` | `String?` | Who assigned it |
| `createdByUserId` | `String` | Who created the row |
| `isChecked` | `bool` | Packed state (toggle by assignee only) |
| `sortOrder` | `int` | Order within assignee's list |

**Service:** `PackingListService` — CRUD, bulk AI insert, `generateSuggestions()`, `reassignItem()`, realtime

**Screens:** `PackingListScreen` (tabs, add/edit sheet, popup menu delete), trip detail packing summary (assignee progress only)

---

## UserNotification

In-app notification for the current user (e.g. packing item assigned).

### Related Enums

- `UserNotificationType` — `packingAssigned`, `other`

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `type` | `UserNotificationType` | Notification category |
| `tripId` | `String?` | Related trip |
| `data` | `Map<String, dynamic>` | e.g. `packing_item_id` |
| `readAt` | `DateTime?` | Null if unread |

**Service:** `NotificationService` — list, unread count, mark read, realtime subscribe

**UI:** `NotificationsScreen`, `NotificationListenerScope` (snackbar on insert), Profile unread badge

---

## Services

### RealtimeService

Centralized service for managing Supabase Realtime WebSocket subscriptions. Singleton pattern ensures consistent subscription management across the app.

**Location:** `lakwatsapp/lib/services/realtime_service.dart`

#### Key Types

```dart
enum RealtimeEvent { insert, update, delete }

class RealtimePayload<T> {
  final RealtimeEvent event;
  final T? newRecord;
  final T? oldRecord;
}
```

#### Subscription Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `subscribeToTrips()` | Subscribe to all trips changes | `Stream<RealtimePayload>` |
| `subscribeToTrip(tripId)` | Subscribe to specific trip | `Stream<RealtimePayload>` |
| `subscribeToTripMembers(tripId)` | Subscribe to trip member changes | `Stream<RealtimePayload>` |
| `subscribeToExpenses(tripId)` | Subscribe to expense changes | `Stream<RealtimePayload>` |
| `subscribeToItineraryItems(tripId)` | Subscribe to itinerary changes | `Stream<RealtimePayload>` |
| `subscribeToActivityLogs(tripId)` | Subscribe to activity log changes | `Stream<RealtimePayload>` |
| `subscribeToDraftItineraries()` | Subscribe to draft changes | `Stream<RealtimePayload>` |
| `subscribeToBookings(tripId)` | Subscribe to booking changes | `Stream<RealtimePayload>` |
| `subscribeToPackingItems(tripId)` | Subscribe to packing list changes | `Stream<RealtimePayload>` |
| `subscribeToUserNotifications(userId)` | Subscribe to user's notifications | `Stream<RealtimePayload>` |

#### Unsubscribe Methods

| Method | Description |
|--------|-------------|
| `unsubscribeFromTrips()` | Unsubscribe from all trips |
| `unsubscribeFromTrip(tripId)` | Unsubscribe from specific trip |
| `unsubscribeFromTripMembers(tripId)` | Unsubscribe from trip members |
| `unsubscribeFromExpenses(tripId)` | Unsubscribe from expenses |
| `unsubscribeFromItineraryItems(tripId)` | Unsubscribe from itinerary |
| `unsubscribeFromActivityLogs(tripId)` | Unsubscribe from activity logs |
| `unsubscribeFromDraftItineraries()` | Unsubscribe from drafts |
| `unsubscribeFromBookings(tripId)` | Unsubscribe from bookings |
| `unsubscribeFromPackingItems(tripId)` | Unsubscribe from packing items |
| `unsubscribeFromUserNotifications(userId)` | Unsubscribe from notifications |
| `unsubscribeAll()` | Unsubscribe from all channels |

#### Usage Pattern

Services wrap RealtimeService and return `StreamSubscription` for proper cleanup:

```dart
// In service (e.g., TripService)
StreamSubscription<void>? subscribeToTripsChanges({
  required void Function() onUpdate,
}) {
  return _realtimeService.subscribeToTrips().listen((payload) {
    onUpdate();
  });
}

// In widget
StreamSubscription<void>? _subscription;

@override
void initState() {
  super.initState();
  _subscription = _tripService.subscribeToTripsChanges(
    onUpdate: () => _loadData(),
  );
}

@override
void dispose() {
  _subscription?.cancel();
  _tripService.unsubscribeFromTrips();
  super.dispose();
}
```

---

## Common Patterns

### JSON Serialization

All models include:

```dart
// Parse from Supabase response
factory Model.fromJson(Map<String, dynamic> json);

// Full JSON (for reading/debugging)
Map<String, dynamic> toJson();

// Insert JSON (excludes id, created_at, updated_at)
Map<String, dynamic> toInsertJson();
```

### Immutable Updates

All models include `copyWith()` for creating modified copies:

```dart
final updatedTrip = trip.copyWith(
  status: TripStatus.ongoing,
  startDate: DateTime.now(),
);
```

### Enum Parsing

Enums include a safe `fromString()` factory with fallback:

```dart
TripStatus.fromString('ongoing');  // TripStatus.ongoing
TripStatus.fromString('invalid');  // TripStatus.planning (fallback)
```

---

*Last updated: May 18, 2026*
