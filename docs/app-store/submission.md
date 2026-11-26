# App Store submission kit

Everything App Store Connect asks for that isn't code. Fill in the `[brackets]`.

## Before you submit

- [ ] Apple Developer Program membership ($99/year). Use an organization account if you can; Apple prefers one for apps that handle medical data.
- [ ] In `ios/project.yml`: set your Team ID as `DEVELOPMENT_TEAM`, and set a bundle ID you own (for example `com.[yourcompany].nutravision`).
- [ ] Meta: register the app in the Wearables Developer Center and put its ID in `Info.plist › MWDAT › MetaAppID`.
- [ ] Supabase:
  - Run migrations `0003`, `0004` and `0005`, then redeploy `analyze-food`.
  - Add custom SMTP, the reset redirect URL and the `ANTHROPIC_API_KEY` secret (see PR #3).
  - Upgrade to a paid plan before launch. Free projects pause after a week without traffic, and then the app can't sign anyone in.
- [ ] Host `docs/app-store/privacy-policy.md` at a public URL (GitHub Pages works). Also host a support page or email.
- [ ] Verify the demo doctor stays verified after `0004`. It's grandfathered, so this should hold.
- [ ] Take screenshots on a 6.9" iPhone (1320 × 2868). The CI screen tour images are a starting point, but they come from a 6.3" simulator.

## Listing

**Name:** NutraVision
**Subtitle (30):** Food log for health conditions
**Category:** Health & Fitness (secondary: Medical)
**Age rating:** 4+. Answer "No" to every content question; there's no user-generated content visible to other users.

**Promotional text (170):**
Log food by photo, barcode or search, see whether each food fits your condition, and share your diary with your doctor.

**Description:**
NutraVision is a food diary built around health conditions. Tell it about type 2 diabetes, high blood pressure, kidney disease, IBS, celiac disease or any of 16 conditions, and every food you log is checked against the limits for that condition.

- Log food by snapping a photo, scanning a barcode, searching the USDA database, or saying "scan this" through Meta AI glasses.
- See calories, protein, carbs, fat, saturated fat, sodium and fiber against daily targets made for your body and conditions.
- Know why a food doesn't fit: too much sodium for DASH, too many carbs for diabetes, gluten for celiac.
- Log blood pressure, blood sugar and drinks against a fluid limit, with clear advice when a reading is in a dangerous range.
- Keep a symptom diary for IBS, IBD, celiac disease or EoE, and see which foods were often followed by symptoms. Each digestive condition comes with recipe ideas from the GI Nutrition Foundation.
- Track weight, workouts and your logging streak. Connect Apple Health to bring in workouts and steps.
- Share with your doctor. Accept a doctor's request and they can follow your diary, send new targets or a diet plan, and you choose whether to accept.
- For doctors: a patient list sorted by who needs attention, with each patient's week at a glance and CSV export.

Condition guidance follows published guidelines from the NIH, the American Heart Association, the USDA and the FDA. Each condition lists its sources in the app.

NutraVision is not medical advice. Talk to your doctor before changing your diet.

**Keywords (100):** diabetes,DASH,sodium,kidney,celiac,calorie counter,food diary,macros,barcode,dietitian,doctor

**Support URL:** [your support page]
**Privacy Policy URL:** [where you host privacy-policy.md]

## App Review information

**Sign-in required:** yes. Give two demo accounts:

| Role | Email | Password |
|---|---|---|
| Patient | maria@nutravision.demo | [demo password from seed.sql] |
| Doctor | doctor@nutravision.demo | [same] |

Before each submission, run `supabase/demo_refresh.sql` so the demo diaries reach the current date.

**Notes for the reviewer:**

> NutraVision is a food diary for people managing a health condition, with optional sharing to their doctor.
>
> - Patient account (Maria): Dashboard, Diary, the + button (search "banana", or Quick add), and More › Conditions. Each condition lists its medical sources.
> - Doctor account: Patients, then tap a patient. Doctors can see a patient only after the patient accepts a request. New doctor accounts start unverified, and can't add patients until we check their license number.
> - AI photo scan: the app explains, before the first scan, that the photo goes to Anthropic's Claude to identify the food. Photos aren't stored.
> - Meta AI glasses are optional. Without glasses, the Glasses screen shows the pairing state; every feature also works from the phone camera. The `bluetooth-peripheral` and `external-accessory` background modes are required by Meta's Wearables SDK to keep the glasses connected.
> - Account deletion: More › Delete account.
> - The app does not diagnose or treat anything. It shows nutrition against targets and says "not medical advice" at sign-up, in More and on every condition screen.

## App Privacy ("nutrition label") answers

Match `ios/NutraVision/PrivacyInfo.xcprivacy`. Tracking: **No** for everything. Every type below is **linked to the user** and used for **App Functionality** only.

| Data type | Collected | Notes |
|---|---|---|
| Contact Info › Name | Yes | Account name |
| Contact Info › Email Address | Yes | Sign-in |
| Health & Fitness › Health | Yes | Conditions, diary, weight |
| Health & Fitness › Fitness | Yes | Workouts |
| User Content › Photos or Videos | Yes | Food photos, sent for analysis and not stored |
| Identifiers, Usage Data, Diagnostics, Location, Financial | No | |

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO` in Info.plist (HTTPS only), so App Store Connect won't ask on each build.

## Likely review questions

- **1.4.1 (medical):** sources are cited in the app, and there's no diagnosis or dosing advice. If asked, explain that the doctor features are for licensed clinicians whose licenses are checked before they can add patients.
- **5.1.1(v) (account deletion):** More › Delete account removes the account and all of its data immediately.
- **5.1.2 (data shared with AI):** there's a consent screen before the first AI scan, and the privacy screen explains it.
- **2.1 (completeness):** make sure the backend is on a paid plan and the demo data is fresh on the day you submit.
