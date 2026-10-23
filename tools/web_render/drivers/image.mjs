// Images: Gemini app "Create images" (Nano Banana). The app has no aspect control, so the ratio
// goes in the prompt (every image prompt in prompts/ already states it). Capture prefers the
// "Download full size" button (2K on a paid plan) over the on-page preview.
import { makeDriver } from './common.mjs';

export default makeDriver('image');
