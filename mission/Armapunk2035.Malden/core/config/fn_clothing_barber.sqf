/*
    AP_fnc_clothing_barber  (LooneyBin stub 2026-06-09 -- BUGS.md #65)
    fn_clothingFilter dispatches shop type "barber" here, but the fn never existed -> script error if
    any shop opened with that type (none currently does). Returns [] = clean empty list. To BUILD the
    barber: return [classname, displayName, price] rows per selection slot (mirror fn_clothing_civ).
*/ []
