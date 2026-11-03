"""Regression checks for bd i3f2; run python3 -I tools/test_temple_strips.py."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_temple_strips as build
import gen_temple_props as standin


class TempleStrips(unittest.TestCase):
    def test_landed_build_is_repeatable_and_sources_untouched(self):
        sources = {p: hashlib.sha256(p.read_bytes()).digest() for p in build.SOURCE.glob('temple_*.png')}
        with tempfile.TemporaryDirectory() as directory, patch.object(build, 'OUT', Path(directory)):
            build.main()
            for name in ('temple_twinkle.png', 'temple_candles.png'):
                actual = Path(directory, name)
                shipped = build.ROOT / 'project/assets/temple' / name
                self.assertEqual(actual.read_bytes(), shipped.read_bytes())
                self.assertTrue(build.keep_strip(actual))
        self.assertEqual(sources, {p: hashlib.sha256(p.read_bytes()).digest() for p in sources})

    def test_twinkle_swells_fades_and_clears(self):
        im = Image.open(build.OUT / 'temple_twinkle.png')
        self.assertEqual(im.size, (288, 48))
        masses = []
        for i in range(6):
            frame = im.crop((48*i, 0, 48*(i+1), 48))
            bounds = frame.getbbox()
            if i == 5:
                self.assertIsNone(bounds)
                continue
            x0, y0, x1, y1 = bounds
            self.assertTrue(0 < x0 < x1 < 48 and 0 < y0 < y1 < 48)
            self.assertLessEqual(abs((x0+x1)/2-24), 1)
            self.assertLessEqual(abs((y0+y1)/2-24), 1)
            masses.append(sum(frame.getchannel('A').tobytes()))
        self.assertTrue(masses[0] < masses[1] < masses[2] > masses[3] > masses[4])

    def test_candle_body_static_and_flame_moves(self):
        im = Image.open(build.OUT / 'temple_candles.png')
        self.assertEqual(im.size, (384, 176))
        frames = [im.crop((96*i, 0, 96*(i+1), 176)) for i in range(4)]
        for frame in frames:
            self.assertEqual(frame.crop((0, 48, 96, 176)).tobytes(), frames[0].crop((0, 48, 96, 176)).tobytes())
            self.assertEqual(frame.getbbox()[0::2], (8, 88))
            self.assertGreater(frame.getchannel('A').getpixel((48, 167)), 0)
            self.assertIsNone(frame.crop((0, 172, 96, 176)).getbbox())
        self.assertEqual(len({f.crop((0, 0, 96, 48)).tobytes() for f in frames}), 4)

    def test_standin_cannot_overwrite_derived_strips(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(standin, 'OUT', Path(directory)):
            for name in ('temple_twinkle.png', 'temple_candles.png'):
                path = Path(directory, name)
                original = (build.OUT / name).read_bytes()
                path.write_bytes(original)
                standin.put(Image.new('RGBA', (1, 1)), name)
                self.assertEqual(path.read_bytes(), original)
                path.unlink()
                with patch.object(standin, 'keep', return_value=False):
                    standin.put(Image.new('RGBA', (1, 1)), name)
                self.assertFalse(build.keep_strip(path))
                with Image.open(path) as placeholder:
                    self.assertEqual(placeholder.size, (1, 1))


if __name__ == '__main__':
    unittest.main()
