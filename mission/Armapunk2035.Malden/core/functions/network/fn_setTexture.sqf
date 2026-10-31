params[["_object", objNull, [objNull]], ["_index", 0, [0]], ["_texture", "", [""]]];
if (isNull _object || _texture isEqualTo "") exitWith {};
if !("rvmat" in _texture) then {_object setObjectTexture[_index, _texture];} else {
    _object setObjectTexture[_index, "#(rgb,8,8,3)color(0.1,0.1,0.1,0.08,no)"];
    _object setObjectMaterial[_index, _texture];};