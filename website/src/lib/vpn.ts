import { q } from "./db";

export interface VpnExempt {
  id: number; playerid: string; name: string; note: string;
  added_by: string; bm_player_id: string; created_at: Date;
}

export async function listVpnExempt(): Promise<VpnExempt[]> {
  return q<VpnExempt>("SELECT * FROM web_vpn_exempt ORDER BY created_at DESC");
}
