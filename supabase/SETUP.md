# Homelab accounts setup

1. Create a Supabase project on the free tier.
2. Open **SQL Editor**, paste in `schema.sql`, and run it.
3. In **Authentication → Providers**, enable Email and email confirmation.
4. Create the first account with your email, then promote it:

   ```sql
   update public.profiles set role = 'admin' where email = 'your-email@example.com';
   ```

5. The portal/mobile client uses only the project URL and public `anon` key. Never put the `service_role` key in the website or Android app.

Once the project exists, its URL and public key can be added as deployment variables and the admin page can manage invitations, roles, and per-app access.
