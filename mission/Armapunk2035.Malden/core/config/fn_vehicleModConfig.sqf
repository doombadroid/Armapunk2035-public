_vehModConfig = [[0, "Alarm", [["No Alarm System - $0", 0, 0], ["Alarm System - $5,000", 1, 5000]]], [1, "Trunk", [
        ["Base Storage - $0", 0, 0], ["+50 Storage - $5,000", 50, 5000], ["+75 Storage - $7,500", 75, 7500],
        ["+100 Storage - $10,000", 100, 10000]]], [2, "Handling", [["Stock Handling - $0", 0, 0], ["Suspension Mod - $3,500", 1, 3500],
        ["Brakes and Suspension - $7,500", 2, 7500]]], [3, "Horn", []], [4, "Nitrous", [["No Nitrous - $0", 0, 0],
        ["Nitrous - $10,000", 1, 10000]]], [5, "Tracker", [["No Tracker - $0", 0, 0], ["Tracker - $10,000", 1, 10000]]], [6, "Paint Tech", [
        // owner 2026-09-06: slot 6 was "pStorage" -- "Unavailable", never sold, never read, but present in every
        // persisted mods array (fn_prepareVehicle pads to 9). It is CHAMELEON PAINT now: the car-radio RESKIN
        // button, which drops the car to two seconds of static and lands a random stock livery. 1 = fitted.
        ["Stock Paint - $0", 0, 0], ["Chameleon Paint - $15,000", 1, 15000]]], [7, "hardenedLocks", [["Stock Locks - $0", 0, 0], ["Basic Locks - $10,000", 1, 10000],
        ["Medium Locks - $20,000", 2, 20000], ["Advanced Locks - $30,000", 3, 30000]]], [8, "Doors", [["No doors - $0", 0, 0],
        ["Doors - $35,000", 1, 35000]]],
    // owner 2026-07-21: slot 9 is now a three-way DRIVETRAIN COMPUTER choice rather than an autopilot toggle.
    // 2 = Analog Retrofit: the onboard computer comes OUT. Nothing to hack (Killswitch, Remote Vehicle Stop and
    // the whole valet/hijack suite all need a live ECU) but you also lose autopilot, GPS routing and the tracker.
    [9, "Drivetrain", [["Stock ECU - $0", 0, 0], ["Autopilot Module - $30,000", 1, 30000], ["Analog Retrofit - $45,000", 2, 45000]]]];
_vehModConfig;