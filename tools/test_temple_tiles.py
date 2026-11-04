"""uc9w atlas integration regressions: python3 -I tools/test_temple_tiles.py."""
import sys
from pathlib import Path
import unittest
from unittest.mock import patch
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_island_tiles as g

class TempleTiles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = g.temple_sources()
        with patch.object(g, 'temple_sources', return_value=None):
            cls.original = g.cells()
        cls.changed = g.landed_temple(cls.original)

    def test_only_expected_cells_change(self):
        allowed = {'floor','floor_b','floor_alt','floor_n','floor_nb','wall','wall_cap','wall_base'}
        for name in ('rug','rug_top','rug_bot','dais'):
            allowed.update(g.piece_cells(name))
        self.assertEqual(set(self.changed), allowed)
        for name, im in self.changed.items():
            self.assertEqual(im.size, (128,128))
            self.assertEqual(im.getchannel('A').getextrema(), (255,255))
        assembled = dict(self.original, **self.changed)
        self.assertEqual(set(assembled), set(self.original))
        for name in set(assembled)-allowed:
            self.assertEqual(assembled[name].tobytes(), self.original[name].tobytes())

    def test_missing_sheet_preserves_procedural_fallback(self):
        with patch.object(g, 'TEMPLE_SHEET', Path('/nonexistent/temple_tiles.png')):
            self.assertIsNone(g.temple_sources())
            self.assertEqual(g.landed_temple(self.original), {})

    def test_crops_are_opaque_and_runner_is_continuous(self):
        self.assertEqual(len(self.sources),8)
        for im in self.sources:
            self.assertEqual(im.getchannel('A').getextrema(),(255,255))
        combined = Image.new('RGBA',(256,256))
        for y in range(2):
            for x in range(2):
                combined.paste(self.changed[f'rug_{x}_{y}'],(x*128,y*128))
        self.assertEqual(combined.tobytes(),self.sources[2].resize((256,256),Image.Resampling.LANCZOS).tobytes())

    def test_blush_lightened_without_recoloring_gold(self):
        import numpy as np
        original = np.array(self.sources[1])
        pale = np.array(self.changed['floor_b'])
        gold = original[:,:,1] >= original[:,:,2]
        self.assertTrue(np.array_equal(pale[gold], original[gold]))
        centre = np.median(pale[48:80,48:80,:3], axis=(0,1))
        self.assertTrue(np.all(np.abs(centre - [255,239,245]) <= 5), centre)
        self.assertTrue(np.array_equal(original[:,:,3], pale[:,:,3]))

    def test_original_dais_emblem_is_present(self):
        for x, y in ((256,108), (202,112), (310,112)):
            name = f'dais_{x//128}_{y//128}'
            actual = self.changed[name].getpixel((x%128,y%128))
            previous = self.original[name].getpixel((x%128,y%128))
            # Antialiasing now blends over the landed panel, not flat old pink.
            self.assertLessEqual(max(abs(a-b) for a,b in zip(actual,previous)), 3)

    def test_dais_steps_stay_unchanged(self):
        for x in range(4):
            name=f'dais_{x}_2'
            self.assertEqual(self.changed[name].tobytes(),self.original[name].tobytes())

if __name__=='__main__':
    unittest.main()
