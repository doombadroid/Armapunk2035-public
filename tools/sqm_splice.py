#!/usr/bin/env python3
"""Append generated layers to a plain-text mission.sqm without rewriting the original bytes.

The only sqm serialiser in this repo (sqm_strip_exported.py) writes the BINARIZED form, and the
shipped sqm is plain text by owner order. Writing a text serialiser would put the designer's
file -- thousands of hand-placed objects -- behind a new component whose failure mode is silent
corruption. Splicing avoids that entirely: the source is copied verbatim and generated layers are
appended, so a diff of the shipped file's own bytes is empty by construction.

Two traps, both handled by the scanner below:
  * Layers contain their own `class Entities`, so the ROOT one has to be found by structure,
    not by taking the first match.
  * Init strings contain braces (`s=""}"";`), so brace depth must be counted with string
    literals skipped -- and in a .sqm a quote is escaped by doubling it, not with a backslash.
"""
import re

import sqm_read


def _scan(text, start):
    """Walk from `start` (just past an opening brace) to its matching close. Returns that offset.

    String-aware: a quote toggles string state, and a doubled quote inside a string is a
    literal quote rather than a terminator.
    """
    depth, i, n = 1, start, len(text)
    while i < n:
        ch = text[i]
        if ch == '"':
            i += 1
            while i < n:
                if text[i] == '"':
                    if i + 1 < n and text[i + 1] == '"':
                        i += 2
                        continue
                    break
                i += 1
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced braces: no matching close brace")


def find_mission_entities(text):
    """(items_count, (start,end) of the root `items=N;`, offset to insert new items at)."""
    m = re.search(r"\bclass\s+Mission\s*\{", text)
    if not m:
        raise ValueError("no `class Mission` in this sqm")
    mission_end = _scan(text, m.end())

    # the first `class Entities` at mission level -- found by scanning forward from the Mission
    # brace and skipping any nested block, so a layer's Entities can never be mistaken for it
    i = m.end()
    while i < mission_end:
        em = re.compile(r"\bclass\s+(\w+)\s*\{").search(text, i)
        if not em or em.start() > mission_end:
            raise ValueError("no `class Entities` directly inside `class Mission`")
        body_end = _scan(text, em.end())
        if em.group(1) == "Entities":
            im = re.compile(r"\bitems\s*=\s*(\d+)\s*;").search(text, em.end(), body_end)
            if not im:
                raise ValueError("root Entities has no items= declaration")
            return int(im.group(1)), (im.start(), im.end()), body_end
        i = body_end + 1
    raise ValueError("no `class Entities` directly inside `class Mission`")


def item_id_provider(text):
    """(next free entity id, (start,end) span of its `nextID=N;` declaration).

    EditorData >> ItemIDProvider >> nextID is 3DEN's allocator for entity ids, and it is not
    decoration: every id in the file is below it, and generated entities numbered ABOVE it make
    3DEN reject the whole scenario on load ("error when loading"). There are several nextID
    declarations in a .sqm -- markers and layer indices have their own -- so this finds the entity
    one structurally rather than taking the first match.
    """
    m = re.search(r"\bclass\s+EditorData\s*\{", text)
    if not m:
        raise ValueError("no `class EditorData` in this sqm")
    ed_end = _scan(text, m.end())
    i = m.end()
    while i < ed_end:
        em = re.compile(r"\bclass\s+(\w+)\s*\{").search(text, i)
        if not em or em.start() > ed_end:
            break
        body_end = _scan(text, em.end())
        if em.group(1) == "ItemIDProvider":
            im = re.compile(r"\bnextID\s*=\s*(\d+)\s*;").search(text, em.end(), body_end)
            if not im:
                raise ValueError("ItemIDProvider has no nextID")
            return int(im.group(1)), (im.start(), im.end())
        i = body_end + 1
    raise ValueError("no `class ItemIDProvider` inside `class EditorData`")


def set_next_id(text, value):
    """Rewrite EditorData >> ItemIDProvider >> nextID. Do this BEFORE splicing, so the splice
    computes its own offsets against the final text."""
    _, span = item_id_provider(text)
    return text[:span[0]] + ("nextID=%d;" % value) + text[span[1]:]


def splice_layers(text, layer_blocks):
    """Insert `layer_blocks` as new root items and bump the root items count."""
    if not layer_blocks:
        return text
    count, span, insert_at = find_mission_entities(text)
    body = "".join(layer_blocks)
    out = text[:insert_at] + body + text[insert_at:]
    # bump the count last, so the offsets above stay valid while splicing
    new_span_start = span[0]
    out = out[:new_span_start] + ("items=%d;" % (count + len(layer_blocks))) + \
        out[new_span_start + (span[1] - span[0]):]
    # self-check: the result must still parse
    sqm_read._parse_text(out)
    return out
