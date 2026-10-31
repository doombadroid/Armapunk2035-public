/*
    LooneyBin car radio -- CfgMusic tracks. Occupants play these via playMusic [track, offset] (SEEK-synced to the
    station's live position + volume follows the in-game Music slider); bystanders play the SAME .ogg via say3D on
    the CfgSounds copy (positional). Class names + files MUST match the CfgSounds entries (the broadcast songId is
    used for both). Add a CfgMusic line here for every radio song you add to CfgSounds.hpp.
*/
// --- Pulse Electro (Radio03) ---
// --- Anarchy Rock (Radio05) ---
// Station ad: Malden migration
// Vanilla-client promo loop for STREAM stations (Malden Radio addon advert). Length must
// equal AUTORADIO_PromoLen in radioCfg.hpp.
class radio_promo_maldenradio { name = ""; sound[] = {"sounds\radio\radio_promo_maldenradio.ogg", 1.0, 1.0}; };
