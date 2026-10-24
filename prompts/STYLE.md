# PERSISTINT — world and style bible

The style bible is private development material (it describes the novel's world) and lives
git-crypt encrypted at `dev/STYLE.md`. Every leaf prompt file under `prompts/` is pre-compiled
from it and is self-contained: paste its `## Prompt` section into the generator as is.
`python3 tools/check_prompts.py` checks the leaf files mechanically.
