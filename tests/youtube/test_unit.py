#!/usr/bin/env python3
"""Network-independent unit tests for the youtube skill's core logic.

Covers the parts that give the skill its intelligence but that the live
test.sh smoke test can't reach deterministically: age/duration/views parsing,
deep-mode filtering (passes_filters) and ranking (score_video), and the
list-artifact parsing helpers.

Run:  python3 tests/youtube/test_unit.py
      (or via test.sh section [13])
"""

import os
import sys
import unittest

# Make scripts/search.py importable regardless of cwd.
_HERE = os.path.dirname(os.path.abspath(__file__))
_SEARCH = os.path.join(_HERE, "..", "..", "skills", "youtube", "scripts", "search.py")
sys.path.insert(0, os.path.dirname(_SEARCH))

import search  # noqa: E402

NOW = 1_800_000_000.0  # fixed "now" so recency math is deterministic
DAY = 86_400.0


class TestFormatting(unittest.TestCase):
    def test_duration(self):
        self.assertEqual(search.format_duration(59), "0:59")
        self.assertEqual(search.format_duration(1200), "20:00")
        self.assertEqual(search.format_duration(3661), "1:01:01")
        self.assertEqual(search.format_duration("bad"), "?")

    def test_views(self):
        self.assertEqual(search.format_views(500), "500 views")
        self.assertEqual(search.format_views(42_000), "42K views")
        self.assertEqual(search.format_views(2_300_000), "2.3M views")
        self.assertEqual(search.format_views("x"), "N/A")

    def test_age(self):
        self.assertEqual(search.format_age(NOW - 3600, NOW), "today")
        self.assertEqual(search.format_age(NOW - 5 * DAY, NOW), "5d ago")
        self.assertEqual(search.format_age(NOW - 90 * DAY, NOW), "3mo ago")
        self.assertEqual(search.format_age(NOW - 700 * DAY, NOW), "1.9yr ago")
        self.assertEqual(search.format_age("bad", NOW), "unknown age")


class TestParseAgeSpec(unittest.TestCase):
    def test_units(self):
        self.assertEqual(search.parse_age_spec("3m"), 3 * 2_592_000)
        self.assertEqual(search.parse_age_spec("1y"), 31_536_000)
        self.assertEqual(search.parse_age_spec("2w"), 2 * 604_800)
        self.assertEqual(search.parse_age_spec("14d"), 14 * DAY)

    def test_no_limit(self):
        for s in ("all", "any", "0", "off", ""):
            self.assertIsNone(search.parse_age_spec(s))

    def test_bad(self):
        with self.assertRaises(ValueError):
            search.parse_age_spec("nope")


class TestSlugify(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(search.slugify("System Design Interviews"), "system-design-interviews")
        self.assertEqual(search.slugify("  Rust  Async  "), "rust-async")
        self.assertEqual(search.slugify(""), "search")
        self.assertEqual(search.slugify("Über café"), "ber-caf")  # non-ascii stripped


class TestPassesFilters(unittest.TestCase):
    def _video(self, **kw):
        base = {
            "viewCount": 5000,
            "lengthSeconds": 1800,
            "published": NOW - 30 * DAY,
            "authorId": "UCabc",
            "author": "Some Channel",
        }
        base.update(kw)
        return base

    def test_passes_all(self):
        v = self._video()
        self.assertTrue(search.passes_filters(v, NOW, 1000, 18 * 30 * DAY, 1200, None, {}, []))

    def test_too_few_views(self):
        v = self._video(viewCount=100)
        self.assertFalse(search.passes_filters(v, NOW, 1000, None, 0, None, {}, []))

    def test_too_short(self):
        v = self._video(lengthSeconds=300)
        self.assertFalse(search.passes_filters(v, NOW, 1000, None, 1200, None, {}, []))

    def test_too_long(self):
        v = self._video(lengthSeconds=4000)
        self.assertFalse(search.passes_filters(v, NOW, 1000, None, 0, 3600, {}, []))

    def test_too_old(self):
        v = self._video(published=NOW - 700 * DAY)
        self.assertFalse(search.passes_filters(v, NOW, 1000, 365 * DAY, 0, None, {}, []))

    def test_unknown_published_age_not_filtered(self):
        # Invidious sometimes omits `published`; age filter must not drop it.
        v = self._video(published=None)
        self.assertTrue(search.passes_filters(v, NOW, 1000, 30 * DAY, 0, None, {}, []))

    def test_blocked_by_ucid(self):
        v = self._video(authorId="UCblocked")
        self.assertFalse(search.passes_filters(v, NOW, 1000, None, 0, None, {"UCblocked": "X"}, []))

    def test_exclude_channel_by_ucid(self):
        v = self._video(authorId="UCxyz")
        self.assertFalse(search.passes_filters(v, NOW, 1000, None, 0, None, {}, ["UCxyz"]))

    def test_exclude_channel_by_name_substring(self):
        v = self._video(author="Tutorial Purge Daily")
        self.assertFalse(search.passes_filters(v, NOW, 1000, None, 0, None, {}, ["tutorial purge"]))


class TestScoreVideo(unittest.TestCase):
    WEIGHTS = search.PRESETS["deep"]  # (0.35, 0.25, 0.15, 0.25)

    def _video(self, **kw):
        base = {
            "viewCount": 100_000,
            "lengthSeconds": 3600,
            "published": NOW - 30 * DAY,
            "authorId": "UCabc",
            "author": "C",
        }
        base.update(kw)
        return base

    def test_recent_scores_higher_than_old(self):
        recent = search.score_video(self._video(published=NOW - 5 * DAY), 0, 10, NOW, self.WEIGHTS, {})
        old = search.score_video(self._video(published=NOW - 700 * DAY), 0, 10, NOW, self.WEIGHTS, {})
        self.assertGreater(recent, old)

    def test_fav_boost(self):
        base = search.score_video(self._video(), 0, 10, NOW, self.WEIGHTS, {})
        boosted = search.score_video(self._video(), 0, 10, NOW, self.WEIGHTS, {"UCabc": "C"})
        self.assertAlmostEqual(boosted, base * search.FAV_BOOST)

    def test_higher_rank_scores_lower(self):
        top = search.score_video(self._video(), 0, 10, NOW, self.WEIGHTS, {})
        bottom = search.score_video(self._video(), 9, 10, NOW, self.WEIGHTS, {})
        self.assertGreater(top, bottom)

    def test_score_in_unit_range(self):
        s = search.score_video(self._video(), 0, 10, NOW, self.WEIGHTS, {})
        self.assertGreaterEqual(s, 0.0)
        self.assertLessEqual(s, 1.0)

    def test_no_published_recency_is_zero(self):
        v = self._video(published=None)
        # Recency contributes 0; the rest still sums to a positive score.
        self.assertGreater(search.score_video(v, 0, 10, NOW, self.WEIGHTS, {}), 0.0)


class TestListParsing(unittest.TestCase):
    def test_video_id_from_url(self):
        self.assertEqual(search.video_id_from_url("https://www.youtube.com/watch?v=abc123XYZ"), "abc123XYZ")
        self.assertEqual(search.video_id_from_url("https://youtu.be/abc123XYZ"), "abc123XYZ")
        self.assertEqual(search.video_id_from_url("abc123XYZ"), "abc123XYZ")

    def test_entry_line_roundtrip(self):
        v = {
            "title": "Deep Dive",
            "videoId": "abc123XYZ",
            "author": "C",
            "authorId": "UCabc",
            "lengthSeconds": 3600,
            "viewCount": 50_000,
            "published": NOW - 10 * DAY,
        }
        line = search.entry_line(v, NOW, score=0.81)
        self.assertIn("youtube.com/watch?v=abc123XYZ", line)
        self.assertIn("ucid:UCabc", line)
        self.assertIn("★0.81", line)

    def test_parse_list_entries_extracts_id_and_ucid(self):
        text = (
            "# t\n"
            "- [**A**](https://www.youtube.com/watch?v=abc123XYZ) — C · 20:00 · 50K views · 10d ago ★0.81 ucid:UCabc\n"
            "- [**B**](https://youtu.be/def456UVW) — D · 5:00\n"
            "## Header (no url)\n"
        )
        entries = list(search.parse_list_entries(text))
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[0][2], "abc123XYZ")
        self.assertEqual(entries[0][3], "UCabc")
        self.assertEqual(entries[1][2], "def456UVW")
        self.assertEqual(entries[1][3], "")


class TestInstanceSelfHeal(unittest.TestCase):
    """Cache merge / promote / evict — network-free via a temp cache file."""

    def setUp(self):
        import tempfile
        self._orig_cache = search.CACHE_FILE
        self._tmp = tempfile.NamedTemporaryFile(suffix=".json", delete=False)
        self._tmp.close()
        search.CACHE_FILE = self._tmp.name

    def tearDown(self):
        search.CACHE_FILE = self._orig_cache
        os.unlink(self._tmp.name)

    def test_cache_roundtrip_and_ttl(self):
        search.save_cached_instances(["a.example", "b.example"])
        self.assertEqual(search.load_cached_instances(), ["a.example", "b.example"])
        # Simulate a stale cache (past TTL).
        import json as _json
        with open(search.CACHE_FILE) as f:
            c = _json.load(f)
        c["ts"] = 0
        with open(search.CACHE_FILE, "w") as f:
            _json.dump(c, f)
        self.assertEqual(search.load_cached_instances(), [])

    def test_get_instances_merges_cache_with_known(self):
        # A stale-or-dead cache must never shadow the known pool.
        search.save_cached_instances(["dead.example"])
        merged = search.get_instances()
        self.assertEqual(merged[0], "dead.example")  # cache first
        for h in search.KNOWN_INSTANCES:
            self.assertIn(h, merged)

    def test_promote_moves_to_front(self):
        search.save_cached_instances(["a.example", "b.example"])
        search.promote_instance("b.example")
        self.assertEqual(search.load_cached_instances(), ["b.example", "a.example"])
        # Promoting an uncached host prepends it.
        search.promote_instance("c.example")
        self.assertEqual(search.load_cached_instances()[0], "c.example")

    def test_evict_drops_dead_hosts(self):
        search.save_cached_instances(["a.example", "b.example"])
        search.evict_instances(["a.example"])
        self.assertEqual(search.load_cached_instances(), ["b.example"])
        # Evicting unknown hosts is a no-op.
        search.evict_instances(["nope.example"])
        self.assertEqual(search.load_cached_instances(), ["b.example"])

    def test_probe_instance_rejects_dead_host(self):
        self.assertFalse(search._probe_instance("nonexistent.invalid", timeout=2))


class TestInstanceStats(unittest.TestCase):
    """Self-maintaining server list: health history ranks + prunes."""

    def setUp(self):
        import tempfile
        self._orig = (search.STATS_FILE, search.CACHE_FILE)
        tmp1 = tempfile.NamedTemporaryFile(suffix=".json", delete=False); tmp1.close()
        tmp2 = tempfile.NamedTemporaryFile(suffix=".json", delete=False); tmp2.close()
        search.STATS_FILE, search.CACHE_FILE = tmp1.name, tmp2.name
        self._tmps = (tmp1.name, tmp2.name)

    def tearDown(self):
        search.STATS_FILE, search.CACHE_FILE = self._orig
        for p in self._tmps:
            os.unlink(p)

    def test_record_and_rank_by_recency(self):
        search._record_stat("old.example", ok=True)
        search._record_stat("new.example", ok=True)
        # Backdate old.example's success so new.example ranks first.
        stats = search.load_stats()
        stats["old.example"]["last_ok"] -= 10 * 86400
        search.save_stats(stats)
        ranked = search._ranked_good_hosts()
        self.assertEqual(ranked[0], "new.example")
        self.assertIn("old.example", ranked)

    def test_rank_drops_stale_successes(self):
        search._record_stat("ancient.example", ok=True)
        stats = search.load_stats()
        stats["ancient.example"]["last_ok"] -= 40 * 86400  # > STATS_RANK_DAYS
        search.save_stats(stats)
        self.assertEqual(search._ranked_good_hosts(), [])

    def test_prune_forgets_rotted_hosts(self):
        search._record_stat("rotted.example", ok=True)
        stats = search.load_stats()
        stats["rotted.example"]["last_ok"] -= 60 * 86400  # > STATS_KEEP_OK_DAYS
        search.save_stats(stats)
        search._record_stat("fresh.example", ok=True)  # triggers prune
        self.assertNotIn("rotted.example", search.load_stats())

    def test_failures_recorded_then_forgotten(self):
        search._record_stat("flaky.example", ok=False)
        stats = search.load_stats()
        # A host that never succeeded has no ranking value — pruned instantly.
        self.assertNotIn("flaky.example", stats)

    def test_get_instances_ranks_stats_above_static_pool(self):
        # Warm cache → get_instances() skips the discovery path (no network).
        search.save_cached_instances(["cached.example"])
        search._record_stat("proven.example", ok=True)
        order = search.get_instances()
        self.assertLess(order.index("cached.example"), order.index("proven.example"))
        self.assertLess(order.index("proven.example"), order.index("iv.catgirl.cloud"))


class TestAgeRestriction(unittest.TestCase):
    def _video(self, **kw):
        base = {
            "title": "T", "videoId": "abc123XYZ", "author": "C", "authorId": "UCabc",
            "lengthSeconds": 3600, "viewCount": 50_000, "published": NOW - 10 * DAY,
        }
        base.update(kw)
        return base

    def test_entry_line_marks_age_restricted(self):
        v = self._video(isAgeLimited=True)
        line = search.entry_line(v, NOW, score=0.5)
        self.assertIn("🔒 age-restricted", line)

    def test_entry_line_clean_for_normal(self):
        v = self._video()
        line = search.entry_line(v, NOW, score=0.5)
        self.assertNotIn("age-restricted", line)
        self.assertNotIn("🔒", line)

    def test_flags_field_detected(self):
        v = self._video(flags=["age-restricted"])
        self.assertTrue(search._is_age_restricted(v))

    def test_age_restricted_field_variants(self):
        self.assertTrue(search._is_age_restricted(self._video(isAgeLimited=True)))
        self.assertTrue(search._is_age_restricted(self._video(ageLimited=True)))
        self.assertFalse(search._is_age_restricted(self._video()))


if __name__ == "__main__":
    unittest.main()
