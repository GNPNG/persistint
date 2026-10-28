---
id: temple_twinkle
tool: Gemini image
drop: prompts/image/levels/temple/assets/temple_twinkle.png
game: project/assets/sheets/temple/temple_twinkle.png
---

# temple_twinkle

Temple effect: the drifting sparkle (source still for the twinkle sprite).

## Prompt

Kawaii pixel-art game art in a clean sticker-illustration style: even warm-brown outlines (never black), flat pastel fills with one soft highlight, round pink cheek blush, dot eyes and small smiles, cute faces (two dot eyes, pink blush, a small smile) on buildings, trees, props, the ship and the bunker, big round readable shapes for a 640×360 game, overhead three-quarter view for places, hearts and four-point sparkles as motifs, soft antialiased edges with no harsh pixel stair-steps. Cute on the surface with something faintly wrong underneath. 1:1 square. No photorealism, no 3D, no text. World for colour and style only (the image shows just the single sparkle described next, not this scene): Symmetrical pastel temple interior: cream and blush checkerboard floor, pink runner to a dais, a row of identical portrait icons of a smiling blonde woman with a crown on the high wall, a red round seal with a bold O above the dais, white columns topped with smiling orbs, a cute flower-crowned skull on a pedestal; gauzy white-pink light. A single four-point sparkle: a plump white four-point star with a pale butter-yellow glow edge and a thin gold rim, perfectly symmetrical, centred, filling about half of the image. One sparkle only. Background: one perfectly flat, solid, pure chroma-key green (hex 00FF00: red 0, green 255, blue 0) filling the whole image edge to edge, with no shadows, no gradient, no texture, no vignette, no floor or ground line, no glow and no green tint spilling onto anything. Nothing in any item is green, lime or mint; wherever a leaf or plant would be green, use soft lavender, pink or butter yellow instead. Every item keeps its complete warm-brown outline all the way round, so it separates cleanly from the green. Generous empty space: the plain green shows between all items, with a gap of at least half an item's width between neighbours and from every edge of the image; no item touches, overlaps or is cut off by another item or the edge. Negative prompt: no text, no letters, no watermark, no logo, no photorealism, no 3D render, no black outlines, no harsh pixel stair-stepping, no dithering, no grime, no realistic blood, no wounds, no weapons, no fighting, no scary faces, no nudity, no anatomy, no real-person likeness, no dark horror lighting, no muddy colours, no scenery or backdrop, no cast shadows, no drop shadows, no gradient, textured or patterned background, no green, lime or mint in any item, no item touching another item or the image edge, no cropped items.

## Notes

The live file project/assets/temple/temple_twinkle.png is a 6-frame strip (frames 48×48, 12×12 world px at 4×, centred; SpriteFrames temple_twinkle.tres): swell and fade frames are made from this still before it replaces the strip. Staging path because a raw still would break the strip. Godot imports everything under project/, so project/assets/sheets/ needs a .gdignore or an export exclude.
