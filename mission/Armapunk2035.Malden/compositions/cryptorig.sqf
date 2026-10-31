/*
    compositions\cryptorig.sqf -- the placeable Crypto Mining Rig composition (owner-built in 3DEN,
    converted by scratchpad/sqe_to_cryptorig.py from Documents/Arma 3/compositions/CryptoMiningRig).
    Read by APS_fnc_miningSRV _spawnRig: [[class, [ox,oy,oz], relDir, (anims)], ...]; offsets rotate
    with placement dir, oz from the lowest piece (=0). Re-export in Eden + rerun the converter to change.
*/
// DO NOT "fix" the desk oz: every piece here is CENTER-pivoted (autocenter p3d, bboxReal min == -max),
// so a resting piece's oz = half its model height above the FLOOR plane, never 0. The .sqe z values are
// Eden surface-snapped RESTING positions -- replicate their relative spacing exactly. A 2026-07-22 "desk
// hovers 0.271" fixup dropped the desk cluster 0.271 and sank it through the floor/table -- reverted.
// oz here = Eden offsets +0.174 (floor-server half-height): the placement point is the FLOOR under the
// preview, so the comp floor plane (lowest piece's BOTTOM, not its origin) must sit at oz 0.
[["Land_PortableServer_01_sand_F", [0.690, 0.062, 0.174], 180.28], ["Land_PortableServer_01_olive_F", [-0.799, 0.006, 0.174], 180.10],
    ["Land_PortableDesk_01_olive_F", [-0.055, 0.007, 0.445], 0.00], ["Land_PortableServer_01_sand_F", [0.685, 0.052, 0.521], 180.18],
    ["Land_PortableServer_01_olive_F", [-0.803, -0.004, 0.521], 180.10], ["Land_Computer_01_black_F", [0.451, -0.023, 0.933], 181.86],
    ["Land_PCSet_Intel_01_F", [-0.839, -0.009, 1.143], 337.20], ["Land_PCSet_01_case_F", [0.722, -0.012, 1.145], 0.00],
    ["Land_MultiScreenComputer_01_black_F", [-0.051, -0.076, 1.147], 0.00]]
