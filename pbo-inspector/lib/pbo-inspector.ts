import { promises as fs } from "fs";
import path from "path";

const PBO_SCAN_LIMIT = 500;
const MAX_CONFIG_BYTES = 6 * 1024 * 1024;
const MAX_LISTED_FILES = 300;

export type PboFileEntry = {
  name: string;
  size: number;
  offset: number;
};

export type PboItem = {
  className: string;
  category: string;
  displayName?: string;
  model?: string;
  picture?: string;
  icon?: string;
  scope?: string;
};

export type PboSummary = {
  path: string;
  name: string;
  addon: string;
  size: number;
  fileCount: number;
  configType: "cpp" | "bin" | "none";
  itemCount: number;
  preview: string[];
  classes: PboItem[];
  files: PboFileEntry[];
  strings: string[];
  warnings: string[];
};

type RawEntry = PboFileEntry & {
  packingMethod: number;
  dataSize: number;
};

type ParsedPbo = {
  entries: RawEntry[];
  warnings: string[];
};

// Allowlist of directory roots the inspector may read from. Set on the server
// via PBO_ALLOWED_ROOTS (path.delimiter-separated). Defaults to a `pbos/` folder
// next to the running app. This is the security boundary that stops the
// ?source= param from reading arbitrary server files (mission PBO, addons, etc).
export function getAllowedRoots(): string[] {
  const fromEnv = (process.env.PBO_ALLOWED_ROOTS ?? "")
    .split(path.delimiter)
    .map((value) => value.trim())
    .filter(Boolean);

  const roots = fromEnv.length ? fromEnv : [path.join(process.cwd(), "pbos")];
  return roots.map((root) => path.resolve(root));
}

async function realOrResolved(target: string): Promise<string> {
  const resolved = path.resolve(target);
  try {
    return await fs.realpath(resolved);
  } catch {
    return resolved;
  }
}

function isInside(child: string, parent: string): boolean {
  const rel = path.relative(parent, child);
  return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

// Resolve symlinks on both sides, then confirm containment, so a symlink inside
// an allowed root cannot escape the boundary.
async function assertAllowed(source: string, allowedRoots: string[]): Promise<string> {
  const realSource = await realOrResolved(source);
  for (const root of allowedRoots) {
    const realRoot = await realOrResolved(root);
    if (isInside(realSource, realRoot)) return realSource;
  }
  throw new Error("That path is outside the allowed scan folders.");
}

export function getDefaultArmaPaths() {
  if (process.platform === "win32") {
    const programFilesX86 = process.env["ProgramFiles(x86)"] ?? "C:\\Program Files (x86)";
    const steamCommon = path.join(programFilesX86, "Steam", "steamapps", "common", "Arma 3");
    const steamWorkshop = path.join(programFilesX86, "Steam", "steamapps", "workshop", "content", "107410");

    return [
      path.join(steamCommon, "Addons"),
      steamWorkshop,
      path.join(process.env.USERPROFILE ?? "", "Documents", "Arma 3"),
      path.join(process.env.USERPROFILE ?? "", "Documents", "Arma 3 - Other Profiles")
    ].filter(Boolean);
  }

  // Linux / macOS (Steam native or Proton)
  const home = process.env.HOME ?? "";
  const steamRoots = [
    path.join(home, ".steam", "steam", "steamapps"),
    path.join(home, ".local", "share", "Steam", "steamapps"),
    path.join(home, "Library", "Application Support", "Steam", "steamapps")
  ];

  return steamRoots
    .flatMap((root) => [
      path.join(root, "common", "Arma 3", "Addons"),
      path.join(root, "workshop", "content", "107410")
    ])
    .filter(Boolean);
}

export async function inspectSource(sourcePath?: string): Promise<{
  sourcePath: string;
  defaultPaths: string[];
  pboFiles: PboSummary[];
  warnings: string[];
}> {
  const allowedRoots = getAllowedRoots();
  const defaultPaths = allowedRoots;
  const warnings: string[] = [];
  const found = new Set<string>();

  let roots: string[];
  if (sourcePath?.trim()) {
    // Throws if the requested path is outside the allowlist -> surfaced as a 500
    // with the message, never reads the file.
    roots = [await assertAllowed(sourcePath.trim(), allowedRoots)];
  } else {
    roots = allowedRoots;
  }

  for (const root of roots) {
    try {
      const stat = await fs.stat(root);
      if (stat.isFile() && root.toLowerCase().endsWith(".pbo")) {
        found.add(root);
      } else if (stat.isDirectory()) {
        for (const pbo of await findPboFiles(root, PBO_SCAN_LIMIT - found.size)) {
          found.add(pbo);
          if (found.size >= PBO_SCAN_LIMIT) break;
        }
      }
    } catch {
      warnings.push(`Could not read ${root}`);
    }

    if (found.size >= PBO_SCAN_LIMIT) {
      warnings.push(`Stopped after ${PBO_SCAN_LIMIT} PBO files to keep the scan responsive.`);
      break;
    }
  }

  const summaries = await Promise.all(
    [...found].map(async (filePath) => inspectPbo(filePath).catch((error: unknown) => ({
      path: filePath,
      name: path.basename(filePath),
      addon: path.basename(path.dirname(filePath)),
      size: 0,
      fileCount: 0,
      configType: "none" as const,
      itemCount: 0,
      preview: [],
      classes: [],
      files: [],
      strings: [],
      warnings: [error instanceof Error ? error.message : "Failed to inspect PBO"]
    })))
  );

  return {
    sourcePath: sourcePath?.trim() || "Default Arma 3 locations",
    defaultPaths,
    pboFiles: summaries.sort((a, b) => a.name.localeCompare(b.name)),
    warnings
  };
}

async function findPboFiles(root: string, limit: number): Promise<string[]> {
  if (limit <= 0) return [];
  const results: string[] = [];
  const queue = [root];

  while (queue.length && results.length < limit) {
    const current = queue.shift()!;
    let entries: import("fs").Dirent[];

    try {
      entries = await fs.readdir(current, { withFileTypes: true });
    } catch {
      continue;
    }

    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        queue.push(fullPath);
      } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".pbo")) {
        results.push(fullPath);
        if (results.length >= limit) break;
      }
    }
  }

  return results;
}

async function inspectPbo(filePath: string): Promise<PboSummary> {
  const buffer = await fs.readFile(filePath);
  const parsed = parsePbo(buffer);
  const config = parsed.entries.find((entry) => /(^|\\|\/)config\.(cpp|bin)$/i.test(entry.name));
  const fileEntries = parsed.entries
    .slice(0, MAX_LISTED_FILES)
    .map(({ name, size, offset }) => ({ name, size, offset }));

  let configType: PboSummary["configType"] = "none";
  let classes: PboItem[] = [];
  let strings: string[] = [];
  const warnings = [...parsed.warnings];

  if (config && config.dataSize <= MAX_CONFIG_BYTES) {
    const configBuffer = buffer.subarray(config.offset, config.offset + config.dataSize);
    if (config.name.toLowerCase().endsWith(".cpp")) {
      configType = "cpp";
      const parsedConfig = parseTextConfig(decodeText(configBuffer));
      classes = parsedConfig.classes;
      strings = parsedConfig.strings;
    } else {
      configType = "bin";
      strings = extractReadableStrings(configBuffer);
      classes = inferItemsFromStrings(strings);
      warnings.push("config.bin is binarized, so class details are inferred from readable strings.");
    }
  } else if (config) {
    warnings.push("Config file is too large to preview in the app.");
  }

  const preview = buildPreview(classes, strings, fileEntries);

  return {
    path: filePath,
    name: path.basename(filePath),
    addon: path.basename(path.dirname(filePath)),
    size: buffer.byteLength,
    fileCount: parsed.entries.length,
    configType,
    itemCount: classes.length,
    preview,
    classes: classes.slice(0, 250),
    files: fileEntries,
    strings: strings.slice(0, 250),
    warnings
  };
}

function parsePbo(buffer: Buffer): ParsedPbo {
  let cursor = 0;
  const warnings: string[] = [];
  const entries: Omit<RawEntry, "offset">[] = [];

  while (cursor < buffer.length) {
    const nameEnd = buffer.indexOf(0, cursor);
    if (nameEnd === -1) throw new Error("Invalid PBO header: missing file name terminator.");

    const name = buffer.toString("utf8", cursor, nameEnd).replaceAll("/", "\\");
    cursor = nameEnd + 1;
    if (cursor + 20 > buffer.length) throw new Error("Invalid PBO header: truncated entry.");

    const packingMethod = buffer.readUInt32LE(cursor);
    const originalSize = buffer.readUInt32LE(cursor + 4);
    const reserved = buffer.readUInt32LE(cursor + 8);
    const timestamp = buffer.readUInt32LE(cursor + 12);
    const dataSize = buffer.readUInt32LE(cursor + 16);
    cursor += 20;

    if (!name) {
      if (packingMethod === 0 && originalSize === 0 && reserved === 0 && timestamp === 0 && dataSize === 0) {
        break;
      }

      if (packingMethod === 0x56657273) {
        cursor = skipHeaderExtensions(buffer, cursor);
        continue;
      }

      warnings.push("Encountered an unknown PBO header extension.");
      continue;
    }

    entries.push({
      name,
      packingMethod,
      size: originalSize || dataSize,
      dataSize
    });
  }

  let dataOffset = cursor;
  const hydrated = entries.map((entry) => {
    const offset = dataOffset;
    dataOffset += entry.dataSize;
    return { ...entry, offset };
  });

  return { entries: hydrated, warnings };
}

function skipHeaderExtensions(buffer: Buffer, cursor: number) {
  while (cursor < buffer.length) {
    const end = buffer.indexOf(0, cursor);
    if (end === -1) return cursor;
    if (end === cursor) return cursor + 1;
    cursor = end + 1;
  }

  return cursor;
}

function parseTextConfig(text: string) {
  const classes: PboItem[] = [];
  const strings = extractReadableStrings(Buffer.from(text)).slice(0, 400);
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  const stack: PboItem[] = [];
  let pendingClass: string | null = null;
  let currentCategory = "Config";

  for (const rawLine of lines) {
    const line = rawLine.replace(/\/\/.*$/, "").trim();
    if (!line) continue;

    const classMatch = line.match(/^class\s+([A-Za-z0-9_]+)/);
    if (classMatch) {
      pendingClass = classMatch[1];
      if (/^Cfg[A-Za-z0-9_]+$/.test(pendingClass)) {
        currentCategory = pendingClass;
      }
    }

    if (line.includes("{")) {
      if (pendingClass) {
        stack.push({ className: pendingClass, category: currentCategory });
        pendingClass = null;
      }
      continue;
    }

    const active = stack.at(-1);
    if (active) {
      assignConfigProperty(active, line);
    }

    if (line.includes("}")) {
      const closed = stack.pop();
      if (closed && shouldShowClass(closed)) {
        classes.push(closed);
      }
    }
  }

  return { classes: classes.slice(0, 500), strings };
}

function assignConfigProperty(item: PboItem, line: string) {
  const property = line.match(/^([A-Za-z0-9_]+)\s*=\s*(.+?);?$/);
  if (!property) return;

  const key = property[1];
  const value = normalizeConfigValue(property[2]);

  if (key === "displayName" || key === "displayNameShort") item.displayName ??= value;
  if (key === "model") item.model = value;
  if (key === "picture") item.picture = value;
  if (key === "icon") item.icon = value;
  if (key === "scope") item.scope = value;
}

function normalizeConfigValue(value: string) {
  return value
    .replace(/^"/, "")
    .replace(/";?$/, "")
    .replaceAll("\\\\", "\\")
    .trim();
}

function shouldShowClass(item: PboItem) {
  const usefulCategories = new Set(["CfgWeapons", "CfgVehicles", "CfgMagazines", "CfgGlasses"]);
  return Boolean(item.displayName || item.model || item.picture || usefulCategories.has(item.category));
}

function inferItemsFromStrings(strings: string[]): PboItem[] {
  const ignored = new Set(["class", "scope", "model", "picture", "displayName", "CfgPatches"]);
  return strings
    .filter((value) => /^[A-Za-z][A-Za-z0-9_]{2,}$/.test(value))
    .filter((value) => !ignored.has(value))
    .slice(0, 120)
    .map((className) => ({ className, category: "Inferred" }));
}

function buildPreview(classes: PboItem[], strings: string[], files: PboFileEntry[]) {
  const names = classes
    .map((item) => item.displayName || item.className)
    .filter(Boolean);

  if (names.length) return unique(names).slice(0, 6);

  const stringNames = strings.filter((value) => value.length > 3 && !value.includes("\\"));
  if (stringNames.length) return unique(stringNames).slice(0, 6);

  return files.map((file) => file.name).slice(0, 6);
}

function extractReadableStrings(buffer: Buffer) {
  const values: string[] = [];
  let current = "";

  for (const byte of buffer) {
    if (byte >= 32 && byte <= 126) {
      current += String.fromCharCode(byte);
    } else {
      if (current.length >= 3) values.push(current);
      current = "";
    }
  }

  if (current.length >= 3) values.push(current);
  return unique(values.map((value) => value.trim()).filter(Boolean));
}

function decodeText(buffer: Buffer) {
  return buffer.toString("utf8").replace(/\u0000/g, "");
}

function unique(values: string[]) {
  return [...new Set(values)];
}
