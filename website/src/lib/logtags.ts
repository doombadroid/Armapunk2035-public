// Curated catalog of `log.tag` values worth surfacing in a public activity feed.
// The firehose (-FNCALL-, -VEHINV-, -SCRIPTERR-, raw numeric tags, ...) is excluded.

export interface TagMeta { label: string; color: string }

export const TAG_CATALOG: Record<string, TagMeta> = {
  "-KILLED-": { label: "Kill", color: "red" },
  "-DOWNED-": { label: "Downed", color: "orange" },
  "-REVIVE-": { label: "Revive", color: "emerald" },
  "-ARREST-": { label: "Arrest", color: "blue" },
  "-TICKET-": { label: "Ticket", color: "blue" },
  "-RESTRAIN-": { label: "Restrain", color: "blue" },
  "-EXECUTE-": { label: "Execution", color: "red" },
  "-ITEMBOUGHT-": { label: "Bought", color: "amber" },
  "-WEAPONBOUGHT-": { label: "Weapon Buy", color: "amber" },
  "-CLOTHESBOUGHT-": { label: "Clothing Buy", color: "amber" },
  "-ITEMSOLD-": { label: "Sold", color: "green" },
  "-PROCESSEDITEMSUCCESS-": { label: "Processed", color: "violet" },
  "-GATHER-": { label: "Gathered", color: "violet" },
  "-WEED-": { label: "Weed", color: "green" },
  "-MINE-": { label: "Mining", color: "violet" },
  "-VEHICLEPULL-": { label: "Vehicle Pull", color: "sky" },
  "-VEHIMPOUND-": { label: "Impound", color: "blue" },
  "-LOCKPICKED-": { label: "Lockpick", color: "orange" },
  "-DEPOSIT-": { label: "Deposit", color: "green" },
  "-WITHDRAW-": { label: "Withdraw", color: "green" },
  "-BANKTRANSFER-": { label: "Transfer", color: "green" },
  "-LOGINBONUS-": { label: "Login Bonus", color: "amber" },
  "-CONNECT-": { label: "Connect", color: "gray" },
  "-DISCONNECT-": { label: "Disconnect", color: "gray" },
  "-RESPAWN-": { label: "Respawn", color: "gray" },
};

export const FEED_TAGS = Object.keys(TAG_CATALOG).filter(
  (t) => !["-CONNECT-", "-DISCONNECT-", "-RESPAWN-"].includes(t)
);

export function tagMeta(tag: string): TagMeta {
  return TAG_CATALOG[tag] ?? { label: tag.replace(/-/g, "").toLowerCase() || "event", color: "gray" };
}
