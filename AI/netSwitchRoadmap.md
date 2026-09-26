# NetSwitch — Roadmap to v1.0

Realistic pacing assumes part-time/evenings-and-weekends work, not full-time. Each phase has an explicit exit criteria — don't move to the next phase until you hit it, since skipping ahead is where solo projects usually stall.

---

## Phase 0 — Foundation ✅ (done)
- [x] Validated `networksetup` commands manually in Terminal
- [x] Xcode project created, App Sandbox entitlement added
- [x] Swift scaffold: `Profile`, `ProfileStore`, `NetworkService`, `MenuBarExtra` + `Settings` scenes wired

**You are here.**

---

## Phase 1 — Core v0.1 loop (1–3 weeks)
Goal: a single profile can be created, saved, and actually applied to your network — the one real unknown (admin-prompt-from-sandbox) gets resolved here.

- [ ] Confirm the `osascript "with administrator privileges"` prompt actually fires correctly from the sandboxed app — **this is the riskiest unknown in the whole project, resolve it first**
- [ ] Wire up the "Edit" button in Preferences (currently only Add/Delete are guaranteed-wired)
- [ ] Show current Wi-Fi SSID somewhere in the menu bar dropdown (you already have `currentSSID()` — just needs a UI hookup)
- [ ] Basic error feedback — if a `networksetup` call fails, show *something* to the user instead of silently doing nothing
- [ ] A real (even simple) app icon — placeholder icons make dogfooding feel less real and you're less likely to actually use it daily

**Exit criteria:** you personally switch networks using NetSwitch instead of System Settings, without reverting back, for at least a few real days in a row.

---

## Phase 2 — Private dogfood hardening (1–2 weeks)
Goal: make it trustworthy enough that *you* rely on it, across your actual real-world network variety.

- [ ] Handle edge cases: Ethernet-only sessions, VPN active + profile switch, a network service that doesn't exist / got renamed
- [ ] Show which profile is currently "active" in the menu bar (not just a flat list)
- [ ] Add "Launch at Login" toggle (`SMAppService` — small, self-contained addition)
- [ ] Defensive coding pass around every `Process`/subprocess call — a crash here is a bad first impression later
- [ ] Test across every network environment you actually use (home, office/coffee shop, hotspot, VPN)

**Exit criteria:** a full week of daily real use with zero crashes and zero "I had to fix it manually" moments.

---

## Phase 3 — Public beta readiness (2–3 weeks)
Goal: get NetSwitch in front of strangers, Typora-style — free, with visible "will become paid at v1.0" framing.

- [ ] **Start Apple Developer Program enrollment now** (developer.apple.com/programs, $99/year) — do this in parallel with coding, not after; approval can take a day or two
- [ ] Get the full signing → notarization → stapling pipeline working end-to-end at least once (this always has a surprise or two the first time — budget real time for it)
- [ ] Minimal first-launch onboarding (what does this app do, where are my profiles)
- [ ] A feedback path that costs you nothing to build: a `mailto:` link or a simple form is enough for now
- [ ] Auto-update: either wire up **Sparkle**, or ship without it and just post "new version" links manually for the beta (fine at this scale — don't let this block launch)
- [ ] A simple landing/download page with explicit **"Free public beta — will become a paid app at v1.0"** messaging
- [ ] Post the beta where the demand signal already exists: r/macapps, the old ControlPlane-replacement threads, a Show HN

**Exit criteria:** 20–50 people outside your own dogfooding are actually running it, without you personally walking any of them through setup.

---

## Phase 4 — Feature expansion (4–6 weeks, paced by real feedback)
Goal: turn "network switcher" into "network & dev toolkit for Mac" — this is what justifies $25–30 instead of $15–20, and it's the phase that should be driven by what beta users actually ask for, not just this list.

- [ ] **Wi-Fi SSID auto-switching** — the headline "context-aware" feature: detect network change, auto-apply the matching profile without a manual click
- [ ] **Dev Network Toolbox bundle** (folded into NetSwitch, not a separate app, per our earlier decision): port lookup/kill (`lsof`-based), `/etc/hosts` editor, quick local diagnostics
- [ ] Export/import profiles as JSON (easy win, useful for your own multi-Mac setup too)
- [ ] Fix whatever the beta feedback actually surfaced as annoying — this line item matters more than any item above it

**Exit criteria:** beta users are explicitly asking "when can I pay for this" — that's your green light for Phase 6.

---

## Phase 5 — CloudKit sync (3–4 weeks) — optional for v1.0
Goal: profiles sync across your Macs. Real decision point here: **you don't have to ship this in v1.0.** Typora-style products expand *after* the paywall goes up too — shipping v1.0 without sync and adding it in a v1.1 update is a completely legitimate call if it's taking too long.

- [ ] CloudKit container + entitlement (should already exist from Phase 0 setup)
- [ ] Sync profile list across devices, handle basic conflict cases (last-write-wins is fine for v1)
- [ ] Test against two real Macs or two iCloud test accounts

**Exit criteria:** reliably syncs across two of your own machines without silent data loss.

---

## Phase 6 — v1.0 paid launch (1–2 weeks)
Goal: flip the switch.

- [ ] Final QA pass across everything above
- [ ] Pick a payment path: Gumroad/Paddle (simplest, fastest to set up) vs. Mac App Store (more reach, more review overhead — your sandboxing work from Phase 0 pays off here if you go this route later)
- [ ] Set the price: **$25–30**, reflecting the expanded feature set from Phase 4, not the original $15–20 estimate for a network-switcher-only scope
- [ ] Announce the paywall transition to your beta users with advance notice — this is the trust-preserving move that made Typora's flip work
- [ ] Decide on grandfathering your earliest testers (optional goodwill gesture, not required)

**Exit criteria:** first paying customer. 🎉

---

## What's explicitly out of scope until after v1.0
- Mac App Store submission (revisit as a *separate*, later decision — not required for a successful paid launch)
- Any feature not requested by real beta users in Phase 3/4
- Perfecting anything before Phase 1's exit criteria is met — a working v0.1 you actually use beats a polished thing that doesn't exist yet
