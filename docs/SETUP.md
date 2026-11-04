# NutraVision owner setup

1. **Supabase project.** Create one at supabase.com. In Authentication > Providers > Email, turn off
   "Confirm email" (demo only).
2. **API keys.** Create a USDA FoodData Central key (api.data.gov) and an Anthropic API key.
3. **Link and push the database** (Supabase CLI):
   ```
   supabase init            # once, if supabase/config.toml is missing
   supabase link --project-ref <ref>
   supabase db push
   ```
4. **Seed.** Run `supabase/seed.sql` in the Supabase SQL editor.
5. **RLS check.** Run `supabase/tests/rls_check.sql` in the SQL editor; it must report
   "Success. No rows returned".
6. **Secrets and functions:**
   ```
   supabase secrets set ANTHROPIC_API_KEY=... FDC_API_KEY=...
   supabase functions deploy food-search analyze-food
   ```
7. **App config.** Put the project URL and anon key (Project Settings > API) in
   `ios/NutraVision/App/Config.swift`.
8. **Generate the Xcode project** (Mac): `brew install xcodegen && cd ios && xcodegen`.
9. **Signing and Meta.** In Xcode set the signing team; set `MetaAppID` in `ios/NutraVision/Info.plist`
   to your Meta App ID. In the Meta AI app, enable Developer Mode for the glasses.
10. **Run** on a physical iPhone (the camera, Bluetooth and glasses need real hardware).
    The iPhone needs iOS 17.2 or later (the Meta Wearables DAT SDK 1.0 minimum).
