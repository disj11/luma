# Luma

macOS character companion prototype built with Swift and AppKit.

## Run

```bash
swift run Luma
```

The app starts as a menu bar accessory with an original desktop character companion. Use the menu bar sparkles icon to open chat, settings, or call the character to the cursor.

## Current MVP

- Transparent floating pet window
- Production-style original character pack with independent pose PNGs and procedural vector fallback
- Stable facing direction, hover dwell reactions, squash/stretch, jump/fall rotation, walking bounce, dynamic shadow, speech bubbles, and manifest-based character packs
- Idle/walk/jump/fall/sit/sleep/groom/play/happy/alert states
- Screen bottom, Dock top approximation, visible window top surfaces, and window edge interactions
- Click the character to open chat; right-click for quick character actions
- Character selection and character pack import from the menu bar
- API endpoint/model/persona settings
- OpenAI-compatible `/v1/chat/completions` adapter
- AI replies are mirrored into the pet speech bubble

## Character Assets

The main character is a manifest-based character pack. Authoring rules are documented in `CHARACTER_PACK_STANDARD.md`.

The current character art is stored as isolated pose PNGs in `Assets/Pets/LunaSera/poses` and copied into the SwiftPM resource bundle at `Sources/AIPet/Resources/Pets/LunaSera/poses`.

The current character has 12 poses: idle, walk 1, walk 2, jump, fall, sit, sleep, wave, happy, alert, play, and peek.

The original source sheet is kept at `Assets/Pets/LunaSera/luna-sera-pose-sheet-chroma.png`. Runtime rendering uses the extracted pose files rather than cropping from the source sheet, which avoids clipping and neighboring-pose artifacts.

Character packs are selected through the `Characters` menu. User-installed packs are copied into the app's Application Support character folder.

On first launch, the built-in character is `루나 세라`, an original fantasy-idol mage companion with silver-lavender twin tails, a crescent ornament, and star-magic accents. Additional characters can be installed from the `Characters` menu by selecting a folder that contains a valid `manifest.json`.

Movement polish:
- Facing direction changes only after a clear velocity threshold and cooldown, preventing rapid left/right flipping.
- Walking uses one stable directional pose with procedural bounce instead of alternating mismatched generated poses.
- Hover reactions require a short dwell and cooldown, preventing alert-pose flicker and ghosting.

## Notes

- Window surface detection uses `CGWindowListCopyWindowInfo`.
- Only screen bottom, Dock top, and window top surfaces are walkable. Window bottom/left/right edges are reserved for cling, peek, and wall-style reactions.
- API keys are stored in Keychain.
- Some macOS modes such as full screen Spaces and Stage Manager may require additional tuning.

## Quality Bar

This project should not settle for a novelty overlay. The target is closer to Murchi and Desktop Mate:

- The pet needs readable emotion, idle life, and user reactions even when AI is unused.
- Movement must feel grounded on real desktop geometry, not random floating.
- AI should feel embodied through the pet's persona, speech, and behavior.
- Future asset work should move from procedural drawing to production-grade sprite or 3D character packs.
