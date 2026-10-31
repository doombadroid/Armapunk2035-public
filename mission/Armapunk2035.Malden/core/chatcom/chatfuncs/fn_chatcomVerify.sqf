if (inputAction "Chat" > 0) then {rwt_chatcom_spawn = [] spawn {waitUntil {shownChat};
        waitUntil {!isNull(finddisplay 24 displayctrl 101)};
        rwt_chatcom_chat_eh = (findDisplay 24) displayAddEventHandler["KeyDown", "_this call RWT_fnc_chatcomProcess"];};};
false;