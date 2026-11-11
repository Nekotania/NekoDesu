# NekoDesu --- Project Specification

> **Purpose:** This document is the source of truth for the product's
> behavior, architecture, constraints, and implementation conventions.
> Read it before changing the application.
>
> **Product in one sentence:** NekoDesu is a macOS menu bar
> procrastination meter with a personality: a pixel-art catgirl, a fake
> internet-rank ritual, a passive-aggressive clipboard companion, and an
> optional browser honesty pass.

## 1. Product principles

NekoDesu is one desktop companion, not a collection of loosely connected
utilities.

1. **One app, one process.** Every feature belongs to the same macOS

   application.
2. **Local-first and offline.** No network requests, accounts, backend,

   analytics, telemetry, or synchronization.
3. **Personality is product behavior.** Copy, timing, rank ceremonies,

   and the desk cat are part of the experience.
4. **Explain observation.** The UI must plainly explain what each

   feature detects, why it needs access, and what it does not collect.
5. **Never take consequential actions for the user.** In particular,

   the honesty pass must not click controls, submit forms, or navigate
     pages.
6. **Keep the implementation understandable.** Prefer small, explicit

   components and centralized configuration over clever abstractions.
7. **Do not invent product behavior.** If a requirement is ambiguous,

   preserve the ambiguity as an open decision rather than quietly
     choosing a behavior.

## 2. Decisions and constraints

### Platform

- macOS application.
- Deployment target: macOS 13.
- Swift and SwiftUI, with AppKit where the system API or window
behavior requires it.
- One `MenuBarExtra` for the menu bar interface.
- One borderless, transparent, non-activating window for the desk cat.
- No second application target, browser extension target, helper app,
or separate repository.
- The Tauri alternative mentioned in the original issue is not part of
this project.

### Network and data

- The application must not make network requests.
- No account, backend, analytics, telemetry, remote configuration, or
sync.
- Clipboard content must never be uploaded or persisted.
- Browser page content is inspected locally for the honesty pass.
- Persist only the minimum state needed for the experience: rank,
meter progress, user preferences, and non-sensitive counters or
timestamps where needed.
- Use the app's Application Support directory for generated
certificates and app-owned persistent data.
- Do not store raw clipboard text, browser page text, Discord
messages, or microphone audio.

### Product rules

- Ranks only increase. There is no demotion mechanic.
- A joke about a revoked rank is copy only; it does not describe real
application behavior.
- The E-Kitten rank is earned by the Discord ritual clock.
- Ranks after E-Kitten are earned by procrastination-toggle minutes.
- The procrastination toggle is a deliberate user action. Do not infer
procrastination from inactivity.
- No streaks, shame dialogs, achievement stack, or phone companion.
- Discord Daddy Mode copy is disabled by default and must be gated consistently
wherever the relevant copy appears.

## 3. Application structure

Keep the project in one target. The following is the intended
responsibility map; filenames may evolve, but responsibilities should
remain recognizable.

```text
Sources/NekoDesu/
  NekoDesuApp.swift
  App/
    AppModel.swift
    AppState.swift
    MenuBar/
      MenuBarView.swift
      MenuBarIcon.swift
    Settings/
      SettingsView.swift
  CatEars/
    CatEarsModel.swift
    ProcrastinationTimer.swift
    DiscordActivityMonitor.swift
    Rank.swift
    RankProgression.swift
    RankCeremony.swift
    CertificateGenerator.swift
  DeskCat/
    DeskCatController.swift
    DeskCatWindow.swift
    DeskCatView.swift
    SpriteAnimator.swift
    SpeechBubbleView.swift
    ScreenPositioning.swift
  Clipboard/
    ClipboardMonitor.swift
    ClipboardClassifier.swift
    ClipboardEvent.swift
  Honesty/
    HonestyPass.swift
    BrowserAutomation.swift
    PhrasePack.swift
    PhraseMatcher.swift
  Voice/
    VoiceCatalog.swift
    RankCopy.swift
    ClipboardCopy.swift
    CeremonyCopy.swift
  Privacy/
    PrivacyDisclosure.swift
    PermissionExplainerView.swift
  Persistence/
    PersistenceStore.swift
    StoredAppState.swift
Resources/
  Catgirl/
  Phrases/
```

This is a proposed organization, not a requirement to create every file
before implementation. Create a file when it has a clear responsibility.
Avoid one giant view/model file and avoid splitting tiny types into
files without a reason.

### Ownership boundaries

  -----------------------------------------------------------------------

  Area                    Owns                    Must not own

  ----------------------- ----------------------- -----------------------

  App                     App lifecycle,          Feature-specific rules
                          dependency  
                          construction, top-level 
                          presentation            

  CatEars                 Clock inputs, points,   Clipboard or browser
                          rank progression,       behavior
                          ceremonies              

  DeskCat                 Window, sprite          Rank calculations
                          animation, positioning, 
                          speech bubble           

  Clipboard               Pasteboard polling,     Long-term clipboard
                          classification, copy    history
                          count, notification  
                          request                 

  Honesty                 Browser identification, Page mutation or
                          local phrase matching,  automated clicks
                          result presentation     

  Voice                   All user-facing copy    Timers and system API
                          and rank/phrase         calls
                          configuration           

  Privacy                 Disclosure text and     Permission workarounds
                          permission explanations 

  Persistence             Reading/writing         Deciding product rules
                      app-owned state         

  -----------------------------------------------------------------------

Use dependency injection or a small composition root so feature models
can be tested without invoking real macOS services.

## 4. State, persistence, and time

### State categories

Keep these concepts distinct:

- **Runtime state:** Whether monitors are active, current detected
Discord state, current clipboard line, current honesty result, and
animation state.
- **Persistent state:** Current rank, accumulated points/minutes,
preferences, ceremony completion, and copy count if retained across
launches.
- **Derived state:** Progress to the next rank, rank label, menu bar
appearance, and whether a ceremony is available.

Do not persist values that can be derived reliably from other stored
values.

### Persistence expectations

- Store app-owned data locally in Application Support or an
appropriate system preference store.
- Use a versioned Codable representation for structured persistent
state.
- Include a schema version so future changes can migrate old state
safely.
- Write state atomically where practical.
- If stored data is missing or invalid, start from safe defaults; do
not crash or invent progress.
- Do not store raw clipboard content or browser page content.
- Generated certificates are files, not the source of truth for rank
state.

### Timekeeping

- Treat elapsed time as elapsed duration, not as a count of timer
callbacks.
- A timer callback can be delayed by app suspension, system load, or
sleep. Never award time merely because a callback fired.
- Record the last accounting timestamp and calculate elapsed time when
the monitor updates.
- Define explicitly whether time during system sleep counts. This is
an open product decision until tested and resolved.
- Clamp or discard unreasonable elapsed intervals after sleep, clock
changes, or long suspension rather than granting a surprising amount
of progress.
- Keep time conversion and point calculation in testable pure
functions.

## 5. Cat Ears Meter

The Cat Ears Meter is the core feature. The menu bar panel displays the
current rank, progress to the next rank, and the **"I'm
procrastinating"** toggle.

### 5.1 Rank ladder

Ranks, from lowest to highest:

1. E-Kitten
2. Stray Cat
3. Street Cat
4. Alley Cat
5. House Cat
6. The Great Old Cat

"Professional Nagger" and "Archduke of Later" are flavor titles shown
beneath a rank. They are not ranks and must not affect progression.

### 5.2 Procrastination toggle

- The user explicitly turns the toggle on or off.
- One full minute while enabled awards one point.
- Points accumulate only while enabled.
- The first threshold after E-Kitten is 30 minutes; subsequent
thresholds are 90, 180, 360, and 720 minutes.
- Thresholds are configuration data in one rank table, not scattered
magic numbers.
- Display progress toward the next rank. At the maximum rank, show a
completed/max-rank state rather than calculating a nonexistent next
rank.
- Persist accumulated progress so quitting and reopening the app does
not erase it.
- Turning the toggle off stops accumulation immediately.
- The toggle must not be enabled automatically on launch.

### 5.3 Discord ritual clock

The Discord clock awards progress toward E-Kitten only. It pauses when
Discord is not running.

Discord detection:

- Use `NSWorkspace` and bundle identifier `com.hnc.discord`.
- A visible Discord window is treated as open/visible.
- Discord running without a visible window is treated as
minimized/background for the purpose of the current design.
- Detect microphone activity using
`kAudioDevicePropertyDeviceIsRunningSomewhere`.
- Do not open an audio capture stream.
- Do not request microphone recording permission.
- Never inspect Discord messages, servers, channels, call
participants, or conversation content.

Current intended rates:

  -----------------------------------------------------------------------

  Detected state                                            Intended rate

  ------------------------------ ----------------------------------------

  Discord running, visible,                    1×; 20 minutes to E-Kitten
  microphone idle                

  Discord running, in a call                   ¼×; 80 minutes to E-Kitten

  Discord running,               Slower rate; exact multiplier is not yet
  minimized/background                                          specified

##   Discord not running                                              Paused

**Important implementation caveat:**
`kAudioDevicePropertyDeviceIsRunningSomewhere` indicates that an audio
device is in use; it does not prove that Discord itself is using the
microphone. Another application may cause a false positive. The
implementation must describe this limitation honestly and must not claim
that it can identify a Discord call with certainty. Keep the detection
logic isolated so it can be improved later without rewriting rank
progression.

**Open decisions to resolve before treating the clock as final:**

- What exact multiplier applies while Discord is minimized/background?
- Does Discord running with no visible window always count as
minimized, or can it be a background state?
- Should time during macOS sleep count? The default implementation
should avoid awarding unobserved time until decided.
- What should happen if Discord is visible but another app is using
the microphone?

### 5.4 E-Kitten ceremony

When the ritual clock first reaches the E-Kitten threshold, run the
ceremony once:

1. Update the rank.
2. Change the menu bar icon.
3. Play a short ear animation.
4. Send a local notification.
5. Make the ceremony line available to the desk cat.
6. Generate a certificate in Application Support.
7. Offer a way to reveal the certificate in Finder.

The ceremony must be idempotent: repeated timer updates, app restarts,
or duplicate events must not issue the same achievement repeatedly.

Certificate text, verbatim:

> This hereby certifies that the bearer has achieved the prestigious
> rank of E-Kitten, following extensive Discord-based research.
>
> Signed: The Great Old Cat.

A PDF is acceptable if PNG generation is materially harder. The
certificate is an artifact of the achievement, not a requirement for the
achievement to persist.

### 5.5 Later rank-ups

When a procrastination threshold is reached:

- Advance exactly to the newly earned rank.
- Update the menu bar icon.
- Play a short ear animation.
- Send a local notification.
- Arm one desk-cat click with the relevant rank line.
- Do not demote, reset, or stack achievements.

### 5.6 Ceremony copy and Discord Daddy Mode setting

Discord Daddy Mode notifications are off until explicitly enabled.

When off, choose one of these lines for the E-Kitten ceremony:

- "Congratulations. Your e-kitten application has been approved.
Please collect your complimentary cat ears."
- "You've been online long enough. The transformation paperwork has
been finalized."
- "Discord has determined that you are now legally a creature of the
internet."
- "The cat distribution system has reviewed your application. You have
been selected."
- "Your previous rank has been revoked. Please familiarize yourself
with your new meow-based responsibilities."

When on, the ceremony may use this line, verbatim, as the one additional
line:

> You're an e-kitten now. Prepare the cat ears, m'lady.

Do not write additional jokes about bodies or gender. The panel
describes the ceremony as a fake internet ritual.

## 6. Desk cat

The desk cat is a persistent visual companion, not a separate app.

### Asset handling

- Use the user's animated pixel-art frames in `Resources/Catgirl/`.
- Accept either a PNG sequence or a sprite sheet with an explicitly
configured frame size.
- Do not redraw, generate a replacement, trace, recolor, or restyle
the supplied artwork.
- Scale by an integer factor.
- Use nearest-neighbor sampling so pixels remain crisp.
- Loop the idle animation while visible.
- If a talk cycle exists, play it while a speech bubble is visible;
otherwise keep the idle loop.

### Window behavior

- Borderless, transparent, and non-activating.
- Joins every Space.
- Does not take keyboard focus.
- Appears at the bottom-left of the primary display from first launch.
- Sits above the Dock when the Dock is on that edge.
- Repositions when the display frame or Dock placement changes.
- Clicks should be accepted only on opaque sprite pixels; transparent
areas should pass through.
- The cat should not block ordinary interaction with other windows.

Use AppKit window APIs where SwiftUI does not expose the required
behavior. Keep window lifecycle and screen-position calculations outside
the sprite view.

### Speech behavior

- A rank-up arms one click.
- Clicking after an achievement opens a small speech bubble beside the
sprite.
- E-Kitten uses the selected ceremony line.
- Later ranks use their configured rank line.
- The bubble closes on a second click or after a few seconds.
- Further clicks repeat the latest available line.
- Before the first achievement, clicking does nothing.
- Clipboard events and honesty passes never arm the cat.
- The Discord Daddy Mode setting gates the desk-cat ceremony line in the same way
it gates the notification.
- A click should consume the one-shot armed event; it should not
create a new achievement.

Starting lines:

- Stray Cat: "Stray Cat. Thirty minutes of not doing the thing. I'm so
proud I could cough up a hairball."
- Street Cat: "Street Cat. You've made procrastination a place. It has
a smell."
- Alley Cat: "Alley Cat. At this point the task is a rumor."
- House Cat: "House Cat. You live here now. The work does not."
- The Great Old Cat: "The Great Old Cat. I sat on this corner the
entire time. You did the rest, which was nothing."

## 7. Passive-aggressive clipboard

The clipboard watcher belongs to the same app and panel.

### Monitoring

- Poll `NSPasteboard.general.changeCount` approximately every 250 ms.
- A changed count indicates a new copy event.
- Post one local notification for each detected copy event, subject to
normal notification authorization and any user preference added
later.
- Update the panel with the latest line and "Last copied: N times".
- Do not read or retain clipboard content unless needed briefly to
classify the current event.
- Do not write clipboard content to disk, logs, crash reports,
analytics, or notifications.
- Do not replace or modify the user's clipboard contents.

### Classification

When text is available, inspect only the minimum information needed to
select a line:

- Whether it matches the previous copied text.
- Whether it is a URL.
- Whether it resembles code.
- Whether it contains an email address.
- Approximate text length.
- Whether several copy events occurred in a short burst.

The copied string must be discarded after classification and line
selection. Retain only the count, selected line, and any minimal
non-content metadata required for duplicate/burst behavior. If duplicate
detection requires comparing text, keep only a short-lived in-memory
fingerprint or equivalent and never persist it. Prefer a keyed digest
over retaining the original string.

If the pasteboard does not contain readable text, use a generic line. Do
not attempt to decode arbitrary binary clipboard formats.

### Copy catalog

Base lines:

- "Ok, we're copying that now? Okay."
- "Control-C? That's a choice. Don't @ me."
- "I came here to assure you that remembering is possible."
- "I see you. I have always seen you."

Content-aware behavior:

  -----------------------------------------------------------------------

  Situation                           Intended response

  ----------------------------------- -----------------------------------

  Same text twice                     "Same thing twice."

  Same text again within a few        "You copied this 4 seconds ago. Do
  seconds                             you not trust me?"

  URL                                 Select a URL-specific line

  Code-like text                      "Stack Overflow again? Proud of
                                      you."

  Email address                       Select an email-specific line

  Very long text                      "That's a whole essay. We have
                                      files for that."

##   Several copies in a short burst     Use a sharper burst line

All lines, including sharper lines, live in `Voice/`. Classification
rules should be separate from copy strings.

### Panel behavior

Show:

- Latest clipboard reaction.
- Total detected copy count.
- A plain-language disclosure explaining that the watcher detects copy
events and briefly examines text locally to choose a reaction.

Do not show copied text in the panel.

## 8. Honesty pass

The honesty pass is a local phrase matcher for the frontmost browser
page. It replaces the proposed Chrome extension; it is not an extension.

### User flow

1. The user selects the honesty-pass menu item or panel button.
2. Before the first browser inspection, explain that macOS Automation

   permission is needed to identify the frontmost browser tab.
3. Request permission only after the user understands why it is needed.
4. Identify the frontmost supported browser page.
5. Match visible or otherwise safely obtainable page text against the

   local phrase pack.
6. Display the result in the NekoDesu panel.

If the browser is unsupported, unavailable, or permission is denied,
show a clear explanation and do not pretend the pass succeeded.

### Levels

- Gentle --- default.
- Brutal.
- Unhinged.

The selected level changes which local replacement line is chosen. Keep
level selection explicit and predictable.

### Phrase pack

- Store phrase data locally as JSON.
- Keep matching logic separate from phrase data.
- Support situation keys and optional host overrides.
- Initial host overrides: Amazon, Apple, Google, GitHub, and
subscription pages.
- Phrase data must be editable without changing browser automation
code.
- Validate phrase-pack structure when loading it. Invalid or missing
data should produce a safe fallback, not a crash.

Starting pairs:

  -----------------------------------------------------------------------

  Original                            Honest version

  ----------------------------------- -----------------------------------

  "We use cookies to improve your     "We use cookies to follow you
  experience."                        around the internet."

  "Accept all"                        "Yeah, take my soul."

  "Manage preferences"                "Good luck finding the off switch."

  "Join the community"                "We want your email."

  "Limited time offer"                "The timer is fake and the internet
                                      is forever."

  "No thanks, I don't like saving     "No thanks, I have self-respect."
  money."                             

##   "Cancel anytime"                    "After 7 menus and a phone call."

### Safety and scope

- The pass never clicks Accept.
- It never fills forms.
- It never submits forms.
- It never navigates or changes the page.
- It never reads mail, messages, or account data.
- It does not inspect arbitrary browser history or tabs.
- A later version may replace visible banner text, but only after the
read-only panel pass is implemented and tested. Such replacement
remains opt-in and must not activate controls.

The initial implementation is read-only: it reports a matched phrase in
the panel and leaves the page untouched.

## 9. Voice and configuration

`Voice/` is the single source of truth for user-facing lines and rank
configuration.

- Keep copy out of view bodies, timer code, and notification plumbing.
- Separate copy by feature: ceremony, ranks, clipboard, and honesty
pass.
- Keep rank thresholds in one table.
- Keep the Discord Daddy Mode line in one clearly identified location.
- Prefer stable keys for phrase packs rather than matching on display
copy.
- Do not duplicate the same line in multiple files.
- Copy changes should not require changing feature logic.

## 10. Privacy disclosures and permissions

The panel must explain what each feature observes before or when the
feature is enabled.

Required disclosure text:

- **Discord ritual:** "The ritual watches whether Discord is running,
whether it has a visible window, and whether the microphone is in
use. It never reads messages, servers, or conversations."
- **Clipboard:** "The clipboard watcher sees that a copy happened,
plus enough of the text to pick a line. It stores the count, not the
text, and it uploads nothing."
- **Honesty pass:** "The honesty pass sees the frontmost site so it
can pick a line. It never reads mail, messages, or account data."

Permission rules:

- Explain Automation permission before requesting it.
- Do not request microphone recording permission or open an audio
capture stream.
- Do not bypass macOS permission controls.
- If permission is unavailable or denied, explain the limitation and
leave the rest of the app usable.
- Never claim a stronger privacy guarantee than the implementation
actually provides.

The microphone disclosure should be understood as device-activity
detection, not audio recording. The implementation must not capture,
decode, or store microphone audio.

## 11. Notifications

- Use local notifications only.
- Request notification authorization at an appropriate point in the
user flow and explain why.
- A notification failure must not prevent rank progression or
certificate generation.
- Keep notification content in `Voice/`.
- Discord Daddy Mode copy remains disabled by default.
- Avoid duplicate notifications for the same achievement or clipboard
change event.
- Do not put clipboard contents or browser page text into notification
payloads.

## 12. Error handling and degraded behavior

The app should remain usable when an optional system capability is
unavailable.

Examples:

- Discord not installed or not running: ritual clock is paused; other
features remain available.
- Audio activity cannot be queried: report an unknown/limited
detection state; do not pretend to know whether a call is active.
- Notification permission denied: update the panel and continue
without notifications.
- Automation permission denied: honesty pass explains how to enable
access; no page inspection occurs.
- Certificate generation fails: rank remains earned; report that the
certificate could not be created and allow retry.
- Sprite resources are missing: show a clear development fallback or
omit the desk cat; do not silently substitute generated artwork.
- Invalid stored state: load safe defaults and preserve a diagnostic
that does not contain private content.

Avoid force unwraps for external resources, system APIs, or persisted
values. Errors should be surfaced at the feature boundary and translated
into concise UI copy.

## 13. Testing expectations

Prefer unit tests for pure logic and small integration tests around
system boundaries.

At minimum, test:

### Rank progression

- Every threshold maps to the correct rank.
- Progress is calculated correctly between thresholds.
- Maximum rank does not index beyond the rank table.
- Rank never decreases.
- Duplicate achievement events do not repeat ceremonies.

### Time accounting

- Full-rate, quarter-rate, and paused intervals.
- Toggle start/stop behavior.
- Delayed timer callbacks.
- Long suspension and clock changes.
- Persistence and restoration of accumulated progress.

### Discord detection

- Discord absent, visible, and running without a visible window.
- Audio-device query unavailable.
- Documented false-positive scenario where another app uses the
microphone.

### Clipboard

- Unchanged change count does nothing.
- One change produces one event.
- Duplicate, URL, code-like, email, long-text, and burst
classification.
- Non-text clipboard content uses a generic reaction.
- Raw clipboard text is not persisted or logged.

### Honesty pass

- Each level selects the intended local phrase.
- Host overrides take precedence only where configured.
- Unknown phrases produce a safe no-match result.
- Permission denial and unsupported browser behavior.
- No action modifies the page.

### Desk cat

- Sprite-sheet frame extraction.
- Integer scaling and nearest-neighbor rendering.
- Idle and optional talk animation.
- Window positioning across display/Dock changes.
- Transparent hit testing and non-activation.

Do not require a live Discord session, real clipboard interaction, or a
real browser for unit tests. Wrap system APIs behind small protocols or
adapters where that makes deterministic tests practical.

## 14. Implementation conventions

- Use clear, descriptive Swift names.
- Keep functions focused and avoid deeply nested conditionals.
- Prefer value types for configuration and event data.
- Keep time/rank/classification logic pure where possible.
- Use `@MainActor` for UI-facing state and window operations where
appropriate.
- Keep polling and system observation lifecycle explicit; start once,
stop when no longer needed, and avoid duplicate observers.
- Cancel timers, tasks, and notification observers when their owner is
torn down.
- Do not use force unwraps in normal runtime paths.
- Do not add dependencies without a concrete need.
- Do not add logging that includes clipboard text, browser text, or
other private content.
- Add comments for non-obvious macOS API behavior, not for code that
is already self-explanatory.
- Keep accessibility labels and useful keyboard navigation in the menu
bar panel.
- Keep UI copy centralized in `Voice/`.

## 15. Definition of done

A feature is not done merely because it compiles.

A feature is done when:

1. Its stated behavior works on the supported macOS deployment target.
2. Its failure and permission-denied paths are understandable.
3. It does not violate the one-app/offline/privacy constraints.
4. Its important logic has deterministic tests.
5. It has no duplicate observers, timers, or achievement events.
6. The panel accurately describes what the feature observes.
7. The feature's copy and configuration live in their intended central

   locations.

## 16. Explicitly out of scope

- A second app, a multi-app monorepo, or a standalone browser
extension.
- Accounts, backend services, analytics, telemetry, sync, or uploads.
- Reading Discord messages, servers, or conversations.
- Recording or analyzing microphone audio.
- Demoting ranks, streaks, shame dialogs, or a phone companion.
- Clicking through cookie banners or signup walls.
- Automatically submitting forms or accepting terms.
- Replacing the user's pixel art with generated or restyled assets.

## 17. Later ideas (not current commitments)

These ideas are intentionally not part of the initial implementation:

- A certificate for every rank, signed by the rank above.
- Custom thresholds and a configurable list of apps that count toward
the meter.
- Opt-in in-page replacement of cookie-banner text, still launched
from this app and never auto-clicking Accept.
- Extra clipboard voices: Godfather, GLaDOS, disappointed teacher, and
the rare slurp.
- Importing a local JSON phrase pack from disk.

Nekotania, the catgirl Discord bot, is the reference for the ritual's
tone. It is a tone reference, not a separate runtime dependency.
