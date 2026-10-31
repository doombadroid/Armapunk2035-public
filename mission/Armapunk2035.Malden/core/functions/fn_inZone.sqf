params[["_markerArray", [], []], ["_distance2D", 0, [0]], ["_playerObj", objNull, [objNull]]];
if (_markerArray isEqualTo[] || _distance2D isEqualTo 0 || isNull _playerObj) exitWith {};
private _nearbyZones = _markerArray select {_playerObj distance(getMarkerPos _x) <= _distance2D};
private _zone = _nearbyZones param[(_nearbyZones apply {_playerObj distance(getMarkerPos _x)}) findIf {
    _x isEqualTo(selectMin(_nearbyZones apply {_playerObj distance(getMarkerPos _x)}))}, ""];
private _return = ((_zone isNotEqualTo "") && (_playerObj distance(getMarkerPos _zone) <= _distance2D));
_return