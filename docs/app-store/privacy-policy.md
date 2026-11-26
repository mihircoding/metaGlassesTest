# NutraVision Privacy Policy

_Effective [date you publish]_

NutraVision ("the app") is a food diary for people managing a health condition, with optional sharing to their doctor. This policy explains what the app collects, why, and the choices you have. Questions: [contact email].

## What we collect

- **Account:** your name, email address, password (stored hashed by our authentication provider) and whether you're a patient or a doctor. Doctors also give a specialty and license number.
- **Health and diary data you enter:** foods and servings, nutrition, meals, drinks and fluid limit, blood pressure and blood sugar readings, symptom diary entries (symptoms, severity, stool type and notes), workouts, weigh-ins, body measurements, birth date, sex, activity level, health conditions, goals, daily targets and diet plans.
- **Food photos:** only when you use photo or glasses scanning. See "AI food recognition" below.
- **Apple Health:** only if you connect it. We read workouts, steps and weight, and write the food and weight you log. Apple Health data isn't used for advertising or sold.

We don't collect location, contacts, advertising identifiers or browsing history. The app has no ads, no tracking and no third-party analytics. The Meta glasses SDK's analytics are turned off.

## How we use it

Only to run the app: to show your diary and progress against your targets, to calculate recommended targets, and to share your data with doctors you've accepted. We don't sell your data or use it for advertising.

## Who can see it

- **You.** Each account can read only its own data.
- **Doctors you accept.** A doctor can see your profile, diary, readings, symptoms, workouts, weight and plans only after you accept their request. Doctors can keep their own notes about your care; those notes are visible only to that doctor, are hidden from them if you revoke access, and are deleted with your account. You can revoke access at any time in Care Team, and the doctor loses access immediately. Doctors' license numbers are checked before they can send requests.
- **Service providers** that process data for us:
  - **Supabase** hosts the database and sign-in.
  - **Anthropic** analyzes food photos.
  - **USDA FoodData Central** and **Open Food Facts** answer food searches and barcode lookups. They receive the search text or barcode only, never your account or diary.

## AI food recognition

When you scan food with the camera or the glasses, the photo is sent to Claude, an AI model made by Anthropic, to identify the food and estimate portions. We don't store the photo. Anthropic processes it under its commercial terms, which don't allow using it to train models. You're asked for consent before your first scan, and you can log food by search or barcode instead.

## Retention and deletion

Your data is kept while your account exists. **More › Delete account** permanently deletes your account and everything in it: diary, workouts, weights, foods, plans, and care-team links. Diet plans a doctor wrote for a patient stay with that patient. Backups age out within [your Supabase plan's backup window].

## Security

Data is encrypted in transit (HTTPS). Database rules restrict each row to its owner and the doctors that owner has accepted.

## Children

NutraVision isn't directed to children under 13, and we don't knowingly collect their data.

## Not medical advice

NutraVision shows nutrition information against targets based on published guidelines. It doesn't diagnose or treat any condition. Talk to your doctor before changing your diet.

## Changes

If this policy changes, we'll update the date above and tell you in the app.
