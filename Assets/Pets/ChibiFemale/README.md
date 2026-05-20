# Chibi Female Character Pack

Generated with the built-in image generation flow on 2026-05-20.

Design:
- Original female chibi desktop companion
- Signature charm points: oversized red ribbon hairpin, star-shaped crossbody pouch, coral dress, cream cardigan
- Cute collectible-figure proportions, non-sexualized, readable at small desktop size

Files:
- `chibi-female-pose-sheet-chroma.png`: original chroma-key source copied from Codex generated images.
- `poses/*.png`: isolated alpha PNG poses extracted from the source sheet.

Runtime copy:
- `Sources/AIPet/Resources/Pets/ChibiFemale/poses/*.png`
- `Sources/AIPet/Resources/Pets/ChibiFemale/manifest.json`

Why poses are split:
- Rendering from the full sheet caused edge clipping and neighboring pose fragments to appear.
- The app now loads independent pose PNGs, so a pose cannot accidentally include another pose from the sheet.

This pack is loaded through `manifest.json`; adding another character should not require changing renderer code.

Extraction:

```bash
/Users/tykim/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Scripts/extract_pose_sprites.py \
  --input Assets/Pets/ChibiFemale/chibi-female-pose-sheet-chroma.png \
  --out-dir Assets/Pets/ChibiFemale/poses \
  --output-size 512 \
  --tolerance 76 \
  --padding 12
```
