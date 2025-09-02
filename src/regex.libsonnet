 
local L(s) = std.length(s);

local containsAny(s, chars) = std.any([std.member(s, c) for c in chars]);

// startsWith at arbitrary position, via findSubstr
local startsWithAt(s, si, needle) =
  if si < 0 || si > L(s) then false
  else std.startsWith(s[si:], needle);

local ch(s, i) = if i < L(s) then std.substr(s, i, 1) else null;

// Simple regex engine supporting a small subset of features.

// Supported tokens:
//   ^, $, ?, *, ., [abc], [^abc], (?!literal)
//
// Notes:
//   - No escaping, no alternation (|), no +, no {m,n}, no capturing groups.
//   - (?!...) accepts literal text only (no meta, no nesting).
//   - '.' matches any single character (including newline).

/* ---------- Validation ---------- */
local isUnsupportedMeta(c) = c == "+" || c == "{" || c == "}" || c == "|";

// Find next ']' at or after index i (no nesting inside char class)
local findClassEnd(p, i) =
    local rel = std.findSubstr("]", p[i:]);
    if std.length(rel) == 0 then -1 else i + rel[0];

// Find next ')' at or after index i (no nested parens supported for lookahead)
local findParenClose(p, i) =
  local rel = std.findSubstr(")", p[i:]);
  if std.length(rel) == 0 then -1 else i + rel[0];

/* ---------- Parse primitives ---------- */
// Character class: returns { ok, end, test(c) }
local parseClass(p, i) =
  local j = findClassEnd(p, i + 1);
  if j == -1 then { ok: false, end: -1, test: function(_) false }
  else
    local start = i + 1;
    local negate = ch(p, start) == "^";
    local contentsStart = if negate then start + 1 else start;
    local contents = p[contentsStart:j];
    {
      ok: L(contents) > 0,
      end: j,
      test: function(c)
        local hit = std.member(contents, c);
        if negate then !hit else hit,
    };

// Negative lookahead (literal only): (?!literal) → { ok, end, lit }
local parseNegLookahead(p, pi) =
  if L(p) - pi >= 3 && std.startsWith(p[pi:], "(?!")
  then
    local close = findParenClose(p, pi + 3);
    if close == -1 then { ok: false, end: -1, lit: "" }
    else { ok: true, end: close, lit: p[pi + 3:close] }
  else { ok: false, end: -1, lit: "" };

// Negative lookbehind (literal only): (?<!literal) → { ok, end, lit }
local parseNegLookbehind(p, pi) =
  if L(p) - pi >= 4 && std.startsWith(p[pi:], "(?<!")
  then
    local close = findParenClose(p, pi + 4);
    if close == -1 then { ok: false, end: -1, lit: "" }
    else { ok: true, end: close, lit: p[pi + 4:close] }
  else { ok: false, end: -1, lit: "" };

// Positive lookbehind (literal only): (?<=literal) → { ok, end, lit }
local parsePosLookbehind(p, pi) =
  if L(p) - pi >= 4 && std.startsWith(p[pi:], "(?<=")
  then
    local close = findParenClose(p, pi + 4);
    if close == -1 then { ok: false, end: -1, lit: "" }
    else { ok: true, end: close, lit: p[pi + 4:close] }
  else { ok: false, end: -1, lit: "" };

/* ---------- Atom ops ---------- */
// Position after current atom
local nextAtomIndex(p, pi) =
  if ch(p, pi) == "[" then
    local cls = parseClass(p, pi);
    if !cls.ok then pi + 1 else cls.end + 1
  else pi + 1;

// Match one atom at s[si] against p at pi → {consumed, ok}
local matchOne(p, pi, s, si) =
  if si >= L(s) then { consumed: 0, ok: false }
  else
    local pc = ch(p, pi);
    if pc == "[" then
      local cls = parseClass(p, pi);
      if !cls.ok then { consumed: 0, ok: false }
      else if cls.test(ch(s, si)) then { consumed: 1, ok: true } else { consumed: 0, ok: false }
    else if pc == "." then
      { consumed: 1, ok: true }  // wildcard
    else
      if pc == ch(s, si) then { consumed: 1, ok: true } else { consumed: 0, ok: false };

/* ---------- Core engine ---------- */
// Recursive: matchFrom(p, s, pi, si, anchoredEnd)
local matchFrom(p, s, pi, si, anchoredEnd) =
  if pi >= L(p) then
    (!anchoredEnd) || (si == L(s))
  else
    // Negative lookahead (zero-width, non-quantifiable)
    local la = parseNegLookahead(p, pi);
    if la.ok then
      if startsWithAt(s, si, la.lit) then false
      else matchFrom(p, s, la.end + 1, si, anchoredEnd)
    else
      // Negative lookbehind (zero-width, literal only)
      local lb = parseNegLookbehind(p, pi);
      if lb.ok then
        local Llit = L(lb.lit);
        local start = si - Llit;
        local behind = if start < 0 then "" else s[start:si];
        if behind == lb.lit then false
        else matchFrom(p, s, lb.end + 1, si, anchoredEnd)
      else
        // Positive lookbehind (zero-width, literal only)
        local lbp = parsePosLookbehind(p, pi);
        if lbp.ok then
          local Llit = L(lbp.lit);
          local start = si - Llit;
          local behind = if start < 0 then "" else s[start:si];
          if behind == lbp.lit then matchFrom(p, s, lbp.end + 1, si, anchoredEnd) else false
    else
      // Atom + optional quantifier
      local afterAtom = nextAtomIndex(p, pi);
      local hasQ = afterAtom < L(p) && (ch(p, afterAtom) == "*" || ch(p, afterAtom) == "?");
      local q = if hasQ then ch(p, afterAtom) else "";

      if !hasQ then
        local m = matchOne(p, pi, s, si);
        if m.ok then matchFrom(p, s, afterAtom, si + m.consumed, anchoredEnd) else false
      else if q == "?" then
        matchFrom(p, s, afterAtom + 1, si, anchoredEnd) ||
        (local m = matchOne(p, pi, s, si);
         if m.ok then matchFrom(p, s, afterAtom + 1, si + m.consumed, anchoredEnd) else false)
      else
        // '*' greedy with backtracking
        local eatMax(si0) =
          if si0 >= L(s) then si0
          else
            local m = matchOne(p, pi, s, si0);
            if m.ok then eatMax(si0 + m.consumed) else si0;

        local maxSi = eatMax(si);
        local tryFrom(k) =
          if k < si then false
          else matchFrom(p, s, afterAtom + 1, k, anchoredEnd) || tryFrom(k - 1);

        tryFrom(maxSi);

local matchNoValidate(pattern, s) =
  local PL = L(pattern);
  local anchoredStart = PL > 0 && ch(pattern, 0) == "^";
  local anchoredEnd   = PL > 0 && ch(pattern, PL - 1) == "$";

  // strip anchors using slice syntax
  local coreStart = if anchoredStart then 1 else 0;
  local coreEnd   = if anchoredEnd then PL - 1 else PL;
  local pat       = pattern[coreStart:coreEnd];

  if anchoredStart then
    matchFrom(pat, s, 0, 0, anchoredEnd)
  else
    // Try all candidate starts (0..L(s)-1)
    std.any([matchFrom(pat, s, 0, i, anchoredEnd) for i in std.range(0, L(s))]);

// validate(pattern) -> { ok, err }
local validate(pattern) =
  local P = pattern;
  local PL = L(P);

  // recursive scan w/ state: (pi, prevCanQuantify, prevWasQuant)
  local v(pi, prevCanQuantify, prevWasQuant) =
    if pi >= PL then { ok: true, err: "" }
    else
      local c = ch(P, pi);

      if isUnsupportedMeta(c) then { ok: false, err: "Unsupported metacharacter '" + c + "'" }
      else if c == "$" then
        if pi != PL - 1 then { ok: false, err: "End anchor '$' must be at pattern end" }
        else { ok: true, err: "" }
      else if c == "^" then
        if pi != 0 then { ok: false, err: "Start anchor '^' must be at pattern start" }
        else v(pi + 1, false, false)
      else if c == "?" || c == "*" then
        if !prevCanQuantify then { ok: false, err: "Quantifier '" + c + "' has no valid preceding atom" }
        else if prevWasQuant then { ok: false, err: "Consecutive quantifiers not allowed" }
        else v(pi + 1, true, true)
      else if c == "[" then
        local j = findClassEnd(P, pi + 1);
        if j == -1 then { ok: false, err: "Unclosed character class '['" }
        else
          local start = pi + 1;
          local negate = ch(P, start) == "^";
          local contentsStart = if negate then start + 1 else start;
          if j <= contentsStart then { ok: false, err: "Empty character class" }
          else v(j + 1, true, false)
      else if std.startsWith(P[pi:], "(?!") then
        local close = findParenClose(P, pi + 3);
        if close == -1 then { ok: false, err: "Unclosed (?!...)" }
        else
          local lit = P[pi + 3:close];
          if L(lit) == 0 then { ok: false, err: "Empty negative lookahead '(?!)' not allowed" }
          else if containsAny(lit, ["[", "]", "(", ")", "?", "*", "^", "$", "."]) then
            { ok: false, err: "Unsupported meta inside (?!...): '" + lit + "'" }
          else v(close + 1, false, false)
      else if std.startsWith(P[pi:], "(?<!") then
        local close = findParenClose(P, pi + 4);
        if close == -1 then { ok: false, err: "Unclosed (?<!...)" }
        else
          local lit = P[pi + 4:close];
          if L(lit) == 0 then { ok: false, err: "Empty negative lookbehind '(?<! )' not allowed" }
          else if containsAny(lit, ["[", "]", "(", ")", "?", "*", "^", "$", "."]) then
            { ok: false, err: "Unsupported meta inside (?<!...): '" + lit + "'" }
          else v(close + 1, false, false)
      else if std.startsWith(P[pi:], "(?<=") then
        local close = findParenClose(P, pi + 4);
        if close == -1 then { ok: false, err: "Unclosed (?<=...)" }
        else
          local lit = P[pi + 4:close];
          if L(lit) == 0 then { ok: false, err: "Empty positive lookbehind '(?<= )' not allowed" }
          else if containsAny(lit, ["[", "]", "(", ")", "?", "*", "^", "$", "."]) then
            { ok: false, err: "Unsupported meta inside (?<=...): '" + lit + "'" }
          else v(close + 1, false, false)
      else if c == ")" || c == "]" then
        { ok: false, err: "Unmatched '" + c + "'" }
      else
        // '.' wildcard and literals both OK as atoms
        v(pi + 1, true, false);

  v(0, false, false);

local assertValid(pattern) =
  local res = validate(pattern);
  if res.ok then true else error res.err;

local match(pattern, s) = assertValid(pattern) && matchNoValidate(pattern, s);

{
    match:: match,
    validate:: validate,
}
