#!/usr/bin/env python3
"""Render tests for the FIXER ALLEGIANCE card in ui/html/deck.html.

WHY A TEST AND NOT JUST html_js_check
    html_js_check proves the page PARSES. It cannot notice that the card offers a
    DEFECT button to a gang whose fixer is at war this week, or lists the gang's
    current fixer among the ones it could switch to, or nags a two-man crew about
    having no patron. Those are the states the card exists to distinguish, and all
    of them parse perfectly.

HOW
    The card is an IIFE returning a string, so it can be lifted out of the page and
    run against stub data with nothing but `esc`, `F` and `S` around it. Extraction
    is by exact anchor: if the card is renamed or restructured the extraction fails
    loudly rather than silently testing nothing, which is the failure mode that
    makes this kind of test worthless.

    Skipped, loudly, when node is unavailable.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(ROOT, "mission", "Armapunk2035.Malden", "ui", "html", "deck.html")
OPEN_ANCHOR = "    (function(){\n      var fx = g.fixers"
CLOSE_ANCHOR = "    })() +"

HARNESS = r"""
function esc(x){return String(x).replace(/[&<>"]/g,function(c){
  return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
function F(n){return String(n);}
var S = {gangArm: null}, g;
function card(){ return __CARD__; }

var FIX3 = [{id:"f_neon",name:"Lightrunners",town:"Larche"},
            {id:"f_dock",name:"Crusaders",town:"Chapoi"},
            {id:"f_pharma",name:"Silent Partners",town:"La Port"}];
var WAR = ["f_neon","f_dock","f_pharma"];   // neon attacks dock; pharma neutral
var out = {};
function run(name, gang){ g = gang; out[name] = card(); }

run("nofixers",  {rank:1,members:[],fixers:[],war:[],faction:""});
run("small",     {rank:1,members:[1,2],fixers:FIX3,war:WAR,faction:"",alignAt:5});
run("fivestrong",{rank:1,members:[1,2,3,4,5],fixers:FIX3,war:WAR,faction:"",alignAt:5});
run("atwar",     {rank:1,members:[1],fixers:FIX3,war:WAR,faction:"f_neon",defectFee:500000,defectDays:7});
run("neutral",   {rank:1,members:[1],fixers:FIX3,war:WAR,faction:"f_pharma",defectFee:500000,defectDays:7});
run("member",    {rank:3,members:[1],fixers:FIX3,war:WAR,faction:"f_neon",defectFee:500000,defectDays:7});
console.log(JSON.stringify(out));
"""


def render_all():
    src = open(PAGE, encoding="utf-8").read()
    start = src.index(OPEN_ANCHOR)
    end = src.index(CLOSE_ANCHOR, start) + len(CLOSE_ANCHOR) - len(" +")
    card = src[start:end].strip()
    js = HARNESS.replace("__CARD__", card)
    fh = tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8")
    fh.write(js)
    fh.close()
    try:
        r = subprocess.run(["node", fh.name], capture_output=True, text=True)
    finally:
        os.unlink(fh.name)
    if r.returncode != 0:
        raise AssertionError("node failed:\n" + r.stderr)
    import json
    return json.loads(r.stdout)


@unittest.skipIf(shutil.which("node") is None, "node not available")
class TestFixerCard(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.out = render_all()

    def test_no_fixers_renders_nothing(self):
        """A world with no territorial faction must not leave an empty card behind."""
        self.assertEqual(self.out["nofixers"], "")

    def test_unaligned_says_so_and_offers_to_swear(self):
        c = self.out["small"]
        self.assertIn("UNALIGNED", c)
        self.assertIn("SWEAR", c)

    def test_no_nag_below_the_threshold(self):
        self.assertNotIn("NO PATRON", self.out["small"])

    def test_nag_at_the_threshold(self):
        self.assertIn("NO PATRON", self.out["fivestrong"])

    def test_defection_blocked_while_your_fixer_is_a_belligerent(self):
        """The server refuses this; the card must not offer it and then be refused."""
        c = self.out["atwar"]
        self.assertIn("CANNOT LEAVE", c)
        self.assertNotIn('data-act="gFaction"', c)

    def test_defection_offered_when_your_fixer_sits_the_week_out(self):
        c = self.out["neutral"]
        self.assertIn("DEFECT", c)
        self.assertNotIn("CANNOT LEAVE", c)

    def test_current_fixer_is_not_offered_as_a_destination(self):
        """Switching to the fixer you already serve is refused server-side."""
        self.assertNotIn("f_pharma", self.out["neutral"])

    def test_the_cost_is_stated_before_the_button(self):
        c = self.out["neutral"]
        self.assertIn("500000", c)
        self.assertIn("7 DAYS", c)
        self.assertIn("PERKS ARE LOST", c)

    def test_non_leaders_get_no_buttons(self):
        c = self.out["member"]
        self.assertIn("ONLY THE LEADER", c)
        self.assertNotIn("data-act", c)

    def test_the_weekly_matchup_is_shown_by_name(self):
        c = self.out["neutral"]
        self.assertIn("THIS WEEK", c)
        self.assertIn("Lightrunners", c)
        self.assertIn("Crusaders", c)
        self.assertIn("NEUTRAL", c)


if __name__ == "__main__":
    unittest.main(verbosity=2)
