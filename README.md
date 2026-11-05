# NutraVision

NutraVision is an iOS nutrition tracker for people whose diet is shaped by a health condition (diabetes, hypertension, kidney disease, ...) or a training goal (bodybuilding, endurance). It combines Cal AI-style AI food logging with a MyFitnessPal-style diary, condition-aware verdicts on every food, a hands-free Meta Ray-Ban glasses voice loop ("scan this", "add it"), doctor-to-patient linking with consent, and Apple Health integration. Built as a demo / portfolio project.

## Features

- AI photo and barcode logging; text search over USDA FoodData Central (Open Food Facts as barcode fallback)
- Diary, dashboard, and progress views (month calendar, 12-month heatmap)
- Condition-aware verdicts from deterministic on-device rules
- Glasses Mode: look, say "scan this", hear name, calories and verdict, say "add it"
- Doctors link to patients (patient accepts), read logs, and send recommendations
- Diet plans with sample plans and food swaps
- Apple Health: import workouts, write nutrition

## Tech stack

SwiftUI (iOS 17.2+), Swift Charts, HealthKit, Meta Wearables DAT SDK, XcodeGen; Supabase (Auth, Postgres with RLS, Edge Functions); Anthropic Claude for vision; USDA FoodData Central.

## Repo layout

- `ios/` - SwiftUI app (`NutraVision`), `NutraCore` Swift package, XcodeGen `project.yml`
- `supabase/` - migrations, seed, SQL tests, Edge Functions (`food-search`, `analyze-food`)
- `docs/` - setup guide and design spec / plan
- `app/` - earlier Android prototype, not part of NutraVision
- tests: `npm test` at the root (Node + PGlite)

## Docs

- [Setup guide](docs/SETUP.md) (setup, demo accounts, walkthrough, device checks)
- [Design spec](docs/superpowers/specs/2026-11-04-nutravision-design.md)
- [Implementation plan](docs/superpowers/plans/2026-11-04-nutravision.md)

## Disclaimer

Not medical advice. NutraVision is a demo and does not replace guidance from a qualified clinician.
