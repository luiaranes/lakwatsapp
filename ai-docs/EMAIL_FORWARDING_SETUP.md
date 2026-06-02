# Lakwatsapp — Email Forwarding Setup

> End-to-end setup guide for receipt email forwarding once you have a domain.

---

## What This Feature Does

Users get a unique per-trip forwarding address (example: `trip-abc123@mail.yourdomain.com`).

When a receipt email is forwarded to that address:
- app validates sender is a trip member
- app validates receipt date is within allowed trip window
- app parses expense details with AI
- app auto-creates an expense in the trip

---

## Current Architecture

Recommended production flow:

1. Inbound email provider receives email for your domain (`mail.yourdomain.com`)
2. Provider forwards event to `process-forwarded-email` Edge Function
3. Function validates secret header (`x-email-webhook-secret`)
4. Function resolves trip via `trip_email_aliases`
5. Function parses with `parse-expense-text`
6. Function creates `expenses` row and logs status in `forwarded_receipt_emails`

For AWS SES specifically:
- SES cannot directly attach custom webhook headers to external HTTPS endpoints.
- Use **SES -> Lambda -> Supabase Edge Function**.

---

## Prerequisites

- Domain name (example: `yourdomain.com`)
- Supabase project ready
- Email forwarding migrations applied
- Edge Functions deployed:
  - `process-forwarded-email`
  - `parse-expense-text`
- Secrets configured in Supabase:
  - `EMAIL_WEBHOOK_SECRET`
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_ANON_KEY`
  - `ANTHROPIC_API_KEY` (for parsing)

---

## Step 1 — Pick Forwarding Subdomain

Use dedicated subdomain for inbound mail:

- `mail.yourdomain.com`

Trip aliases are generated as:
- `trip-<random>@mail.yourdomain.com`

> Important: current SQL migration uses hardcoded domain in RPC (`mail.lakwatsapp.app`).
> Update migration function to your real domain before running in production.

---

## Step 2 — Configure Supabase Database

Apply migration:

```sql
-- supabase/migrations/016_email_forwarding.sql
```

This adds:
- `trip_email_aliases`
- `forwarded_receipt_emails`
- RPCs:
  - `get_or_create_trip_email_alias`
  - `regenerate_trip_email_alias`
  - `get_trip_member_emails`

---

## Step 3 — Deploy Edge Functions

Deploy parser:

```bash
supabase functions deploy parse-expense-text --no-verify-jwt
```

Deploy inbound processor:

```bash
supabase functions deploy process-forwarded-email --no-verify-jwt
```

> `--no-verify-jwt` is used because inbound webhook caller is not a signed user session.

---

## Step 4 — Set Supabase Secrets

Generate strong webhook secret:

```bash
openssl rand -base64 48
```

Set secrets:

```bash
supabase secrets set EMAIL_WEBHOOK_SECRET='YOUR_SECRET'
supabase secrets set SUPABASE_URL='https://<project-ref>.supabase.co'
supabase secrets set SUPABASE_SERVICE_ROLE_KEY='YOUR_SERVICE_ROLE_KEY'
supabase secrets set SUPABASE_ANON_KEY='YOUR_ANON_KEY'
supabase secrets set ANTHROPIC_API_KEY='YOUR_ANTHROPIC_KEY'
```

---

## Step 5 — Configure AWS SES (Inbound)

### 5.1 Verify Domain in SES

In SES:
- verify `yourdomain.com`
- publish SES verification DNS records

### 5.2 Add MX Record for Inbound

In DNS provider:

- Host/Name: `mail.yourdomain.com`
- Type: `MX`
- Value: `10 inbound-smtp.<ses-region>.amazonaws.com`

Use same SES region where receipt rules are configured.

### 5.3 Create Receipt Rule Set + Rule

In SES:
- create rule set (make active)
- create receipt rule for recipients:
  - `*@mail.yourdomain.com`

Recommended actions order:
1. (Optional) S3 action (archive raw email)
2. Lambda action (forward to Supabase)

---

## Step 6 — Add Lambda Forwarder (SES -> Supabase)

Lambda receives SES event and POSTs to:

```text
https://<project-ref>.supabase.co/functions/v1/process-forwarded-email
```

Required headers:
- `Content-Type: application/json`
- `x-email-webhook-secret: <EMAIL_WEBHOOK_SECRET>`

Payload shape expected by function:

```json
{
  "from": "sender@example.com",
  "to": "trip-xxxx@mail.yourdomain.com",
  "subject": "Receipt subject",
  "text": "Email body text",
  "date": "2026-07-10T12:00:00Z",
  "messageId": "provider-message-id"
}
```

### 6.1 Lambda Permission

Allow SES to invoke Lambda:
- principal: `ses.amazonaws.com`
- source ARN: receipt rule ARN

---

## Step 7 — App Usage

In app:

1. Open trip -> Expenses
2. Tap **Add Expense**
3. Tap **Email Forwarding**
4. Copy generated trip email alias
5. Use that alias as forwarding destination

Owner can regenerate alias from same dialog.

---

## Step 8 — End-to-End Test

Use curl test before SES:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/process-forwarded-email" \
  -H "Content-Type: application/json" \
  -H "x-email-webhook-secret: YOUR_SECRET" \
  -d '{
    "from": "member@example.com",
    "to": "trip-xxxx@mail.yourdomain.com",
    "subject": "Jollibee receipt",
    "text": "Lunch 350 PHP",
    "date": "2026-07-10T12:00:00Z",
    "messageId": "dev-test-1"
  }'
```

Possible statuses:
- `processed` -> success
- `ignored_no_trip` -> alias not found
- `rejected_sender` -> sender email not trip member
- `rejected_date` -> parsed/received date outside allowed range
- `failed_parse` -> parser failed to extract amount/details
- `failed_create` -> DB insert failed

---

## Troubleshooting

### `UNAUTHORIZED_NO_AUTH_HEADER`

Function deployed with JWT verification on.  
Redeploy with:

```bash
supabase functions deploy process-forwarded-email --no-verify-jwt
```

### `UNAUTHORIZED_INVALID_JWT_FORMAT` from parser

`parse-expense-text` still expects JWT.  
Redeploy parser with:

```bash
supabase functions deploy parse-expense-text --no-verify-jwt
```

### Repeated `rejected_date` even with valid date

Avoid relative words (`yesterday`, `last week`) in test text.  
Parser may prioritize NLP date over payload date.

### `ignored_no_trip`

Trip alias not found.  
Generate alias from app first and use exact `to` address.

---

## Security Notes

- Rotate `EMAIL_WEBHOOK_SECRET` immediately if exposed.
- Prefer dedicated inbound subdomain (`mail.`), not root domain.
- Restrict Lambda execution role to minimum required permissions.
- Consider adding internal function secret between
  `process-forwarded-email` and `parse-expense-text` if both run without JWT verification.

---

*Last updated: April 27, 2026*
