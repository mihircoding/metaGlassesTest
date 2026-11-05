# NutraVision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing `ios/MetaGlassesVoice` prototype into NutraVision: a Supabase-backed iOS nutrition tracker with
USDA/Open Food Facts search, Claude photo analysis, a hands-free Meta glasses voice loop, doctor ↔ patient linking,
fitness/Apple Health, and condition-aware goals and diet plans.

**Architecture:** SwiftUI app (iOS 17) + a Foundation-only Swift package `NutraCore` holding all testable rules. Supabase
provides Auth, Postgres with row-level security, and two Deno Edge Functions (`food-search`, `analyze-food`) that hold the
USDA and Anthropic keys. Pure TypeScript modules under `supabase/functions/_shared` are tested with Node; SQL is tested
in-process with PGlite.

**Tech Stack:** Swift 5.10 / SwiftUI / Observation / Swift Charts / HealthKit / VisionKit / Speech / AVFoundation ·
supabase-swift 2.55+ · Meta Wearables DAT SDK 1.0 (MWDATCore, MWDATCamera) · Supabase (Postgres 15, Deno Edge Functions) ·
`@anthropic-ai/sdk` 0.137.0 (Deno `npm:`) · Node 26 test runner · `@electric-sql/pglite` 0.5.10 (dev) · XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-04-nutravision-design.md` (read it with this plan; section refs like "spec §3" point there).

## Global Constraints

- iOS deployment target `17.0`; `swift-tools-version: 5.10`; bundle id `com.nutravision.app`; display name `NutraVision`;
  URL scheme `nutravision` (Info.plist `CFBundleURLSchemes` and `MWDAT.AppLinkURLScheme = nutravision://`).
- Swift packages: `https://github.com/supabase/supabase-swift` `from: 2.55.0` (product `Supabase`);
  `https://github.com/meta/meta-wearables-dat-ios` `from: 1.0.0` (products `MWDATCore`, `MWDATCamera`); local `NutraCore`.
  No other Swift dependencies.
- `NutraCore` imports Foundation only (no UIKit, SwiftUI, Combine, os). Every type/func used by the app is `public`.
  It must also build with the Swift toolchains for Linux/Windows.
- Edge TypeScript: erasable syntax only (no `enum`, `namespace`, parameter properties); type-only imports use
  `import type`; relative imports end in `.ts`. Only `*/index.ts` may touch `Deno.*` or `npm:` specifiers.
- JSON/DB names are snake_case exactly as spec §3. Nutrient keys: `kcal, protein_g, carbs_g, fat_g, sat_fat_g,
  sodium_mg, fiber_g, sugar_g`. Target keys: `kcal_target, protein_g, carbs_g, fat_g, sat_fat_g, sodium_mg, fiber_g`.
  Swift rows use explicit `CodingKeys` (no global key strategy). Postgres `date` columns are Swift `String` (`yyyy-MM-dd`).
- Claude: model constant `MODEL = "claude-opus-5-5"`, `output_config.effort: "low"`, structured output via
  `output_config.format`, beta `server-side-fallback-2026-07-01` with `fallbacks: "default"`. No forced `tool_choice`.
- The app holds only the Supabase URL and anon key (`App/Config.swift`). API keys live in Supabase secrets
  `ANTHROPIC_API_KEY`, `FDC_API_KEY`.
- Theme: accent `#10B981`, secondary `#0D9488`; verdict colors Good fit = green, OK in moderation = orange,
  Not recommended = red. Light and dark mode.
- Disclaimer copy (More tab and condition screens): "NutraVision is not medical advice. Talk to your doctor before
  changing your diet."
- Where to run things: `npm test` (Node + PGlite) runs on this Windows machine. `swift test` in `ios/NutraCore` needs a
  Swift toolchain (Mac, or Windows if installed). Xcode builds and device checks run on the owner's Mac; their compile
  errors come back as fix-ups to the same task.
- Commits go to branch `nutravision`, never `main`; every commit message ends with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A USDA/OFF food with no kcal field (only kJ) or missing sat fat/sodium should still return a usable item: kcal from
   kJ ÷ 4.184, missing nutrients as 0 — never NaN or a dropped item. (Task 9 tests.)
2. A barcode read as EAN-13 `0012345678905` must find the product stored as UPC-A `012345678905`, and vice versa.
   (Task 9 + Task 10 tests.)
3. Food logged at 23:30 local time must appear on that local day in Diary and Progress, even though it is stored in
   UTC. (Task 1 `DayKey` test; Task 7 uses local day bounds.)
4. A doctor typing `  Patient@Example.com ` must still reach the patient; typing a doctor's email must fail with
   "No patient with that email". (Task 4 SQL test.)
5. Claude output that is odd but valid JSON (grams 0, negative or 5000; blank names; `is_food: true` with no items)
   must be clamped/dropped/treated as not-food instead of logging a 0 kcal or 50 kg item. (Task 11 tests.)

---

# Phase 1 — Foundation

### Task 1: NutraCore package, Nutrients, Meal slots, day keys

**Files:**
- Create: `ios/NutraCore/Package.swift`, `ios/NutraCore/Sources/NutraCore/Nutrients.swift`,
  `ios/NutraCore/Sources/NutraCore/MealSlot.swift`
- Test: `ios/NutraCore/Tests/NutraCoreTests/NutrientsTests.swift`, `.../MealSlotTests.swift`
- Modify: `.gitignore` (add `node_modules/`, `ios/*.xcodeproj/`, `ios/NutraCore/.build/`, `.DS_Store`)

**Interfaces:**
- Produces:
  - `public struct Nutrients: Codable, Equatable, Sendable { kcal, proteinG, carbsG, fatG, satFatG, sodiumMg, fiberG, sugarG: Double }`
    with memberwise `public init` defaulting every field to 0, `public static let zero`, `static func +`,
    `func scaled(by: Double) -> Nutrients`, `var netCarbsG: Double` (`max(carbsG - fiberG, 0)`). CodingKeys are the
    snake_case nutrient keys. `extension Sequence where Element == Nutrients { public func sum() -> Nutrients }`.
  - `public enum Meal: String, Codable, CaseIterable, Sendable { case breakfast, lunch, dinner, snack }` with
    `public var title: String` ("Breakfast", …, "Snacks").
  - `public enum MealSlot { public static func meal(at: Date, calendar: Calendar = .current) -> Meal }`
  - `public enum DayKey { public static func key(for: Date, calendar: Calendar = .current) -> String }` → `"yyyy-MM-dd"` in the calendar's time zone.

- [ ] **Step 1: Write `Package.swift`** — library product `NutraCore`, target `NutraCore`, test target `NutraCoreTests`,
  `platforms: [.iOS(.v17), .macOS(.v14)]`.

- [ ] **Step 2: Write the failing tests**

```swift
final class NutrientsTests: XCTestCase {
  func testAddScaleSum() {
    let a = Nutrients(kcal: 100, proteinG: 10, sodiumMg: 200)
    let b = Nutrients(kcal: 50, fiberG: 3)
    XCTAssertEqual((a + b).kcal, 150); XCTAssertEqual((a + b).fiberG, 3)
    XCTAssertEqual(a.scaled(by: 1.5), Nutrients(kcal: 150, proteinG: 15, sodiumMg: 300))
    XCTAssertEqual([a, b, a].sum().kcal, 250)
    XCTAssertEqual(Nutrients(carbsG: 10, fiberG: 12).netCarbsG, 0)
  }
  func testSnakeCaseJSON() throws {
    let json = String(data: try JSONEncoder().encode(Nutrients(satFatG: 2)), encoding: .utf8)!
    XCTAssertTrue(json.contains("\"sat_fat_g\":2"))
    let back = try JSONDecoder().decode(Nutrients.self, from: #"{"kcal":5,"protein_g":1,"carbs_g":0,"fat_g":0,"sat_fat_g":0,"sodium_mg":7,"fiber_g":0,"sugar_g":0}"#.data(using: .utf8)!)
    XCTAssertEqual(back.sodiumMg, 7)
  }
}
final class MealSlotTests: XCTestCase {
  let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
  func at(_ h: Int, _ m: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: h, minute: m))! }
  func testBoundaries() {
    let cases: [(Int, Int, Meal)] = [(3,59,.snack),(4,0,.breakfast),(10,59,.breakfast),(11,0,.lunch),(14,59,.lunch),
                                     (15,0,.snack),(16,59,.snack),(17,0,.dinner),(21,29,.dinner),(21,30,.snack)]
    for (h, m, meal) in cases { XCTAssertEqual(MealSlot.meal(at: at(h, m), calendar: utc), meal, "\(h):\(m)") }
  }
  func testDayKeyUsesLocalZone() {
    var ny = Calendar(identifier: .gregorian); ny.timeZone = TimeZone(identifier: "America/New_York")!
    let lateEvening = ISO8601DateFormatter().date(from: "2026-11-04T03:30:00Z")!   // 22:30 on Nov 3 in New York
    XCTAssertEqual(DayKey.key(for: lateEvening, calendar: ny), "2026-11-03")
  }
}
```

- [ ] **Step 3: Run to confirm failure** — `cd ios/NutraCore && swift test` → fails: `cannot find 'Nutrients' in scope`.
- [ ] **Step 4: Implement** `Nutrients.swift` and `MealSlot.swift` (`DayKey` lives in `MealSlot.swift`; build the key from
  `calendar.dateComponents([.year,.month,.day], from:)` with zero-padding — no `DateFormatter`).
- [ ] **Step 5: Run** `swift test` → all pass.
- [ ] **Step 6: Commit** — `git add .gitignore ios/NutraCore && git commit -m "feat(core): NutraCore package with Nutrients, MealSlot, DayKey"`

### Task 2: ConditionCatalog and sample plans

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/ConditionCatalog.swift`, `.../SamplePlans.swift`
- Test: `ios/NutraCore/Tests/NutraCoreTests/ConditionCatalogTests.swift`
- Read (port, don't import): `git show 5e4dec7:ios/MetaGlassesVoice/Models/MedicalCondition.swift` (summary, recommendations,
  avoid lists) and `git show 5e4dec7:ios/MetaGlassesVoice/Views/CreateMealPlanView.swift` (meal templates).

**Interfaces:**
- Consumes: `Nutrients`, `Meal` (Task 1).
- Produces:
  - `public struct Condition: Identifiable, Sendable { id, name, icon: String; proteinPct, carbsPct, fatPct, sodiumMg, satFatPctMax, fiberG: Double; summary: String; recommend, avoid: [String]; flag: KeywordFlag?; samplePlan: [PlanMeal] }`
  - `public enum KeywordFlag: Sendable { case gluten, highFodmap, pregnancyAvoid; public var keywords: [String]; public func matches(_ foodName: String) -> Bool }`
  - `public struct PlanItem: Codable, Equatable, Identifiable, Sendable { id: UUID; name, servingDesc: String; servingGrams: Double?; nutrients: Nutrients }`
    — JSON keys `name, serving_desc, serving_grams` plus the nutrient keys **flattened** (decode with
    `nutrients = try Nutrients(from: decoder)`, encode with `try nutrients.encode(to: encoder)`); `id` decodes to a new
    UUID when absent.
  - `public struct PlanMeal: Codable, Equatable, Sendable { meal: Meal; items: [PlanItem] }`
  - `public enum ConditionCatalog { public static let all: [Condition]; public static func condition(id: String) -> Condition }`
    (unknown id → `general`).

- [ ] **Step 1: Write the failing tests**

```swift
final class ConditionCatalogTests: XCTestCase {
  func testTableValues() {
    XCTAssertEqual(ConditionCatalog.all.map(\.id), ["general","t2_diabetes","t1_diabetes","hypertension","heart_disease",
      "high_cholesterol","ckd","liver","celiac","weight_loss","hypothyroid","ibs","bodybuilding","endurance","pregnancy"])
    let h = ConditionCatalog.condition(id: "hypertension")
    XCTAssertEqual([h.proteinPct, h.carbsPct, h.fatPct, h.sodiumMg, h.satFatPctMax, h.fiberG], [18, 55, 27, 1500, 6, 30])
    let ckd = ConditionCatalog.condition(id: "ckd")
    XCTAssertEqual([ckd.proteinPct, ckd.sodiumMg], [12, 2000])
    XCTAssertEqual(ConditionCatalog.condition(id: "nope").id, "general")
  }
  func testEveryConditionHasUsablePlanAndGuidance() {
    for c in ConditionCatalog.all {
      XCTAssertEqual(c.proteinPct + c.carbsPct + c.fatPct, 100, c.id)
      XCTAssertEqual(Set(c.samplePlan.map(\.meal)), Set(Meal.allCases), c.id)
      let day = c.samplePlan.flatMap(\.items).map(\.nutrients).sum()
      XCTAssertTrue((1400...3400).contains(day.kcal), "\(c.id) kcal \(day.kcal)")
      XCTAssertLessThanOrEqual(day.sodiumMg, c.sodiumMg, c.id)
      XCTAssertFalse(c.recommend.isEmpty || c.avoid.isEmpty || c.summary.isEmpty, c.id)
    }
  }
  func testKeywordFlags() {
    XCTAssertTrue(KeywordFlag.gluten.matches("Whole Wheat Bread"))
    XCTAssertFalse(KeywordFlag.gluten.matches("Brown rice"))
    XCTAssertTrue(KeywordFlag.pregnancyAvoid.matches("Salmon sashimi"))
    XCTAssertTrue(KeywordFlag.highFodmap.matches("garlic naan"))
    XCTAssertEqual(ConditionCatalog.condition(id: "celiac").flag, .gluten)
  }
  func testPlanItemFlatJSON() throws {
    let item = try JSONDecoder().decode(PlanItem.self, from: #"{"name":"Oats","serving_desc":"1 cup","serving_grams":80,"kcal":300,"protein_g":10,"carbs_g":54,"fat_g":5,"sat_fat_g":1,"sodium_mg":5,"fiber_g":8,"sugar_g":1}"#.data(using: .utf8)!)
    XCTAssertEqual(item.nutrients.fiberG, 8)
    let json = String(data: try JSONEncoder().encode(item), encoding: .utf8)!
    XCTAssertTrue(json.contains("\"fiber_g\":8") && !json.contains("nutrients"))
  }
}
```

- [ ] **Step 2: Run** `swift test --filter ConditionCatalogTests` → fails: `cannot find 'ConditionCatalog'`.
- [ ] **Step 3: Implement.** Values from spec §5 table; keyword lists from spec §5 (celiac→`.gluten`, ibs→`.highFodmap`,
  pregnancy→`.pregnancyAvoid`); icons carried over from `MedicalCondition.icon` (new: hypertension `heart.text.square`,
  high_cholesterol `drop.triangle`, endurance `figure.run`, pregnancy `figure.and.child.holdinghands`). Guidance text
  ported for the 11 existing conditions (old→new ids: none→general, diabetes→t2_diabetes, type1Diabetes→t1_diabetes,
  weightTraining→bodybuilding, liverCirrhosis→liver, heartDisease→heart_disease, kidneyDisease→ckd,
  celiacDisease→celiac, obesity→weight_loss, hypothyroidism→hypothyroid, ibs→ibs) and written fresh for the 4 new ones.
  `SamplePlans.swift` holds one day per condition: 4 meals, 1–3 items each, realistic USDA-style nutrients.
  `KeywordFlag.matches` = case-insensitive substring.
- [ ] **Step 4: Run** `swift test` → all pass.
- [ ] **Step 5: Commit** — `feat(core): condition catalog with targets, guidance and sample plans`

### Task 3: TargetCalculator

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/Targets.swift`
- Test: `ios/NutraCore/Tests/NutraCoreTests/TargetCalculatorTests.swift`

**Interfaces:**
- Consumes: `ConditionCatalog.condition(id:)` (Task 2).
- Produces:
  - `public enum Sex: String, Codable, CaseIterable, Sendable { case male, female, unspecified }`
  - `public enum Activity: String, Codable, CaseIterable, Sendable { case sedentary, light, moderate, very, extra; public var multiplier: Double; public var title: String }`
  - `public struct BodyStats: Sendable { sex: Sex; birthDate: Date?; heightCm: Double?; weightKg: Double?; activity: Activity }` (public memberwise init)
  - `public struct Targets: Codable, Equatable, Sendable { kcal, proteinG, carbsG, fatG, satFatG, sodiumMg, fiberG: Double }`
    — CodingKeys are the target keys (`kcal` ↔ `kcal_target`); `public static let defaults = Targets(kcal: 2000, proteinG: 100, carbsG: 250, fatG: 67, satFatG: 22, sodiumMg: 2300, fiberG: 28)`.
  - `public enum TargetCalculator { public static func bmr(_: BodyStats, now: Date) -> Double?; public static func targets(stats: BodyStats, conditionIds: [String], weeklyRateKg: Double, now: Date = Date()) -> Targets }`

Rules (spec §5): Mifflin–St Jeor (+5 / −161 / −78); age = whole years via Gregorian calendar; TDEE × activity;
`+ weeklyRateKg × 7700 / 7`; floor 1500 / 1200 / 1350; pregnancy (any listed id) clamps a negative rate to 0 then +300;
missing height/weight/birthDate → 2000 with no rate or pregnancy adjustment. Round kcal to the nearest 10, then derive
grams from the rounded kcal and round each to a whole number. Empty `conditionIds` = `["general"]`; primary = first id.

- [ ] **Step 1: Write the failing tests**

```swift
final class TargetCalculatorTests: XCTestCase {
  let now = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
  func d(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T12:00:00Z")! }
  lazy var man = BodyStats(sex: .male, birthDate: d("1996-01-15"), heightCm: 180, weightKg: 80, activity: .moderate)

  func testBMR() { XCTAssertEqual(TargetCalculator.bmr(man, now: now), 1780) }
  func testGeneralMaintenance() {
    XCTAssertEqual(TargetCalculator.targets(stats: man, conditionIds: [], weeklyRateKg: 0, now: now),
                   Targets(kcal: 2760, proteinG: 138, carbsG: 345, fatG: 92, satFatG: 31, sodiumMg: 2300, fiberG: 28))
  }
  func testDiabetesPlusHypertensionLosing() {
    XCTAssertEqual(TargetCalculator.targets(stats: man, conditionIds: ["t2_diabetes", "hypertension"], weeklyRateKg: -0.5, now: now),
                   Targets(kcal: 2210, proteinG: 138, carbsG: 221, fatG: 86, satFatG: 15, sodiumMg: 1500, fiberG: 30))
  }
  func testFemaleFloor() {
    let s = BodyStats(sex: .female, birthDate: d("1966-06-01"), heightCm: 155, weightKg: 50, activity: .sedentary)
    XCTAssertEqual(TargetCalculator.targets(stats: s, conditionIds: [], weeklyRateKg: -1, now: now).kcal, 1200)
  }
  func testPregnancyIgnoresLossAndAdds300() {
    let s = BodyStats(sex: .female, birthDate: d("1998-03-10"), heightCm: 165, weightKg: 60, activity: .light)
    XCTAssertEqual(TargetCalculator.targets(stats: s, conditionIds: ["pregnancy"], weeklyRateKg: -0.5, now: now).kcal, 2130)
  }
  func testMissingStats() {
    let s = BodyStats(sex: .unspecified, birthDate: nil, heightCm: nil, weightKg: 70, activity: .light)
    XCTAssertEqual(TargetCalculator.targets(stats: s, conditionIds: [], weeklyRateKg: -1, now: now).kcal, 2000)
  }
  func testTargetsJSONKeys() throws {
    let json = String(data: try JSONEncoder().encode(Targets.defaults), encoding: .utf8)!
    XCTAssertTrue(json.contains("\"kcal_target\":2000"))
  }
}
```

- [ ] **Step 2: Run** `swift test --filter TargetCalculatorTests` → fails: `cannot find 'TargetCalculator'`.
- [ ] **Step 3: Implement** `Targets.swift`.
- [ ] **Step 4: Run** `swift test` → all pass.
- [ ] **Step 5: Commit** — `feat(core): calorie and macro target calculator`

### Task 4: Supabase schema, RLS and database functions

**Files:**
- Create: `package.json`, `supabase/migrations/0001_init.sql`, `supabase/tests/auth_stub.sql`,
  `supabase/tests/rls_check.sql`, `supabase/tests/sql.test.mjs`

**Interfaces:**
- Produces (used by Tasks 5, 7, 18, 19): tables and columns exactly as spec §3; RPCs
  `request_patient(patient_email text) returns care_links`, `respond_care_link(link_id uuid, accept boolean) returns void`,
  `accept_recommendation(rec_id uuid) returns void`; helper `is_doctor_of(p uuid) returns boolean`.
  Error messages: `'No patient with that email'`, `'Only doctors can send requests'`, `'Request not found'`,
  `'Recommendation not found'`.

- [ ] **Step 1: `package.json`** — `"private": true, "type": "module"`, devDependency `"@electric-sql/pglite": "0.5.10"`,
  script `"test": "node --test \"supabase/functions/tests/*.test.ts\" supabase/tests/sql.test.mjs"`. Run `npm install`.

- [ ] **Step 2: `auth_stub.sql`** — mimics the parts of Supabase the migration relies on: roles `anon`, `authenticated`
  (nologin), `service_role` (nologin bypassrls); schema `extensions` with `create extension pgcrypto schema extensions`;
  schema `auth` with `auth.users` (`instance_id uuid, id uuid primary key, aud text, role text, email text,
  encrypted_password text, email_confirmed_at timestamptz, raw_app_meta_data jsonb, raw_user_meta_data jsonb,
  created_at timestamptz, updated_at timestamptz, confirmation_token text, email_change text,
  email_change_token_new text, recovery_token text`) and `auth.identities` (`id uuid primary key default
  gen_random_uuid(), user_id uuid references auth.users, provider_id text, identity_data jsonb, provider text,
  last_sign_in_at timestamptz, created_at timestamptz, updated_at timestamptz`); `auth.uid()` returning
  `nullif(current_setting('request.jwt.claims', true)::json->>'sub', '')::uuid`; usage on schema `auth` and execute on
  `auth.uid()` granted to `authenticated`.

- [ ] **Step 3: Write the failing test — `rls_check.sql`** (also runnable as-is in the Supabase SQL editor)

```sql
begin;
create schema rls_test;   -- rolled back at the end; a real schema so the authenticated role can call the helpers
grant usage on schema rls_test to authenticated;
create function rls_test.ok(cond boolean, label text) returns void language plpgsql as $$
begin if cond is not true then raise exception 'RLS check failed: %', label; end if; end $$;
create function rls_test.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true); $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('d1000000-0000-4000-8000-000000000001', 'rls-doctor@test.local',   '{"role":"doctor","full_name":"Dr RLS"}'),
  ('d1000000-0000-4000-8000-000000000002', 'rls-doctor2@test.local',  '{"role":"doctor","full_name":"Dr Other"}'),
  ('a1000000-0000-4000-8000-000000000001', 'rls-patient@test.local',  '{"role":"patient","full_name":"Pat RLS"}'),
  ('a1000000-0000-4000-8000-000000000002', 'rls-stranger@test.local', '{"role":"patient","full_name":"Stranger"}');
set local role authenticated;

select rls_test.as_user('a1000000-0000-4000-8000-000000000001');
insert into food_logs (user_id, logged_at, meal, name, serving_desc, kcal, source)
  values (auth.uid(), now(), 'lunch', 'Apple', '1 medium', 95, 'manual');
select rls_test.ok((select count(*) from food_logs) = 1, 'patient sees own log');
do $$ begin
  begin update profiles set role = 'doctor' where id = auth.uid(); exception when others then return; end;
  raise exception 'RLS check failed: role change allowed'; end $$;
do $$ begin
  begin insert into care_links (doctor_id, patient_id, status) values ('d1000000-0000-4000-8000-000000000002', auth.uid(), 'accepted');
  exception when others then return; end;
  raise exception 'RLS check failed: patient inserted a link'; end $$;

select rls_test.as_user('a1000000-0000-4000-8000-000000000002');
select rls_test.ok((select count(*) from food_logs) = 0, 'stranger sees no logs');

select rls_test.as_user('d1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from food_logs) = 0, 'unlinked doctor sees no logs');
select rls_test.ok((select count(*) from profiles where id = 'a1000000-0000-4000-8000-000000000001') = 0, 'unlinked doctor cannot read profile');
select request_patient('  RLS-Patient@Test.Local ');
select rls_test.ok((select status from care_links where patient_id = 'a1000000-0000-4000-8000-000000000001') = 'pending', 'request is pending');
select rls_test.ok((select count(*) from food_logs) = 0, 'pending link grants nothing');
do $$ begin
  begin perform request_patient('rls-doctor2@test.local'); exception when others then return; end;
  raise exception 'RLS check failed: requested a doctor'; end $$;
do $$ begin
  begin insert into recommendations (doctor_id, patient_id, kind, payload, message)
        values (auth.uid(), 'a1000000-0000-4000-8000-000000000001', 'note', '{}', 'hi');
  exception when others then return; end;
  raise exception 'RLS check failed: recommended without link'; end $$;

select rls_test.as_user('a1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from profiles where role = 'doctor') = 1, 'patient sees only the requesting doctor');
select respond_care_link((select id from care_links where patient_id = auth.uid()), true);

select rls_test.as_user('d1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from food_logs) = 1, 'linked doctor reads logs');
update food_logs set kcal = 1;
select rls_test.ok((select kcal from food_logs limit 1) = 95, 'doctor cannot edit logs');
insert into recommendations (doctor_id, patient_id, kind, payload, message) values
  (auth.uid(), 'a1000000-0000-4000-8000-000000000001', 'targets',
   '{"targets":{"kcal_target":1800,"protein_g":110,"carbs_g":180,"fat_g":60,"sat_fat_g":12,"sodium_mg":1500,"fiber_g":30}}', 'Lower sodium'),
  (auth.uid(), 'a1000000-0000-4000-8000-000000000001', 'diet_plan',
   '{"diet_plan":{"name":"DASH week 1","condition_id":"hypertension","notes":"","targets":{"kcal_target":1800,"protein_g":110,"carbs_g":180,"fat_g":60,"sat_fat_g":12,"sodium_mg":1500,"fiber_g":30},"meals":[]}}', 'Try this');

select rls_test.as_user('a1000000-0000-4000-8000-000000000001');
select accept_recommendation((select id from recommendations where kind = 'targets'));
select rls_test.ok((select kcal_target = 1800 and sodium_mg = 1500 and targets_source = 'doctor' from profiles where id = auth.uid()), 'targets applied');
select accept_recommendation((select id from recommendations where kind = 'diet_plan'));
select rls_test.ok((select count(*) from diet_plans where is_active) = 1, 'one active plan');
select rls_test.ok((select author_id from diet_plans where is_active) = 'd1000000-0000-4000-8000-000000000001', 'plan authored by doctor');
do $$ begin
  begin perform accept_recommendation((select id from recommendations where kind = 'targets')); exception when others then return; end;
  raise exception 'RLS check failed: accepted twice'; end $$;
update care_links set status = 'revoked' where patient_id = auth.uid();

select rls_test.as_user('d1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from food_logs) = 0, 'revoked doctor sees nothing');
select request_patient('rls-patient@test.local');
select rls_test.ok((select status from care_links where patient_id = 'a1000000-0000-4000-8000-000000000001') = 'pending', 're-request resets to pending');
reset role;
rollback;
```

- [ ] **Step 4: `sql.test.mjs`** — `node:test` file: create `new PGlite({ extensions: { pgcrypto } })` (import from
  `@electric-sql/pglite` and `@electric-sql/pglite/contrib/pgcrypto`), `exec` `auth_stub.sql`, then
  `0001_init.sql`, then `rls_check.sql`; the test passes when no statement throws. (Task 5 appends the seed test.)
- [ ] **Step 5: Run** `npm test` → fails (migration file missing / relation "food_logs" does not exist).
- [ ] **Step 6: Implement `0001_init.sql`.** Tables, checks and indexes per spec §3, including `care_links.patient_email`.
  New profiles default to `Targets.defaults` values and `conditions '{general}'`. Nutrient columns are
  `numeric not null default 0 check (… >= 0)`; `servings numeric not null default 1 check (servings > 0)`. Decisions the spec leaves open:
  - `handle_new_user()` trigger on `auth.users` (security definer, `set search_path = public`): role from
    `raw_user_meta_data->>'role'` (default `patient`), `full_name`, `lower(new.email)`.
  - `lock_role()` before-update trigger on `profiles` raises when `new.role <> old.role`.
  - `is_doctor_of(p)` security definer, stable.
  - Policies per the spec §3 table. Patient `update` on `care_links` only `with check (patient_id = auth.uid() and status = 'revoked')`;
    doctor only `with check (doctor_id = auth.uid() and status = 'revoked')`. Patient `update` on `recommendations` only
    `with check (status = 'declined')`. `diet_plans` owner insert/update `with check (user_id = auth.uid() and author_id = auth.uid())`.
  - Grants (explicit, because Supabase's defaults grant everything): `revoke all on all tables in schema public from anon, authenticated;`
    then `grant select, insert, update, delete` on `profiles, food_logs, custom_foods, workouts, weight_logs, diet_plans`;
    `grant select` on `care_links, recommendations`; `grant insert` on `recommendations`;
    `grant update (status) on care_links, recommendations`; revoke execute on the four functions from `public, anon`
    and grant it to `authenticated`.
  - `request_patient`: caller must be a doctor; match `lower(trim(patient_email))` against `profiles.email` where
    `role = 'patient'`; `insert … on conflict (doctor_id, patient_id) do update set status = 'pending', responded_at = null, patient_email = excluded.patient_email`.
  - `respond_care_link` and `accept_recommendation` as spec §3 (pending-only, caller must be the patient, one transaction).
- [ ] **Step 7: Run** `npm test` → passes.
- [ ] **Step 8: Commit** — `feat(db): schema, RLS and doctor-patient functions with PGlite checks`

### Task 5: Demo seed

**Files:**
- Create: `supabase/seed.sql`
- Modify: `supabase/tests/sql.test.mjs` (add seed test)

**Interfaces:**
- Consumes: schema from Task 4.
- Produces: demo accounts `doctor@nutravision.demo`, `maria@nutravision.demo` (t2_diabetes), `james@nutravision.demo`
  (hypertension), `alex@nutravision.demo` (bodybuilding); password `demo1234` for all.

- [ ] **Step 1: Write the failing test** — second `test()` in `sql.test.mjs` on a fresh PGlite (stub → migration → seed):

```js
const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
assert.equal(Number(await one(`select count(*) from profiles`)), 4);
assert.equal(Number(await one(`select count(*) from care_links where status = 'accepted'`)), 3);
for (const email of ['maria@nutravision.demo', 'james@nutravision.demo', 'alex@nutravision.demo']) {
  const days = await one(`select count(distinct (logged_at at time zone 'UTC')::date) from food_logs f join profiles p on p.id = f.user_id where p.email = '${email}'`);
  assert.equal(Number(days), 30, email);
}
assert.ok(Number(await one(`select count(*) from workouts`)) >= 30);
assert.ok(Number(await one(`select count(*) from weight_logs`)) >= 12);
assert.equal(Number(await one(`select count(*) from recommendations where status = 'pending'`)), 1);
const saltyDays = Number(await one(`select count(*) from (select sum(sodium_mg * servings) s from food_logs f join profiles p on p.id = f.user_id
  where p.email = 'james@nutravision.demo' and logged_at > now() - interval '7 days' group by (logged_at at time zone 'UTC')::date) d where s > 1500`));
assert.ok(saltyDays >= 2 && saltyDays <= 5, `salty days ${saltyDays}`);
assert.equal(Number(await one(`select count(*) from auth.identities`)), 4);
```

- [ ] **Step 2: Run** `npm test` → seed test fails (file missing).
- [ ] **Step 3: Implement `seed.sql`.** Insert the 4 users into `auth.users` with every column the stub defines:
  `instance_id '00000000-0000-0000-0000-000000000000'`, `aud`/`role` `'authenticated'`,
  `encrypted_password extensions.crypt('demo1234', extensions.gen_salt('bf'))`, `email_confirmed_at now()`,
  `raw_app_meta_data '{"provider":"email","providers":["email"]}'`, role/full_name metadata, timestamps, and `''` for the
  four token columns (GoTrue rejects NULLs there); one `auth.identities` row each (`provider 'email'`,
  `provider_id = user id text`, `identity_data {sub, email}`). Update each patient's profile (body stats, conditions,
  targets matching `TargetCalculator` for those stats, `goal_weight_kg`, `weekly_rate_kg`). Accepted links for all three.
  30 days × 3–5 logs per patient via `generate_series` over a per-persona `values` list, varied by day; James exceeds
  1500 mg sodium on 2–5 of the last 7 days. Workouts ~4/week per patient; weekly weights trending toward goal; one pending
  `targets` recommendation for James. Fixed UUIDs so re-running fails loudly instead of duplicating.
- [ ] **Step 4: Run** `npm test` → all pass.
- [ ] **Step 5: Commit** — `feat(db): demo seed with doctor and three patients`

### Task 6: Xcode project, rename and cleanup

**Files:**
- Move: `ios/MetaGlassesVoice/` → `ios/NutraVision/`; `WearablesViewModel.swift`, `RegistrationView.swift`,
  `OnDeviceSpeechRecognizer.swift` → `ios/NutraVision/Glasses/`
- Delete: `ContentView.swift`, `BarcodeScannerSession.swift`, `MetaGlassesVoiceApp.swift`, `Models/`, `Services/`,
  `ViewModels/`, `Views/` (all files), `ios/SETUP.txt` — originals stay readable via `git show 5e4dec7:<path>`
- Create: `ios/project.yml`, `ios/NutraVision/App/NutraVisionApp.swift`, `App/RootView.swift` (temporary
  `Text("NutraVision")` body, replaced in Task 8), `App/Config.swift`, `App/Theme.swift`,
  `ios/NutraVision/NutraVision.entitlements`, `docs/SETUP.md`
- Modify: `ios/NutraVision/Info.plist`

**Interfaces:**
- Produces: `enum Config { static let supabaseURL: URL; static let supabaseAnonKey: String }` (placeholder values the
  owner fills); `enum Theme { static let accent, accent2, good, moderation, bad: Color }`; `WearablesViewModel`
  injected via `.environment` from `NutraVisionApp` (converted to `@Observable`, registration API unchanged in SDK 1.0).

- [ ] **Step 1: `project.yml`** — packages `Supabase` (`url`, `from: 2.55.0`), `MWDAT` (`url`, `from: 1.0.0`),
  `NutraCore` (`path: NutraCore`). Target `NutraVision` (application, iOS): `sources: [{path: NutraVision, excludes: [Info.plist]}]`,
  settings `INFOPLIST_FILE: NutraVision/Info.plist`, `PRODUCT_BUNDLE_IDENTIFIER: com.nutravision.app`,
  `CODE_SIGN_ENTITLEMENTS: NutraVision/NutraVision.entitlements`, `DEVELOPMENT_TEAM: ""`; dependencies `Supabase`,
  `MWDAT/MWDATCore`, `MWDAT/MWDATCamera`, `NutraCore`. (NutraCore's tests run with `swift test`, not through this project.)
- [ ] **Step 2: Info.plist** — keep the existing external-accessory, background-mode and MWDAT keys; set
  `CFBundleDisplayName` NutraVision, URL scheme `nutravision`, `MWDAT.AppLinkURLScheme` `nutravision://`; add usage strings
  `NSCameraUsageDescription` ("Scan food and barcodes with your phone camera."), `NSMicrophoneUsageDescription`
  ("Hear voice commands like 'scan this' and 'add it'."), `NSSpeechRecognitionUsageDescription` ("Understand voice
  commands on your device."), `NSHealthShareUsageDescription` ("Import workouts, steps and weight from Apple Health."),
  `NSHealthUpdateUsageDescription` ("Save the food and weight you log to Apple Health."). Entitlements:
  `com.apple.developer.healthkit = true`, `com.apple.developer.healthkit.access = []`.
- [ ] **Step 3: App shell** — `NutraVisionApp` keeps `Wearables.configure()` and the `RegistrationView` overlay from the
  old `MetaGlassesVoiceApp`, shows `RootView`.
- [ ] **Step 4: `docs/SETUP.md`** — spec §12 steps, plus: in Supabase Auth settings turn off "Confirm email" (demo),
  `supabase init` then `supabase link --project-ref <ref>`, `supabase db push`, run `supabase/seed.sql` in the SQL editor,
  run `supabase/tests/rls_check.sql` in the SQL editor (expects "Success. No rows returned").
- [ ] **Step 5: Verify here** — `grep -rnE "NutritionDataStore|NutritionViewModel|DoctorViewModel|AIFoodScannerService|FoodDatabaseService|MedicalCondition|FoodEntry|BarcodeScannerSession|StreamSession\(" ios/NutraVision` → no output.
- [ ] **Step 6: Verify on Mac** — `cd ios && xcodegen generate && xcodebuild -project NutraVision.xcodeproj -scheme NutraVision -destination 'generic/platform=iOS' build`
  → `BUILD SUCCEEDED`; `cd NutraCore && swift test` → all pass.
- [ ] **Step 7: Commit** — `chore(ios): rename to NutraVision, XcodeGen project, remove legacy local-only code`

### Task 7: Data layer (rows, Backend, AppModel)

**Files:**
- Create: `ios/NutraVision/Data/Rows.swift`, `Data/FoodItem.swift`, `Data/Backend.swift`, `Data/AppModel.swift`, `Data/DayModel.swift`

**Interfaces:**
- Consumes: `Nutrients`, `Targets`, `Sex`, `Activity`, `Meal`, `TargetCalculator`, `BodyStats` (Tasks 1–3); RPC names (Task 4).
- Produces:
  - Rows (all `Codable, Identifiable, Equatable`, explicit snake_case `CodingKeys`, nutrients/targets flattened like `PlanItem`):
    `ProfileRow { id: UUID; role: Role(.patient/.doctor); fullName, email: String; birthDate: String?; sex: Sex; heightCm, weightKg: Double?; activity: Activity; conditions: [String]; goalWeightKg: Double?; weeklyRateKg: Double; targets: Targets; targetsSource: TargetsSource(.auto/.custom/.doctor); addExerciseKcal: Bool; specialty, licenseNumber: String? }`
    with `var bodyStats: BodyStats`;
    `FoodLogRow { id: UUID; userId: UUID; loggedAt: Date; meal: Meal; name: String; brand: String?; servingDesc: String; servingGrams: Double?; servings: Double; perServing: Nutrients; source: FoodSource; sourceRef: String?; aiConfidence: String?; scanId: UUID? }` with `var total: Nutrients { perServing.scaled(by: servings) }`;
    `enum FoodSource: String, Codable { case manual, search, barcode, glassesAI = "glasses_ai", photoAI = "photo_ai", plan }`;
    `CustomFoodRow`, `WorkoutRow { kind: ExerciseKind …}` (until Task 20 adds `ExerciseKind`, store `kind: String`), `WeightLogRow`,
    `DietPlanRow { meals: [PlanMeal]; targets: Targets; … }`, `CareLinkRow`, `RecommendationRow { kind; payload: RecommendationPayload; … }`
    where `RecommendationPayload { targets: Targets?; dietPlan: DietPlanDraft? }` and `DietPlanDraft { name, conditionId, notes: String; targets: Targets; meals: [PlanMeal] }`.
  - `FoodItem` / `AnalyzeResult` / `AnalyzedItem` Swift mirrors of spec §4 types; `AnalyzedItem.source` is
    `enum NutrientSource: String, Codable { case usda, off, aiEstimate = "ai_estimate" }`, and
    `AnalyzedItem.init(product: FoodItem)` (grams = `servingGrams ?? 100`, confidence `high`, nutrients = `perServing`,
    source/sourceRef carried over) lets barcode results use the same scan card and logging path as photo scans.
  - `@MainActor final class Backend { static let shared; let client: SupabaseClient }` with:
    auth `signUp(email:password:fullName:role:)`, `signIn(email:password:)`, `signOut()`, `var userId: UUID?`;
    `profile(id:) -> ProfileRow`, `profiles(ids: [UUID]) -> [ProfileRow]`, `updateProfile(_:)`;
    `foodLogs(userId:day:) -> [FoodLogRow]`, `foodLogs(userId:from:to:)`, `insertFoodLogs(_:)`, `updateFoodLog(_:)`,
    `deleteFoodLog(id:)`, `recentFoods(userId:limit: Int = 30) -> [FoodLogRow]` (newest first, unique by lowercased name);
    `customFoods(matching:) -> [CustomFoodRow]`, `insertCustomFood(_:)`;
    `searchFoods(query:) -> [FoodItem]`, `lookupBarcode(_:) -> [FoodItem]`, `analyzePhoto(jpeg: Data) -> AnalyzeResult`;
    `workouts(userId:from:to:)`, `insertWorkout(_:)`, `upsertWorkouts(_:)` (on conflict `user_id,healthkit_uuid`), `deleteWorkout(id:)`;
    `weights(userId:from:to:)`, `insertWeight(_:)`, `upsertWeights(_:)`;
    `dietPlans(userId:)`, `saveDietPlan(_:)`, `activatePlan(id:userId:)` (deactivate others first);
    `careLinks()`, `requestPatient(email:)`, `respondCareLink(id:accept:)`, `revokeCareLink(id:)`;
    `recommendations()`, `sendRecommendation(_:)`, `acceptRecommendation(id:)`, `declineRecommendation(id:)`. All `async throws`.
    Day queries use `Calendar.current.dateInterval(of: .day, for:)` (local midnight to midnight).
  - `@Observable @MainActor final class DayModel { userId: UUID; date: Date; logs: [FoodLogRow]; workouts: [WorkoutRow]; var consumed: Nutrients; var exerciseKcal: Double; func load() async throws }`
  - `@Observable @MainActor final class AppModel { enum Phase { loading, signedOut, onboarding, patient, doctor }; phase; profile: ProfileRow?; today: DayModel?; banner: String?; var targets: Targets; var dailyGoalKcal: Double; func start() async; func saveProfile(_:) async throws; func refresh() async }`
    — `start()` listens to `client.auth.authStateChanges`; patients without `heightCm` go to `.onboarding`.
    `saveProfile` recomputes `targets` with `TargetCalculator` when `targetsSource == .auto`.
    `dailyGoalKcal = targets.kcal + (addExerciseKcal ? today.exerciseKcal : 0)`.

- [ ] **Step 1: Implement the five files.** `functions.invoke("food-search", options: .init(body: ["query": q]))` decoding
  `{items: [FoodItem]}`; `analyze-food` body `{image_base64, media_type: "image/jpeg"}`. Map Supabase/function errors to
  `BackendError.message(String)` with the server's `{error}` text when present.
- [ ] **Step 2: Verify on Mac** — project builds (Task 6 command).
- [ ] **Step 3: Commit** — `feat(ios): Supabase data layer, AppModel and DayModel`

### Task 8: Auth, onboarding and tab shells

**Files:**
- Create: `Features/Auth/WelcomeView.swift`, `Features/Auth/SignInView.swift`, `Features/Auth/SignUpView.swift`,
  `Features/Onboarding/OnboardingView.swift`, `Features/Profile/ProfileGoalsView.swift`, `Features/More/MoreView.swift`,
  `App/PatientTabs.swift`, `App/DoctorTabs.swift`
- Modify: `App/RootView.swift` (switch on `AppModel.phase`)

**Interfaces:**
- Consumes: `AppModel`, `Backend` (Task 7), `ConditionCatalog`, `TargetCalculator`.
- Produces: `PatientTabs` with tabs Dashboard | Diary | ＋ | Progress | More (Dashboard/Diary/Progress show placeholders
  until Tasks 14/22); `DoctorTabs` with Patients | Requests | More placeholders; `ProfileGoalsView` reused by onboarding's
  last step and by More.

- [ ] **Step 1: Implement.** Sign-up has name, email, password (≥ 8 chars, validated inline), and a Patient/Doctor segmented
  picker (doctors also enter specialty and license #, saved after sign-up). Onboarding (patients): sex, birth date,
  height (cm or ft/in), weight (kg or lb), activity, conditions (multi-select from `ConditionCatalog.all`, first tap = primary,
  marked "Primary"), goal weight + pace slider −1…+1 kg/week in 0.25 steps (label shows lb too). Final step shows computed
  targets, editable; editing any target sets `targetsSource = .custom`; "Reset to recommended" sets `.auto`. Profile & Goals
  also has the "Add exercise calories to goal" toggle (`addExerciseKcal`, default on).
  More: Profile & Goals, Sign out, disclaimer (rows for later tasks appear as they land).
- [ ] **Step 2: Verify on Mac (simulator)** — sign up as a patient with Type 2 diabetes + Hypertension, 180 cm, 80 kg,
  born 1996-01-15, moderate, −0.5 kg/week → targets screen shows 2210 kcal / 1500 mg sodium (matching
  `TargetCalculator` tests); relaunch keeps you signed in; sign out → Welcome; sign in as `doctor@nutravision.demo`
  → Doctor tabs.
- [ ] **Step 3: Commit** — `feat(ios): auth, onboarding and tab shells`

# Phase 2 — Food data and AI

### Task 9: Nutrient mapping (TypeScript)

**Files:**
- Create: `supabase/functions/_shared/nutrients.ts`, `supabase/functions/_shared/fdc.ts`
- Create fixtures: `supabase/functions/tests/fixtures/fdc_search_text.json`, `fdc_search_barcode.json`, `off_product.json`
  — record real responses with `DEMO_KEY` (FDC `POST https://api.nal.usda.gov/fdc/v1/foods/search?api_key=DEMO_KEY`,
  queries `"greek yogurt"` all data types and `"031200037206"` Branded) and OFF product `3017620422003`; trim to 2 foods.
- Test: `supabase/functions/tests/nutrients.test.ts`

**Interfaces:**
- Produces:
  - `export type Nutrients = { kcal: number; protein_g: number; carbs_g: number; fat_g: number; sat_fat_g: number; sodium_mg: number; fiber_g: number; sugar_g: number }`; `export const ZERO: Nutrients`
  - `export function scale(n: Nutrients, factor: number): Nutrients` (each field × factor, rounded to 1 decimal)
  - `export function sum(list: Nutrients[]): Nutrients` (rounded to 1 decimal)
  - `export function fromFdc(list: { nutrientId: number; value?: number }[]): Nutrients` — per 100 g; ids from spec §4; energy
    `1008` → `2047` → `2048` → `1062 / 4.184`; every field rounded to 1 decimal
  - `export function fromOff(n: Record<string, unknown>): Nutrients` — per 100 g; kcal `energy-kcal_100g` → `energy_100g / 4.184`;
    sodium `sodium_100g × 1000` → `salt_100g × 400`; numeric strings accepted; missing → 0; every field rounded to 1 decimal
  - `export function barcodeVariants(code: string): string[]` — digits only; 12 digits → also `"0" + code`; 13 digits with
    leading 0 → also `code.slice(1)`; original first, deduped
  - `export function titleCase(s: string): string`
  - `export type FoodItem` (spec §4), `export type FdcFood`, `export type OffProduct`
  - `export function fdcFoodToItem(food: FdcFood): FoodItem` — Branded with `servingSize` and unit `g`/`GRM`/`ml`/`MLT`:
    per serving = per-100 g × size / 100, `serving_grams = size`, `serving_desc = household ? \`${household} (${size} g)\` : \`${size} g\``,
    name title-cased, brand `brandName ?? brandOwner`; otherwise per 100 g, `serving_desc "100 g"`, `serving_grams 100`
  - `export function offProductToItem(code: string, p: OffProduct): FoodItem | null` — null without `product_name`;
    `serving_quantity` (number or numeric string) scales per serving, `serving_desc = serving_size ?? "100 g"`
  - `fdc.ts`: `export type FetchFn = typeof fetch`;
    `export async function searchFdc(query: string, dataTypes: string[], apiKey: string, fetchFn: FetchFn, pageSize = 25): Promise<FdcFood[]>`
    (POST JSON `{query, dataType, pageSize}`; non-2xx → `throw new Error(\`fdc ${status}\`)`);
    `export async function fetchOffProduct(code: string, fetchFn: FetchFn): Promise<OffProduct | null>`
    (`GET https://world.openfoodfacts.org/api/v2/product/${code}.json?fields=product_name,brands,serving_size,serving_quantity,nutriments`,
    header `User-Agent: NutraVision/1.0 (demo app)`; `status !== 1` or 404 → null; other non-2xx → throw)

- [ ] **Step 1: Write the failing tests**

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { fromFdc, fromOff, scale, sum, barcodeVariants, titleCase, fdcFoodToItem, offProductToItem } from "../_shared/nutrients.ts";

test("fromFdc energy fallbacks and missing fields", () => {
  assert.deepEqual(fromFdc([{ nutrientId: 1008, value: 52 }, { nutrientId: 1003, value: 0.3 }, { nutrientId: 1093, value: 1 }]),
    { kcal: 52, protein_g: 0.3, carbs_g: 0, fat_g: 0, sat_fat_g: 0, sodium_mg: 1, fiber_g: 0, sugar_g: 0 });
  assert.equal(fromFdc([{ nutrientId: 2047, value: 100 }]).kcal, 100);
  assert.equal(fromFdc([{ nutrientId: 1062, value: 418.4 }]).kcal, 100);
  assert.equal(fromFdc([{ nutrientId: 1008 }]).kcal, 0);
});
test("fromOff salt, kJ and strings", () => {
  assert.equal(fromOff({ sodium_100g: 0.4 }).sodium_mg, 400);
  assert.equal(fromOff({ salt_100g: 1 }).sodium_mg, 400);
  assert.equal(fromOff({ energy_100g: 1000 }).kcal, 239);
  assert.equal(fromOff({ "energy-kcal_100g": "120", "saturated-fat_100g": "2.5" }).sat_fat_g, 2.5);
});
test("scale and sum round to one decimal", () => {
  assert.equal(scale({ ...fromFdc([{ nutrientId: 1008, value: 165 }]) }, 1.5).kcal, 247.5);
  assert.equal(sum([scale(fromFdc([{ nutrientId: 1003, value: 1 }]), 0.33), scale(fromFdc([{ nutrientId: 1003, value: 1 }]), 0.33)]).protein_g, 0.6);
});
test("barcode variants", () => {
  assert.deepEqual(barcodeVariants("012345678905"), ["012345678905", "0012345678905"]);
  assert.deepEqual(barcodeVariants("0012345678905"), ["0012345678905", "012345678905"]);
  assert.deepEqual(barcodeVariants(" 4006381333931 "), ["4006381333931"]);
});
test("titleCase", () => assert.equal(titleCase("GREEK YOGURT, PLAIN"), "Greek Yogurt, Plain"));
test("branded FDC food uses labeled serving", () => {
  const item = fdcFoodToItem({ fdcId: 2035482, description: "GREEK YOGURT", dataType: "Branded", brandName: "OCEAN SPRAY",
    servingSize: 30, servingSizeUnit: "g", householdServingFullText: "2 Tbsp",
    foodNutrients: [{ nutrientId: 1008, value: 400 }, { nutrientId: 1003, value: 3.33 }] });
  assert.deepEqual([item.name, item.brand, item.source, item.source_ref, item.serving_desc, item.serving_grams, item.per_serving.kcal],
    ["Greek Yogurt", "OCEAN SPRAY", "usda", "2035482", "2 Tbsp (30 g)", 30, 120]);
});
test("generic FDC food is per 100 g", () => {
  const item = fdcFoodToItem({ fdcId: 1, description: "Apples, raw", dataType: "Foundation", foodNutrients: [{ nutrientId: 2047, value: 52 }] });
  assert.deepEqual([item.name, item.serving_desc, item.serving_grams, item.per_serving.kcal], ["Apples, raw", "100 g", 100, 52]);
});
test("OFF product", () => {
  assert.equal(offProductToItem("1", { nutriments: {} }), null);
  const item = offProductToItem("3017620422003", { product_name: "Nutella", brands: "Ferrero", serving_size: "15 g", serving_quantity: "15",
    nutriments: { "energy-kcal_100g": 540, sodium_100g: 0.04 } })!;
  assert.deepEqual([item.source, item.serving_desc, item.serving_grams, item.per_serving.kcal, item.per_serving.sodium_mg],
    ["off", "15 g", 15, 81, 6]);
});
test("recorded fixtures map without NaN", async () => {
  const { readFile } = await import("node:fs/promises");
  for (const f of ["fdc_search_text.json", "fdc_search_barcode.json"]) {
    const foods = JSON.parse(await readFile(new URL(`./fixtures/${f}`, import.meta.url), "utf8")).foods;
    for (const item of foods.map(fdcFoodToItem)) for (const v of Object.values(item.per_serving)) assert.ok(Number.isFinite(v));
  }
});
```

- [ ] **Step 2: Run** `npm test` → fails: `Cannot find module '../_shared/nutrients.ts'`.
- [ ] **Step 3: Implement** `nutrients.ts` and `fdc.ts`; record the fixtures.
- [ ] **Step 4: Run** `npm test` → all pass.
- [ ] **Step 5: Commit** — `feat(functions): USDA and Open Food Facts nutrient mapping`

### Task 10: `food-search` function

**Files:**
- Create: `supabase/functions/_shared/search.ts`, `supabase/functions/food-search/index.ts`
- Test: `supabase/functions/tests/search.test.ts`

**Interfaces:**
- Consumes: Task 9 exports.
- Produces: `export async function handleFoodSearch(req: Request, deps: { fdcKey: string; fetchFn: FetchFn }): Promise<Response>`;
  `index.ts` is `Deno.serve((req) => handleFoodSearch(req, { fdcKey: Deno.env.get("FDC_API_KEY") ?? "", fetchFn: fetch }))`.

Behavior: non-POST → 405; bad JSON, neither field, or `query` shorter than 2 chars → 400 `{error: "Send a query or a barcode"}`;
text → `searchFdc(query, ["Foundation","SR Legacy","Survey (FNDDS)","Branded"])` → `{items}`; barcode → for each variant,
`searchFdc(variant, ["Branded"], …, 10)` and keep foods whose `gtinUpc` is in the variants → first match; else
`fetchOffProduct` per variant → first hit; else `{items: []}`; any upstream throw → 502 `{error: "Food database unavailable"}`.

- [ ] **Step 1: Write the failing tests** — a `fakeFetch(routes)` helper returning `new Response(JSON.stringify(body), {status})`
  by URL substring + request body. Cases (assert status and `items` content):
  1. `{query: "greek yogurt"}` with the text fixture → 200, `items.length === fixture.foods.length`, `items[0].source === "usda"`.
  2. `{barcode: "0031200037206"}` (EAN-13 form) where FDC returns the food with `gtinUpc: "031200037206"` → 200, 1 item.
  3. `{barcode: "3017620422003"}`, FDC returns `{foods: []}`, OFF returns the fixture → 200, `items[0].source === "off"`.
  4. Barcode found nowhere (FDC empty, OFF `{status: 0}`) → 200, `items: []`.
  5. `{}` → 400; `GET` → 405; FDC answers 500 for a text query → 502 `{error: "Food database unavailable"}`.
- [ ] **Step 2: Run** `npm test` → fails: cannot find `../_shared/search.ts`.
- [ ] **Step 3: Implement** `search.ts` and `index.ts`.
- [ ] **Step 4: Run** `npm test` → all pass.
- [ ] **Step 5: Commit** — `feat(functions): food-search edge function`

### Task 11: `analyze-food` function

**Files:**
- Create: `supabase/functions/_shared/claude.ts`, `supabase/functions/_shared/analyze.ts`, `supabase/functions/analyze-food/index.ts`
- Test: `supabase/functions/tests/analyze.test.ts`

**Interfaces:**
- Consumes: Task 9 exports.
- Produces:
  - `claude.ts`: `export const MODEL = "claude-opus-5-5"`; `export const SYSTEM_PROMPT: string`; `export const OUTPUT_SCHEMA`
    (JSON schema: object, `additionalProperties: false`, required `is_food, notes, package, items`; `package` is
    `anyOf [null, {brand, product}]`; each item requires `name, fdc_query, grams, cooking_method, confidence (enum high|medium|low), estimate`
    with `estimate` an object of the 8 nutrient keys, all numbers); `export type ClaudeFood`, `export type ClaudeItem`;
    `export function parseClaudeFood(text: string): ClaudeFood` — throws on invalid JSON/shape; clamps `grams` to [1, 2000];
    drops items whose trimmed name is empty; `is_food` becomes false when no items remain.
  - `analyze.ts`: `export type CallClaude = (imageB64: string, mediaType: string) => Promise<ClaudeFood>`;
    `export type AnalyzedItem` (spec §4); `export async function handleAnalyzeFood(req: Request, deps: { fdcKey: string; fetchFn: FetchFn; callClaude: CallClaude }): Promise<Response>`.

SYSTEM_PROMPT must tell Claude to: list each distinct food separately; estimate grams of the visible portion using plate
(~27 cm), utensils and hands for scale; write `fdc_query` in USDA naming style ("Chicken, breast, roasted"); give
`estimate` for the estimated grams; read brand/product from visible packaging into `package`; set `is_food` false when
no food is visible; keep `notes` to one sentence.

Handler: non-POST → 405; `image_base64` missing/empty/over 1,500,000 chars or `media_type` not `image/jpeg|image/png` → 400;
`callClaude` throws → 502 `{error: "AI analysis failed"}`; not food → 200 `{is_food: false, items: [], totals: ZERO, notes}`;
otherwise per item in parallel: `searchFdc(fdc_query, ["Survey (FNDDS)","Foundation","SR Legacy"], key, fetchFn, 5)` →
first food → `nutrients = scale(fromFdc(food.foodNutrients), grams / 100)`, `source "usda"`, `source_ref` fdcId;
no food or FDC throws → `estimate`, `source "ai_estimate"`; item `name` is Claude's name; `totals = sum(items)`.

- [ ] **Step 1: Write the failing tests**

```ts
test("parseClaudeFood clamps and drops", () => {
  const base = { name: "Rice", fdc_query: "Rice, white, cooked", cooking_method: "boiled", confidence: "high",
    estimate: { kcal: 200, protein_g: 4, carbs_g: 44, fat_g: 0.4, sat_fat_g: 0.1, sodium_mg: 2, fiber_g: 0.6, sugar_g: 0 } };
  const r = parseClaudeFood(JSON.stringify({ is_food: true, notes: "", package: null, items: [
    { ...base, grams: 0 }, { ...base, grams: -5 }, { ...base, grams: 5000 }, { ...base, name: "  ", grams: 100 }] }));
  assert.deepEqual(r.items.map(i => i.grams), [1, 1, 2000]);
  assert.equal(parseClaudeFood(JSON.stringify({ is_food: true, notes: "", package: null, items: [] })).is_food, false);
  assert.throws(() => parseClaudeFood("not json"));
});
```
  Handler cases with a fake `callClaude` and `fakeFetch` (from Task 10's helper, moved to `tests/helpers.ts`):
  1. One item, 150 g, FDC returns a food with `1008: 165` → item `{source: "usda", nutrients.kcal: 247.5}`, `totals.kcal 247.5`.
  2. Two items, FDC empty for the second → second item `source "ai_estimate"` with its `estimate`; totals = sum of both.
  3. FDC returns 500 for every query → all items `ai_estimate`, status 200.
  4. `callClaude` returns `{is_food: false, …}` → `{is_food: false, items: []}`.
  5. `callClaude` throws → 502; missing image → 400; `media_type: "image/gif"` → 400.
- [ ] **Step 2: Run** `npm test` → fails: cannot find `../_shared/claude.ts`.
- [ ] **Step 3: Implement** `claude.ts`, `analyze.ts`, and `analyze-food/index.ts`:

```ts
import Anthropic from "npm:@anthropic-ai/sdk@0.137.0";
import { MODEL, OUTPUT_SCHEMA, SYSTEM_PROMPT, parseClaudeFood } from "../_shared/claude.ts";
import { handleAnalyzeFood, type CallClaude } from "../_shared/analyze.ts";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
const callClaude: CallClaude = async (data, mediaType) => {
  const res = await client.beta.messages.create({
    model: MODEL, max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"], fallbacks: "default",
    output_config: { effort: "low", format: { type: "json_schema", schema: OUTPUT_SCHEMA } },
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: [
      { type: "image", source: { type: "base64", media_type: mediaType, data } },
      { type: "text", text: "Identify the food in this photo." },
    ] }],
  });
  if (res.stop_reason === "refusal") throw new Error("refused");
  const text = res.content.find((b) => b.type === "text");
  return parseClaudeFood(text && "text" in text ? text.text : "");
};
Deno.serve((req) => handleAnalyzeFood(req, { fdcKey: Deno.env.get("FDC_API_KEY") ?? "", fetchFn: fetch, callClaude }));
```
  If the 0.137.0 types reject `fallbacks: "default"` or `output_config.format`, keep the fields and cast the params object
  (`as unknown as Anthropic.Beta.MessageCreateParamsNonStreaming`); do not drop them.
- [ ] **Step 4: Run** `npm test` → all pass.
- [ ] **Step 5: Verify after the owner deploys** — `supabase functions deploy analyze-food food-search`, then from the app's
  photo scan (Task 13) a plate photo returns items within ~8 s.
- [ ] **Step 6: Commit** — `feat(functions): analyze-food with Claude identification and USDA nutrients`

### Task 12: HealthVerdict

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/Verdict.swift`
- Test: `ios/NutraCore/Tests/NutraCoreTests/VerdictTests.swift`

**Interfaces:**
- Consumes: `Nutrients`, `Targets`, `ConditionCatalog`, `KeywordFlag`.
- Produces: `public enum Severity: Int, Comparable { case bad, caution, good }`; `public struct VerdictReason: Equatable { severity: Severity; text: String }`;
  `public enum VerdictLevel: String { case goodFit = "Good fit", moderation = "OK in moderation", notRecommended = "Not recommended" }`;
  `public struct Verdict: Equatable { level: VerdictLevel; reasons: [VerdictReason] }`;
  `public enum HealthVerdict { public static func evaluate(name: String, item: Nutrients, targets: Targets, dailyGoalKcal: Double, consumed: Nutrients, conditionIds: [String]) -> Verdict }`.

Rules are spec §5's table, each producing **one** reason whose severity is upgraded by the condition (never two reasons
for the same rule). Reason copy (numbers via `Int(x.rounded())`):

| Rule | Text |
|---|---|
| item sodium | `High sodium, {mg} mg, {pct}% of your daily limit` |
| day sodium | `Puts you over today's sodium limit` |
| sat fat | `High saturated fat, {g} g` |
| net carbs | `High carbs, {g} g net carbs` |
| sugar | `High sugar, {g} g` |
| ckd protein | `High protein for a kidney diet, {g} g` |
| calories | `Puts you {kcal} kcal over today's goal` |
| gluten / pregnancy / fodmap | `May contain gluten` / `Not advised during pregnancy` / `High-FODMAP ingredient` |
| protein density / carbs / fiber | `Great protein source` / `Good carb fuel` / `Good source of fiber` |

Reasons are evaluated in the table's order, stable-sorted by severity, and capped at 2.

- [ ] **Step 1: Write the failing tests** — helper `let T = Targets(kcal: 2000, proteinG: 100, carbsG: 250, fatG: 67, satFatG: 20, sodiumMg: 2000, fiberG: 28)`.

```swift
func testCaesarForHypertensiveDiabetic() {
  var t = T; t.sodiumMg = 1500; t.satFatG = 15
  let v = HealthVerdict.evaluate(name: "Chicken Caesar salad",
    item: Nutrients(kcal: 470, proteinG: 34, carbsG: 20, fatG: 30, satFatG: 8, sodiumMg: 1100, fiberG: 4, sugarG: 4),
    targets: t, dailyGoalKcal: 2210, consumed: Nutrients(kcal: 1500, sodiumMg: 900), conditionIds: ["t2_diabetes", "hypertension"])
  XCTAssertEqual(v.level, .notRecommended)
  XCTAssertEqual(v.reasons.map(\.text), ["High sodium, 1100 mg, 73% of your daily limit", "Puts you over today's sodium limit"])
}
func testGeneralSodiumIsCaution() {
  let v = HealthVerdict.evaluate(name: "Soup", item: Nutrients(kcal: 150, sodiumMg: 900), targets: T, dailyGoalKcal: 2000, consumed: .zero, conditionIds: [])
  XCTAssertEqual(v, Verdict(level: .moderation, reasons: [VerdictReason(severity: .caution, text: "High sodium, 900 mg, 45% of your daily limit")]))
}
func testHeartSatFatBad() {
  XCTAssertEqual(eval(Nutrients(kcal: 300, satFatG: 11), ["heart_disease"]),
                 Verdict(level: .notRecommended, reasons: [VerdictReason(severity: .bad, text: "High saturated fat, 11 g")]))
}
func testDiabetesCarbsAndSugar() {
  XCTAssertEqual(eval(Nutrients(kcal: 300, carbsG: 60, fiberG: 5), ["t2_diabetes"]).reasons.first, VerdictReason(severity: .bad, text: "High carbs, 55 g net carbs"))
  XCTAssertEqual(eval(Nutrients(kcal: 300, carbsG: 40, fiberG: 5), ["t2_diabetes"]).level, .moderation)
  XCTAssertEqual(eval(Nutrients(kcal: 100, sugarG: 20), ["t1_diabetes"]).reasons.first?.severity, .caution)
  XCTAssertEqual(eval(Nutrients(kcal: 100, sugarG: 30), ["t1_diabetes"]).reasons.first?.severity, .bad)
}
func testKidneyProtein() { XCTAssertEqual(eval(Nutrients(kcal: 300, proteinG: 35), ["ckd"]).reasons.first?.text, "High protein for a kidney diet, 35 g") }
func testCalories() {
  XCTAssertEqual(evalWith(consumed: 1800, kcal: 300, ["general"]).reasons.first, VerdictReason(severity: .caution, text: "Puts you 100 kcal over today's goal"))
  XCTAssertEqual(evalWith(consumed: 1800, kcal: 300, ["weight_loss"]).level, .moderation)
  XCTAssertEqual(evalWith(consumed: 2000, kcal: 300, ["weight_loss"]).level, .notRecommended)
}
func testKeywords() {
  XCTAssertEqual(eval(Nutrients(kcal: 80), ["celiac"], name: "Whole wheat bread").reasons.first?.text, "May contain gluten")
  XCTAssertEqual(eval(Nutrients(kcal: 80), ["pregnancy"], name: "Salmon sashimi").level, .notRecommended)
  XCTAssertEqual(eval(Nutrients(kcal: 80), ["ibs"], name: "Garlic bread").level, .moderation)
}
func testPositives() {
  XCTAssertEqual(eval(Nutrients(kcal: 248, proteinG: 46.5, fatG: 5.4, satFatG: 1.5, sodiumMg: 111), ["bodybuilding"]),
                 Verdict(level: .goodFit, reasons: [VerdictReason(severity: .good, text: "Great protein source")]))
  XCTAssertEqual(eval(Nutrients(kcal: 200, carbsG: 30), ["endurance"]).reasons.first?.text, "Good carb fuel")
  XCTAssertEqual(eval(Nutrients(kcal: 100, fiberG: 6), []).reasons.first?.text, "Good source of fiber")
  XCTAssertEqual(eval(Nutrients(kcal: 100), []), Verdict(level: .goodFit, reasons: []))
}
func testOrderingAndCap() {
  let v = eval(Nutrients(kcal: 300, carbsG: 60, fiberG: 6, sodiumMg: 900), ["t2_diabetes"])
  XCTAssertEqual(v.reasons.map(\.severity), [.bad, .caution])   // fiber's "good" is cut by the cap
}
```
  (`eval(item, ids, name: = "Food")` and `evalWith(consumed:kcal:ids)` are test helpers using `T`, goal 2000, consumed `.zero` unless given.)
- [ ] **Step 2: Run** `swift test --filter VerdictTests` → fails: `cannot find 'HealthVerdict'`.
- [ ] **Step 3: Implement** `Verdict.swift`.
- [ ] **Step 4: Run** `swift test` → all pass.
- [ ] **Step 5: Commit** — `feat(core): condition-aware health verdict rules`

### Task 13: Add Food, food detail, barcode and photo scans

**Files:**
- Create: `Features/AddFood/AddFoodView.swift`, `FoodDetailView.swift`, `CreateFoodView.swift`, `BarcodeScanSheet.swift`,
  `PhotoScanSheet.swift`; `Features/Shared/ScanResultCard.swift`, `Features/Shared/VerdictBadge.swift`, `Features/Shared/NutritionLabel.swift`;
  `Data/ImagePrep.swift`; `Data/LogBuilders.swift`

**Interfaces:**
- Consumes: `Backend` search/barcode/analyze/insert, `AppModel` (targets, consumed, goal, conditions), `HealthVerdict`, `MealSlot`.
- Produces:
  - `AddFoodView(meal: Meal, date: Date)`; segments Search | Recent | My Foods | Plan; barcode button.
  - `FoodDetailView(item: FoodItem, meal: Meal, date: Date)` — serving picker (labeled serving, "100 g", "Grams" with a
    number field), servings stepper (0.25 steps), meal picker, `NutritionLabel`, `VerdictBadge` (live as servings change), Add.
  - `ScanResultCard(items: Binding<[AnalyzedItem]>, verdict: Verdict, onAdd: (Meal) -> Void, onSkip: () -> Void)` —
    per-item grams field rescales that item's nutrients proportionally; reused by Glasses Mode (Task 17).
  - `ImagePrep.jpegForUpload(_ image: UIImage) -> Data?` — longest side 1024 px, JPEG quality 0.7.
  - `extension FoodLogRow { init(item: FoodItem, userId: UUID, date: Date, meal: Meal, servings: Double, source: FoodSource); init(analyzed: AnalyzedItem, userId: UUID, date: Date, meal: Meal, source: FoodSource, scanId: UUID) }`
    — the AI init stores `servings 1`, `serving_desc "\(Int(grams)) g"`, `serving_grams grams`, nutrients as given;
    `date` today → `loggedAt = Date()`, another day → noon of that day. In `FoodDetailView`, a gram amount becomes
    `servings = grams / item.servingGrams`; the "Grams" option is hidden when `servingGrams` is nil.
  - `BarcodeScanSheet` wraps VisionKit `DataScannerViewController` (barcode symbologies EAN-8/13, UPC-E, Code 128),
    returns the first payload; shows "Barcode scanning isn't supported on this device" when `isSupported` is false.
  - `PhotoScanSheet` wraps `UIImagePickerController(sourceType: .camera)`; result → `ImagePrep` → `Backend.analyzePhoto`
    → `ScanResultCard`.
- [ ] **Step 1: Implement.** Search debounces 400 ms, needs ≥ 2 chars, shows custom foods (ilike) above USDA/OFF results.
  Failures keep the sheet open and show the error with Retry (spec §9). Verdict input: item total for the chosen amount,
  `AppModel.today.consumed`, `dailyGoalKcal`, profile conditions.
- [ ] **Step 2: Verify on Mac** — build; on device: search "greek yogurt" → USDA items with brand; add 1.5 servings →
  Diary row shows 1.5×; scan a grocery barcode → product found; photo of a plate → items + verdict; edit grams on one item →
  totals update; Add logs one row per item.
- [ ] **Step 3: Commit** — `feat(ios): add food search, detail, barcode and photo scan`

### Task 14: Diary, Dashboard and the ＋ sheet

**Files:**
- Create: `Features/Diary/DiaryView.swift`, `Features/Diary/DayNutritionView.swift`, `Features/Dashboard/DashboardView.swift`,
  `Features/Dashboard/MacroCard.swift`, `App/PlusSheet.swift`
- Modify: `App/PatientTabs.swift`

**Interfaces:**
- Consumes: `DayModel`, `AppModel`, `AddFoodView`, `FoodDetailView`, `HealthVerdict`.
- Produces: `DiaryView(userId: UUID, readOnly: Bool)` (reused read-only by the doctor in Task 19);
  `PlusSheet` actions: Glasses Mode (Task 17 wires it; disabled until then), Photo scan, Barcode, Search food,
  Log exercise (Task 20), Log weight (Task 20).
- [ ] **Step 1: Implement** per spec §7 Patient tabs table. Remaining-calories equation bar `Goal − Food + Exercise = Remaining`;
  meal sections with rows (name, serving × servings, kcal, verdict dot computed with consumed-before-this-item = 0 for
  speed); swipe to delete (not when `readOnly`); tap → edit servings/meal; Exercise section lists workouts; Nutrition
  button → `DayNutritionView` (each nutrient vs target with a bar). Dashboard ring + five `MacroCard`s (protein, carbs, fat,
  sat fat, sodium; sodium/sat fat cards turn red above 100%), a weight sparkline (last 30 days of `weight_logs`), and an
  exercise-kcal tile (steps/active energy join it in Task 21). The ＋ tab opens `PlusSheet` and leaves the selected tab unchanged.
- [ ] **Step 2: Verify on Mac** — sign in as `maria@nutravision.demo`: Diary shows seeded meals for today; date stepper
  moves days; the equation matches the sum of rows; deleting a row updates Dashboard after returning.
- [ ] **Step 3: Commit** — `feat(ios): MyFitnessPal-style diary, dashboard and quick-add sheet`

# Phase 3 — Hands-free glasses

### Task 15: Voice commands, voice flow and spoken text

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/Voice.swift`
- Test: `ios/NutraCore/Tests/NutraCoreTests/VoiceTests.swift`

**Interfaces:**
- Consumes: `Meal`, `Nutrients`, `Verdict`.
- Produces:
  - `public enum VoiceCommand: Equatable { case scan, add(Meal?), skip, status, exit, none; public static func parse(_: String) -> VoiceCommand }`
    — normalize: lowercase, `’`→`'`, everything but letters/digits/apostrophes → space; match phrases on word
    boundaries; priority exit > status > scan > skip > add. Phrases from spec §5.
  - `public enum VoiceState: Equatable { case idle, analyzing, awaitingConfirm }`
  - `public enum VoiceEffect: Equatable { case captureAndAnalyze, log(Meal?), discard, speak(String), speakStatus, stop }`
  - `public enum VoiceFlow { public static func next(_ state: VoiceState, _ command: VoiceCommand) -> (VoiceState, [VoiceEffect]) }`
  - `public enum SpokenText` with `scanResult(itemNames: [String], total: Nutrients, lowConfidence: Bool, verdict: Verdict, conditionName: String?) -> String`,
    `added(consumedKcal: Double, goalKcal: Double) -> String`, `status(consumedKcal: Double, goalKcal: Double, closestLimit: (name: String, percent: Int)?) -> String`,
    and constants `notFood = "I don't see food. Try again."`, `analyzeFailed = "Couldn't analyze. Try again."`,
    `productNotFound = "I couldn't find that product. Try saying scan this."`, `nothingPending = "Nothing to add. Say scan this first."`,
    `skipped = "Skipped."`, `glassesDisconnected = "Glasses disconnected."`.
- [ ] **Step 1: Write the failing tests**

```swift
func testParse() {
  let cases: [(String, VoiceCommand)] = [("Hey, scan this", .scan), ("What’s this?", .scan), ("what am I eating", .scan),
    ("add it to dinner", .add(.dinner)), ("log it", .add(nil)), ("yeah", .add(nil)), ("no thanks", .skip), ("cancel", .skip),
    ("I know that", .none), ("how am I doing?", .status), ("calories left", .status), ("stop glasses mode", .exit), ("", .none)]
  for (s, c) in cases { XCTAssertEqual(VoiceCommand.parse(s), c, s) }
}
func testFlow() {
  XCTAssertTrue(VoiceFlow.next(.idle, .scan) == (.analyzing, [.captureAndAnalyze]))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .scan) == (.analyzing, [.discard, .captureAndAnalyze]))
  XCTAssertTrue(VoiceFlow.next(.analyzing, .add(nil)) == (.analyzing, []))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .add(.lunch)) == (.idle, [.log(.lunch)]))
  XCTAssertTrue(VoiceFlow.next(.idle, .add(nil)) == (.idle, [.speak(SpokenText.nothingPending)]))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .skip) == (.idle, [.discard, .speak(SpokenText.skipped)]))
  XCTAssertTrue(VoiceFlow.next(.idle, .skip) == (.idle, []))
  XCTAssertTrue(VoiceFlow.next(.idle, .status) == (.idle, [.speakStatus]))
  XCTAssertTrue(VoiceFlow.next(.analyzing, .status) == (.analyzing, []))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .exit) == (.idle, [.discard, .stop]))
  XCTAssertTrue(VoiceFlow.next(.idle, .none) == (.idle, []))
}
func testSpokenText() {
  let v = Verdict(level: .notRecommended, reasons: [VerdictReason(severity: .bad, text: "High sodium, 1100 mg, 73% of your daily limit")])
  XCTAssertEqual(SpokenText.scanResult(itemNames: ["Chicken Caesar salad"], total: Nutrients(kcal: 470.4, proteinG: 33.6), lowConfidence: false, verdict: v, conditionName: "Hypertension (DASH)"),
    "Chicken Caesar salad, about 470 calories and 34 grams of protein. Not recommended for your Hypertension plan: high sodium, 1100 mg, 73% of your daily limit. Say add it or skip.")
  XCTAssertEqual(SpokenText.scanResult(itemNames: ["Rice", "Beans"], total: Nutrients(kcal: 400, proteinG: 15), lowConfidence: true, verdict: Verdict(level: .goodFit, reasons: []), conditionName: nil),
    "I think this is 2 items, about 400 calories and 15 grams of protein. Good fit. Say add it or skip.")
  XCTAssertEqual(SpokenText.added(consumedKcal: 1240, goalKcal: 2000), "Added. 1240 of 2000 calories today.")
  XCTAssertEqual(SpokenText.status(consumedKcal: 1030, goalKcal: 2000, closestLimit: ("Sodium", 85)), "You have 970 calories left today. Sodium is at 85% of your limit.")
  XCTAssertEqual(SpokenText.status(consumedKcal: 2120, goalKcal: 2000, closestLimit: nil), "You're 120 calories over today's goal.")
}
```
  (Tuple `==` on `(VoiceState, [VoiceEffect])` works because both elements are `Equatable`.)
- [ ] **Step 2: Run** `swift test --filter VoiceTests` → fails: `cannot find 'VoiceCommand'`.
- [ ] **Step 3: Implement** `Voice.swift`. `conditionName` drops a trailing ` (…)`; the first reason's first letter is lowercased.
- [ ] **Step 4: Run** `swift test` → all pass.
- [ ] **Step 5: Commit** — `feat(core): voice command parser, voice flow and spoken text`

### Task 16: Camera sources (glasses and phone)

**Files:**
- Create: `ios/NutraVision/Glasses/CameraSource.swift`, `Glasses/GlassesSession.swift`, `Glasses/PhoneCameraSession.swift`
- Reference: `git show 5e4dec7:ios/MetaGlassesVoice/BarcodeScannerSession.swift` (Vision loop) and the SDK 1.0 sample
  `samples/CameraAccess/CameraAccess/ViewModels/CameraViewModel.swift` in `meta/meta-wearables-dat-ios`.

**Interfaces:**
- Produces:
  - `@MainActor protocol CameraSource: AnyObject { var latestFrame: UIImage? { get }; var onBarcode: ((String) -> Void)? { get set }; func start() async throws; func stop(); func capturePhoto() async -> UIImage? }`
  - `@MainActor final class GlassesSession: CameraSource` — `Wearables.shared.createSession(deviceSelector: AutoDeviceSelector(wearables: Wearables.shared))`,
    `session.start()`, request `Permission.camera` if not granted, `session.addCamera(config: StreamConfiguration(videoCodec: .raw, resolution: .low, frameRate: 15))`,
    listen `stream.videoFramePublisher` (frames → `latestFrame` via `frame.makeUIImage()`, Vision barcode every ≥ 0.35 s, same
    payload suppressed for 5 s), `stream.photoDataPublisher` (resumes the pending `capturePhoto`), `stream.errorPublisher`
    and session state (stopped → `onDisconnect`). `capturePhoto()` calls `stream.capturePhoto(format: .jpeg)` and waits up to
    3 s, then falls back to `latestFrame`. Tokens stored in a `ListenerTokenBag`. Also `var onDisconnect: (() -> Void)?`.
  - `@MainActor final class PhoneCameraSession: CameraSource` — `AVCaptureSession` (back wide camera), `AVCapturePhotoOutput`,
    `AVCaptureMetadataOutput` (types `.ean8, .ean13, .upce, .code128`), plus `var previewLayer: AVCaptureVideoPreviewLayer`.
- [ ] **Step 1: Implement.** If `makeUIImage()` is missing in 1.0, build the image from `frame.sampleBuffer` via
  `CMSampleBufferGetImageBuffer` → `CIImage` → `CIContext().createCGImage`.
- [ ] **Step 2: Verify on Mac + device** — temporary debug button in More → "Camera test" shows `latestFrame` updating
  from glasses (and from phone), a barcode prints, and `capturePhoto` returns a full-size image within 3 s. Remove the
  debug button before committing.
- [ ] **Step 3: Commit** — `feat(ios): glasses and phone camera sources for SDK 1.0`

### Task 17: Voice loop and Glasses Mode screen

**Files:**
- Create: `ios/NutraVision/Glasses/VoiceLoop.swift`, `Features/Glasses/GlassesModeView.swift`,
  `Features/More/GlassesSettingsView.swift` (registration state, Connect / Disconnect via `WearablesViewModel`, device
  list, glasses camera permission; linked from More → Glasses)
- Modify: `Glasses/OnDeviceSpeechRecognizer.swift` → rename to `Glasses/SpeechRecognizer.swift`; `App/PlusSheet.swift`,
  `Features/Dashboard/DashboardView.swift` (Glasses Mode buttons)

**Interfaces:**
- Consumes: `CameraSource` (Task 16), `VoiceCommand`/`VoiceFlow`/`SpokenText` (Task 15), `Backend.analyzePhoto`/`lookupBarcode`/`insertFoodLogs`,
  `HealthVerdict`, `MealSlot`, `ScanResultCard`, `AppModel`.
- Produces:
  - `@MainActor final class SpeechRecognizer` — continuous mode: `start(onFinal: @escaping (String) -> Void) throws`,
    `pause()`, `resume()`, `stop()`; audio session `.playAndRecord`, options `[.allowBluetoothHFP, .defaultToSpeaker]`
    (`.allowBluetooth` on older SDKs); on-device recognition when supported; restarts a task after each final result or error.
  - `@Observable @MainActor final class VoiceLoop { state: VoiceState; transcript: String; pending: [AnalyzedItem]; pendingSource: FoodSource; verdict: Verdict?; init(source: CameraSource, app: AppModel); func start() async; func stop(); func handle(_ command: VoiceCommand) }`
    — runs `VoiceFlow.next` and executes effects; `AVSpeechSynthesizer` delegate pauses recognition while speaking and
    resumes in `didFinish`; barcodes arriving while `idle` → lookup → result spoken, state `awaitingConfirm`; unknown
    barcode → `productNotFound`; barcode hits become `[AnalyzedItem(product:)]` with `pendingSource = .barcode`, AI
    scans set `.glassesAI` (or `.photoAI` on the phone source); pending scan auto-discards after 60 s; `log` inserts rows
    via `FoodLogRow(analyzed:…, source: pendingSource, scanId:)`, then speaks `SpokenText.added` with refreshed totals;
    disconnect → speak `glassesDisconnected` and stop.
  - `GlassesModeView(useGlasses: Bool)` — full screen: live frame (or phone preview layer), state chip, live transcript,
    `ScanResultCard` bound to `pending`, big Scan / Add / Skip buttons that call `handle` (same path as voice), Exit.
- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify on device with glasses** (spec §1 walkthrough steps 2–3): "scan this" at a plate → spoken name,
  calories and verdict; "add it" → row in Diary under the time-of-day meal, spoken total; look at a barcode → spoken without
  a command; "skip" → nothing logged; "how am I doing" → remaining calories; the app never reacts to its own speech;
  turning glasses off mid-session → "Glasses disconnected." Repeat once with `useGlasses: false` on the phone.
- [ ] **Step 3: Commit** — `feat(ios): hands-free glasses voice loop`

# Phase 4 — Doctor ↔ patient

### Task 18: Patient flags and the patient's Care Team

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/PatientFlags.swift`, `ios/NutraCore/Tests/NutraCoreTests/PatientFlagsTests.swift`,
  `Features/CareTeam/CareTeamView.swift`, `Features/CareTeam/RecommendationDetailView.swift`
- Modify: `Features/Dashboard/DashboardView.swift` (banner), `Features/More/MoreView.swift` (Care Team row with badge)

**Interfaces:**
- Consumes: `Backend` care/recommendation methods, `Targets`, `Nutrients`.
- Produces: `public enum PatientFlags { public static func flags(days: [Nutrients], targets: Targets, dailyGoalKcal: Double) -> [String] }`
  — counts days over a limit among `days` (one entry per logged day, oldest → newest): sodium > `sodiumMg`, sat fat >
  `satFatG`, kcal > `dailyGoalKcal × 1.1`; emits `"Sodium over limit {n} of last {days.count} days"`,
  `"Saturated fat over limit …"`, `"Calories over goal …"` in that order, only when n ≥ 1.
- [ ] **Step 1: Write the failing test**

```swift
func testFlags() {
  let t = Targets(kcal: 2000, proteinG: 100, carbsG: 250, fatG: 67, satFatG: 20, sodiumMg: 1500, fiberG: 28)
  let days = [Nutrients(kcal: 1900, satFatG: 10, sodiumMg: 1600), Nutrients(kcal: 2300, satFatG: 25, sodiumMg: 1400),
              Nutrients(kcal: 2000, sodiumMg: 1700)]
  XCTAssertEqual(PatientFlags.flags(days: days, targets: t, dailyGoalKcal: 2000),
                 ["Sodium over limit 2 of last 3 days", "Saturated fat over limit 1 of last 3 days", "Calories over goal 1 of last 3 days"])
  XCTAssertEqual(PatientFlags.flags(days: [], targets: t, dailyGoalKcal: 2000), [])
}
```
- [ ] **Step 2: Run** `swift test --filter PatientFlagsTests` → fails; **Step 3:** implement; **Step 4:** run → pass.
- [ ] **Step 5: Implement Care Team UI** — sections Pending requests (doctor name, specialty, license #, Accept/Decline),
  My doctors (Revoke with confirm), Recommendations (pending first; detail shows current vs proposed targets side by side,
  or the plan's meals; Accept/Decline). Accepting refreshes `AppModel` so targets and verdicts change immediately.
  Dashboard banner: "Dr X wants to follow your food log" / "New recommendation from Dr X" → opens Care Team.
- [ ] **Step 6: Verify on Mac** — as `james@nutravision.demo`, the seeded pending recommendation shows in the banner;
  accept → Dashboard sodium target changes to the recommended value.
- [ ] **Step 7: Commit** — `feat: patient care team, recommendations inbox and doctor flags logic`

### Task 19: Doctor tabs

**Files:**
- Create: `Features/Doctor/PatientsView.swift`, `Features/Doctor/PatientDetailView.swift`, `Features/Doctor/RequestsView.swift`,
  `Features/Doctor/SendRecommendationView.swift`
- Modify: `App/DoctorTabs.swift`

**Interfaces:**
- Consumes: `Backend.careLinks/profiles/foodLogs/workouts/weights/dietPlans/requestPatient/revokeCareLink/sendRecommendation`,
  `PatientFlags`, `DiaryView(userId:readOnly:)` (Task 14), `NutritionProgressView(userId:)` (Task 22 — until it lands, the detail
  shows Diary only), `ConditionCatalog` sample plans.
- Produces: doctor experience per spec §7 Doctor tabs table.
- [ ] **Step 1: Implement.** Patients list loads accepted links → profiles → last 7 days of logs (one query with
  `from: 7 days ago`), groups by `DayKey`, computes today's kcal, 7-day average and `PatientFlags`. Patient detail
  segments: Diary | Progress | Weight & workouts | Plan & history; toolbar "Send recommendation" → targets editor (seeded
  from the patient's current targets) or plan editor (seeded from `ConditionCatalog.condition(id: primary).samplePlan`)
  plus message. Requests: email field + Send (`request_patient` errors shown verbatim), list with status chips, swipe to revoke.
- [ ] **Step 2: Verify on Mac (two simulators or sign out/in)** — spec §1 step 7: doctor requests a new patient account →
  patient accepts → doctor sees the diary → doctor sends targets with sodium 1500 → patient accepts → patient verdicts change.
- [ ] **Step 3: Commit** — `feat(ios): doctor patients, requests and recommendations`

# Phase 5 — Health and goals

### Task 20: Exercise and weight logging

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/ExerciseCalories.swift`, `ios/NutraCore/Tests/NutraCoreTests/ExerciseCaloriesTests.swift`,
  `Features/Exercise/LogExerciseView.swift`, `Features/Weight/LogWeightView.swift`
- Modify: `Data/Rows.swift` (`WorkoutRow.kind: ExerciseKind`), `App/PlusSheet.swift`, `Features/Diary/DiaryView.swift` (Add exercise)

**Interfaces:**
- Produces: `public enum ExerciseKind: String, Codable, CaseIterable, Sendable { case running, walking, cycling, swimming, strength, hiit, yoga, other; public var met: Double; public var title: String; public var symbol: String }`;
  `public enum ExerciseCalories { public static func kcal(kind: ExerciseKind, minutes: Double, weightKg: Double?) -> Double }` (whole number).
- [ ] **Step 1: Write the failing test**

```swift
func testKcal() {
  XCTAssertEqual(ExerciseCalories.kcal(kind: .running, minutes: 30, weightKg: 70), 343)
  XCTAssertEqual(ExerciseCalories.kcal(kind: .yoga, minutes: 60, weightKg: 80), 200)
  XCTAssertEqual(ExerciseCalories.kcal(kind: .walking, minutes: 45, weightKg: nil), 184)
  XCTAssertEqual(ExerciseKind.allCases.map(\.met), [9.8, 3.5, 7.5, 6.0, 5.0, 8.0, 2.5, 4.0])
}
```
- [ ] **Step 2: Run** → fails; **Step 3:** implement; **Step 4:** run → pass.
- [ ] **Step 5: Implement the forms.** Exercise: kind, start time, duration, optional distance (km/mi), notes, calories
  prefilled from `ExerciseCalories` with the profile weight and editable. Weight: date + kg/lb; saving also sets
  `profile.weightKg` when it is the newest entry and saves through `AppModel.saveProfile` (recomputes targets when `auto`).
- [ ] **Step 6: Verify on Mac** — log a 30 min run → Diary Exercise section shows it and Remaining grows by its kcal;
  log a weight 2 kg lower → Profile & Goals shows the new weight and (auto targets) a lower kcal target.
- [ ] **Step 7: Commit** — `feat: exercise and weight logging`

### Task 21: Apple Health sync

**Files:**
- Create: `ios/NutraVision/Health/HealthSync.swift`, `Features/More/AppleHealthView.swift`
- Modify: `Data/AppModel.swift` (sync on foreground and refresh), food insert/delete call sites (write/remove samples)

**Interfaces:**
- Consumes: `Backend.upsertWorkouts/upsertWeights`, `FoodLogRow`, `WeightLogRow`.
- Produces: `@MainActor final class HealthSync { static let shared; var isAuthorized: Bool; func requestAccess() async throws; func importNew(userId: UUID) async throws; func todaySteps() async -> Int?; func todayActiveKcal() async -> Double?; func save(_ log: FoodLogRow) async; func remove(_ logId: UUID) async; func save(_ weight: WeightLogRow) async }`
  — read types: workouts, body mass, step count, active energy; write types: dietary energy, protein, carbs, fat, sat fat,
  sodium, fiber, sugar, body mass. Anchored queries with anchors stored in `UserDefaults` (`hk.anchor.workouts`, `hk.anchor.bodyMass`).
  Workout kind map: running→`.running`, walking→`.walking`, cycling→`.cycling`, swimming→`.swimming`,
  traditional/functional strength→`.strength`, HIIT→`.hiit`, yoga→`.yoga`, else `.other`. Food samples are an
  `HKCorrelation(.food)` with metadata `HKMetadataKeyExternalUUID = log.id`; `remove` deletes by that metadata
  (works for older entries too, so the spec §8 ceiling no longer applies).
- [ ] **Step 1: Implement.** Permission is only requested from `AppleHealthView`. Dashboard shows steps/active energy when authorized.
- [ ] **Step 2: Verify on device** — connect Apple Health; a workout recorded on Apple Watch (or added in Health) appears in
  Diary as a heart-marked row once, even after pulling to refresh twice; a logged food shows in Health → Nutrition; deleting it removes it.
- [ ] **Step 3: Commit** — `feat(ios): Apple Health import and export`

### Task 22: Progress — calendars and charts

**Files:**
- Create: `ios/NutraCore/Sources/NutraCore/DayStatus.swift`, `ios/NutraCore/Tests/NutraCoreTests/DayStatusTests.swift`,
  `Features/Progress/NutritionProgressView.swift`, `Features/Progress/MonthCalendarView.swift`, `Features/Progress/YearHeatmapView.swift`,
  `Features/Progress/TrendCharts.swift`
- Modify: `App/PatientTabs.swift`, `Features/Doctor/PatientDetailView.swift` (Progress segment)

**Interfaces:**
- Produces: `public enum DayStatus: Equatable { case noData, under, near, over; public static func classify(kcal: Double?, goal: Double) -> DayStatus }`
  (`near` when within ±10 % of goal inclusive); `NutritionProgressView(userId: UUID)` (not `ProgressView`, which
  would shadow SwiftUI's).
- [ ] **Step 1: Write the failing test**

```swift
func testClassify() {
  XCTAssertEqual(DayStatus.classify(kcal: nil, goal: 2000), .noData)
  XCTAssertEqual(DayStatus.classify(kcal: 0, goal: 2000), .noData)
  XCTAssertEqual(DayStatus.classify(kcal: 1799, goal: 2000), .under)
  XCTAssertEqual(DayStatus.classify(kcal: 1800, goal: 2000), .near)
  XCTAssertEqual(DayStatus.classify(kcal: 2200, goal: 2000), .near)
  XCTAssertEqual(DayStatus.classify(kcal: 2201, goal: 2000), .over)
}
```
- [ ] **Step 2: Run** → fails; **Step 3:** implement; **Step 4:** run → pass.
- [ ] **Step 5: Implement the views.** One query per visible range (`foodLogs(userId:from:to:)`), grouped by `DayKey`.
  Month grid (Monday-first per `Calendar.current.firstWeekday`), colors: under = teal, near = green, over = red,
  noData = grey; Year view = 12 mini-months heatmap; tapping a day pushes `DiaryView(userId:readOnly:)` on that date
  (read-only when viewed by a doctor). Charts (Swift Charts): weight line with a goal `RuleMark`; 30-day kcal bars with the
  goal line; sodium and sat-fat lines with their limits.
- [ ] **Step 6: Verify on Mac** — as `james@nutravision.demo`: month view shows a mix of colors from the seed; year view
  shows the last 30 days colored and earlier days grey; tapping a day opens that day's diary.
- [ ] **Step 7: Commit** — `feat(ios): progress calendars, year heatmap and trends`

### Task 23: Conditions and diet plans

**Files:**
- Create: `Features/Conditions/ConditionLibraryView.swift`, `Features/Conditions/ConditionDetailView.swift`,
  `Features/DietPlans/DietPlansView.swift`, `Features/DietPlans/DietPlanEditorView.swift`
- Modify: `Features/More/MoreView.swift`, `Features/AddFood/AddFoodView.swift` (Plan segment reads the active plan)

**Interfaces:**
- Consumes: `ConditionCatalog`, `Backend.dietPlans/saveDietPlan/activatePlan`, `AddFoodView` (to pick a swap food), `PlanItem`.
- Produces: `DietPlanEditorView(plan: DietPlanRow)` reused by the doctor's plan recommendation editor (Task 19 switches to it).
- [ ] **Step 1: Implement.** Library lists all 15 conditions with icon and summary; detail shows guidance (recommend/avoid),
  limits, the sample day, disclaimer, and "Start this plan" (copies into `diet_plans`, `author_id` = self, activates it).
  "Add to my conditions" updates the profile. Editor: rename, edit targets, per meal add (via Add Food picker), remove,
  swap, change portion (rescales nutrients), day totals vs targets. Plans list: active first, re-activate past plans.
- [ ] **Step 2: Verify on Mac** — spec §1 step 8: start the Bodybuilding plan, swap a food, save → it is the active plan
  and its items appear under Add Food → Plan.
- [ ] **Step 3: Commit** — `feat(ios): condition library and editable diet plans`

### Task 24: Final pass

**Files:**
- Modify: `docs/SETUP.md` (final), `README.md` (create: one-paragraph overview, link to SETUP and the spec)

- [ ] **Step 1: Run everything available here** — `npm test` → all pass; `grep -rn "TODO\|FIXME" ios supabase docs` → none.
- [ ] **Step 2: Owner runs on Mac** — `swift test` in `ios/NutraCore` → all pass; full spec §1 walkthrough on device; the
  SQL editor run of `supabase/tests/rls_check.sql` on the real project → success.
- [ ] **Step 3: Commit** — `docs: setup guide and README`
