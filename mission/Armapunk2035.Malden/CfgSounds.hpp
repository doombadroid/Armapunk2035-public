// LooneyBin: original CfgSounds.hpp held mis-mapped briefing SQF (deobf artifact) and was emptied, which
// silently KILLED every custom vehicle horn -- fn_horn does `_vehicle say3D[_hornType,650]` and say3D needs a
// CfgSounds class named exactly that horn's sound id (oofhorn, emotionalDamage, ...). Restored here from the
// fn_hornCfg sound ids that have a matching sounds\horns\*.ogg (so all horns play again), + the new
// "imgonnasayit" horn (owner 2026-06-11). Missing ogg: iLoveLoonyBin (id 34) -> left out until the file exists.
class AP_DroneSiren {name = "AP_DroneSiren";
    sound[] = {"sounds\Siren_Medic.ogg", 3.16, 1.0};
    titles[] = {};};

// owner 2026-06-14 (#198): fn_gather plays `playSound "ziptie"` x3 on gather completion, but no "ziptie"
// CfgSounds class existed -> silent. The audio file (sounds\zip.ogg) was on disk the whole time; declare it.
class ziptie { name = "ziptie"; sound[] = {"sounds\zip.ogg", 1.0, 1.0}; titles[] = {}; };

// owner 2026-06-19 (#399): the Loony Bin thermite phase (core/actions/fn_loonyBin.sqf "thermiteEffects")
// say3D'd "loonyBinThermiteLoop" (looping while it burns) + "loonyBinThermiteEnded" (burn-through) but NO
// CfgSounds class existed -> "sound loonyBinThermiteLoop not found" RPT spam + silent thermite. Reuse the
// jewelry safe TORCH loop (same cutting/burning sound) and a break for the burn-through; both .oggs on disk.
class loonyBinThermiteLoop  { name = "loonyBinThermiteLoop";  sound[] = {"sounds\jewelrySafeTorchLoop.ogg", 3.16, 1.0}; titles[] = {}; };
class loonyBinThermiteEnded { name = "loonyBinThermiteEnded"; sound[] = {"sounds\break.ogg",               3.16, 1.0}; titles[] = {}; };

// LooneyBin 2026-06-12: vehicle SIRENS. The .oggs were on disk all along but NO CfgSounds classes
// existed -> fn_copSiren/fn_medicSiren say3D'd undeclared names -> every siren (F / Shift+F / Ctrl+F,
// medic wails, purge event) played SILENTLY. Names + loop lengths match the switch tables in
// core/cop/fn_copSiren.sqf and core/medical/fn_medicSiren.sqf.

// MaxSec standard siren (owner 2026-08-14). Unlike every other siren here the file is cut to
// EXACTLY one cycle -- 167936 samples @ 48 kHz -- and its seam sits inside the 133 ms window where
// the siren is silent between cycles. fn_copSiren re-triggers on a uiSleep, which can only land on
// a frame boundary, so the retrigger jitters a few ms either way; because the seam is in silence
// the jitter lands in silence too and cannot be heard. See the loop length in fn_copSiren.sqf.
class SirenMaxSec { name = "SirenMaxSec"; sound[] = {"sounds\SirenMaxSec.ogg", 3.16, 1.0}; titles[] = {}; };
// Same asset, louder, for the armoured branch (owner 2026-08-14). Field 2 is a LINEAR amplitude
// multiplier, so the 3.16 every siren here uses is +10 dB written the long way (10^(10/20)); 6.31
// is +16 dB, i.e. +6 dB over a patrol car -- the same step this file already uses between its two
// horn tiers (1.0 -> 2.0). Net effect on the MRAP is smaller than that: it plays siren2 today, and
// siren2's .ogg is 2.7 dB hotter than this one, so the armoured siren ends up ~3.3 dB above where
// it sits now. Declaring a second class over one .ogg is the existing pattern (see line 18 vs 120).
// Do NOT chase loudness with the 650 in fn_copSiren instead: that literal is the range for EVERY
// vehicle-mounted emitter in the mission (cop, TT, drone, all horns), and everything above it is a
// fixed world announcement. A truck should not out-carry the government PA speaker.
class SirenMaxSecHeavy { name = "SirenMaxSecHeavy"; sound[] = {"sounds\SirenMaxSec.ogg", 6.31, 1.0}; titles[] = {}; };
class SirenWail   { name = "SirenWail";   sound[] = {"sounds\SirenWail.ogg",   3.16, 1.0}; titles[] = {}; };
class SirenYelp   { name = "SirenYelp";   sound[] = {"sounds\SirenYelp.ogg",   3.16, 1.0}; titles[] = {}; };
class SirenPhaser { name = "SirenPhaser"; sound[] = {"sounds\SirenPhaser.ogg", 3.16, 1.0}; titles[] = {}; };
class siren2      { name = "siren2";      sound[] = {"sounds\siren2.ogg",      3.16, 1.0}; titles[] = {}; };
class medicWail   { name = "medicWail";   sound[] = {"sounds\medicWail.ogg",   3.16, 1.0}; titles[] = {}; };
class medicYelp   { name = "medicYelp";   sound[] = {"sounds\medicYelp.ogg",   3.16, 1.0}; titles[] = {}; };
class medicQwail  { name = "medicQwail";  sound[] = {"sounds\medicQwail.ogg",  3.16, 1.0}; titles[] = {}; };
class purgeSiren  { name = "purgeSiren";  sound[] = {"sounds\purgeSiren.ogg",  3.16, 1.0}; titles[] = {}; };
// bonus: file existed but was never declared -- skydive ambience (fn_skyDive plays "airplane")
class airplane    { name = "airplane";    sound[] = {"sounds\airplane.ogg",    2.0,  1.0}; titles[] = {}; };

// LooneyBin 2026-06-11: bank vault drill sound (APS_fnc_bankDrillVault plays "drilling") -- class was lost
// when CfgSounds was emptied in deobf -> "Sound drilling not found". Restored from sounds\drilling.ogg.
class drilling {name = "drilling";
    sound[] = {"sounds\drilling.ogg", 1.0, 1.0};
    titles[] = {};};

// ---- vehicle horns (fn_hornCfg sound ids -> sounds\horns\<id>.ogg) ----
class officerMaggot     { name = "officerMaggot";     sound[] = {"sounds\horns\officerMaggot.ogg",     2.0, 1.0}; titles[] = {}; };
class openthedoor       { name = "openthedoor";       sound[] = {"sounds\horns\openthedoor.ogg",       2.0, 1.0}; titles[] = {}; };
class hangKnocker       { name = "hangKnocker";       sound[] = {"sounds\horns\hangKnocker.ogg",       2.0, 1.0}; titles[] = {}; };
class EFN               { name = "EFN";               sound[] = {"sounds\horns\EFN.ogg",               2.0, 1.0}; titles[] = {}; };
class randymarsh        { name = "randymarsh";        sound[] = {"sounds\horns\randy-marsh.ogg",        2.0, 1.0}; titles[] = {}; };
class notabigfan        { name = "notabigfan";        sound[] = {"sounds\horns\notabigfan.ogg",         2.0, 1.0}; titles[] = {}; };
class ripgeorge         { name = "ripgeorge";         sound[] = {"sounds\horns\ripgeorge.ogg",          2.0, 1.0}; titles[] = {}; };
class whopper           { name = "whopper";           sound[] = {"sounds\horns\whopper.ogg",            2.0, 1.0}; titles[] = {}; };
class tornadosiren      { name = "tornadosiren";      sound[] = {"sounds\horns\tornadosiren.ogg",       2.0, 1.0}; titles[] = {}; };
class rickyspanish      { name = "rickyspanish";      sound[] = {"sounds\horns\rickyspanish.ogg",       2.0, 1.0}; titles[] = {}; };
class hornCucaracha     { name = "hornCucaracha";     sound[] = {"sounds\horns\hornCucaracha.ogg",     1.0, 1.0}; titles[] = {}; };
class hornBattle        { name = "hornBattle";        sound[] = {"sounds\horns\hornBattle.ogg",        1.0, 1.0}; titles[] = {}; };
class hornBike          { name = "hornBike";          sound[] = {"sounds\horns\hornBike.ogg",          1.0, 1.0}; titles[] = {}; };
class roadrunner        { name = "roadrunner";        sound[] = {"sounds\horns\roadrunner.ogg",        1.0, 1.0}; titles[] = {}; };
class slowbruh          { name = "slowbruh";          sound[] = {"sounds\horns\slowbruh.ogg",          1.0, 1.0}; titles[] = {}; };
class oofhorn           { name = "oofhorn";           sound[] = {"sounds\horns\oofhorn.ogg",           1.0, 1.0}; titles[] = {}; };
class tractorhorn       { name = "tractorhorn";       sound[] = {"sounds\horns\tractorhorn.ogg",       1.0, 1.0}; titles[] = {}; };
class shiphorn          { name = "shiphorn";          sound[] = {"sounds\horns\shiphorn.ogg",          1.0, 1.0}; titles[] = {}; };
class magicschool       { name = "magicschool";       sound[] = {"sounds\horns\magicschool.ogg",       1.0, 1.0}; titles[] = {}; };
class movebitch         { name = "movebitch";         sound[] = {"sounds\horns\movebitch.ogg",         1.0, 1.0}; titles[] = {}; };
class discordping       { name = "discordping";       sound[] = {"sounds\horns\discordping.ogg",       1.0, 1.0}; titles[] = {}; };
class chainsaw          { name = "chainsaw";          sound[] = {"sounds\horns\chainsaw.ogg",          1.0, 1.0}; titles[] = {}; };
class realestate        { name = "realestate";        sound[] = {"sounds\horns\realestate.ogg",        1.0, 1.0}; titles[] = {}; };
class noothorn          { name = "noothorn";          sound[] = {"sounds\horns\noothorn.ogg",          1.0, 1.0}; titles[] = {}; };
class trainhorn         { name = "trainhorn";         sound[] = {"sounds\horns\trainhorn.ogg",         1.0, 1.0}; titles[] = {}; };
class mikemyers         { name = "mikemyers";         sound[] = {"sounds\horns\mikemyers.ogg",         1.0, 1.0}; titles[] = {}; };
class tacnuke           { name = "tacnuke";           sound[] = {"sounds\horns\tacnuke.ogg",           1.0, 1.0}; titles[] = {}; };
class leeroy            { name = "leeroy";            sound[] = {"sounds\horns\leeroy.ogg",            1.0, 1.0}; titles[] = {}; };
class tspoke            { name = "tspoke";            sound[] = {"sounds\horns\tspoke.ogg",            1.0, 1.0}; titles[] = {}; };
class godPlsNo          { name = "godPlsNo";          sound[] = {"sounds\horns\godPlsNo.ogg",          1.0, 1.0}; titles[] = {}; };
class denseMotherFucker { name = "denseMotherFucker"; sound[] = {"sounds\horns\denseMotherFucker.ogg", 1.0, 1.0}; titles[] = {}; };
class noToDrugs         { name = "noToDrugs";         sound[] = {"sounds\horns\noToDrugs.ogg",         1.0, 1.0}; titles[] = {}; };
class wannaDoThis       { name = "wannaDoThis";       sound[] = {"sounds\horns\wannaDoThis.ogg",       1.0, 1.0}; titles[] = {}; };
class whoSaidThat       { name = "whoSaidThat";       sound[] = {"sounds\horns\whoSaidThat.ogg",       1.0, 1.0}; titles[] = {}; };
class sendToJesus       { name = "sendToJesus";       sound[] = {"sounds\horns\sendToJesus.ogg",       1.0, 1.0}; titles[] = {}; };
class emotionalDamage   { name = "emotionalDamage";   sound[] = {"sounds\horns\emotionalDamage.ogg",   1.0, 1.0}; titles[] = {}; };
class dixiehorn         { name = "dixiehorn";         sound[] = {"sounds\horns\dixiehorn.ogg",         1.0, 1.0}; titles[] = {}; };

// ---- NEW (owner 2026-06-11): "I'm gonna say it" horn (imgonnasayit.ogg, ~8s) ----
class imgonnasayit      { name = "imgonnasayit";      sound[] = {"sounds\horns\imgonnasayit.ogg",      1.0, 1.0}; titles[] = {}; };

// ---- RESTORED (owner 2026-06-11): 43 deobf-silent sounds. CfgSounds was emptied in deobf so these
// playSound/say3D classes were 'not found' even though the .ogg ships in the PBO. Re-added with the
// code's exact spelling -> volume 1.0 default (tune alarms/voices later). Loops (bombPhone/torch/fire/
// ufoHover) loop via their caller as before; the class just makes them audible again. ----
// airplane already declared above (line ~25, skydive ambience vol 2.0) -- duplicate here removed
// (owner 2026-06-13): "CfgSounds.airplane: member already defined" crashed PBO load on first connect.
class bombarm                    { name = "bombarm"; sound[] = {"sounds\bombarm.ogg", 1.0, 1.0}; titles[] = {}; };
class bombPhoneAnswer            { name = "bombPhoneAnswer"; sound[] = {"sounds\bombPhoneAnswer.ogg", 1.0, 1.0}; titles[] = {}; };
class bombPhoneAnswerTalk        { name = "bombPhoneAnswerTalk"; sound[] = {"sounds\bombPhoneAnswerTalk.ogg", 1.0, 1.0}; titles[] = {}; };
class bombPhoneInit              { name = "bombPhoneInit"; sound[] = {"sounds\bombPhoneInit.ogg", 1.0, 1.0}; titles[] = {}; };
class bombPhoneLoop              { name = "bombPhoneLoop"; sound[] = {"sounds\bombPhoneLoop.ogg", 1.0, 1.0}; titles[] = {}; };
class Camera                     { name = "Camera"; sound[] = {"sounds\camera.ogg", 1.0, 1.0}; titles[] = {}; };
class car_lock                   { name = "car_lock"; sound[] = {"sounds\car_lock.ogg", 1.0, 1.0}; titles[] = {}; };
class chop                       { name = "chop"; sound[] = {"sounds\chop.ogg", 1.0, 1.0}; titles[] = {}; };
// resource rig (traded system): 5.66s deploy sweep, 1.75s drill loop segment
class ap_rig_deploy              { name = "ap_rig_deploy"; sound[] = {"sounds\ap_rig_deploy.ogg", 2.0, 1.0}; titles[] = {}; };
class ap_rig_drill               { name = "ap_rig_drill";  sound[] = {"sounds\ap_rig_drill.ogg", 2.0, 1.0}; titles[] = {}; };
class CokeSlosh1                 { name = "CokeSlosh1"; sound[] = {"sounds\CokeSlosh1.ogg", 1.0, 1.0}; titles[] = {}; };
class CokeSlosh2                 { name = "CokeSlosh2"; sound[] = {"sounds\CokeSlosh2.ogg", 1.0, 1.0}; titles[] = {}; };
class elechair                   { name = "elechair"; sound[] = {"sounds\elechair.ogg", 1.0, 1.0}; titles[] = {}; };
class executionerAnyLastWords    { name = "executionerAnyLastWords"; sound[] = {"sounds\executionerAnyLastWords.ogg", 1.0, 1.0}; titles[] = {}; };
class executionerFatality        { name = "executionerFatality"; sound[] = {"sounds\executionerFatality.ogg", 1.0, 1.0}; titles[] = {}; };
class executionerGunshot         { name = "executionerGunshot"; sound[] = {"sounds\executionerGunshot.ogg", 1.0, 1.0}; titles[] = {}; };
class executionerHeadshot        { name = "executionerHeadshot"; sound[] = {"sounds\executionerHeadshot.ogg", 1.0, 1.0}; titles[] = {}; };
class executionerWaitWait        { name = "executionerWaitWait"; sound[] = {"sounds\executionerWaitWait.ogg", 1.0, 1.0}; titles[] = {}; };
class executionerWeDontCare      { name = "executionerWeDontCare"; sound[] = {"sounds\executionerWeDontCare.ogg", 1.0, 1.0}; titles[] = {}; };
class Flashbang                  { name = "Flashbang"; sound[] = {"sounds\flashbang.ogg", 1.0, 1.0}; titles[] = {}; };
class govSpeaker                 { name = "govSpeaker"; sound[] = {"sounds\govSpeaker.ogg", 1.0, 1.0}; titles[] = {}; };
class handcuffs                  { name = "handcuffs"; sound[] = {"sounds\handcuffs.ogg", 1.0, 1.0}; titles[] = {}; };
class jewelryAlarm               { name = "jewelryAlarm"; sound[] = {"sounds\jewelryAlarm.ogg", 1.0, 1.0}; titles[] = {}; };
class bankalarm                  { name = "bankalarm"; sound[] = {"sounds\bankalarm.ogg", 3.16, 1.0}; titles[] = {}; };   // the .ogg shipped with no class -- used for the radar-sabotage fuse
class jewelrySafeTorchLoop       { name = "jewelrySafeTorchLoop"; sound[] = {"sounds\jewelrySafeTorchLoop.ogg", 1.0, 1.0}; titles[] = {}; };
class medicFireFlames1           { name = "medicFireFlames1"; sound[] = {"sounds\medicFireFlames1.ogg", 1.0, 1.0}; titles[] = {}; };
class medicFireFlames2           { name = "medicFireFlames2"; sound[] = {"sounds\medicFireFlames2.ogg", 1.0, 1.0}; titles[] = {}; };
class medicFireHose              { name = "medicFireHose"; sound[] = {"sounds\medicFireHose.ogg", 1.0, 1.0}; titles[] = {}; };
class medicFireHoseFill          { name = "medicFireHoseFill"; sound[] = {"sounds\medicFireHoseFill.ogg", 1.0, 1.0}; titles[] = {}; };
class metalDetectScan            { name = "metalDetectScan"; sound[] = {"sounds\metalDetectScan.ogg", 1.0, 1.0}; titles[] = {}; };
class PhoneDial                  { name = "PhoneDial"; sound[] = {"sounds\phonedial.ogg", 1.0, 1.0}; titles[] = {}; };
class PhoneRing                  { name = "PhoneRing"; sound[] = {"sounds\phonering.ogg", 1.0, 1.0}; titles[] = {}; };
class pickaxe                    { name = "pickaxe"; sound[] = {"sounds\pickaxe.ogg", 1.0, 1.0}; titles[] = {}; };
class Purchase                   { name = "Purchase"; sound[] = {"sounds\purchase.ogg", 1.0, 1.0}; titles[] = {}; };
class questDoneNormal            { name = "questDoneNormal"; sound[] = {"sounds\questDoneNormal.ogg", 1.0, 1.0}; titles[] = {}; };
class questDoneSeasonal          { name = "questDoneSeasonal"; sound[] = {"sounds\questDoneSeasonal.ogg", 1.0, 1.0}; titles[] = {}; };
class questStart                 { name = "questStart"; sound[] = {"sounds\questStart.ogg", 1.0, 1.0}; titles[] = {}; };
class racebeep1                  { name = "racebeep1"; sound[] = {"sounds\racebeep1.ogg", 1.0, 1.0}; titles[] = {}; };
class racebeep2                  { name = "racebeep2"; sound[] = {"sounds\racebeep2.ogg", 1.0, 1.0}; titles[] = {}; };
class sprayCanStart              { name = "sprayCanStart"; sound[] = {"sounds\sprayCanStart.ogg", 1.0, 1.0}; titles[] = {}; };
class ufoCrash                   { name = "ufoCrash"; sound[] = {"sounds\ufoCrash.ogg", 1.0, 1.0}; titles[] = {}; };
class ufoHover                   { name = "ufoHover"; sound[] = {"sounds\ufoHover.ogg", 1.0, 1.0}; titles[] = {}; };
class ufoLeave                   { name = "ufoLeave"; sound[] = {"sounds\ufoLeave.ogg", 1.0, 1.0}; titles[] = {}; };
class unlock                     { name = "unlock"; sound[] = {"sounds\unlock.ogg", 1.0, 1.0}; titles[] = {}; };
class lock                       { name = "lock"; sound[] = {"sounds\lock.ogg", 1.0, 1.0}; titles[] = {}; };   // owner 2026-06-15 (#246): "lock" sound class was missing -> "Lock sound not found" on house lock + no lock sfx (sounds\lock.ogg already shipped)
// owner 2026-06-24: 2 NEW vehicle horns (fn_hornCfg ids 46/47). say3D needs a CfgSounds class named exactly the horn's soundId.
class water                      { name = "water"; sound[] = {"sounds\horns\water.ogg", 1.0, 1.0}; titles[] = {}; };
class glorytochina               { name = "glorytochina"; sound[] = {"sounds\horns\glorytochina.ogg", 1.0, 1.0}; titles[] = {}; };
// LooneyBin car radio -- CfgSounds tracks (stations in core\radio\radioCfg.hpp). Cleared 2026-07-06 for a fresh,
// genre-segregated tracklist. Add one class per song here as: name + sound[]={"sounds\radio\<file>.ogg",vol,pitch}.
// --- CLASSICAL (Classico, station 04) ---
// --- Pulse Electro (Radio03) ---
// --- Station ad: Malden migration (forced every 3rd track on every populated station, see APS_fnc_radioSRV) ---
class radio_promo_maldenradio  { name = "radio_promo_maldenradio"; sound[] = {"sounds\radio\radio_promo_maldenradio.ogg", 1.0, 1.0}; titles[] = {}; };
