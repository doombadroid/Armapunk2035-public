/*
    File: fn_mapCfg.sqf  (AP_fnc_mapCfg)
    Streaming constants. ONE definition for the server, every client, the headless client and
    the self-test; consumers read by name. Values and their reasons: mapdb.md D3.

      cell        1000 m  grid cell edge; key = floor(x/cell)_floor(y/cell)
      far         2000 m  stream_r above this (or 0 = always) lives in the "far" bucket sent at join
      defaultR    1500 m  stream_r for rows with NULL (-1 on the wire)
      hyst         250 m  delete only beyond stream_r + hyst
      fetchR      2000 m  cells whose square is within this of the focus are fetched (>= defaultR + hyst)
      poll           2 s  streamer tick
      retry         15 s  re-request a cell that never answered
      createBatch   20    creates (or deletes) per uiSleep inside one tick
*/
createHashMapFromArray [
    ["cell", 1000], ["far", 2000], ["defaultR", 1500], ["hyst", 250], ["fetchR", 2000],
    ["poll", 2], ["retry", 15], ["createBatch", 20]
]
