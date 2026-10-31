private _menuType =
if (isNull AP_my_gang) then {"groupMenuBrowse"} else {"groupMenuMain"};
[_menuType] spawn AP_fnc_createDialog;