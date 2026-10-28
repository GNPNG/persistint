---
id: temple_candles
tool: Gemini image
drop: prompts/image/levels/temple/assets/temple_candles.png
game: project/assets/sheets/temple/temple_candles.png
---

# temple_candles

Temple prop: a candle stand (source still for the flickering candle sprite).

## Prompt

Kawaii pixel-art game art in a clean sticker-illustration style: even warm-brown outlines (never black), flat pastel fills with one soft highlight, round pink cheek blush, dot eyes and small smiles, cute faces (two dot eyes, pink blush, a small smile) on buildings, trees, props, the ship and the bunker, big round readable shapes for a 640×360 game, overhead three-quarter view for places, hearts and four-point sparkles as motifs, soft antialiased edges with no harsh pixel stair-steps. Cute on the surface with something faintly wrong underneath. 1:1 square. No photorealism, no 3D, no text. World for colour and style only (the image shows just the single prop described next, not this scene): Symmetrical pastel temple interior: cream and blush checkerboard floor, pink runner to a dais, a row of identical portrait icons of a smiling blonde woman with a crown on the high wall, a red round seal with a bold O above the dais, white columns topped with smiling orbs, a cute flower-crowned skull on a pedestal; gauzy white-pink light. A candle stand: a slim cream candle on a round pale-gold dish stand with a small smiling face on the dish, a soft butter-yellow teardrop flame with a white core, a tiny drip of wax; straight-on front with a slight top-down tilt, standing upright, centred, filling about two thirds of the image height. One prop only. Background: one perfectly flat, solid, pure chroma-key green (hex 00FF00: red 0, green 255, blue 0) filling the whole image edge to edge, with no shadows, no gradient, no texture, no vignette, no floor or ground line, no glow and no green tint spilling onto anything. Nothing in any item is green, lime or mint; wherever a leaf or plant would be green, use soft lavender, pink or butter yellow instead. Every item keeps its complete warm-brown outline all the way round, so it separates cleanly from the green. Generous empty space: the plain green shows between all items, with a gap of at least half an item's width between neighbours and from every edge of the image; no item touches, overlaps or is cut off by another item or the edge. Negative prompt: no text, no letters, no watermark, no logo, no photorealism, no 3D render, no black outlines, no harsh pixel stair-stepping, no dithering, no grime, no realistic blood, no wounds, no weapons, no fighting, no scary faces, no nudity, no anatomy, no real-person likeness, no dark horror lighting, no muddy colours, no scenery or backdrop, no cast shadows, no drop shadows, no gradient, textured or patterned background, no green, lime or mint in any item, no item touching another item or the image edge, no cropped items.

## Notes

The live file project/assets/temple/temple_candles.png is a 4-frame flicker strip (frames 96×176, 24×44 world px at 4×, foot at x 48, y 168; SpriteFrames temple_candles.tres), so this still lands in a staging path and the four frames are made from it (flame scaled and nudged per frame) before it replaces the strip. Godot imports everything under project/, so project/assets/sheets/ needs a .gdignore or an export exclude.
