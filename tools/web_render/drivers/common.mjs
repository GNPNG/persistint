// Shared driver logic. Each kind's driver only decides how the prompt text is adjusted for its
// surface; the page work is done by lib/engine.mjs from the surface's selectors.json entry.
import { RATIO_RE } from '../lib/tasks.mjs';
import { fill } from '../lib/config.mjs';
import { renderOnSurface } from '../lib/engine.mjs';

/**
 * Final prompt text. If the surface cannot set the aspect ratio in its UI (aspectInPrompt) and
 * the prompt does not already state a ratio, append the surface's promptSuffix ("{aspect} ...").
 * A surface may also always append extraSuffix (e.g. a length hint for music).
 */
export function preparePrompt(task, surface) {
  let p = task.prompt;
  if (surface.aspectInPrompt && surface.promptSuffix && !RATIO_RE.test(p)) {
    p = `${p} ${fill(surface.promptSuffix, { aspect: task.aspect, id: task.id })}`;
  }
  if (surface.promptPrefix) p = `${fill(surface.promptPrefix, { aspect: task.aspect, id: task.id })} ${p}`;
  if (surface.extraSuffix) p = `${p} ${fill(surface.extraSuffix, { aspect: task.aspect, id: task.id })}`;
  return p.trim();
}

export function makeDriver(kind) {
  return {
    kind,
    preparePrompt,
    render(session, surface, task, opts = {}) {
      if (task.kind !== kind) throw new Error(`${task.id} is ${task.kind}, not ${kind}`);
      return renderOnSurface(session, surface, task, preparePrompt(task, surface), opts);
    },
  };
}
