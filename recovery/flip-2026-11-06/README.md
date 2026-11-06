# FLIP working-file recovery, 2026-11-06

This branch preserves files left outside commits in the older Windows checkout. Its base is private-forge main at `13a0c79bc3e1788e829dc58494cf52521fe439fe`. The files are review material; the patches have not been applied to the current game.

| File | Origin |
|---|---|
| `studio-intro.patch` | Three modified intro scene, script, and test files in worktree `agent-a4bc81b719d072b57`, based on `12c740b` |
| `project-settings.patch` | Modified `project/project.godot` in the older main checkout, based on `47acfe7` |
| `key_art_island_present.png` | Untracked alternate artwork from the older checkout |
| `key_art_island_present_src.jpg` | Untracked source JPEG accompanying that artwork |

The alternate artwork differs from the version in current main. Both image files use the repository's LFS rules. The original files and worktrees remain in place.

Recovery checks cover byte-for-byte image copies, patch correspondence to the modified working files, and LFS pointers in the commit. They do not establish that the older intro behavior or project settings should replace current main. No gameplay change is made by this recovery branch.
