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
9. **Signing and Meta.** In Xcode set the signing team. For the demo leave `MetaAppID` empty in
   `ios/NutraVision/Info.plist` (Developer Mode requires it empty) and enable Developer Mode for the glasses in the
   Meta AI app. Only for a production release: register the app in the Wearables Developer Center
   (wearables.developer.meta.com) and set `MetaAppID` together with `ClientToken` (and `TeamID`).
10. **Run** on a physical iPhone (the camera, Bluetooth and glasses need real hardware).
    The iPhone needs iOS 17.2 or later (the Meta Wearables DAT SDK 1.0 minimum).

## Verify

```
npm test                                   # Node + PGlite; runs anywhere (schema, RLS, seed, Edge Functions)
cd ios/NutraCore && swift test             # Mac: core logic tests
cd ios && xcodegen generate && xcodebuild -project NutraVision.xcodeproj -scheme NutraVision -destination 'generic/platform=iOS' build
```

## Demo accounts

All use password `demo1234`.

| Account | Role |
|---|---|
| doctor@nutravision.demo | Doctor |
| maria@nutravision.demo | Patient, Type 2 diabetes |
| james@nutravision.demo | Patient, hypertension, one pending recommendation |
| alex@nutravision.demo | Patient, bodybuilding |

## Demo walkthrough

1. Sign up as a patient with Type 2 diabetes + Hypertension and the goal "lose 0.5 kg/week"; the Dashboard shows computed daily targets.
2. More > Glasses: connect, then start Glasses Mode. Look at a plate, say "scan this" and hear the name, calories and verdict (about 8 s). Say "add it"; it is logged to the right meal and you hear the new daily total.
3. Look at a packaged item's barcode; the result is spoken without a command. Say "add it".
4. Tap the Add tab (＋), search "greek yogurt"; see USDA generic and branded results and add one with a serving size.
5. Open Diary (MyFitnessPal layout), then Progress: colored month calendar and 12-month year heatmap.
6. Log exercise (a run) from the Add tab, then More > Apple Health to import a workout; remaining calories on the Dashboard increase.
7. Sign in as doctor@nutravision.demo and send a link request to the patient. Patient: More > Care Team > accept. Doctor opens the patient's diary, then sends lower sodium targets. Patient accepts; targets and verdicts change (More > Conditions shows the active rules).
8. More > Diet Plans: start the Bodybuilding sample plan, swap a food, keep it as the active plan.

## Device checks to run once

The code was written without a compiler or device, so the first build and run will surface fix-ups.

- **(a) First Xcode build compiles.** Likeliest spots: Meta SDK names in `GlassesSettingsView` (`deviceForIdentifier(_:)?.nameOrId()`, `RegistrationState.available`) and Swift Charts `.value(String, ...)` calls in `TrendCharts`.
- **(b) Glasses Mode.**
  - "Scan this" gives a spoken result.
  - Taking a photo must not end the glasses session. If every scan says "Glasses disconnected", report it.
  - Folding or removing the glasses ends Glasses Mode with "Glasses disconnected."
  - The app must not react to its own speech; if it does, tune `echoTail` in `VoiceLoop`.
  - Check phone calls and Siri interrupting Glasses Mode.
- **(c) Cameras.** Phone barcode scan starts (DataScanner), and phone photo capture in Glasses Mode (Phone camera) never gets stuck.
- **(d) Apple Health.** Connect; a workout appears once with a heart; a food shows in Health > Nutrition and disappears when deleted in the app.
- **(e) Keep the phone unlocked** during Glasses Mode. The app keeps the screen awake; a locked phone pauses the glasses stream.

## Known limitations

- No push notifications: pull to refresh or reopen the app.
- No offline logging.
- The phone must stay unlocked during Glasses Mode.
- Keyword-based gluten/FODMAP/pregnancy flags miss unnamed ingredients.
- AI portion estimates are estimates.
- Demo-grade security: anyone can sign up as a doctor; patients must accept links.
