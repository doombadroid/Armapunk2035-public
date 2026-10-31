/*
    fn_aqJournalOpen.sqf  (AP_fnc_aqJournalOpen) -- opens the ArmaQuest quest
    journal from the deck's app grid (AP_phone_buttons, "Quest Log").

    aq_fnc_journal's own ["open"] verb does the whole job: with no control
    attached yet (the normal case, reaching this fresh from the deck grid)
    it runs createDialog "AQ_Journal" (dialog\web_journal.hpp, idd 937900),
    finds that dialog's browser control (idc 937901 -- set by aq_content.hpp's
    AQ_Settings override, see that file's comment for why this mission does
    NOT use the library's own default 8100/8101), and attaches itself to it
    in the same call -- see ArmaQuest\functions\fn_journal.sqf, case "open".
    This wrapper exists only so AP_phone_buttons has a plain function name to
    call, the same as every other deck app that owns its own dialog (Casino,
    Summon, MALDEN GRID) rather than an inline action string.

    If the dialog cannot open (missing include, whitelist miss, etc.)
    aq_fnc_journal logs once and returns false -- quests keep progressing and
    paying as Arma native tasks either way; this button only ever offers the
    extra page, never gates the underlying system. See that function's own
    header for the full contract, including why the whitelist entry
    ("ArmaQuest\ui\*" in description.ext's allowedHTMLLoadURIs) is what makes
    the page able to call back at all -- without it the page still renders,
    just mute, with no error on either side.

    Usage:  [] call AP_fnc_aqJournalOpen;   (AP_phone_buttons action string)
*/

["open"] call aq_fnc_journal;
