# Luma

macOS character companion prototype built with Swift and AppKit.

## Product Direction

Luma is a character-first desktop AI companion. The character keeps its own tone, but still helps with real tasks such as search, recommendations, and contextual conversation.

## Run

```bash
swift run Luma
```

## Build App Bundle

```bash
bash Scripts/build_app_bundle.sh
```

The unsigned app bundle is written to `.build/Luma.app`.

The app starts as a menu bar accessory with an original desktop character companion. On first launch, Luma shows a short Korean onboarding window. Use the menu bar sparkles icon to open chat, settings, character management, or surface debugging.

## Current MVP

- Transparent floating pet window
- Four bundled production-style character packs with independent pose PNGs and persona manifests
- Stable facing direction, hover dwell reactions, squash/stretch, jump/fall rotation, walking bounce, dynamic shadow, speech bubbles, and manifest-based character packs
- Idle/walk/jump/fall/sit/sleep/groom/play/happy/alert states
- Screen bottom, Dock top approximation, visible window top surfaces, and window edge interactions
- Click the character to open chat; right-click for quick character actions
- Character selection and character pack import from the menu bar
- API endpoint/model/persona settings
- Optional search endpoint/API key settings
- OpenAI-compatible `/v1/chat/completions` adapter
- Chat sessions stored locally with recent-message context
- Long sessions are compacted into local summary memory
- AI requests can be cancelled and failed prompts can be retried
- Markdown rendering for assistant replies
- AI replies are mirrored into the pet speech bubble
- Surface debug overlay for tuning window/Dock/edge interactions
- First-launch onboarding explains permissions, chat, search, character packs, and local data paths

## Character Assets

The characters are manifest-based character packs. Authoring rules are documented in `CHARACTER_PACK_STANDARD.md`.

The character art is stored as isolated pose PNGs in `Assets/Pets/<Character>/poses` and copied into the SwiftPM resource bundle at `Sources/AIPet/Resources/Pets/<Character>/poses`.

Each bundled character has 12 poses: idle, walk 1, walk 2, jump, fall, sit, sleep, wave, happy, alert, play, and peek.

Original source sheets are kept under `Assets/Pets`. Runtime rendering uses the extracted pose files rather than cropping from the source sheet, which avoids clipping and neighboring-pose artifacts.

Character packs are selected through the `Characters` menu. User-installed packs are copied into `~/Library/Application Support/Luma/Characters`.

On first launch, the default character is `루나 세라`, an original fantasy-idol mage companion with silver-lavender twin tails, a crescent ornament, and star-magic accents. The bundled roster also includes `모리 코하쿠`, a forest courier with a short bob, green hood, fox-ear silhouette, oversized gloves, satchel, and leaf-and-bell accents. Additional characters can be installed from the `Characters` menu by selecting a folder that contains a valid `manifest.json`.

Movement polish:
- Facing direction changes only after a clear velocity threshold and cooldown, preventing rapid left/right flipping.
- Walking uses one stable directional pose with procedural bounce instead of alternating mismatched generated poses.
- Hover reactions require a short dwell and cooldown, preventing alert-pose flicker and ghosting.

## Notes

- Window surface detection uses `CGWindowListCopyWindowInfo`.
- Only screen bottom, Dock top, and window top surfaces are walkable. Window bottom/left/right edges are reserved for cling, peek, and wall-style reactions.
- Luma does not request Accessibility permission for the default desktop behavior.
- API keys are stored in Keychain.
- Chat sessions are stored in `~/Library/Application Support/Luma/ChatSessions`.
- Optional search integration expects a JSON endpoint that accepts a `q` query parameter.
- When running from Terminal, macOS may print `IMKCFRunLoopWakeUpReliable` input-method logs on first typing in text fields. This is a system input-method stderr message, not a Luma runtime failure.
- Some macOS modes such as full screen Spaces and Stage Manager may require additional tuning.

## Search Endpoint Shape

The optional search endpoint is intentionally provider-neutral. Luma sends a GET request and appends `q=<user query>` if the URL does not already include a query parameter named `q` or `query`.

Supported JSON result shapes include arrays or dictionaries containing `results`, `organic`, `items`, `webPages.value`, `documents`, or nested provider shapes such as `web.results`. Each item should contain title/name, url/link, and snippet/content/description when possible.

Examples:
- SearXNG: `https://search.example.com/search?format=json`, no API key required for many private instances.
- Brave Search API: `https://api.search.brave.com/res/v1/web/search`, search header Key `X-Subscription-Token`, Value set to the Brave token.
- Custom proxy: expose a GET endpoint that returns `{ "results": [{ "title": "...", "url": "...", "snippet": "..." }] }`.

## Quality Bar

This project should not settle for a novelty overlay. The target is closer to Murchi and Desktop Mate:

- The pet needs readable emotion, idle life, and user reactions even when AI is unused.
- Movement must feel grounded on real desktop geometry, not random floating.
- AI should feel embodied through the pet's persona, speech, and behavior.
- Future asset work should move from procedural drawing to production-grade sprite or 3D character packs.
