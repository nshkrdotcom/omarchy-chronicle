import unittest


class SoakMeasurementTests(unittest.TestCase):
    def test_startup_descriptors_are_not_misreported_as_steady_state_growth(self):
        from scripts.soak import summarize
        result = summarize([
            {"ready":False,"rss_kib":12000,"fds":3,"cpu_seconds":0},
            {"ready":True,"rss_kib":22000,"fds":8,"cpu_seconds":.01},
            {"ready":True,"rss_kib":22500,"fds":8,"cpu_seconds":.02},
        ])
        self.assertEqual(result["fd_growth"],0)
        self.assertTrue(result["within_bounds"])

    def test_real_growth_and_missing_ready_baseline_fail(self):
        from scripts.soak import summarize
        self.assertFalse(summarize([
            {"ready":True,"rss_kib":20000,"fds":8,"cpu_seconds":0},
            {"ready":True,"rss_kib":20000,"fds":9,"cpu_seconds":1},
        ])["within_bounds"])
        self.assertFalse(summarize([])["within_bounds"])
