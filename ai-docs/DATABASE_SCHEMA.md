# Lakwatsapp — Database Schema

> This document describes the Supabase/PostgreSQL database schema. Migration files are in `supabase/migrations/`.

---

## Quick Start

Run these SQL files in order in your **Supabase SQL Editor**:

1. `001_initial_schema.sql` — Tables, indexes, triggers
2. `002_rls_policies.sql` — Row Level Security policies
3. `003_storage_buckets.sql` — Storage buckets for images
4. `004_create_profile_trigger.sql` — Auto-create profile on signup
5. `005_user_search_functions.sql` — User search functionality
6. `006_friendships.sql` — Friends system
7. `007_all_members_can_edit.sql` — Collaborative editing permissions
8. `008_activity_logs.sql` — Activity tracking/audit log
9. `009_expenses_member_update.sql` — Allow trip members to update expenses
10. `010_expense_itinerary_link.sql` — Link expenses to itinerary items
11. `011_expense_splits_member_access.sql` — Allow trip members to manage expense splits
12. `012_receipts_storage.sql` — Receipts storage bucket
13. `013_expense_line_items.sql` — Expense line items
14. `014_draft_itineraries.sql` — AI-generated draft itineraries
15. `015_enable_realtime.sql` — Realtime publication for core tables
16. `016_email_forwarding.sql` — Per-trip email aliases + forwarded receipt emails
17. `017_trip_bookings.sql` — Trip bookings/reservations + forwarded booking emails
18. `018_trip_packing_items.sql` — Trip packing list items
19. `019_packing_assignments_notifications.sql` — Packing assignee columns + `user_notifications`

---

## Entity Relationship Diagram

```
┌─────────────────┐
│   auth.users    │ (Supabase built-in)
└────────┬────────┘
         │ 1:1
         ▼
┌─────────────────┐
│  user_profiles  │
└─────────────────┘
         │
         │ 1:many
         ▼
┌─────────────────┐       ┌─────────────────┐
│      trips      │◄──────│  trip_members   │ (many:many junction)
└────────┬────────┘       └─────────────────┘
         │
         ├──────────┬───────────┬───────────┬──────────────┐
         │          │           │           │              │
         ▼          ▼           ▼           ▼              ▼
┌──────────────┐ ┌───────────┐ ┌─────────┐ ┌────────────┐ ┌──────────────────┐
│trip_destinat.│ │itinerary_ │ │expenses │ │trip_bookings│ │trip_packing_items│
└──────┬───────┘ │  items    │ └────┬────┘ └────────────┘ └──────────────────┘
       │         └───────────┘      │
       ▼                            ▼
┌──────────────┐              ┌──────────────┐
│ destinations │              │expense_splits│
└──────────────┘              └──────────────┘

┌─────────────────┐       ┌─────────────────────┐
│      posts      │       │ user_notifications  │ → auth.users
└─────────────────┘       └─────────────────────┘
```

---

## Tables

### user_profiles

Extends `auth.users` with app-specific profile data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK, DEFAULT uuid_generate_v4() | Primary key |
| `auth_id` | `UUID` | UNIQUE, NOT NULL, FK → auth.users | Supabase auth user |
| `display_name` | `TEXT` | | User's display name |
| `avatar_url` | `TEXT` | | Profile photo URL |
| `bio` | `TEXT` | | Short bio |
| `home_city` | `TEXT` | | Home city |
| `home_country` | `TEXT` | | Home country |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Updated timestamp |

**Indexes:** `idx_user_profiles_auth_id`

**Trigger:** Auto-created on user signup via `handle_new_user()` function.

---

### trips

Main trip/vacation records.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `owner_id` | `UUID` | NOT NULL, FK → auth.users | Trip owner |
| `title` | `TEXT` | NOT NULL | Trip name |
| `description` | `TEXT` | | Trip description |
| `start_date` | `DATE` | | Start date |
| `end_date` | `DATE` | | End date |
| `status` | `TEXT` | CHECK IN ('planning', 'ongoing', 'completed'), DEFAULT 'planning' | Trip status |
| `cover_image_url` | `TEXT` | | Cover photo |
| `budget` | `DECIMAL(12,2)` | | Total budget |
| `currency` | `TEXT` | DEFAULT 'PHP' | Currency code |
| `is_public` | `BOOLEAN` | DEFAULT FALSE | Public visibility |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Updated timestamp |

**Indexes:** `idx_trips_owner_id`, `idx_trips_status`, `idx_trips_start_date`

---

### trip_members

Group trip membership (many-to-many between users and trips).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `trip_id` | `UUID` | NOT NULL, FK → trips | Trip reference |
| `user_id` | `UUID` | NOT NULL, FK → auth.users | User reference |
| `role` | `TEXT` | CHECK IN ('owner', 'editor', 'viewer'), DEFAULT 'viewer' | Permission level |
| `joined_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Join timestamp |

**Unique constraint:** `(trip_id, user_id)`

**Indexes:** `idx_trip_members_trip_id`, `idx_trip_members_user_id`

---

### destinations

Places/locations catalog (shared, not per-trip).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `name` | `TEXT` | NOT NULL | Place name |
| `description` | `TEXT` | | Description |
| `latitude` | `DECIMAL(10,8)` | | GPS latitude |
| `longitude` | `DECIMAL(11,8)` | | GPS longitude |
| `address` | `TEXT` | | Street address |
| `city` | `TEXT` | | City |
| `province` | `TEXT` | | Province/state |
| `country` | `TEXT` | DEFAULT 'Philippines' | Country |
| `category` | `TEXT` | CHECK IN (...), DEFAULT 'other' | Destination type |
| `photos` | `TEXT[]` | DEFAULT '{}' | Photo URLs array |
| `tips` | `TEXT` | | Travel tips |
| `average_rating` | `DECIMAL(2,1)` | | Average rating (0.0-5.0) |
| `review_count` | `INTEGER` | DEFAULT 0 | Number of reviews |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Updated timestamp |

**Category values:** `city`, `beach`, `mountain`, `island`, `historicSite`, `naturalWonder`, `park`, `resort`, `other`

**Indexes:** `idx_destinations_category`, `idx_destinations_city`, `idx_destinations_country`

---

### trip_destinations

Links trips to destinations with trip-specific details.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `trip_id` | `UUID` | NOT NULL, FK → trips | Trip reference |
| `destination_id` | `UUID` | NOT NULL, FK → destinations | Destination reference |
| `day_number` | `INTEGER` | | Which day of trip |
| `sort_order` | `INTEGER` | DEFAULT 0 | Display order |
| `notes` | `TEXT` | | Trip-specific notes |
| `planned_date` | `DATE` | | Specific planned date |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |

**Unique constraint:** `(trip_id, destination_id)`

**Indexes:** `idx_trip_destinations_trip_id`, `idx_trip_destinations_destination_id`

---

### itinerary_items

Daily activities within a trip.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `trip_id` | `UUID` | NOT NULL, FK → trips | Trip reference |
| `day_number` | `INTEGER` | NOT NULL | Day number (1, 2, 3...) |
| `sort_order` | `INTEGER` | DEFAULT 0 | Order within day |
| `title` | `TEXT` | NOT NULL | Activity name |
| `description` | `TEXT` | | Details |
| `start_time` | `TIME` | | Start time |
| `end_time` | `TIME` | | End time |
| `location` | `TEXT` | | Location name |
| `latitude` | `DECIMAL(10,8)` | | GPS latitude |
| `longitude` | `DECIMAL(11,8)` | | GPS longitude |
| `category` | `TEXT` | CHECK IN (...), DEFAULT 'other' | Activity type |
| `estimated_cost` | `DECIMAL(12,2)` | | Estimated cost |
| `currency` | `TEXT` | DEFAULT 'PHP' | Currency |
| `notes` | `TEXT` | | Additional notes |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Updated timestamp |

**Category values:** `transport`, `accommodation`, `food`, `activity`, `sightseeing`, `shopping`, `rest`, `other`

**Indexes:** `idx_itinerary_items_trip_id`, `idx_itinerary_items_day_number`

---

### expenses

Expense tracking for trips.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `trip_id` | `UUID` | NOT NULL, FK → trips | Trip reference |
| `paid_by_user_id` | `UUID` | NOT NULL, FK → auth.users | Who paid |
| `amount` | `DECIMAL(12,2)` | NOT NULL | Total amount |
| `currency` | `TEXT` | DEFAULT 'PHP' | Currency code |
| `category` | `TEXT` | CHECK IN (...), DEFAULT 'other' | Expense type |
| `description` | `TEXT` | NOT NULL | What was purchased |
| `expense_date` | `DATE` | NOT NULL | Date of expense |
| `receipt_url` | `TEXT` | | Receipt photo URL |
| `notes` | `TEXT` | | Additional notes |
| `itinerary_item_id` | `UUID` | FK → itinerary_items (SET NULL) | Linked itinerary item |
| `is_settled` | `BOOLEAN` | DEFAULT FALSE | All splits settled? |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Updated timestamp |

**Category values:** `transport`, `accommodation`, `food`, `activities`, `shopping`, `fees`, `tips`, `other`

**Indexes:** `idx_expenses_trip_id`, `idx_expenses_paid_by_user_id`, `idx_expenses_expense_date`, `idx_expenses_itinerary_item_id`

---

### expense_splits

How expenses are divided among trip members.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `expense_id` | `UUID` | NOT NULL, FK → expenses | Expense reference |
| `user_id` | `UUID` | NOT NULL, FK → auth.users | Who owes |
| `amount` | `DECIMAL(12,2)` | NOT NULL | Amount owed |
| `percentage` | `DECIMAL(5,2)` | | Percentage (if split by %) |
| `split_type` | `TEXT` | CHECK IN ('equal', 'percentage', 'exact'), DEFAULT 'equal' | Split method |
| `is_settled` | `BOOLEAN` | DEFAULT FALSE | Has this been paid? |
| `settled_at` | `TIMESTAMPTZ` | | When settled |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |

**Unique constraint:** `(expense_id, user_id)`

**Indexes:** `idx_expense_splits_expense_id`, `idx_expense_splits_user_id`

---

### posts

Social feed posts (Phase 2 feature).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `user_id` | `UUID` | NOT NULL, FK → auth.users | Post author |
| `trip_id` | `UUID` | FK → trips (SET NULL on delete) | Related trip |
| `destination_id` | `UUID` | FK → destinations (SET NULL) | Related destination |
| `content` | `TEXT` | | Post text/caption |
| `photos` | `TEXT[]` | DEFAULT '{}' | Photo URLs array |
| `likes_count` | `INTEGER` | DEFAULT 0 | Like counter |
| `comments_count` | `INTEGER` | DEFAULT 0 | Comment counter |
| `is_public` | `BOOLEAN` | DEFAULT TRUE | Public visibility |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Created timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Updated timestamp |

**Indexes:** `idx_posts_user_id`, `idx_posts_trip_id`, `idx_posts_created_at`

---

### friendships

Mutual friend relationships between users. Friend requests must be accepted before users are considered friends.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `requester_id` | `UUID` | NOT NULL, FK → auth.users | User who sent the request |
| `addressee_id` | `UUID` | NOT NULL, FK → auth.users | User who received the request |
| `status` | `VARCHAR(20)` | NOT NULL, CHECK IN ('pending', 'accepted', 'rejected', 'blocked'), DEFAULT 'pending' | Friendship status |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Request timestamp |
| `responded_at` | `TIMESTAMPTZ` | | When request was responded to |

**Unique constraint:** `(requester_id, addressee_id)`

**Check constraint:** `requester_id != addressee_id` (no self-friending)

**Indexes:** `idx_friendships_requester_id`, `idx_friendships_addressee_id`, `idx_friendships_status`, `idx_friendships_accepted`

---

### activity_logs

Tracks user activities for audit trail and collaboration visibility.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `entity_type` | `TEXT` | NOT NULL | Type of entity (trip, itinerary_item, expense, etc.) |
| `entity_id` | `UUID` | NOT NULL | ID of the entity being tracked |
| `trip_id` | `UUID` | FK → trips (CASCADE) | Associated trip (for filtering) |
| `user_id` | `UUID` | NOT NULL, FK → auth.users (CASCADE) | Who performed the action |
| `action` | `TEXT` | NOT NULL | Action type (created, updated, deleted, joined, etc.) |
| `details` | `JSONB` | DEFAULT '{}' | Additional metadata (title, changed fields, etc.) |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | When the action occurred |

**Indexes:** `idx_activity_logs_trip_id`, `idx_activity_logs_entity`, `idx_activity_logs_user_id`, `idx_activity_logs_created_at`, `idx_activity_logs_trip_created`

**Helper function:** `log_activity(entity_type, entity_id, trip_id, action, details)` — SQL function to log activities

---

### draft_itineraries

AI-generated draft itineraries awaiting user review and approval.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `user_id` | `UUID` | NOT NULL, FK → auth.users (CASCADE) | Owner of the draft |
| `destination_id` | `UUID` | NOT NULL, FK → destinations (CASCADE) | Target destination |
| `preferences` | `JSONB` | NOT NULL | Trip preferences (dates, travelers, budget, etc.) |
| `generated_itinerary` | `JSONB` | NOT NULL | AI-generated itinerary data |
| `review_state` | `JSONB` | NOT NULL, DEFAULT '{}' | Accept/skip status per activity |
| `edited_activities` | `JSONB` | NOT NULL, DEFAULT '{}' | User-edited activity versions |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Draft creation time |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | Last update time |
| `expires_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() + 30 days | Auto-expiry date |

**Indexes:** `idx_draft_itineraries_user_id`, `idx_draft_itineraries_destination_id`, `idx_draft_itineraries_expires_at`

**Helper function:** `cleanup_expired_drafts()` — Deletes drafts past their expiry date

---

### trip_bookings

Flight, hotel, and activity reservations linked to a trip (migration `017_trip_bookings.sql`).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `trip_id` | `UUID` | NOT NULL, FK → trips (CASCADE) | Parent trip |
| `created_by_user_id` | `UUID` | NOT NULL, FK → auth.users | Who added the booking |
| `booking_type` | `TEXT` | NOT NULL | `flight`, `hotel`, `activity`, `transport`, `other` |
| `source` | `TEXT` | NOT NULL | `manual` or `email` |
| `title` | `TEXT` | NOT NULL | Display title |
| `provider` | `TEXT` | | Airline, hotel chain, etc. |
| `confirmation_number` | `TEXT` | | Booking reference |
| `start_date` / `end_date` | `DATE` | | Booking window |
| `start_time` / `end_time` | `TEXT` | | Optional times |
| `location` / `address` | `TEXT` | | Venue or address |
| `amount` | `DECIMAL(12,2)` | | Optional cost |
| `currency` | `TEXT` | DEFAULT `PHP` | |
| `notes` | `TEXT` | | |
| `itinerary_item_id` | `UUID` | FK → itinerary_items (SET NULL) | Linked activity |
| `details` | `JSONB` | NOT NULL, DEFAULT `{}` | Type-specific fields |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | NOT NULL | Timestamps |

---

### trip_packing_items

Per-trip packing checklist items, assigned to individual trip members (migrations `018`, `019`).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `trip_id` | `UUID` | NOT NULL, FK → trips (CASCADE) | Parent trip |
| `created_by_user_id` | `UUID` | NOT NULL, FK → auth.users | Who created the row |
| `assigned_to_user_id` | `UUID` | NOT NULL, FK → auth.users | Who should pack this item |
| `assigned_by_user_id` | `UUID` | FK → auth.users | Who made the assignment |
| `assigned_at` | `TIMESTAMPTZ` | | Last assignment time |
| `name` | `TEXT` | NOT NULL | Item label |
| `category` | `TEXT` | NOT NULL | `clothing`, `toiletries`, `electronics`, `documents`, `health`, `gear`, `other` |
| `source` | `TEXT` | NOT NULL | `manual` or `ai` |
| `is_checked` | `BOOLEAN` | NOT NULL, DEFAULT false | Packed / not packed |
| `sort_order` | `INTEGER` | NOT NULL, DEFAULT 0 | Display order per assignee |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | NOT NULL | Timestamps |

**Triggers:** `validate_packing_assignee` (assignee must be trip member), `notify_packing_assignment` (in-app notification when assigned to someone else)

---

### user_notifications

In-app notification inbox (migration `019_packing_assignments_notifications.sql`). Push (FCM) can be added later.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | Primary key |
| `user_id` | `UUID` | NOT NULL, FK → auth.users (CASCADE) | Recipient |
| `trip_id` | `UUID` | FK → trips (CASCADE) | Related trip (optional) |
| `type` | `TEXT` | NOT NULL | e.g. `packing_assigned` |
| `title` | `TEXT` | NOT NULL | Short title |
| `body` | `TEXT` | | Message body |
| `data` | `JSONB` | NOT NULL, DEFAULT `{}` | Payload (`packing_item_id`, etc.) |
| `read_at` | `TIMESTAMPTZ` | | Null = unread |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

## Triggers

### updated_at Auto-Update

All tables with `updated_at` have a trigger that auto-updates on row modification:

```sql
CREATE TRIGGER update_<table>_updated_at
    BEFORE UPDATE ON <table>
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Auto-Create User Profile

When a new user signs up, a profile is automatically created:

```sql
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

This extracts:
- `display_name` from `full_name` or `name` in user metadata
- `avatar_url` from user metadata (for OAuth like Google)

---

## Row Level Security (RLS)

All tables have RLS enabled. Key policies:

### user_profiles
- **SELECT:** Anyone can view profiles (for social features)
- **UPDATE:** Only own profile
- **INSERT:** Only own profile

### trips
- **SELECT:** Owner, members, or public trips
- **INSERT:** Authenticated users (become owner)
- **UPDATE:** All trip members can edit
- **DELETE:** Owner only

### trip_members
- **SELECT:** Members of the same trip
- **INSERT:** Any member can invite new members
- **UPDATE:** Owner only (role changes)
- **DELETE:** Owner can remove others; members can remove themselves

### destinations
- **SELECT:** Everyone (public catalog)
- **INSERT/UPDATE:** Authenticated users

### trip_destinations, itinerary_items
- **SELECT:** Trip members or public trips
- **INSERT/UPDATE/DELETE:** All trip members (collaborative editing)

### expenses
- **SELECT:** Trip members
- **INSERT:** Trip members
- **UPDATE:** Trip members (allows editing on behalf of others)
- **DELETE:** Payer or trip owner

### expense_splits
- **SELECT:** Trip members
- **INSERT/UPDATE/DELETE:** Expense payer
- **UPDATE (settle):** The user who owes can mark as settled

### posts
- **SELECT:** Public posts or own posts
- **INSERT/UPDATE/DELETE:** Own posts only

### friendships
- **SELECT:** Users can view friendships they are part of
- **INSERT:** Users can send friend requests (as requester, status must be pending)
- **UPDATE:** Only addressee can respond (accept/reject/block)
- **DELETE:** Either party can delete (unfriend or cancel request)

### activity_logs
- **SELECT:** Trip members can view logs for their trips, or users can view their own logs
- **INSERT:** Authenticated users can insert logs for their own actions only
- **UPDATE:** Not allowed (logs are immutable)
- **DELETE:** Trip owner only (for cleanup)

### draft_itineraries
- **SELECT:** Users can only view their own drafts
- **INSERT:** Users can create their own drafts
- **UPDATE:** Users can update their own drafts
- **DELETE:** Users can delete their own drafts

### trip_bookings
- **SELECT/INSERT/UPDATE/DELETE:** Trip members (insert requires `created_by_user_id = auth.uid()`)

### trip_packing_items
- **SELECT:** Trip members who are the assignee (`assigned_to_user_id`) or creator (`created_by_user_id`)
- **INSERT:** Trip members (`created_by_user_id = auth.uid()`); assignee must be a trip member (trigger)
- **UPDATE/DELETE:** Assignee or creator
- **Notifications:** `notify_packing_assignment` trigger inserts into `user_notifications` when assignee ≠ assigner

### user_notifications
- **SELECT/UPDATE/DELETE:** Own rows only (`user_id = auth.uid()`)
- **INSERT:** Via `SECURITY DEFINER` trigger only (not direct client insert)

---

## Common Queries

### Get user's trips (owned + member of)

```sql
SELECT DISTINCT t.*
FROM trips t
LEFT JOIN trip_members tm ON tm.trip_id = t.id
WHERE t.owner_id = auth.uid()
   OR tm.user_id = auth.uid()
ORDER BY t.start_date DESC;
```

### Get trip itinerary by day

```sql
SELECT *
FROM itinerary_items
WHERE trip_id = '<trip_id>'
ORDER BY day_number, sort_order;
```

### Get my packing items for a trip

```sql
SELECT *
FROM trip_packing_items
WHERE trip_id = '<trip_id>'
  AND assigned_to_user_id = auth.uid()
ORDER BY is_checked ASC, sort_order ASC, created_at ASC;
```

### Get expense balances for a trip

```sql
SELECT 
    u.display_name,
    SUM(CASE WHEN e.paid_by_user_id = up.auth_id THEN e.amount ELSE 0 END) as total_paid,
    SUM(es.amount) as total_owed
FROM user_profiles up
JOIN trip_members tm ON tm.user_id = up.auth_id
LEFT JOIN expenses e ON e.trip_id = tm.trip_id AND e.paid_by_user_id = up.auth_id
LEFT JOIN expense_splits es ON es.user_id = up.auth_id
WHERE tm.trip_id = '<trip_id>'
GROUP BY up.id, up.display_name;
```

---

## Storage Buckets (Supabase Storage)

Create these buckets in Supabase Dashboard → Storage:

| Bucket | Purpose | Public |
|--------|---------|--------|
| `avatars` | User profile photos | Yes |
| `trip-covers` | Trip cover images | Yes |
| `receipts` | Expense receipts | No |
| `posts` | Social post photos | Yes |
| `destinations` | Destination photos | Yes |

---

## Realtime Configuration

Enable Supabase Realtime for tables that need live updates (migration `015_enable_realtime.sql`):

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE trips;
ALTER PUBLICATION supabase_realtime ADD TABLE trip_members;
ALTER PUBLICATION supabase_realtime ADD TABLE itinerary_items;
ALTER PUBLICATION supabase_realtime ADD TABLE expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE expense_splits;
ALTER PUBLICATION supabase_realtime ADD TABLE activity_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE draft_itineraries;
ALTER PUBLICATION supabase_realtime ADD TABLE trip_destinations;
ALTER PUBLICATION supabase_realtime ADD TABLE trip_bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE trip_packing_items;
ALTER PUBLICATION supabase_realtime ADD TABLE user_notifications;
```

This allows the Flutter app to receive real-time WebSocket notifications when data changes in these tables.

---

## Edge Functions (Supabase)

| Function | Purpose |
|----------|---------|
| `generate-itinerary` | AI trip itinerary from destination + preferences |
| `generate-packing-suggestions` | AI packing list items for a trip context |
| `parse-itinerary-text` | Natural language → itinerary activity |
| `parse-expense-text` | Natural language → expense |
| `parse-receipt` | Receipt image → expense fields |
| `parse-booking-email` | Booking confirmation email → booking fields |
| `process-forwarded-email` | Inbound trip email webhook (receipts + bookings) |

Deploy: `supabase functions deploy <function-name>`

---

*Last updated: May 18, 2026*
