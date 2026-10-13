# GrowPlus

GrowPlus is being built as a global-first creator-growth platform. This repository currently contains the first responsive, multilingual public landing-page prototype.

## Current status
- Responsive mobile/desktop landing page.
- English, French, Arabic (RTL), and Spanish.
- Browser-language detection with manual language override saved in the browser.
- Creator discovery, legitimate campaign planning, tasks/rewards concepts, and safety principles.
- Demo metrics are labeled as illustrative; authentication and payments are not active yet.

## Not live yet
Google sign-in, password recovery, user accounts, persistent profiles, tasks, points, referral ledger, real wallet/earnings, payment collection, withdrawals, country-specific payment availability, AI admin control center, and verified social analytics are not yet implemented/configured. Do not advertise them as active.

## Planned implementation order
1. Configure Supabase Auth/database and Google OAuth, email confirmation, password reset, and row-level security.
2. Build authenticated user dashboard and persistent profile.
3. Implement server-authoritative tasks, reward ledger, referrals and fraud controls.
4. Integrate a payment provider after confirming merchant eligibility, country support, and payout capabilities.
5. Add permitted official analytics integrations and authentic promotion workflows.
6. Build a separate owner-only AI Control Center with least-privilege access, audit logs, staging preview, tests, approvals for sensitive changes, and rollback.
7. Test on mobile Chrome and desktop browsers before production release.

## Preview
Open `index.html` in a browser. This is a static page; sign-in buttons intentionally show a setup notice and do not authenticate users.

## OAuth setup
Supabase Google sign-in requires a Google Cloud OAuth client, the correct authorized origin/callback URL, and configuration in Supabase Auth. Redirect URLs must be explicitly allowed:
- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://supabase.com/docs/guides/auth/redirect-urls

Never commit service-role keys, payment secrets, or other private credentials. Privileged operations belong on the server.

## Product safety
GrowPlus is intended for authentic creator discovery, legitimate advertising, collaborations, permitted tasks, and approved analytics. Do not implement fake followers, artificial views/likes, sub-for-sub, or deceptive engagement schemes. Payment methods must be confirmed per country and provider.
