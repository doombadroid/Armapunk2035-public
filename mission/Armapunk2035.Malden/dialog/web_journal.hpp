/*
    web_journal.hpp -- the ArmaQuest quest journal. One browser control,
    ArmaQuest\ui\journal.html. idd/idc set by aq_content.hpp's AQ_Settings
    override (937900/937901) -- see that file's comment for why this is NOT
    ArmaQuest\config\CfgArmaQuest.hpp's own default (8100/8101): those numbers
    already belong to this mission's deleted native quest_menu.hpp dialog.

    NO onLoad here, unlike this mission's other web_*.hpp dialogs (web_breach,
    web_map, ...). Every one of those is opened by something that just calls
    createDialog and reacts to its OWN existence via onLoad to run the
    init/attach dance. This dialog is opened differently: aq_fnc_journal's own
    ["open"] verb (ArmaQuest\functions\fn_journal.sqf) runs createDialog
    "AQ_Journal" ITSELF, then immediately fetches this control by idd/idc and
    attaches to it in the same breath -- see that verb's own code. An onLoad
    here calling back into aq_fnc_journal would re-enter ["open"] while the
    outer call is still inside its own createDialog.

    The page MUST be handed over with `url=` from a path listed in
    CfgCommands::allowedHTMLLoadURIs (description.ext) -- "ArmaQuest\ui\*".
    Without it the page renders and can never call back, with no error.
*/
class AQ_Journal {
    idd = 937900;
    name = "AQ_Journal";
    movingEnable = false;
    enableSimulation = true;
    class controls {
        class Page {
            idc = 937901;
            type = 106;                 // CT_WEBBROWSER, Arma 2.20+
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ArmaQuest\ui\journal.html";
        };
    };
};
