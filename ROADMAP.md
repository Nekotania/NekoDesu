# NekoDesu --- Development Roadmap

> **Purpose:** This document tracks what to build, in what order, and
> how to decide whether a phase is finished.
>
> Product behavior, architecture, privacy rules, and implementation
> constraints live in [`AGENTS.md`](AGENTS.md). If this roadmap
> conflicts with that specification, update the specification
> deliberately and then reconcile this file.

## Project approach

NekoDesu is one native macOS menu bar companion. Build the features in
the order below, keeping each phase small enough to finish and verify
before moving on.

### Working rules

-   Keep all features in the same application target and process.
-   Build a thin vertical slice before polishing.
-   Prefer working behavior over placeholder UI.
-   Keep system APIs behind small adapters where that improves testing.
-   Do not start a later phase by quietly expanding an earlier phase's
    scope.
-   Record unresolved product decisions in the decision log below.
-   Do not mark a phase complete until its acceptance checklist passes.

### Status legend

-   `[ ]` Not started
-   `[-]` In progress
-   `[x]` Complete
-   `[?]` Blocked or awaiting a decision

Update these markers as implementation progresses. Do not mark work
complete solely because code exists; verify the acceptance criteria.

------------------------------------------------------------------------

## Phase 0 --- App foundation

**Goal:** Establish the single-app structure and prove the two UI
surfaces can coexist.

### Tasks

-   [x] Create the macOS app target with deployment target macOS 13.
-   [x] Set up SwiftUI app lifecycle and one `MenuBarExtra`.
-   [x] Create the menu bar panel shell.
-   [x] Create the desk-cat borderless window shell using AppKit where
    needed.
-   [x] Confirm the desk-cat window does not activate or take keyboard
    focus.
-   [x] Establish the proposed source-folder organization from
    `AGENTS.md`.
-   [x] Add a small persistence layer with versioned state.
-   [x] Add a composition root for constructing feature models and
    system adapters.
-   [x] Add a basic test target.
-   [x] Confirm the app makes no network requests and has no additional
    app/extension targets.

### Acceptance criteria

-   [x] App launches on macOS 13 or later.
-   [ ] Menu bar item opens and closes the panel.
-   [x] Desk-cat window can be shown independently of the panel.
-   [x] The two surfaces coexist without duplicate app instances.
-   [x] Stored state can be read and written locally.
-   [x] A clean install starts from safe defaults.

------------------------------------------------------------------------

## Phase 1 --- Cat Ears Meter

**Goal:** Ship the core joke: the Discord ritual earns E-Kitten, and the
procrastination toggle earns later ranks.

### 1.1 Rank model and progression

-   [ ] Define the six ranks in one ordered rank table.
-   [ ] Store the thresholds after E-Kitten in that table: 30, 90, 180,
    360, and 720 minutes.
-   [ ] Implement pure functions for rank lookup and
    progress-to-next-rank.
-   [ ] Implement maximum-rank behavior.
-   [ ] Ensure rank progression is monotonic and cannot demote.
-   [ ] Add unit tests for every threshold and boundary.

### 1.2 Procrastination toggle

-   [ ] Add the "I'm procrastinating" toggle to the panel.
-   [ ] Award one point per minute while enabled.
-   [ ] Account for elapsed duration rather than assuming timer
    callbacks are punctual.
-   [ ] Stop accumulation immediately when the toggle is turned off.
-   [ ] Restore accumulated progress after relaunch.
-   [ ] Show current rank and progress toward the next rank.
-   [ ] Do not enable the toggle automatically on launch.

### 1.3 Discord ritual clock

-   [ ] Detect Discord using `NSWorkspace` and `com.hnc.discord`.
-   [ ] Distinguish visible Discord from running-without-visible-window.
-   [ ] Query audio-device running state without opening an audio
    capture stream.
-   [ ] Implement full-rate, quarter-rate, and paused accounting.
-   [ ] Keep the minimized/background multiplier configurable until its
    value is decided.
-   [ ] Handle unknown audio-device state without claiming a call was
    detected.
-   [ ] Add tests for state transitions, delayed updates, and long
    suspension.
-   [ ] Add the Discord privacy explanation to the panel.

### 1.4 E-Kitten ceremony

-   [ ] Trigger the ceremony once when the ritual threshold is reached.
-   [ ] Change the menu bar icon.
-   [ ] Play the short ear animation.
-   [ ] Send a local notification.
-   [ ] Select ceremony copy from `Voice/`.
-   [ ] Generate the certificate in Application Support.
-   [ ] Add a panel action to reveal the certificate in Finder.
-   [ ] Make ceremony execution idempotent across repeated updates and
    relaunches.
-   [ ] Ensure notification or certificate failure does not undo the
    earned rank.

### 1.5 Desk cat

-   [ ] Load the user's frames from `Resources/Catgirl/`.
-   [ ] Support the agreed PNG-sequence or sprite-sheet format.
-   [ ] Render at integer scale with nearest-neighbor filtering.
-   [ ] Loop idle animation from first launch.
-   [ ] Support a talk cycle if one is supplied.
-   [ ] Position the window at the bottom-left of the primary display.
-   [ ] Account for Dock placement and display-frame changes.
-   [ ] Implement transparent-pixel hit testing.
-   [ ] Ensure the window is borderless, transparent, non-activating,
    and joins every Space.
-   [ ] Add rank-up click arming and speech bubble behavior.
-   [ ] Ensure pre-achievement clicks do nothing.
-   [ ] Ensure clipboard and honesty events never arm the cat.
-   [ ] Gate Discord Daddy Mode speech with the same setting as Discord Daddy Mode notifications.

### 1.6 Rank-up feedback

-   [ ] Add later-rank notifications.
-   [ ] Change the menu bar icon as ranks increase.
-   [ ] Play the short ear animation.
-   [ ] Arm the matching desk-cat line.
-   [ ] Verify a rank-up is announced once, not on every launch.

### Phase 1 acceptance criteria

-   [ ] A Discord session can earn E-Kitten using the specified rates.
-   [ ] Discord quitting pauses the ritual clock.
-   [ ] Discord running without a visible window uses the configured
    minimized/background behavior.
-   [ ] The panel shows rank, progress, and the procrastination toggle.
-   [ ] Toggle minutes can progress from E-Kitten toward Stray Cat and
    beyond.
-   [ ] The E-Kitten ceremony runs once and creates a certificate.
-   [ ] The certificate can be revealed in Finder.
-   [ ] The user's catgirl art appears crisp at the bottom-left from
    launch.
-   [ ] Clicking after a rank-up displays the correct line.
-   [ ] The panel explains what the ritual detects.
-   [ ] No network access, additional target, or extension was
    introduced.

**Stop condition:** The core meter, ceremony, certificate, and desk cat
work reliably. Do not add polish that is not needed for these acceptance
criteria.

------------------------------------------------------------------------

## Phase 2 --- Passive-aggressive clipboard

**Goal:** React to copy events without keeping the copied content.

### Tasks

-   [ ] Poll `NSPasteboard.general.changeCount` at approximately 250 ms.
-   [ ] Detect changes without generating duplicate events.
-   [ ] Maintain a total copy count.
-   [ ] Add base reaction lines in `Voice/`.
-   [ ] Add local classification for URLs, code-like text, email
    addresses, and long text.
-   [ ] Add duplicate detection with only short-lived in-memory
    comparison data or a suitable fingerprint.
-   [ ] Add burst detection.
-   [ ] Use a generic reaction for non-text clipboard content.
-   [ ] Post a local notification for a detected copy event.
-   [ ] Show the latest line and copy count in the panel.
-   [ ] Add the clipboard privacy disclosure.
-   [ ] Verify clipboard contents are not persisted, logged, or included
    in notifications.

### Acceptance criteria

-   [ ] A new copy produces one reaction.
-   [ ] The panel count matches detected copy events.
-   [ ] Duplicate, URL, code-like, email, long-text, and burst cases
    select the intended category.
-   [ ] Non-text clipboard changes do not crash the watcher.
-   [ ] The panel never displays the copied text.
-   [ ] No raw copied text remains after classification.
-   [ ] No clipboard content is written to disk or sent over the
    network.

**Stop condition:** The clipboard watcher reliably reacts and retains
only the permitted metadata. Do not add extra character voices yet.

------------------------------------------------------------------------

## Phase 3 --- Honesty pass

**Goal:** Let the user run a read-only, local phrase match against the
frontmost browser page.

### Tasks

-   [ ] Add an honesty-pass action to the panel and menu.
-   [ ] Explain Automation permission before the first request.
-   [ ] Implement frontmost-browser identification behind a small
    adapter.
-   [ ] Handle unsupported browsers and missing browser windows.
-   [ ] Handle denied or unavailable Automation permission.
-   [ ] Define a local JSON phrase-pack schema.
-   [ ] Add Gentle, Brutal, and Unhinged levels.
-   [ ] Set Gentle as the default.
-   [ ] Add the initial phrase pairs from `AGENTS.md`.
-   [ ] Add optional host overrides for Amazon, Apple, Google, GitHub,
    and subscription pages.
-   [ ] Implement deterministic phrase matching.
-   [ ] Display the matched honest line in the panel.
-   [ ] Add the honesty-pass privacy disclosure.
-   [ ] Verify the browser page is not changed.

### Acceptance criteria

-   [ ] The user can launch the pass from the menu or panel.
-   [ ] The permission explanation appears before the Automation prompt.
-   [ ] A supported frontmost page can be inspected locally.
-   [ ] A matching phrase produces the correct result for the selected
    level.
-   [ ] Host-specific overrides are applied only to their configured
    hosts.
-   [ ] Unknown phrases return a clear no-match result.
-   [ ] Permission denial and unsupported browsers produce useful
    messages.
-   [ ] The pass never clicks, types, submits, navigates, or modifies
    the page.
-   [ ] No browser text is persisted or uploaded.

**Stop condition:** The panel can report a local phrase match and the
page remains untouched. In-page replacement is not part of this phase.

------------------------------------------------------------------------

## Phase 4 --- Consolidation and release readiness

**Goal:** Make the three features feel like one coherent app and prepare
a dependable release.

### Tasks

-   [ ] Review the panel hierarchy and make the three features easy to
    discover.
-   [ ] Ensure settings and feature states have sensible defaults.
-   [ ] Review notification authorization and denied-permission
    behavior.
-   [ ] Review all privacy disclosures against actual implementation.
-   [ ] Verify app launch, quit, and relaunch behavior.
-   [ ] Verify timers and observers are not duplicated.
-   [ ] Verify persistence migration and invalid-state fallback.
-   [ ] Run unit tests and manual acceptance checks on macOS 13+.
-   [ ] Check Voice catalog for duplicated or hardcoded copy.
-   [ ] Check resources and certificate output paths.
-   [ ] Check accessibility labels and keyboard navigation in the panel.
-   [ ] Remove unused scaffolding and temporary debug behavior.
-   [ ] Document known limitations, especially microphone activity
    detection.
-   [ ] Create a release build and test a clean installation.

### Acceptance criteria

-   [ ] All three features work from the same menu bar app.
-   [ ] The app remains useful when optional permissions are denied.
-   [ ] The privacy disclosures are accurate.
-   [ ] No private clipboard or browser content is persisted.
-   [ ] No network activity or extra app target exists.
-   [ ] No duplicate timers, observers, or achievement notifications
    occur.
-   [ ] The app launches cleanly after a fresh install and after an
    upgrade.

------------------------------------------------------------------------

## Later --- Explicitly deferred ideas

These are not release blockers and should not be started until the core
phases are complete.

-   [ ] A certificate for every rank, signed by the rank above.
-   [ ] Custom rank thresholds.
-   [ ] A configurable list of applications that count toward the meter.
-   [ ] Opt-in in-page replacement of cookie-banner text, still launched
    from this app and never auto-clicking Accept.
-   [ ] Extra clipboard voices: Godfather, GLaDOS, disappointed teacher,
    and the rare slurp.
-   [ ] Importing a local JSON phrase pack from disk.

Nekotania, the catgirl Discord bot, is the reference for the ritual's
tone.

## Out of scope

-   A second app, a multi-app monorepo, or a standalone browser
    extension.
-   Accounts, a backend, analytics, telemetry, sync, or uploads.
-   Reading Discord messages, servers, or conversations.
-   Recording or analyzing microphone audio.
-   Demoting ranks, streaks, shame dialogs, or a phone companion.
-   Clicking through cookie banners or signup walls.
-   Automatically accepting terms or submitting forms.

------------------------------------------------------------------------

## Decision log

Keep unresolved behavior here so implementation does not accidentally
turn guesses into product requirements.

  ----------------------------------------------------------------------------------
  ID                Decision needed        Current position        Status
  ----------------- ---------------------- ----------------------- -----------------
  D-01              Minimized/background   "Slower" is specified,  Open
                    Discord multiplier     but no exact rate is    
                                           given.                  

  D-02              Discord call detection Current audio-device    Open
                    accuracy               signal may be caused by 
                                           another app.            

  D-03              Time during macOS      Do not award unobserved Open
                    sleep                  time until behavior is  
                                           decided and tested.     

  D-04              Discord running with   Currently grouped as    Open
                    no visible window      minimized/background.   
                                           Confirm whether other   
                                           states need             
                                           distinction.            

  D-05              Notification           Local notifications are Open
                    preference controls    part of the feature;    
                                           additional per-feature  
                                           controls are not yet    
                                           specified.              

  D-06              Supported browsers for Browser scripting       Open
                    honesty pass           approach and supported  
                                           browser list need to be 
                                           confirmed during        
                                           implementation.         

  D-07              Sprite asset format    PNG sequence or sprite  Open
                                           sheet are both          
                                           acceptable; choose the  
                                           actual supplied format  
                                           when assets are added.  
  ----------------------------------------------------------------------------------

## Change management

When a product decision changes:

1.  Update `AGENTS.md` first, because it defines expected behavior.
2.  Update this roadmap if the change affects scope, order, or
    acceptance criteria.
3.  Add or close a decision-log entry.
4.  Update tests to match the new behavior.
5.  Do not leave contradictory copies of the same rule in both files.

When a phase is complete, check its acceptance criteria, note any known
limitations, and move on. The goal is a finished, coherent joke---not an
endless feature list.
