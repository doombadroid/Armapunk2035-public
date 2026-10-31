# LooneyBin — Stub / Missing-Feature Inventory

> Deobfuscation (2017 server ↔ 2020 client) left ~109 stubs. Audited 2026-06-07.
> Legend: **DEAD** = no-op, does nothing · **MAYBE** = arg-drift passthrough, may be silently
> broken (like the gang bank was) · **VERIFY** = best-guess passthrough, probably works, untested.
> 🔴 high / 🟡 medium / ⚪ low-cosmetic.
>
> Totals: 32 server no-ops (DEAD) · 24 ADAPT passthroughs (MAYBE) · 15 VERIFY · 38 mission no-ops.
> Already repaired this work: gangBank, addHouse, fetchLoadouts, updateHouseTrunk, garageCount,
> handlePhoneMsg, handlePhoneCallSRV, bldgUpdateKeys, setJail, handleJail, copSplit, repairBuilding,
> srvSellHouse, ignitionBomb, medicFire, vehOwnerSwap, wantedSyncList, srvSellVehicle.

## 🔴 Priority — security / money / core

- **wacClient** (MAYBE → `checkHacks`) — memhack/anti-cheat report handler. Client sends
  `[player,[50,"MAIN_RE",...]]`. If the passthrough is wrong it silently drops hack reports →
  undermines the layer-1 BE/anti-cheat story. **Verify it processes + acts.**
- **handleWireTransfer** (MAYBE → `update`) — the wire-transfer SEND side (receive side is fine).
  May be silently broken like the gang bank → wires might not debit/credit. **Verify.**
- **cartelSRV** (MAYBE → `monitorCaptures`) — drug/arms/oil/wong cartel capture monitor. CORE gameplay.
  Partially works (no live RPT errors), but it's an unverified passthrough. Verify capture + payout.
- **exchangeSystemSRV** (MAYBE → `reduceMarket`) — market price decay on sells. (#42 fixed the table;
  this pricing fn is still a passthrough.)
- **battlEyeReceive** (DEAD, mission) — SQF BE-event relay. NOTE: BE's engine-level detection still
  runs via config; this is only a custom in-game relay. Low risk, but wire it if you want BE→game hooks.

## DEAD — no-op, feature does nothing (server)

**Admin events (minigames):** eventBRSRV (Battle Royale), eventGunGameSRV, eventPurgeSRV,
eventGraveyardSRV, duelArenaSystemSRV. ⚠️ Duel Arena: client death-logic IS wired (onPlayerKilled reads
`SRV_duelArenaData`) but the server never starts it → dead button.

**Heists / robberies:** loonyBinSRV (the signature Loony Bin heist), jewelryEmporiumSRV (referenced in
`fn_spawnPointCfg` — the #41 var), convoyRobbery + endConvoyRobbery, bankLightHouseToggle.

**Racing:** createTimeTrialVehSRV (+ timeTrialSRV MAYBE). Client: joinRace/startRace/raceWon all DEAD.

**Gang houses:** addGangHouse, changeGangHouseSRV, removeGangHouseSRV, gangBHistory (bank history log).

**Medic / air:** airDrop, airDropMedic, medSupplySpawn, medicSplit (medic payout split — cop copSplit
was fixed; this is the TT equivalent), enableCoPilot (heli co-pilot takeover on pilot death).

**Cop:** evidenceTruck, evidenceAppend (evidence system), srvMobileHQ (mobile HQ).

**Seasonal / cosmetic:** easterSeasonalEvent, xmasTreeAndPresentsSRV, discordEmbed (Discord webhooks),
playKaraoke, handleTimer, doBuySkin (vehicle skins — skins were stripped anyway).

**Economy / misc:** loginBonusSRV (daily login reward), houseTaxSRV (house tax), wantedRemoveCharge,
keyManagement (moot — keys are pid-derived).

## MAYBE-broken — ADAPT passthroughs (verify arg/return like gangBank)

House: transferHouse, updateHousePrice, updateVehicleMods, vehicleRepairSRV, spawnPhysicalItem.
Gang: setGangTagSRV, updateGangMem, update1GangTalents, transferGangOwnerSRV.
Admin: adminPlayerQuerySRV, adminDelVeh.
Player/stats: checkPlayer (GUID), getStatsArr, statTableUpdate, varPersist, bulkAdd, getID,
srvObjectMonitor, eventParticipants.
(+ the 🔴 four above: wacClient, handleWireTransfer, cartelSRV, exchangeSystemSRV, and timeTrialSRV.)

## VERIFY — probably work, untested

bankRobbery, fedRobbery, srvRobStore, huntingGrounds, handlePrisonBreak, trialSystemSRV, handleDispatch,
registerMaxTac, srvSpikeStrip, srvChopShopSell, changeWeather, govSystemSRV, processMailbox, add2Lotto,
changeServCycle.

## Mission-side silent no-ops (38, mostly legacy compat shims)

Many are harmless reverse-drift duplicates (real logic lives elsewhere). Grouped:
- **Court/trial:** trialBegin, trialDefendant, trialJury, jurySummons.
- **Dispatch:** createDispatch, newDispatch, finishDispatch.
- **MaxTac:** maxtacDispatch, maxtacDispatched, maxtacDeactivate.
- **Prison:** startPrisonBreak, prisonBreaker.
- **Wanted:** wantedPardon, wantedPerson, setBounty.
- **Racing:** joinRace, startRace, raceWon.
- **Other:** addStatistic, addToGang, applyWeather, battlEyeReceive, capNotice, createVehicle,
  forceJoinGroup, GEMenu, impoundMenu, jackpot, jail, jailSys, localChatMessage, newWaypoint,
  receiveOwner, reqsync, sessionReceive, setRestrained, vehicleExit.
  (jail/jailSys/setRestrained: live jail works via the repaired setJail/handleJail — these are stale shims.)
