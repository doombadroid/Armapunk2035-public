params[["_exclude", "", [""]]];
private _federalEvents = [["fed", ((missionNamespace getVariable ["SRV_maldenFed", [0]]) param[0, 0]) > 0], ["bank", AP_bank_robbed param[0, false]],
    ["evidence", !(SRV_evidence_status param[1, true])],   // LooneyBin: ACTIVE = defenses down (slot 1 false). Slot 0 = "cops have seized stuff" (set by every seizure) -- using it here BLOCKED every other federal event whenever the evidence locker had contents.
    ["prison", SRV_prisonData param[1, false]], ["convoy", SRV_convoy_status param[0, false]],
    ["loonybin", SRV_loonyBinData param[1, false]], ["jewelry", SRV_jewelryEmporiumSRV param[1, false]]];
private _eventsToCheck = (_federalEvents select {(_x select 0) != _exclude}) apply {_x select 1};
true in _eventsToCheck