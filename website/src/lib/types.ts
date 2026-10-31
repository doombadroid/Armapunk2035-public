export interface PlayerRow {
  id: number;
  playerid: string;
  name: string;
  instance: number;
  cash: number | string;
  bankacc: number | string;
  new_drachma: number | string;
  civ_exp: number | string;
  cop_exp: number | string;
  med_exp: number | string;
  infamy_exp: number | string;
  gang0: number | null;
  gangrank0: number;
  title: number;
  ismaxtac: number;
  isscd: number;
  isfirefighter: number;
  lastupdated: Date;
}

export interface PlayerGlobalRow {
  playerid: string;
  adminlevel: number;
  coplevel: number;
  copretired: number;
  mediclevel: number;
  betatester: number;
  honor_exp: number | string;
  wealth: number | string;
  stats: string | null;
  lifetime_stats: string | null;
  mailbox: string | null;
  achievements: string | null;
}

export interface PlayerDetail {
  uid: string;
  name: string;
  cash: number;
  bank: number;
  newDrachma: number;
  wealth: number;
  civExp: number;
  copExp: number;
  medExp: number;
  infamyExp: number;
  honorExp: number;
  civTime: number; // minutes
  copTime: number;
  medTime: number;
  copLevel: number;
  copRetired: number;
  medicLevel: number;
  adminLevel: number;
  isMaxTac: boolean;
  isSCD: boolean;
  isFirefighter: boolean;
  betaTester: boolean;
  gangId: number | null;
  gangName: string | null;
  gangRank: number;
  aliases: string[];
  joined: Date | null;
  lastSeen: Date;
  discordId: string | null;
  vehicleCount: number;
  vehiclesBySide: { civ: number; cop: number; med: number };
  houseCount: number;
  bountyAmount: number;
  banned: boolean;
}

export interface VehicleRow {
  id: number;
  side: string;
  classname: string;
  type: string;
  plate: number;
  customplate: string | null;
  color: number;
  active: number;
  alive: number;
  listed: number;
}

export interface HouseRow {
  id: number;
  oid: string;
  worldspace: string;
  locked: number;
  sale: number | string;
  vcap: number;
  phys_cap: number;
  greenhouse: number;
  barrel: number;
  classname: string | null;
}

export interface GangRow {
  id: number;
  name: string;
  bank: number | string;
  experience: number | string;
  inviterank: number;
  kickrank: number;
  house_pos: string | null;
}

export interface GangDetail extends GangRow {
  members: { uid: string; name: string; rank: number }[];
  vehicleCount: number;
  warIds: number[];
  fortWins: number;
}

export interface LeaderRow {
  uid: string;
  name: string;
  value: number;
  gangName: string | null;
}

export interface ActivityRow {
  id: number;
  ts: Date;
  tag: string;
  playerid: string;
  name: string;
  message: string;
}
