// The world this mission is built for. initPlayerLocal compares the world the CLIENT actually
// loaded against it, to catch Arma's stale-world cache bug (client keeps a previous mission's
// terrain and every position lands somewhere meaningless). Inherited from the Altis fork, where
// it was spelled "Altis" inline -- a client on Malden then failed that check and was kicked to
// "Wrong World Loaded" before it could ever reach a slot. One constant so a future map move is
// a single edit rather than a hunt.
#define AP_WORLD "Malden"
#define __SETCONST__(var1,var2) var1 = compileFinal(if (var2 isEqualType "") then {var2} else {str(var2)})
#define fileName (__FILE__ select [29, count __FILE__ - 33])
#define scriptAvailable(cooldownTime) (cooldownTime call { \
    _zindex = AP_scriptCooldowns find fileName; \
    _zret = false; \
    if !(_zindex isEqualTo -1) then { \
        if ((AP_scriptCooldowns select (_zindex + 1)) > (time - _this)) then { \
            _zret = true; \
        } else { \
            AP_scriptCooldowns set [_zindex + 1, time]; \
        }; \
    } else { \
        if !(fileName isEqualTo "") then { \
            AP_scriptCooldowns pushBack fileName; \
            AP_scriptCooldowns pushBack time; \
        }; \
    }; \
    _zret; \
})
#define getControl(disp,ctrl) ((findDisplay ##disp) displayCtrl ##ctrl)
#define getSelData(ctrl) (lbData [##ctrl, (lbCurSel ##ctrl)])
