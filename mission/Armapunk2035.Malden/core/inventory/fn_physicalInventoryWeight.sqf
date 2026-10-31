private _total = 0; {private _itemWeight = getNumber(missionConfigFile >> "CfgWeights" >> (_x select 0) >> "weight");
    _total = _total + (_itemWeight * (_x select 1));}
forEach _this;
_total