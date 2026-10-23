// Video: Gemini app "Create video" by default (one fresh chat per clip: the chat is locked while
// it renders). Switch selectors.json kinds.video to "flow_video" to use Flow instead.
import { makeDriver } from './common.mjs';

export default makeDriver('video');
