# GrowPlus Pro activation checklist

The code is published in GitHub, but database features do not become active until the SQL is run in the correct Supabase project.

## 1. Repair and install the database schema
1. Open https://supabase.com/dashboard/project/cnjahjgtfwrgtzyhrxak/sql/new
2. Because this project already has an older `tasks` table, first run `supabase/repair_existing_tasks.sql`. It adds compatible columns and preserves existing task rows.
3. Then run `supabase/growplus_setup.sql` to create missing feature tables and policies. The script is now compatible with older `points` / `active` task columns.
4. Then run `supabase/growplus_pro.sql` to enable the protected admin review features.
5. If a script reports an error, stop at that error. Do not repeatedly rerun different scripts at random.

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
- Google sign-in cannot work from code alone: in Supabase Authentication → Sign In / Providers → Google, enable the provider and enter the Google OAuth Client ID and Client Secret from Google Cloud. Add `https://cnjahjgtfwrgtzyhrxak.supabase.co/auth/v1/callback` as the authorized redirect URI in Google Cloud, and allow `https://elbidouni99-gif.github.io/growplus/` in Supabase Auth URL configuration.
- The Auth log error `535 5.7.8` indicates SMTP authentication was rejected. In Supabase Auth email/SMTP settings, use Brevo host `smtp-relay.brevo.com`, port `587`, the SMTP login shown in Brevo, and a newly generated **SMTP key** (not the API key). Confirm the sender address is verified in Brevo. Do not paste SMTP keys into GitHub or chat. The site code cannot safely enter these private credentials on your behalf.
- Withdrawals are **manual review**, not automatic money transfers. No bank, PayPal, or Moroccan payment processor is connected by these changes.
- AI is not activated by this database/admin upgrade; a real AI provider needs a server-side Edge Function and a provider key stored as a Supabase secret. Never put private AI or service-role keys in HTML/JavaScript.
- The starter tasks are placeholders. Only publish video/survey tasks you have the right to offer and can genuinely verify; don't claim users have earned cash until payout rules and a funded payment process exist.
