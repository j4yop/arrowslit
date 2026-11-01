# Arrowslit Sports — provider research and implementation plan

**Status:** research/design only. No app code changed.
**Date:** 1 November 2026.
**Goal:** live football and cricket scores in Arrowslit, with La Liga, Premier League, Champions League, IPL, T20Is, ODIs and Tests, configurable in Settings and fitting the notch/compact strip UI.

---

## 0. Implemented choice (1 November 2026)

Arrowslit now ships the **BigBallsData Free** adapter selected here:

- Sports starts in **Preview** with sample La Liga, UCL, IPL, T20I and Test matches, so the nook works without a key.
- A free `bbs_live_…` key is entered in **Settings › Sports** and stored in the macOS Keychain.
- One all-sports live request refreshes both football and cricket; fixtures are cached for 30 minutes.
- The nook shows a **Following + Featured** shelf, inline match detail, team follow stars, a pin button and a 32px compact score.
- The free tier is 250 requests/day. Polling is 30/60/120 seconds, slows down when the quota is low, and stops at zero.

## 1. Bottom line

There is no free, official, production-grade feed that covers all of the requested competitions reliably.

The realistic choices are:

1. **Best coverage per dollar (BYOK):** API-Football Pro for football + OpenCricketAPI Developer for cricket. About **$33/month per user**. Live cricket comes from ESPN's public scoreboard via OpenCricketAPI, so the licensing is the weak point.
2. **Best quality and cleanest licensing (single vendor):** Sportmonks Football Starter + Cricket World. About **€104/month**. Five football leagues (EPL, La Liga, UCL + two more) and 60+ cricket leagues including IPL, Tests and ODIs. This is the safest shippable option, but expensive for a free app.
3. **Cheapest single key:** BigBallsData Trio at **$49/month** for football + cricket. Good football coverage and live cadence, but IPL/BBL/PSL are archive-only with no forward schedule, so it cannot promise "all IPL live" today.
4. **Free prototype only:** BigBallsData Free (250/500 requests/day) or SportScore (about 10,000/day, 60-second cache, attribution). Useful to build and evaluate the UI; not suitable as the shipped default.

**Recommended path:** build the UI shell with demo data first, then a BYOK adapter for API-Football + OpenCricketAPI, and only move to Sportmonks or a hosted relay if this is going to ship to non-technical users.

The most important architectural rule: **poll one "all live matches" endpoint per sport, not one request per match.** Ten live matches polled individually at 30 seconds is 28,800 requests/day; one all-live poll is 2,880/day. Free tiers only work with the second design.

---

## 2. Scope

### Football
- Premier League
- La Liga
- UEFA Champions League
- Optional: Serie A, Bundesliga, Ligue 1, Europa League

### Cricket
- IPL
- T20 Internationals
- One Day Internationals
- Test series
- Optional: Big Bash, PSL, The Hundred, international tours

### Product behaviour
- Live scores with minute / innings / overs / run rate.
- Today's fixtures, upcoming fixtures, recent results.
- Follow competitions and teams; pin one match to the notch.
- Optional goal/wicket notch alerts while Arrowslit is running.
- Sports off by default; no network until the user turns it on.

"All matchups" in this document means **all matches in the selected competitions**, not every league in the world.

---

## 3. Provider matrix

Prices and limits checked on 1 November 2026. Currency and tax vary.

| Provider | Sports | Coverage | Live cadence | Free tier | Paid entry | Rate limit | Main catch |
|---|---|---|---|---|---|---|---|
| **API-Football** | Football | All competitions included on every plan; very broad | Provider live feed; poll every 15–30s | 100 req/day | **$19/mo** 7,500/day; $29 75,000/day; $39 150,000/day | Daily quota; per-minute limit | Football only; separate key |
| **Sportmonks Football** | Football | 2,200+ leagues; pick 5 / 30 / 120 leagues | Minute-to-minute; polling | 14-day trial | **€29/mo** Starter (5 leagues); €99 Growth (30); €249 Pro (120) | 2,000 / 2,500 / 3,000 calls per entity/hour | Per-domain terms; 5-league entry plan |
| **Sportmonks Cricket** | Cricket | Major: IPL, BBL, PSL, T20 Blast, T20 World Cups. World: + Tests, ODIs, ICC World Cup | Minute-to-minute; ball-by-ball on all plans | 14-day trial | **€29/mo** Major; **€75/mo** World; €129+ Enterprise | 2,000 calls/hour per endpoint | Tests/ODIs need World, not Major |
| **OpenCricketAPI** | Cricket | Tests, ODIs, T20Is, IPL and major T20 leagues; 23,800+ matches | About 20s; live scores from ESPN scoreboard | 1,000 req/month, no live | **$14/mo** Developer (250k/month); **$39/mo** Pro (2M/month) | 100 / 250 requests per minute | Live data is ESPN-derived, "no open licence"; commercial use on Pro |
| **BigBallsData** | Football + Cricket | EPL, La Liga, Serie A, Bundesliga, Ligue 1, UCL, MLS, WC2026; Tests, ODIs, T20Is, IPL, BBL, PSL, SA20 | Football ~13s; cricket live state endpoint | 250 req/day (500 with GitHub) | **$19/mo** Solo (1 sport, 10k/day); **$49/mo** Trio (3 sports, 25k/day) | 100/min free; 300/500/min paid | IPL/BBL/PSL have no forward schedule; archive only right now |
| **SportScore** | Football, cricket, basketball, tennis | Patchy; UCL works, La Liga missing in a spot check | 60s edge cache | ~10,000 req/day/IP, no key | Custom | 10k/day/IP | Attribution badge is web-oriented; not suitable for a native app without permission |
| **Entity Sport** | Cricket + football | Tests, ODIs, T20s, IPL, domestic; football 10–100+ leagues | Real-time / WebSocket on top plans | None | **$150–$750/mo per sport** | 500k–4M calls | Too expensive for this app |
| **Sportradar / Stats Perform** | Both | Official, exhaustive | Real-time push | None | Custom enterprise | Custom | Only viable with a commercial deal |

---

## 4. Provider notes

### API-Football

- Pricing: Free 100 requests/day; Pro $19 for 7,500/day; Ultra $29 for 75,000/day; Mega $39 for 150,000/day.
- The pricing page states: **"All our plans include all competitions and endpoints."** That is the key advantage over Sportmonks' league-count plans.
- The live endpoint is the fixtures endpoint with `live=all`, which returns all in-play fixtures in one response. That makes polling cheap.
- Good fit for a football-first MVP. It does not solve cricket.

Source: <https://www.api-football.com/pricing>

### Sportmonks

- Football: Starter €29 (5 leagues), Growth €99 (30), Pro €249 (120). All data features included; the plan only changes league count and call capacity.
- Cricket: Major €29 (20+ leagues: IPL, Big Bash, PSL, T20 Blast, both ICC T20 World Cups); World €75 (60+ leagues, adds Test series, ODIs and the ICC World Cup); Enterprise €129+ (100+ leagues).
- Every cricket plan includes ball-by-ball, live scores and the same 2,000 calls/hour per endpoint. The only difference is league count.
- The football livescores documentation says `GET All Inplay Livescores` returns **all in-play fixtures** in one request. There is also a `Latest Updated Livescores` endpoint for changes within 10 seconds.
- Coverage list confirms IPL #1, ODI #2, T20I #3, Test Series #4 and ICC World Cup #18.
- Terms: reselling the raw feed is not allowed; building an app on the data is allowed. The account is personal and may not be shared with other developers. Logos and player photos are separately copyrighted. Pricing is "per domain", which is written for web products; a native Mac app should confirm the desktop-app case with Sportmonks sales before shipping.
- For a single-vendor build: Football Starter + Cricket World is the smallest plan that covers EPL, La Liga, UCL, IPL, T20Is, ODIs and Tests. That is **€104/month** before tax.

Sources:
- <https://www.sportmonks.com/football-api/plans-pricing/>
- <https://www.sportmonks.com/cricket-api/plans-pricing/>
- <https://www.sportmonks.com/cricket-api/coverage/>
- <https://docs.sportmonks.com/football/endpoints-and-entities/endpoints/livescores>
- <https://www.sportmonks.com/terms-of-service/>

### OpenCricketAPI

- Free Starter: 1,000 requests/month, 10 requests/minute, last 12 months of archive, **no live scores**.
- Developer $14/month: 250,000 requests/month, 100/minute, live scores worldwide, fixtures for the next two weeks, full archive and ball-by-ball.
- Pro $39/month: 2,000,000 requests/month, 250/minute, **commercial use**.
- Live scores and fixtures come from **ESPN's public scoreboard**, refreshed about every 20 seconds. The docs explicitly say "no open licence" and "fine for score apps and dashboards, not for in-play betting."
- One `GET /v1/live` request returns matches in progress worldwide, so a 20–30 second poll is cheap.
- This is the cheapest way to get live cricket for a personal build. For a distributed or paid app, the ESPN licensing and the Developer-vs-Pro commercial distinction need a written answer from the provider.

Sources:
- <https://opencricketapi.com/pricing>
- <https://opencricketapi.com/docs>

### BigBallsData

- Free: 250 requests/day (500 with GitHub), 100 requests/minute, all sports and leagues, current season.
- Solo: $19/month, one sport, 10,000 requests/day.
- Trio: $49/month, three sports, 25,000 requests/day, 500 requests/minute.
- Football: EPL, La Liga, Serie A, Bundesliga, Ligue 1, UCL, MLS and WC2026. The endpoint list shows the soccer match list refreshing about every 13 seconds.
- Cricket: Tests, ODIs, T20Is, IPL, BBL, PSL, SA20 and others. Tests and ODIs have forward fixtures; IPL/BBL/PSL are described as complete archives with **no fixtures scheduled ahead**. That is the blocker for "all IPL live" today.
- Terms allow displaying data in an app and storing responses; they prohibit reselling the raw feed or sharing a key.

Sources:
- <https://bigballsdata.com/pricing>
- <https://bigballsdata.com/football-api>
- <https://bigballsdata.com/cricket-api>
- <https://bigballsdata.com/coverage>
- <https://bigballsdata.com/legal/terms>

### SportScore

- Free, no key, about 10,000 requests/day/IP, responses edge-cached for 60 seconds.
- Covers football, basketball, cricket and tennis.
- Free tier requires a visible "Powered by SportScore" link on every screen that renders the data; open-source apps qualify.
- The terms are written for web pages: a real HTML `<a>` element, crawlable, `rel="dofollow"`. A native macOS app cannot satisfy that literally. It may be acceptable with a visible clickable link and written permission, but do not assume it.
- A spot check on 1 November 2026 returned UCL standings but "Competition not found" for La Liga and "No current season" for the Premier League, and cricket standings were unavailable. Live matches did include BBL Women, an ODI series and a T20 series. Coverage is not consistent enough for the requested top competitions.

Sources:
- <https://sportscore.com/developers/>
- <https://sportscore.com/developers/terms/>

### Entity Sport

- Cricket: Starter $150/month (500k calls, Tests/ODIs/T20Is), Pro $250 (1M, adds domestic T20/T10), Elite $450 (2M, adds List A/first-class).
- Football is a separate plan: Starter $250/month for 10 leagues including the Premier League, Pro $450 for 35 leagues, Elite $750 for 65, Gold $1,600 for 100+ with live WebSocket.
- Real-time and comprehensive, but the cost is an order of magnitude above the other options.

Source: <https://www.entitysport.com/pricing>

### Sportradar / Stats Perform

The official-data route. Enterprise pricing, contracts and push feeds. The right choice only if Arrowslit Sports becomes a funded product with a commercial data agreement.

---

## 5. Rate-limit math

The numbers that decide the architecture:

| Design | Requests/day | Fits |
|---|---:|---|
| 1 all-live football poll every 30s | 2,880 | API-Football Pro 7,500/day |
| 1 all-live football poll every 15s | 5,760 | API-Football Pro 7,500/day |
| 1 all-live cricket poll every 20s | 4,320 (≈129,600/month) | OpenCricketAPI Developer 250k/month |
| 10 matches polled individually every 30s | 28,800 | No free tier; needs Ultra/Mega or a relay |
| 1 all-live football poll every 30s + 1 cricket poll every 20s | ~7,200/day | API-Football Pro + OpenCricketAPI Developer |

Consequences:

- Use the provider's **all-live** endpoint. Never poll per match unless the user has pinned exactly one match and the provider has no all-live endpoint.
- Poll only while the Sports pane is visible, or while a pinned/favorite match is live and the user has enabled the notch score. Do not poll 24/7 by default.
- Slow down when nothing is live: fixtures every 5–15 minutes, competitions once a day.
- On 429, honor `Retry-After`; on 5xx, back off 15s → 30s → 60s → 2m → 5m; on 401/403, stop and show "Reconnect in Settings".
- A shared relay changes the math: one upstream poll serves every user. That is the only way a free consumer app can afford continuous live scores.

---

## 6. Licensing and attribution

- **Do not ship a provider key in the app.** Keys are extractable from a Mac binary, and every provider's terms prohibit sharing or exposing them.
- **BYOK** (bring your own key) is the only zero-server option. Store keys in the macOS Keychain, never in `UserDefaults`, logs or crash reports.
- **Hosted relay** is the only way to give every user a zero-setup feed. The key stays on the server; the app authenticates to the relay. This needs a privacy policy, abuse limits and ongoing hosting cost.
- Provider terms differ on redistribution:
  - Sportmonks: apps are allowed; reselling the raw feed is not; account sharing is not; logos/photos need separate rights.
  - BigBallsData: displaying data in an app is allowed; reselling the raw feed or sharing a key is not.
  - OpenCricketAPI: live data is ESPN-derived with no open licence; commercial use is on Pro.
  - SportScore: attribution is mandatory on the free tier; the exact badge is web-oriented.
- **Team crests and league logos are separate intellectual property.** For the MVP, use team abbreviations and colors (monogram circles) rather than official crests. Add logos only after checking the provider's logo rights.
- Attribution in the app: a small "Data by [provider]" link in Settings and at the bottom of the Sports pane. Even where not legally required, it is good practice and a condition of some free tiers.

---

## 7. Architecture

### 7.1 Models

Create `Sources/ArrowslitKit/Core/SportsModels.swift`:

```swift
public enum Sport: String, Codable, Sendable {
    case football, cricket
}

public struct Competition: Identifiable, Hashable, Sendable {
    public let id: String          // canonical: "football/premier-league"
    public let sport: Sport
    public let name: String
    public let shortName: String
    public let country: String?
    public let priority: Int       // for sorting
}

public struct Team: Identifiable, Hashable, Sendable {
    public let id: String          // provider-stable id
    public let name: String
    public let shortName: String   // "LAL", "BAR", "IND"
    public let color: String?      // hex, optional
}

public enum MatchState: String, Codable, Sendable {
    case scheduled, live, break, finished, postponed, cancelled, abandoned
}

public struct FootballScore: Hashable, Sendable {
    public var home: Int
    public var away: Int
    public var minute: Int?        // 67
    public var stoppage: Int?      // 90+3
    public var aggregateHome: Int?
    public var aggregateAway: Int?
}

public struct CricketInnings: Hashable, Sendable {
    public let teamID: String
    public var runs: Int
    public var wickets: Int
    public var overs: Double       // 42.3
    public var declared: Bool
    public var followOn: Bool
}

public struct CricketScore: Hashable, Sendable {
    public var innings: [CricketInnings]
    public var target: Int?
    public var requiredRate: Double?
    public var batters: [String]  // "Kohli 75*", "Rahul 32"
    public var bowler: String?     // "Cummins 2/34"
    public var day: Int?           // Test: Day 3
    public var statusLine: String? // "India need 84 runs"
}

public struct Match: Identifiable, Hashable, Sendable {
    public let id: String
    public let sport: Sport
    public let competition: Competition
    public let home: Team
    public let away: Team
    public let start: Date
    public var state: MatchState
    public var football: FootballScore?
    public var cricket: CricketScore?
    public var venue: String?
    public var lastUpdated: Date
    public var source: String
}
```

Keep the provider payloads out of the UI. Adapters decode provider JSON and produce only these types.

### 7.2 Service and adapters

Create `Sources/ArrowslitKit/Services/SportsService.swift`:

```swift
public protocol SportsProvider: Sendable {
    var id: SportsProviderID { get }
    func competitions(sport: Sport) async throws -> [Competition]
    func liveMatches(sport: Sport) async throws -> [Match]
    func matches(competition: CompetitionID, from: Date, to: Date) async throws -> [Match]
    func match(id: MatchID) async throws -> Match?
}
```

Adapters:

| Adapter | Football | Cricket |
|---|---|---|
| `APIFootballProvider` | `GET /fixtures?live=all`; `/fixtures?league=&season=&from=&to=`; `/leagues` | — |
| `SportmonksFootballProvider` | `/v3/football/livescores/inplay`; fixtures by league/date | — |
| `SportmonksCricketProvider` | — | `/v3/cricket/livescores/inplay`; fixtures; match detail |
| `OpenCricketProvider` | — | `GET /v1/live`; `/v1/fixtures`; `/v1/matches/{id}` |
| `BigBallsProvider` | `/v1/matches?sport=football&league=` | `/v1/cricket/matches`; `/v1/cricket/matches/{id}/state` |

`SportsService` is `@MainActor @Observable`:

```swift
public enum SportsLoadState: Equatable {
    case disabled
    case idle
    case loading
    case ready(SportsSnapshot)
    case failed(String)
}

public struct SportsSnapshot: Equatable {
    public var live: [Match]
    public var upcoming: [Match]
    public var finished: [Match]
    public var lastUpdated: Date?
    public var isStale: Bool
}
```

Responsibilities:
- Own the provider and the Keychain key.
- Single-flight refresh: if a refresh is already running, return the same task.
- Merge football + cricket snapshots into one list.
- Sort: pinned > favorite team > favorite competition > live > starting soon > priority.
- Expose `hasLiveFavorite`, `pinnedMatch`, `liveCount`.
- Stop all polling when `sportsEnabled == false` or the app is asleep.

### 7.3 Polling, caching and backoff

Use a `Task` loop, not a `Timer`:

```swift
private func runPolling() {
    pollTask = Task { [weak self] in
        while !Task.isCancelled {
            await self?.refresh()
            let interval = self?.currentInterval ?? .seconds(30)
            try? await Task.sleep(for: interval)
        }
    }
}
```

Policy:

| Situation | Interval |
|---|---|
| Sports pane visible, live matches | 20–30s |
| Sports pane visible, no live matches | 60s |
| Pane closed, pinned/favorite live, notch score on | 30s |
| Pane closed, nothing live | stop |
| App asleep / screen locked | stop |
| After 429 | `Retry-After` |
| After network error | 15, 30, 60, 120, 300s |
| Fixtures / competitions | 5–15 min / 24h |

Cache:
- In-memory snapshot with `lastUpdated`.
- `URLCache` for HTTP responses (10 MB memory, 50 MB disk).
- Do not persist raw provider payloads; persist only settings and favorites.
- Mark the UI stale when `now - lastUpdated > 2 × interval`; never show a stale score as live without a stale badge.

Rate limiter:
- Token bucket per provider.
- Count every request, including retries.
- Prefer one all-live request per sport per tick.

### 7.4 Settings and Keychain

Add to `SettingsStore`:

```swift
public var sportsEnabled: Bool
public var sportsProvider: String          // "api-football", "sportmonks", ...
public var sportsRefreshSeconds: Int       // 15, 30, 60
public var sportsShowInNotch: Bool
public var sportsGoalAlerts: Bool
public var sportsWicketAlerts: Bool
public var sportsCompetitions: [String]    // canonical ids
public var sportsTeams: [String]           // canonical ids
public var sportsPinnedMatch: String?
```

Keys in Keychain:

```swift
KeychainStore(service: "com.j4yop.arrowslit.sports", account: providerID)
```

Settings UI, after Features:

- **Sports** toggle (default off).
- **Provider**: API-Football + OpenCricketAPI / Sportmonks / BigBallsData / Demo.
- **API key** fields (SecureField), "Save in Keychain", "Test connection".
- **Competitions**: checkboxes grouped Football / Cricket.
- **Following**: favorite teams, optional search.
- **Refresh**: 15 / 30 / 60 seconds.
- **Show live score in the notch**.
- **Goal and wicket alerts** with the note "only while Arrowslit is running".
- **Data by [provider]** link.
- **Clear sports cache**.

When Sports is off, do not read the Keychain, do not create a `URLSession` task, and do not poll.

### 7.5 Nook and launcher

The live expanded surface is `NookView`: **560×178**, or 560×204 on Home. `WorkbenchView` (720×420) exists in the source but is not currently used by the app; do not wire Sports into it.

Add `WorkbenchTab.sports` in `AppState.swift`:

- `title`: "Sports"
- `symbol`: `"sportscourt"` (or `"soccerball"`)
- Add to the `NookView` switch.
- Add to `LauncherPane.items` and `tint` (green/blue). Twelve tiles still fit six columns × two rows.
- Add to the Settings feature grid.
- Do not make it a primary tab by default; let the user pin it as a shortcut.

`SportsPane` layout for 560×178:

- Top row (about 24pt): `Football` / `Cricket` chips, then competition chips, a live count, and a small refresh/status label.
- Main area: a horizontal `ScrollView` of match cards, about 168×96 each, three visible at once.
- Match card: competition + status pill; home/away abbreviations; score; minute/overs; favorite star; pin button.
- Tapping a card replaces the card row with an inline match detail: scoreboard on the left, events/innings on the right, and a back chevron. Keep the first version read-only.
- Empty state: "No live matches right now" + the next fixture.
- Error state: "Sports is offline" + "Retry" + "Open Settings".

Do not try to fit a full scorecard into 178pt. The nook is a scoreboard; the inline detail is the scorecard.

### 7.6 Compact notch (32px)

This is the delightful part, but it is also the most constrained.

Add `NotchActivity.sports` and a branch in `CompactBar`:

- Left ear: competition/team abbreviation + a small live dot.
- Right ear: score + clock/overs.
- Show only the **pinned** or highest-ranked live favorite.
- If there are two live favorites, show the pinned one; the Sports pane shows the rest.
- Only when `sportsEnabled && sportsShowInNotch && sports.hasLiveFavorite`.
- Give sports a priority below calls and timers, above now playing? A live match is arguably more important than music, but a user might disagree. Suggested order: call → timer → sports → stopwatch → nowPlaying → charging → stats. Make it configurable later if needed.

### 7.7 Goal and wicket alerts

Add a `NotchAlert` case:

```swift
case sports(kind: SportsAlertKind, match: String, detail: String)

public enum SportsAlertKind: String, Sendable {
    case goal, wicket, fullTime, inningsBreak
}
```

- `kind`: `.sports`
- `displayDuration`: 6 seconds
- `usesCompactHUD`: true for a one-line goal/wicket; false for a full score card
- `isUrgent`: false
- Tap opens the Sports pane on that match.

Detect changes by diffing the previous and new snapshots:
- Football: home/away goals increased.
- Cricket: wicket count increased or innings ended.
- Do not alert on the first load; only on a change after a baseline.
- Respect `sportsGoalAlerts` / `sportsWicketAlerts` and `hapticFeedback`.
- Debounce: one alert per match per 10 seconds.

**Important macOS constraint:** Arrowslit is ad-hoc signed. Local notifications work while the app is running, but **background push when the app is quit requires APNs**, which requires an Apple Developer Program membership, Developer ID signing and notarization. In-app notch alerts are the only reliable MVP. "Alert me when Arrowslit is closed" is a separate project.

### 7.8 Home

Do not displace the current three-column Home. Options, in order:

1. Add a small "Live now" chip in the Home header that opens Sports. Minimal risk.
2. Add a fourth narrow column only when a favorite is live. The 560pt Home is already tight; test on a 14-inch MacBook.
3. Swap the Timer column for a live match card when a favorite is live, with a "Timer" button to switch back. This is clever but can surprise the user.

Recommendation: option 1 for the first release; consider option 2 after a visual review.

---

## 8. "Most viewed match-ups"

A local-first app has no global view counts. Do not add silent telemetry just to rank matches.

Three honest options:

1. **Following (recommended):** the user pins matches and follows teams/competitions. Rank pinned > favorite team > favorite competition > live > starting soon. This is predictable and private.
2. **Featured:** a curated list of big fixtures (El Clásico, Manchester derby, UCL knockout, IPL playoffs, India–Australia, Ashes). This can be a static JSON file shipped with the app, updated each release. No backend.
3. **Global trending:** a relay aggregates anonymous "match opened" counts. This requires consent, a privacy policy and a backend. Only do this if the product explicitly promises "most viewed by everyone".

For the first version, use **Following + Featured**. Call the section "Following" or "Live & Upcoming", not "Most viewed".

---

## 9. Phased plan

### Phase 1 — UI shell with demo data (no network)
- Models, `SportsPane`, `CompactSports`, launcher/settings wiring.
- Demo matches: Real Madrid vs Barcelona, India vs Australia (Test), IPL match.
- Verify the 560×178 nook, the 560×204 Home height and the 32px compact strip.
- No provider, no keys, no network.

### Phase 2 — First real adapter
- Choose one free provider (BigBallsData Free or SportScore).
- Build the adapter and normalization tests.
- Poll only while the Sports pane is open; 60s.
- Prove the end-to-end path with a real competition.

### Phase 3 — Production BYOK
- API-Football (football) + OpenCricketAPI (cricket), or Sportmonks for both.
- Keychain, Settings, provider picker, competitions, favorites.
- 20–30s polling while visible; 30s when a pinned match is live.
- Compact notch score + goal/wicket alerts.
- Tests for normalization, ranking, polling policy, rate-limit backoff.

### Phase 4 — Relay and background alerts (only if shipping broadly)
- Cloudflare Worker or small Vapor service.
- Provider keys on the server; shared cache; normalized `/v1/sports/live`.
- App authenticates with an anonymous install token.
- APNs for background alerts, which also requires Developer ID signing and notarization.
- Paid tier or donations to cover provider + hosting costs.

---

## 10. Test plan

Pure logic tests, no live network:

- Decode API-Football fixture JSON → canonical `Match`.
- Decode OpenCricketAPI `/v1/live` JSON → canonical `Match`.
- Decode Sportmonks cricket innings JSON → `CricketScore`.
- Status mapping: `1H`, `HT`, `2H`, `ET`, `P`, `FT`, `NS`, `PST`, `CANC`; cricket `live`, `innings break`, `stumps`, `result`.
- Football score change detection: 1–0 → 2–0 emits one goal alert, not two.
- Cricket wicket detection: 245/5 → 245/6 emits one wicket alert.
- Ranking: pinned > favorite team > favorite competition > live > upcoming.
- Polling: disabled → zero requests; 429 → backoff; 401 → stop; cache hit → zero requests.
- Formatting: `67'`, `90+3'`, `245/6 (42.3)`, required run rate, Test `Day 3 · Stumps`.
- Settings persistence; Keychain is not touched when Sports is off.

Use `URLProtocol` stubs for provider tests. Keep recorded JSON small and redact keys.

---

## 11. Decisions needed before coding

1. **Who pays?**
   - BYOK (user brings keys): no server, honest local-first, but each user needs a subscription.
   - Hosted relay: zero setup for users, but you pay the provider and host it.
   - Free provider: zero cost, but coverage/terms/rate limits are weak.

2. **Which competitions are must-have?**
   - Football: EPL, La Liga, UCL only, or also Serie A/Bundesliga?
   - Cricket: IPL + T20Is, or also ODIs and Tests? Tests/ODIs force Sportmonks World (€75), not Major (€29).

3. **Alerts:** notch-only while Arrowslit is running, or system notifications/background? Background requires APNs and a signed app.

4. **"Most viewed":** local Following + Featured, or global trending with telemetry?

5. **Provider:** best coverage (Sportmonks), lowest cost (API-Football + OpenCricketAPI), or single key (BigBallsData)?

6. **Free or paid Sports tier?** A free app cannot absorb €104/month per active user. If Sports ships to everyone, it needs a funding model.

---

## 12. Sources

- API-Football pricing: <https://www.api-football.com/pricing>
- API-Football documentation: <https://www.api-football.com/documentation-v3>
- Sportmonks football plans: <https://www.sportmonks.com/football-api/plans-pricing/>
- Sportmonks cricket plans: <https://www.sportmonks.com/cricket-api/plans-pricing/>
- Sportmonks cricket coverage: <https://www.sportmonks.com/cricket-api/coverage/>
- Sportmonks livescores docs: <https://docs.sportmonks.com/football/endpoints-and-entities/endpoints/livescores>
- Sportmonks terms: <https://www.sportmonks.com/terms-of-service/>
- OpenCricketAPI pricing: <https://opencricketapi.com/pricing>
- OpenCricketAPI docs: <https://opencricketapi.com/docs>
- BigBallsData pricing: <https://bigballsdata.com/pricing>
- BigBallsData football: <https://bigballsdata.com/football-api>
- BigBallsData cricket: <https://bigballsdata.com/cricket-api>
- BigBallsData coverage: <https://bigballsdata.com/coverage>
- BigBallsData terms: <https://bigballsdata.com/legal/terms>
- SportScore developer terms: <https://sportscore.com/developers/terms/>
- Entity Sport pricing: <https://www.entitysport.com/pricing>
