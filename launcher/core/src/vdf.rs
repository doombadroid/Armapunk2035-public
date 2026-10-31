//! Steam KeyValues (text VDF) parser that keeps byte spans, so callers can
//! edit one value in place without reformatting the rest of the file.

use anyhow::{bail, Result};

#[derive(Debug, Clone)]
pub enum Value {
    Str { text: String, span: (usize, usize) },
    Obj { children: Vec<Node>, open: usize, close: usize },
}

#[derive(Debug, Clone)]
pub struct Node { pub key: String, pub key_span: (usize, usize), pub value: Value }

impl Node {
    pub fn child(&self, key: &str) -> Option<&Node> {
        match &self.value {
            Value::Obj { children, .. } => children.iter().find(|c| c.key.eq_ignore_ascii_case(key)),
            _ => None,
        }
    }
    pub fn path(&self, keys: &[&str]) -> Option<&Node> {
        let mut n = self;
        for k in keys { n = n.child(k)?; }
        Some(n)
    }
    pub fn str(&self) -> Option<&str> { if let Value::Str { text, .. } = &self.value { Some(text) } else { None } }
}

pub fn quote(s: &str) -> String { format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\"")) }

enum Tok { Str(String, usize, usize), Open(usize), Close(usize) }

fn lex(t: &str) -> Result<Vec<Tok>> {
    let b = t.as_bytes();
    let (mut i, mut out) = (0usize, Vec::new());
    while i < b.len() {
        match b[i] {
            b' ' | b'\t' | b'\r' | b'\n' => i += 1,
            b'/' if b.get(i + 1) == Some(&b'/') => { while i < b.len() && b[i] != b'\n' { i += 1; } }
            b'{' => { out.push(Tok::Open(i)); i += 1; }
            b'}' => { out.push(Tok::Close(i)); i += 1; }
            b'"' => {
                let start = i;
                i += 1;
                let mut s = String::new();
                loop {
                    if i >= b.len() { bail!("unterminated string at byte {start}"); }
                    match b[i] {
                        b'\\' if i + 1 < b.len() => {
                            match b[i + 1] { b'n' => s.push('\n'), b't' => s.push('\t'), c => s.push(c as char) }
                            i += 2;
                        }
                        b'"' => { i += 1; break; }
                        _ => {
                            let ch = t[i..].chars().next().unwrap();
                            s.push(ch);
                            i += ch.len_utf8();
                        }
                    }
                }
                out.push(Tok::Str(s, start, i));
            }
            _ => bail!("unexpected byte {:?} at {i}", b[i] as char),
        }
    }
    Ok(out)
}

fn items(toks: &[Tok], pos: &mut usize, closing: bool) -> Result<(Vec<Node>, Option<usize>)> {
    let mut out = Vec::new();
    while *pos < toks.len() {
        match &toks[*pos] {
            Tok::Close(at) => { if !closing { bail!("unexpected '}}' at {at}"); } *pos += 1; return Ok((out, Some(*at))); }
            Tok::Open(at) => bail!("'{{' without key at {at}"),
            Tok::Str(k, ks, ke) => {
                let (key, key_span) = (k.clone(), (*ks, *ke));
                *pos += 1;
                let value = match toks.get(*pos) {
                    Some(Tok::Str(v, vs, ve)) => { *pos += 1; Value::Str { text: v.clone(), span: (*vs, *ve) } }
                    Some(Tok::Open(o)) => {
                        let open = *o;
                        *pos += 1;
                        let (children, close) = items(toks, pos, true)?;
                        Value::Obj { children, open, close: close.unwrap() }
                    }
                    _ => bail!("key {key:?} has no value"),
                };
                out.push(Node { key, key_span, value });
            }
        }
    }
    if closing { bail!("missing '}}'"); }
    Ok((out, None))
}

/// Parses a whole file into a synthetic root node (key "", object spanning the file).
pub fn parse(text: &str) -> Result<Node> {
    let toks = lex(text)?;
    let mut pos = 0;
    let (children, _) = items(&toks, &mut pos, false)?;
    Ok(Node { key: String::new(), key_span: (0, 0), value: Value::Obj { children, open: 0, close: text.len() } })
}

#[cfg(test)]
mod tests {
    use super::*;
    const SAMPLE: &str = "\"Root\"\n{\n\t\"Apps\"\n\t{\n\t\t\"107410\"\n\t\t{\n\t\t\t\"LaunchOptions\"\t\t\"a \\\"q\\\" %command%\"\n\t\t}\n\t}\n\t\"x\"\t\"1\"\n}\n";

    #[test]
    fn finds_nested_value_case_insensitive_with_spans() {
        let root = parse(SAMPLE).unwrap();
        let lo = root.path(&["root", "apps", "107410", "launchoptions"]).unwrap();
        match &lo.value {
            Value::Str { text, span } => {
                assert_eq!(text, "a \"q\" %command%");
                assert_eq!(&SAMPLE[span.0..span.1], "\"a \\\"q\\\" %command%\"");
            }
            _ => panic!("expected string"),
        }
        let app = root.path(&["Root", "Apps", "107410"]).unwrap();
        match &app.value { Value::Obj { close, .. } => assert_eq!(&SAMPLE[*close..*close + 1], "}"), _ => panic!() }
    }

    #[test]
    fn quote_escapes() { assert_eq!(quote("a\"b\\c"), "\"a\\\"b\\\\c\""); }

    #[test]
    fn rejects_unbalanced() { assert!(parse("\"a\" { \"b\" \"c\"").is_err()); }
}
