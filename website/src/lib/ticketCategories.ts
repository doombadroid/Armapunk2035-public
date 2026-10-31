// Support-ticket category catalog + per-category guided-form specs.
// (store/purchase categories dropped, Trauma Team added.) `report` marks
// misconduct-report categories routed to a command review queue.

export type FieldType = "text" | "textarea" | "datetime" | "youtube" | "yesno" | "radio";
export interface FieldSpec {
  name: string; label: string; type: FieldType;
  required?: boolean; placeholder?: string; help?: string; rows?: number;
  options?: string[]; // for type "radio"
}
export interface GateSpec {
  title: string; intro?: string; bullets: string[]; info?: string[]; checkboxLabel: string;
}
export interface FormSpec {
  gate?: GateSpec;
  fields: FieldSpec[];
  subjectPrefix?: string;     // e.g. "Player Report"
  subjectFrom?: string;       // field name whose value is appended to the subject
  special?: "compensation";   // rendered by a bespoke component
}

// `key` and `report` are PERSISTED VALUES, not display text: key lands in web_tickets.category on
// every ticket ever filed, and report drives the routing checks in actions.ts. They keep their "apd"
// and "ng" spellings through the MaxSec and Trauma Team rebrands on purpose — renaming them would
// orphan the existing rows.
// Rename the labels freely; leave the keys alone unless a data migration comes with it.
export interface TicketCategory {
  key: string;
  label: string;
  desc: string;
  icon: string;
  report?: "apd" | "ng" | "staff";
  form: FormSpec;
  // hidden from the Support-Tickets category grid. police-app is submitted via
  // /maxsec/apply and routed into the maxsec_applications table (MaxSec → Applications tab),
  // not web_tickets — so it must not appear as a support ticket option.
  hidden?: boolean;
}

const DESC: FieldSpec = { name: "description", label: "Description", type: "textarea", required: true, rows: 6, placeholder: "Provide detailed information about your request…" };
const VIDEO: FieldSpec = { name: "video_url", label: "Video Evidence URL", type: "youtube", placeholder: "https://www.youtube.com/watch?v=…", help: "YouTube links only (youtube.com or youtu.be). Invalid URLs are discarded." };

export const TICKET_CATEGORIES: TicketCategory[] = [
  {
    key: "player-report", label: "Player Reporting", icon: "CircleAlert",
    desc: "Report in-game server rule violations privately to staff.",
    form: {
      subjectPrefix: "Player Report", subjectFrom: "reported_name",
      gate: {
        title: "Evidence Requirements",
        bullets: [
          "VDM (Vehicular Death Match) — video showing roughly 10 seconds before the incident.",
          "Combat Logging (CL) — full screenshot(s) of the player downed then immediately disconnecting with continuous chat, OR video of them ESC-suiciding / disconnecting to avoid interaction, OR video of them disconnecting after death then rejoining.",
          "RDM (Random Death Match) — video showing the 5 minutes prior to the RDM (before your death).",
          "Exploiting — clear video evidence of the exploit happening.",
        ],
        info: [
          "If you don't have sufficient evidence you may still file a report to support future reports on the player.",
          "Admin staff have the right to refuse to take action on any report.",
          "If you report someone who has already compensated you, you (the reporter) are likely to be banned.",
          "Reports MUST be filed within 72 hours of the incident.",
          "We do not accept 3rd-party reports for CL, VDM, or RDM.",
        ],
        checkboxLabel: "I understand the minimum evidence requirements and confirm my report meets them, or that I am submitting without full evidence as permitted above.",
      },
      fields: [
        { name: "your_name", label: "Your In-Game Name", type: "text", required: true, placeholder: "Your in-game character name", help: "We already know your Steam account — we need your in-character name from the incident." },
        { name: "reported_name", label: "Reported Player's In-Game Name", type: "text", required: true, placeholder: "Their in-game character name" },
        { name: "when", label: "Date & Time of Incident", type: "datetime", required: true },
        DESC, VIDEO,
      ],
    },
  },
  {
    key: "apd-report", label: "Report a MaxSec Officer", icon: "ShieldAlert", report: "apd",
    desc: "Report misconduct or rule violations by a MaxSec officer.",
    form: {
      subjectPrefix: "MaxSec Report", subjectFrom: "reported_name",
      gate: {
        title: "Reporting Requirements",
        bullets: [
          "This category is for reporting an officer for breaking MaxSec/cop rules — use the correct reporting format below.",
          "Video evidence speaks volumes during an investigation and is the best way for us to see what an officer did.",
          "If an officer broke general server rules, report them under Player Reporting instead.",
        ],
        checkboxLabel: "I understand this category is for reporting cop-rule violations and that video evidence is strongly recommended.",
      },
      fields: [
        { name: "reported_name", label: "In-Game Name of the MaxSec Member You Are Reporting", type: "text", required: true, placeholder: "Their in-game character name" },
        DESC, VIDEO,
      ],
    },
  },
  {
    key: "ng-report", label: "Report a Trauma Team Member", icon: "Stethoscope", report: "ng",
    desc: "Report misconduct by a Trauma Team member.",
    form: {
      subjectPrefix: "TT Report", subjectFrom: "reported_name",
      gate: {
        title: "Reporting Requirements",
        bullets: [
          "This category is for reporting a Trauma Team member for breaking TT rules — use the correct format below.",
          "Video evidence speaks volumes during an investigation and is the best way for us to see what happened.",
          "If the member broke general server rules, report them under Player Reporting instead.",
        ],
        checkboxLabel: "I understand this category is for reporting TT-rule violations and that video evidence is strongly recommended.",
      },
      fields: [
        { name: "reported_name", label: "In-Game Name of the TT Member You Are Reporting", type: "text", required: true, placeholder: "Their in-game character name" },
        DESC, VIDEO,
      ],
    },
  },
  {
    key: "comp", label: "Compensation Request", icon: "Banknote",
    desc: "Request compensation for acts of Arma or other events causing loss.",
    form: { special: "compensation", fields: [{ ...DESC, placeholder: "Describe what happened and what you lost…" }] },
  },
  {
    key: "account", label: "Character / Account / VPN", icon: "UserCog",
    desc: "Character, account, or VPN-whitelist support — in and out of game.",
    form: { fields: [DESC] },
  },
  {
    key: "police-app", label: "Police Application", icon: "ShieldCheck",
    desc: "Apply for MaxSec.",
    hidden: true, // submitted via /maxsec/apply → maxsec_applications, not support tickets
    form: {
      subjectPrefix: "Police Application",
      gate: {
        title: "Eligibility & Requirements",
        intro: "To apply for MaxSec, you must meet the following requirements:",
        bullets: [
          "Able to use voice communication (Discord).",
          "Able to speak fluent English.",
          "Must have at least 20+ hours played on civilian. (Waived for now.)",
          "Must be 16 years of age or older.",
          "Must not be currently blacklisted from MaxSec.",
          "Must not have any active bans.",
        ],
        info: ["You must fully fill out the application format or you will be denied."],
        checkboxLabel: "I understand the eligibility requirements and confirm that I meet all criteria listed above.",
      },
      fields: [
        { name: "discord_name", label: "Discord Name", type: "text", required: true, placeholder: "Your Discord username" },
        { name: "read_rules", label: "Have you read and do you understand the server rules?", type: "yesno", required: true },
        { name: "banned_before", label: "Have you been banned before?", type: "yesno", required: true },
        { name: "cop_experience", label: "Have you been a cop on any other server? If so, please explain", type: "textarea", required: true, rows: 4, placeholder: "Describe any cop experience on other servers…" },
        { name: "why", label: "Why do you want to join MaxSec?", type: "textarea", required: true, rows: 4, placeholder: "Tell us why you want to join…" },
      ],
    },
  },
  {
    key: "ng-app", label: "Trauma Team Application", icon: "Stethoscope",
    desc: "Apply for Trauma Team.",
    hidden: true, // submitted via /trauma-team/apply → maxsec_applications (faction='ng')
    form: {
      subjectPrefix: "Trauma Team Application",
      gate: {
        title: "Eligibility & Requirements",
        intro: "To apply for Trauma Team, you must meet the following requirements:",
        bullets: [
          "Able to use voice communication (Discord).",
          "Able to speak fluent English.",
          "Must have at least 20+ hours played on civilian. (Waived for now.)",
          "Must be 16 years of age or older.",
          "Must not be currently blacklisted from Trauma Team.",
          "Must not have any active bans.",
        ],
        info: ["You must fully fill out the application format or you will be denied."],
        checkboxLabel: "I understand the eligibility requirements and confirm that I meet all criteria listed above.",
      },
      fields: [
        { name: "discord_name", label: "Discord Name", type: "text", required: true, placeholder: "Your Discord username" },
        { name: "read_rules", label: "Have you read and do you understand the server rules?", type: "yesno", required: true },
        { name: "banned_before", label: "Have you been banned before?", type: "yesno", required: true },
        { name: "cop_experience", label: "Any medical/support experience on other servers? If so, please explain", type: "textarea", required: true, rows: 4, placeholder: "Describe any relevant experience on other servers…" },
        { name: "why", label: "Why do you want to join Trauma Team?", type: "textarea", required: true, rows: 4, placeholder: "Tell us why you want to join…" },
      ],
    },
  },
  {
    key: "ban-appeal", label: "Ban Appeal", icon: "Scale",
    desc: "Request staff review of your ban.",
    form: { fields: [{ ...DESC, placeholder: "Explain your ban and why it should be reviewed…" }] },
  },
  {
    key: "staff-report", label: "Report a Staff Member", icon: "UserX", report: "staff",
    desc: "Report a staff member directly to server ownership.",
    form: {
      subjectPrefix: "Staff Report", subjectFrom: "reported_name",
      fields: [
        { name: "reported_name", label: "In-Game Name of the Staff Member You Are Reporting", type: "text", required: true, placeholder: "Their in-game character name" },
        DESC,
      ],
    },
  },
  {
    key: "bug", label: "Bug & Exploit Report", icon: "Bug",
    desc: "Report in-game or website bugs / exploits — rewards for valid reports!",
    form: { fields: [{ ...DESC, placeholder: "Describe the bug/exploit and how to reproduce it…" }] },
  },
  {
    key: "staff-app", label: "Staff Application", icon: "UserPlus",
    desc: "Apply for Support, Moderator, or Development positions.",
    form: {
      subjectPrefix: "Staff Application",
      gate: {
        title: "Eligibility & Requirements",
        intro: "To apply for staff, you must meet the following requirements:",
        bullets: [
          "Able to use voice communication (TeamSpeak).",
          "Able to speak fluent English.",
          "Must have at least 100+ hours played in game. (Waived for now.)",
          "Must be 16 years of age or older.",
          "Must not have any active bans.",
        ],
        info: ["You must fully fill out the application format or you will be denied."],
        checkboxLabel: "I understand the eligibility requirements and confirm that I meet all criteria listed above.",
      },
      fields: [
        { name: "application_type", label: "Application Type", type: "radio", required: true, options: ["Support", "Moderator", "Developer"] },
        { name: "discord_name", label: "Discord Name", type: "text", required: true, placeholder: "Your Discord username" },
        { name: "read_rules", label: "Have you read and do you understand the server rules?", type: "yesno", required: true },
        { name: "banned_before", label: "Have you been banned before?", type: "yesno", required: true },
        { name: "prior_experience", label: "Prior Experience", type: "textarea", required: true, rows: 4, help: "Can be in or out of Arma 3 scope.", placeholder: "Describe any relevant prior experience…" },
        { name: "prev_staff_server", label: "Have you been staff on another Arma 3 server?", type: "yesno", required: true },
        { name: "difficult_player", label: "How would you handle a difficult player?", type: "textarea", required: true, rows: 4, placeholder: "Please provide a detailed answer…" },
        { name: "why", label: "Why do you want to join the staff team?", type: "textarea", required: true, rows: 4, placeholder: "Tell us why you want to join…" },
      ],
    },
  },
  {
    key: "general", label: "General Support", icon: "CircleHelp",
    desc: "Anything that doesn't fit the categories above.",
    form: { fields: [DESC] },
  },
];

export const TICKET_CAT = new Map(TICKET_CATEGORIES.map((c) => [c.key, c] as const));

export function ticketCat(key: string): TicketCategory {
  return TICKET_CAT.get(key) ?? { key, label: key, desc: "", icon: "CircleHelp", form: { fields: [{ name: "description", label: "Description", type: "textarea", required: true, rows: 6 }] } };
}
export function isValidCategory(key: string): boolean {
  return TICKET_CAT.has(key);
}
