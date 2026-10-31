class REMOVEALLEVENTHANDLERS {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{"OBJECT"}, {"STRING"}};};};
class REMOVEALLMPEVENTHANDLERS {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"STRING"}};};};
class CREATEUNIT {class SYNTAX1 {targets[] = {
            0, 0, 0   // launch.md 2c (2026-09-07): client createUnit re-blocked (was 1 for the BIS arsenal preview, #100)
        };
        args[] = {{"STRING"}, {"ARRAY"}};};
    class SYNTAX2 {targets[] = {0, 0, 0   // launch.md 2c (2026-09-07): client createUnit re-blocked (was 1 for the BIS arsenal preview, #100)
        };
        args[] = {{"GROUP"}, {"ARRAY"}};};};
class CREATEAGENT {class SYNTAX1 {targets[] = {0, 0, 0};   // launch.md 2c (2026-09-07)
        args[] = {{}, {"ARRAY"}};};};
class SETDAMMAGE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"SCALAR"}};};};
class ALLVARIABLES {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {"CONTROL"}};};
    class SYNTAX2 {targets[] = {1, 1, 0};
        args[] = {{}, {"TEAM_MEMBER"}};};
    class SYNTAX3 {targets[] = {1, 1, 0};
        args[] = {{}, {"NAMESPACE"}};};
    class SYNTAX4 {targets[] = {1, 1, 0};
        args[] = {{}, {"OBJECT"}};};
    class SYNTAX5 {targets[] = {1, 1, 0};
        args[] = {{}, {"GROUP"}};};
    class SYNTAX6 {targets[] = {1, 1, 0};
        args[] = {{}, {"TASK"}};};
    class SYNTAX7 {targets[] = {1, 1, 0};
        args[] = {{}, {"LOCATION"}};};};
class REMOVEALLITEMS {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {"OBJECT"}};};};
class CREATETEAM {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{}, {"ARRAY"}};};};
class SETWEAPONRELOADINGTIME {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"ARRAY"}};};};
class ADDGROUPICON {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"GROUP"}, {"ARRAY"}};};};
class ADDMPEVENTHANDLER {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"ARRAY"}};};};
class CREATEVEHICLECREW {class SYNTAX1 {targets[] = {1, 0, 0};
        args[] = {{}, {"OBJECT"}};};};
class LOADFILE {class SYNTAX1 {targets[] = {
            0, 1, 0   // CLIENT ENABLED 2026-09-02, same reason as CREATELOCATION above: the mission's
                      // OWN code calls loadFile. webui/functions/fn_init.sqf re-injects webui.js with
                      // it on every page open, and a refusal does not return "" -- it ABORTS the calling
                      // script at that line, uncatchably, which is why that block had to be moved last
                      // in the file and why 'pageloaded' never once won the readiness race. The audit
                      // recorded in that file blamed the ENGINE for refusing loadFile on clients; the
                      // refusal was this list. Server and HC stay blocked: loadFile there would read
                      // server-side files, and nothing server-side calls it.
        };
        args[] = {{}, {"STRING"}};};};
class REMOVEMPEVENTHANDLER {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"ARRAY"}};};};
class CREATEMARKER {class SYNTAX1 {targets[] = {1, 0, 0};
        args[] = {{}, {"ARRAY"}};};};
class SETWAYPOINTSTATEMENTS {class SYNTAX1 {targets[] = {1, 0, 0};
        args[] = {{"ARRAY"}, {"ARRAY"}};};};
class CREATELOCATION {class SYNTAX1 {targets[] = {
            0, 1, 0   // CLIENT ENABLED 2026-09-01. createLocation is CBA's namespace primitive
                      // (CBA_fnc_createNamespace = createLocation ["CBA_NamespaceDummy", ...]), and a
                      // disabled command returns nil, so every CBA cache guarded by "if the namespace
                      // is null then build it" can never populate and retries at its caller's rate --
                      // ~30 blocked calls a second, 22,570 in 16 minutes, drowning the client RPT.
                      // No mission or server code calls createLocation, and locations are LOCAL, so
                      // blocking it client-side protected nothing. Remote abuse is already closed by
                      // CfgRemoteExec: class Commands {mode = 0;} blocks remoteExec of every raw
                      // command, which is the only way a client could push this onto another machine.
                      // Server and HC stay disabled -- nothing there has ever needed it.
        };
        args[] = {{}, {"ARRAY"}};};};
class SENDAUMESSAGE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{}, {"ARRAY"}};};};
class SENDUDPMESSAGE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{}, {"ARRAY"}};};};
class ADDWAYPOINT {class SYNTAX1 {targets[] = {1, 0, 0};
        args[] = {{"GROUP"}, {"ARRAY"}};};};
class REMOTECONTROL {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"OBJECT"}};};};
class CREATEGEARDIALOG {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {"ARRAY"}};};};
class OPENDLCPAGE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{}, {"SCALAR"}};};};
class VECTORNORMALIZED {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {"ARRAY"}};};};
class GETMOUSEPOSITION {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {}};};};
class CREATEMINE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{}, {"ARRAY"}};};};
class ADDLIVESTATS {class SYNTAX0 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"SCALAR"}};};};
class ADDFORCE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"ARRAY"}};};};
class ADDTORQUE {class SYNTAX1 {targets[] = {0, 0, 0};
        args[] = {{"OBJECT"}, {"ARRAY"}};};};
class SETVELOCITYTRANSFORMATION {class SYNTAX1 {targets[] = {1, 0, 1};
        args[] = {{"OBJECT"}, {"ARRAY"}};};};
class ONPRELOADFINISHED {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {"STRING", "CODE"}};};};
class ONPRELOADSTARTED {class SYNTAX1 {targets[] = {1, 1, 0};
        args[] = {{}, {"STRING", "CODE"}};};};