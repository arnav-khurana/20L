# Setup

## 1. Supabase project settings (do this first)
1. Create a project at supabase.com (free tier is fine), or reuse your existing one.
2. **Authentication → Providers** — make sure **Email** is enabled (it is by default).
3. **Authentication → Settings** — turn **OFF** "Confirm email". This lets people sign up and be logged in immediately, with no email server to configure. (If you'd rather require email confirmation, leave it on — the site handles that case too, it just tells people to check their inbox before their first login.)

## 2. Database
Go to **SQL Editor → New query**, paste in `schema.sql`, and run it.

⚠️ This drops and recreates the `orders`, `profiles`, and `admins` tables — it wipes any existing data. Export anything you need first (Table Editor → the table → Export as CSV).

## 3. Make yourself an admin
1. Open the live site and **sign up** for a normal account, same as any customer would.
2. Back in Supabase, go to **SQL Editor** and run (with your real signup email):
   ```sql
   insert into admins (id) select id from auth.users where email = 'you@example.com';
   ```
3. Log out and back in on the site — visit `/admin/` and log in; it will now show the full order table instead of "not an admin."

Repeat step 2 for anyone else who should have admin access.

## 4. Configure the site
Open `config.js` (used by both `index.html` and `admin/index.html`):
```js
const CONFIG = {
  SUPABASE_URL: "https://your-project.supabase.co",
  SUPABASE_ANON_KEY: "your-anon-key",
  WHATSAPP_NUMBER: "91XXXXXXXXXX",   // country code + number, no + or spaces
  UPI_ID: "9810163772@ptyes",        // already set from the QR you sent
  UPI_PAYEE_NAME: "20L"              // name shown in the customer's UPI app
};
```
Edit it once here — both pages read from this same file.

## 5. Deploy (GitHub Pages)
1. Push all four files to a GitHub repo, keeping this exact layout:
   ```
   index.html
   config.js
   admin/index.html
   ```
2. Repo → **Settings → Pages** → Deploy from branch → `main` / root.
3. The customer site is at `https://<username>.github.io/<repo>/`.
   The admin panel is at `https://<username>.github.io/<repo>/admin/` — it isn't linked from anywhere on the main site, so only people who know that URL (or are told it) will find it. It still requires an admin login to see anything, so this is convenience, not the actual security — the login is.

## How it all works now

**Accounts.** Ordering requires an account (email + password, via Supabase Auth). Signing up asks for name, email, password, hostel, room number, wing, and phone — that profile is reused on every future order, so the checkout form auto-fills.

**First-time combo prompt.** Right after someone signs up, a modal offers a ₹320 combo (1 new bottle + 1 refill, bundled — same total as buying both separately, just offered as an easy default first order). It only appears once per account; dismissing it or adding the combo both mark it as shown, via `profiles.first_order_claimed`.

**Payment.** Same UPI-QR-then-WhatsApp flow as before, now with your real UPI ID.

**Order history.** "My orders" now shows your own logged-in account's history automatically — no more typing in a phone number.

**Admin panel.** Lives at `/admin/` — a separate page, not part of the main site, with no link to it anywhere in the nav. Log in there with an admin account and it lists every order (newest first). Click any row to see:
- Every item from that same checkout (grouped via `order_group_id`, so a cart with 3 different items shows as one order, not three unrelated rows).
- Dropdowns to update that line's **status** (`pending`/`confirmed`/`delivered`/`cancelled`) and **payment status** (`unpaid`/`claimed`/`confirmed`) — hit Save.
- That customer's full order history below it, so you can see repeat customers and past issues at a glance.

**Security note, plainly stated:** admin status is just a row in the `admins` table — there's no separate "make me admin" button in the UI on purpose, so a customer account can never grant itself admin rights. Only someone with direct SQL access to your Supabase project (you) can create an admin.

## What else you could add later
- **Real-time payment verification** — a payment gateway (Razorpay, Cashfree) with a webhook that flips `payment_status` to `confirmed` automatically, instead of the admin checking screenshots by hand.
- **Password reset** — Supabase Auth supports it natively; the UI here doesn't have a "forgot password" link yet.
- **Cancel/pause a recurring order** — right now that's still a manual WhatsApp + admin-panel-status conversation, not a customer-facing button.
- **Admin search/filter** — the admin table currently just lists everything newest-first; a search box by name/room/phone would help once order volume grows.
