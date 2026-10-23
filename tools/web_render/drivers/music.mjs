// Music: Gemini app "Create music" (Lyria). The download menu must pick audio only (MP3),
// not the MP4 with cover art; a wrong format is converted with ffmpeg when it is installed.
import { makeDriver } from './common.mjs';

export default makeDriver('music');
