# Lakwatsapp — Monetization & Cost Strategy

> This document outlines infrastructure costs, pricing tiers, and which features should be free vs premium.

---

## Infrastructure Costs

### Always Free (Open Source / On-Device)

| Component | Cost | Notes |
|-----------|------|-------|
| Flutter | ₱0 | Open source framework |
| Riverpod / Bloc | ₱0 | State management packages |
| Google ML Kit | ₱0 | On-device OCR, no API calls |
| Supabase (Free tier) | ₱0 | 500MB DB, 1GB storage, 50K MAU |

### Variable Costs (Pay-as-you-grow)

| Service | Free Tier | Paid Pricing | Cost Driver |
|---------|-----------|--------------|-------------|
| **Supabase Pro** | 500MB DB, 1GB storage | $25/month (~₱1,400) | Database size, need for backups |
| **OpenAI Vision API** | None | ~₱1.50 per receipt | Receipt scans (complex ones) |
| **Google Maps SDK** | $200/month credit | ~₱400 per 1,000 map loads | Map views, directions |
| **SendGrid** | 100 emails/day | $15/month (~₱850) | Email forwarding volume |
| **AWS SES** | 3,000/month (on EC2) | ₱5.50 per 1,000 emails | Transactional emails |
| **Push Notifications** | FCM is free | ₱0 | Firebase Cloud Messaging |
| **App Store** | — | $99/year (~₱5,500) | Apple Developer Program |
| **Play Store** | — | $25 one-time (~₱1,400) | Google Play Console |

---

## Estimated Monthly Costs by Stage

| Stage | Users | Monthly Cost | Notes |
|-------|-------|--------------|-------|
| **Development** | 1-5 | **₱0** | Free tiers only |
| **Private Beta** | 50-100 | **₱0 - ₱500** | Still within free tiers |
| **Public Beta** | 500-1,000 | **₱1,500 - ₱4,000** | Supabase Pro + some AI usage |
| **Early Growth** | 1,000-5,000 | **₱5,000 - ₱10,000** | AI costs grow with usage |
| **Scale** | 10,000+ | **₱15,000 - ₱30,000** | Premium revenue should cover this |

---

## Cost Optimization Strategies

### 1. On-Device First for OCR
```
Receipt captured
       │
       ▼
┌─────────────────┐
│ Google ML Kit   │ ← Free, on-device
│ (basic OCR)     │
└─────────────────┘
       │
       ▼
┌─────────────────┐
│ Confidence > 80%│───Yes──▶ Use result (₱0)
└─────────────────┘
       │ No
       ▼
┌─────────────────┐
│ OpenAI Vision   │ ← Paid, cloud API
│ (advanced OCR)  │
└─────────────────┘
       │
       ▼
   Use result (~₱1.50)
```

**Estimated savings:** 70-80% of receipts handled by free ML Kit.

### 2. Cache Common Patterns
- Store recognized merchant names, receipt formats
- Re-use patterns for repeat purchases (Jollibee, Grab, 7-Eleven)
- Reduce AI calls for familiar receipts

### 3. Batch Processing
- Queue non-urgent receipt parsing
- Process during off-peak hours for lower latency costs
- Aggregate API calls where possible

### 4. Map Optimization
- Cache static map tiles
- Limit live directions API calls
- Use static map images for trip previews (cheaper than interactive)

### 5. Email Volume Control
- Rate limit receipt forwarding (e.g., 50/day per user)
- Auto-reject obvious spam before processing

---

## Freemium Model

### Lakwatsapp Free

Core features that make the app useful — enough to get hooked.

| Feature | Limit |
|---------|-------|
| Create trips | Up to **3 active trips** |
| Trip members | Up to **5 members** per trip |
| Manual expense entry | **Unlimited** |
| Receipt scanning (ML Kit) | **10 scans/month** |
| Expense splitting | **Basic** (equal split only) |
| Budget tracking | **Overall budget** only |
| Explore destinations | **Full access** |
| Maps | **View only** (no directions) |
| Trip sharing | **Private only** |

### Lakwatsapp Premium

Power features for serious travelers and group trips.

| Feature | Premium Benefit |
|---------|-----------------|
| Active trips | **Unlimited** |
| Trip members | **Unlimited** |
| Receipt scanning | **Unlimited** (ML Kit + AI fallback) |
| Email forwarding | **Full access** (unique trip email) |
| Expense splitting | **Advanced** (percentage, custom, itemized) |
| Budget tracking | **Per-day, per-category, per-person** |
| Settlement suggestions | **Smart minimize transactions** |
| AI itinerary suggestions | **Full access** |
| AI budget assistant | **Full access** |
| Maps & directions | **Full access** |
| Trip sharing | **Public + social feed** |
| Offline mode | **Full offline support** |
| Export trip data | **PDF, spreadsheet export** |
| Priority support | **Yes** |

---

## Pricing Tiers

### Option A: Simple Monthly/Yearly

| Plan | Price | Billing |
|------|-------|---------|
| **Free** | ₱0 | — |
| **Premium Monthly** | ₱149/month | Monthly |
| **Premium Yearly** | ₱999/year (~₱83/month) | Annual (save 44%) |

### Option B: Per-Trip Pricing (Alternative)

For users who only travel occasionally:

| Plan | Price | Notes |
|------|-------|-------|
| **Free** | ₱0 | 3 trips, basic features |
| **Trip Pass** | ₱79/trip | Unlock premium for 1 trip |
| **Premium** | ₱149/month | Unlimited everything |

### Option C: Group-Focused Pricing

Since group travel is the core value prop:

| Plan | Price | Notes |
|------|-------|-------|
| **Solo** | ₱0 | 1 traveler, basic features |
| **Barkada** | ₱249/month | Up to 10 members, shared billing |
| **Travel Crew** | ₱499/month | Unlimited members, all features |

---

## Revenue Projections

Assuming **Option A** pricing with 5% free-to-premium conversion:

| Users | Free (95%) | Premium (5%) | Monthly Revenue |
|-------|------------|--------------|-----------------|
| 1,000 | 950 | 50 | ₱7,450 |
| 5,000 | 4,750 | 250 | ₱37,250 |
| 10,000 | 9,500 | 500 | ₱74,500 |
| 50,000 | 47,500 | 2,500 | ₱372,500 |

*Assumes average of ₱149/month per premium user (mix of monthly and yearly).*

---

## Premium Feature Rationale

| Feature | Why Premium? |
|---------|--------------|
| Unlimited receipt scanning | High AI/OCR cost per scan |
| Email forwarding | Infrastructure cost (inbound email parsing) |
| Advanced splitting | Differentiator, power user feature |
| AI suggestions | API costs (OpenAI/Gemini) |
| Offline mode | Development complexity, storage costs |
| Export to PDF/spreadsheet | Low cost but high perceived value |

| Feature | Why Free? |
|---------|-----------|
| Manual expense entry | Core value, no marginal cost |
| Basic splitting (equal) | Gets users hooked on group features |
| Explore destinations | Content is free, drives engagement |
| 3 active trips | Enough to experience value |
| 10 receipt scans/month | Taste of automation, upsell to premium |

---

## Launch Strategy

### Phase 1: Beta (Free for All)
- All features free during beta
- Collect feedback, refine UX
- Build user base and social proof

### Phase 2: Soft Launch (Freemium)
- Introduce free tier limits
- Premium available but with **50% launch discount**
- Grandfather early beta users with extended free premium

### Phase 3: Full Launch
- Standard pricing
- Referral program (invite friends, get free premium months)
- Seasonal promos (summer travel, holiday discounts)

---

## Payment Integration

| Platform | Provider | Notes |
|----------|----------|-------|
| iOS | Apple In-App Purchase | Required for App Store |
| Android | Google Play Billing | Required for Play Store |
| Web | Stripe / PayMongo | Direct billing, better margins |
| PH-specific | GCash, Maya, GrabPay | Consider for web checkout |

---

*Last updated: March 17, 2026*
