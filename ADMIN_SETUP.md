# GrowPlus Pro activation checklist

The code is published in GitHub, but database features do not become active until the SQL is run in the correct Supabase project.

## 1. Install database schema
1. Open https://supabase.com/dashboard/project/cnjahjgtfwrgtzyhrxak/sql/new
2. Open `supabase/growplus_setup.sql` in this repository, copy the whole file into the SQL editor and run it.
3. Open `supabase/growplus_pro.sql`, copy the whole file into the SQL editor and run it.
4. If either script reports an error, stop and fix that error before continuing.

## 2. Create the owner/admin account
1. Register on the GrowPlus website with the email you control and verify it if email confirmation is enabled.
2. Open Supabase Authentication → Users and find that account.
3. Copy its **User UID**.
4. In the Supabase SQL editor, run the following after replacing only `PASTE-YOUR-USER-UUID-HERE` with that UID:

```sql
insert into public.growplus_admins (user_id)
values ('PASTE-YOUR-USER-UUID-HERE'::uuid)
on conflict (user_id) do nothing;
```

Only add accounts you personally trust. Never make admin assignment public or allow website visitors to choose their own role.

## 3. Open the dashboards
- Public site: https://elbidouni99-gif.github.io/growplus/
- Member dashboard: https://elbidouni99-gif.github.io/growplus/dashboard.html
- Admin dashboard: https://elbidouni99-gif.github.io/growplus/admin.html

## 4. What the admin dashboard supports
- Review task submissions with approve/reject decisions.
- Award task points only from the protected database review function.
- Create tasks and pause/reactivate tasks.
- Review withdrawal requests, approve/reject them, and mark approved requests paid after a real transfer.
- Keep an audit record of admin decisions.

## Important limitations / activation still required
- This repository update does not run SQL in your Supabase account. Do steps 1 and 2 before the admin panel can work.
- Google sign-in remains dependent on enabling Google in Supabase and configuring a Google OAuth client and redirect URLs.
- Email confirmation and password-reset delivery require valid SMTP settings and a verified sender/domain in your email provider.
- Withdrawals are **manual review**, not automatic money transfers. No bank, PayPal, or Moroccan payment processor is connected by these changes.
- AI is not activated by this database/admin upgrade; a real AI provider needs a server-side Edge Function and a provider key stored as a Supabase secret. Never put private AI or service-role keys in HTML/JavaScript.
- The starter tasks are placeholders. Only publish video/survey tasks you have the right to offer and can genuinely verify; don't claim users have earned cash until payout rules and a funded payment process exist.
