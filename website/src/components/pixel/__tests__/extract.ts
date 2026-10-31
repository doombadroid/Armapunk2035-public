// Fidelity oracle extractor for the Armapunk Pixel client port.
//
// One extractor for both sides: it is run over the reference sources (the de-minified page,
// its shadcn wrappers) to build `reference/derived_*.json`, and over our port at test time.
// Classes = every string literal / template chunk in a class context (a `className`-suffixed JSX
// attribute or object key, or an argument of `cn(...)` / `cva(...)`). Strings = every other string
// literal, template chunk and JSX text (JSX whitespace rules applied), minus import sources,
// directives and TypeScript type positions.

import { parse } from "@babel/parser";

export interface Extracted {
  strings: Set<string>;
  classes: Set<string>;
}

interface Node {
  type: string;
  [key: string]: unknown;
}

function isNode(v: unknown): v is Node {
  return typeof v === "object" && v !== null && typeof (v as { type?: unknown }).type === "string";
}

// Babel's JSX text cleaning (what React receives as the child string).
export function cleanJsxText(raw: string): string {
  const lines = raw.split(/\r\n|\n|\r/);
  let lastNonEmpty = 0;
  for (let i = 0; i < lines.length; i++) if (/[^ \t]/.test(lines[i])) lastNonEmpty = i;
  let out = "";
  for (let i = 0; i < lines.length; i++) {
    const isFirst = i === 0,
      isLast = i === lines.length - 1,
      isLastNonEmpty = i === lastNonEmpty;
    let line = lines[i].replace(/\t/g, " ");
    if (!isFirst) line = line.replace(/^[ ]+/, "");
    if (!isLast) line = line.replace(/[ ]+$/, "");
    if (line) {
      if (!isLastNonEmpty) line += " ";
      out += line;
    }
  }
  return out;
}

const JSX_SCOPE = /\bjsx-[0-9a-f]{12,}\s*/g;

function calleeName(callee: unknown): string | null {
  if (!isNode(callee)) return null;
  if (callee.type === "Identifier") return callee.name as string;
  if (callee.type === "MemberExpression" && isNode(callee.property) && callee.property.type === "Identifier") return callee.property.name as string;
  if (callee.type === "SequenceExpression") {
    const exprs = callee.expressions as unknown[];
    return calleeName(exprs[exprs.length - 1]);
  }
  return null;
}

export function extractFromSource(code: string, filename: string): Extracted {
  const ast = parse(code, {
    sourceType: "module",
    plugins: ["jsx", "typescript"],
    sourceFilename: filename,
  });
  const strings = new Set<string>(),
    classes = new Set<string>();

  const add = (value: string, classCtx: boolean) => {
    if (classCtx) {
      const v = value.replace(JSX_SCOPE, "").trim();
      if (v) classes.add(v);
    } else if (value !== "") strings.add(value);
  };

  const walk = (node: unknown, parent: Node | null, key: string | null, classCtx: boolean) => {
    if (Array.isArray(node)) {
      for (const child of node) walk(child, parent, key, classCtx);
      return;
    }
    if (!isNode(node)) return;
    // TypeScript type positions carry no runtime strings.
    if (node.type.startsWith("TS")) return;
    if (node.type === "ImportDeclaration" || node.type === "ExportAllDeclaration") return;
    if (node.type === "ExportNamedDeclaration" && node.source) {
      walk(node.declaration, node, "declaration", classCtx);
      return;
    }
    let ctx = classCtx;
    if (node.type === "JSXAttribute" && isNode(node.name) && /className$/i.test(String(node.name.name))) ctx = true;
    if ((node.type === "ObjectProperty" || node.type === "Property") && !node.computed && isNode(node.key)) {
      const k = node.key.type === "Identifier" ? String(node.key.name) : node.key.type === "StringLiteral" ? String(node.key.value) : "";
      if (/className$/i.test(k)) ctx = true;
    }
    if (node.type === "CallExpression") {
      const name = calleeName(node.callee);
      if (name === "cn" || name === "cva") ctx = true;
    }
    switch (node.type) {
      case "StringLiteral": {
        if (parent && (parent.type === "ObjectProperty" || parent.type === "Property") && key === "key" && !parent.computed) return;
        add(String(node.value), ctx);
        return;
      }
      case "TemplateElement": {
        const cooked = (node.value as { cooked?: string | null }).cooked;
        if (typeof cooked === "string") add(cooked, ctx);
        return;
      }
      case "JSXText": {
        add(cleanJsxText(String(node.value)), false);
        return;
      }
      case "DirectiveLiteral":
        return;
    }
    for (const [k, v] of Object.entries(node)) {
      if (k === "loc" || k === "start" || k === "end" || k === "extra" || k === "leadingComments" || k === "trailingComments" || k === "innerComments") continue;
      walk(v, node, k, ctx);
    }
  };
  walk(ast.program, null, null, false);
  return { strings, classes };
}
