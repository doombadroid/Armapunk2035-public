switch (true) do {case ((vehicle player) isKindOf "CAManBase"): {setViewDistance tawvd_foot};
    case ((vehicle player) isKindOf "LandVehicle"): {setViewDistance tawvd_car};
    case ((vehicle player) isKindOf "Air"): {setViewDistance tawvd_air};};