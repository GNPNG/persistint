# PERSISTINT — the game

Promotional/fundraising sandbox game for the novel **Persistint** (Per-sist-INT).
A cute island. A lovely community. Everyone contributes. *Everyone.*

Not-for-profit project: helping girls and women recognize, name, and feel comfortable
criticizing social-control behavior. The cuteness is the weapon.

- Engine: Godot 4.6 (GL Compatibility → HTML5-exportable)
- Design: [docs/DESIGN.md](docs/DESIGN.md)
- Dialogue: [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) (`project/dialogue/*.dialogue`)
- Placeholder art: `tools/gen_placeholder_art.sh` (ImageMagick) until the
  NotebookLM/Stable-Diffusion canon pipeline replaces it

## Run

```bash
godot --path project            # editor/run
tools/gen_placeholder_art.sh    # regenerate placeholder assets
```

Controls: click to walk · click people/things to interact · **P** wardrobe
