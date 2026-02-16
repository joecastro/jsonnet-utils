local str = import './stringUtils.libsonnet';
local L(s) = std.length(s);
local containsAny(s, needles) = str.containsAny(s, needles);
local startsWithAt(s, si, needle) = str.startsWithAt(s, si, needle);
local ch(s, i) = s[i];

// Simple regex engine supporting a small subset of features.

// Supported tokens:
//   ^, $, ?, *, ., \d ([0-9]), \w ([A-Za-z0-9_]), [abc] (not ranges), [^abc], (?!literal), top-level a|b alternation
//
// Notes:
//   - Supports \d and \w escapes (including inside character classes).
//   - No +, no {m,n}, no capturing groups.
//   - (?!...) accepts literal text only (no meta, no nesting).
//   - '.' matches any single character (including newline).

/* ---------- Validation ---------- */
local isUnsupportedMeta(c) = c == '+' || c == '{' || c == '}';

// Find next ']' at or after index i (no nesting inside char class)
local findClassEnd(p, i) =
  local rel = std.findSubstr(']', p[i:]);
  if L(rel) == 0 then -1 else i + rel[0];

// Find next ')' at or after index i (no nested parens supported for lookahead)
local findParenClose(p, i) =
  local rel = std.findSubstr(')', p[i:]);
  if L(rel) == 0 then -1 else i + rel[0];

local isDigitChar(c) = std.member('0123456789', c);
local isWordChar(c) = std.member('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_', c);

local classContainsChar(contents, c) =
  local CL = L(contents);
  local loop(i) =
    if i >= CL then false
    else
      local cc = ch(contents, i);
      if cc == '\\' then
        if i + 1 >= CL then false
        else
          local esc = ch(contents, i + 1);
          if esc == 'd' then isDigitChar(c) || loop(i + 2)
          else if esc == 'w' then isWordChar(c) || loop(i + 2)
          else if esc == c then true
          else loop(i + 2)
      else if cc == c then true
      else loop(i + 1);
  loop(0);

/* ---------- Parse primitives ---------- */
// Character class: returns { ok, end, test(c) }
local parseClass(p, i) =
  local j = findClassEnd(p, i + 1);
  if j == -1 then { ok: false, end: -1, negate: false, contents: '', test: function(_) false }
  else
    local start = i + 1;
    local negate = ch(p, start) == '^';
    local contentsStart = if negate then start + 1 else start;
    local contents = p[contentsStart:j];
    {
      ok: L(contents) > 0,
      end: j,
      negate: negate,
      contents: contents,
      test: function(c)
        local hit = classContainsChar(contents, c);
        if negate then !hit else hit,
    };

// Negative lookahead (literal only): (?!literal) → { ok, end, lit }
local parseNegLookahead(p, pi) =
  if L(p) - pi >= 3 && std.startsWith(p[pi:], '(?!')
  then
    local close = findParenClose(p, pi + 3);
    if close == -1 then { ok: false, end: -1, lit: '' }
    else { ok: true, end: close, lit: p[pi + 3:close] }
  else { ok: false, end: -1, lit: '' };

// Negative lookbehind (literal only): (?<!literal) → { ok, end, lit }
local parseNegLookbehind(p, pi) =
  if L(p) - pi >= 4 && std.startsWith(p[pi:], '(?<!')
  then
    local close = findParenClose(p, pi + 4);
    if close == -1 then { ok: false, end: -1, lit: '' }
    else { ok: true, end: close, lit: p[pi + 4:close] }
  else { ok: false, end: -1, lit: '' };

// Positive lookbehind (literal only): (?<=literal) → { ok, end, lit }
local parsePosLookbehind(p, pi) =
  if L(p) - pi >= 4 && std.startsWith(p[pi:], '(?<=')
  then
    local close = findParenClose(p, pi + 4);
    if close == -1 then { ok: false, end: -1, lit: '' }
    else { ok: true, end: close, lit: p[pi + 4:close] }
  else { ok: false, end: -1, lit: '' };

// Split top-level alternation in a core pattern, ignoring pipes inside classes/lookarounds.
local splitTopLevelAlternatives(core) =
  local CL = L(core);
  local loop(i, start, parts) =
    if i >= CL then parts + [core[start:CL]]
    else if ch(core, i) == '[' then
      local j = findClassEnd(core, i + 1);
      if j == -1 then parts + [core[start:CL]] else loop(j + 1, start, parts)
    else
      local la = parseNegLookahead(core, i);
      if la.ok then loop(la.end + 1, start, parts)
      else
        local lb = parseNegLookbehind(core, i);
        if lb.ok then loop(lb.end + 1, start, parts)
        else
          local lbp = parsePosLookbehind(core, i);
          if lbp.ok then loop(lbp.end + 1, start, parts)
          else if ch(core, i) == '|' then loop(i + 1, i + 1, parts + [core[start:i]])
          else loop(i + 1, start, parts);
  loop(0, 0, []);

local validateClassContents(contents) =
  local CL = L(contents);
  local v(i) =
    if i >= CL then { ok: true, err: '' }
    else
      local c = ch(contents, i);
      if c != '\\' then v(i + 1)
      else if i + 1 >= CL then { ok: false, err: "Dangling escape '\\' in character class" }
      else
        local esc = ch(contents, i + 1);
        if esc == 'd' || esc == 'w' || esc == '\\' || esc == '[' || esc == ']' then v(i + 2)
        else { ok: false, err: "Unsupported escape '\\" + esc + "' in character class" };
  v(0);

/* ---------- Atom ops ---------- */
// Position after current atom
local nextAtomIndex(p, pi) =
  if ch(p, pi) == '[' then
    local cls = parseClass(p, pi);
    if !cls.ok then pi + 1 else cls.end + 1
  else if ch(p, pi) == '\\' then
    if pi + 1 < L(p) then pi + 2 else pi + 1
  else pi + 1;

// Match one atom at s[si] against p at pi → {consumed, ok}
local matchOne(p, pi, s, si) =
  if si >= L(s) then { consumed: 0, ok: false }
  else
    local pc = ch(p, pi);
    if pc == '[' then
      local cls = parseClass(p, pi);
      if !cls.ok then { consumed: 0, ok: false }
      else if cls.test(ch(s, si)) then { consumed: 1, ok: true } else { consumed: 0, ok: false }
    else if pc == '\\' then
      if pi + 1 >= L(p) then { consumed: 0, ok: false }
      else
        local esc = ch(p, pi + 1);
        if esc == 'd' then
          if isDigitChar(ch(s, si)) then { consumed: 1, ok: true } else { consumed: 0, ok: false }
        else if esc == 'w' then
          if isWordChar(ch(s, si)) then { consumed: 1, ok: true } else { consumed: 0, ok: false }
        else
          if esc == ch(s, si) then { consumed: 1, ok: true } else { consumed: 0, ok: false }
    else if pc == '.' then
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
        local behind = if start < 0 then '' else s[start:si];
        if behind == lb.lit then false
        else matchFrom(p, s, lb.end + 1, si, anchoredEnd)
      else
        // Positive lookbehind (zero-width, literal only)
        local lbp = parsePosLookbehind(p, pi);
        if lbp.ok then
          local Llit = L(lbp.lit);
          local start = si - Llit;
          local behind = if start < 0 then '' else s[start:si];
          if behind == lbp.lit then matchFrom(p, s, lbp.end + 1, si, anchoredEnd) else false
        else
          // Atom + optional quantifier
          local afterAtom = nextAtomIndex(p, pi);
          local hasQ = afterAtom < L(p) && (ch(p, afterAtom) == '*' || ch(p, afterAtom) == '?');
          local q = if hasQ then ch(p, afterAtom) else '';

          if !hasQ then
            local m = matchOne(p, pi, s, si);
            if m.ok then matchFrom(p, s, afterAtom, si + m.consumed, anchoredEnd) else false
          else if q == '?' then
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
  local anchoredStart = PL > 0 && ch(pattern, 0) == '^';
  local anchoredEnd = PL > 0 && ch(pattern, PL - 1) == '$';

  // strip anchors using slice syntax
  local coreStart = if anchoredStart then 1 else 0;
  local coreEnd = if anchoredEnd then PL - 1 else PL;
  local core = pattern[coreStart:coreEnd];
  local branches = splitTopLevelAlternatives(core);
  local matchBranch(branch) =
    if anchoredStart then
      matchFrom(branch, s, 0, 0, anchoredEnd)
    else
      // Try all candidate starts (0..L(s))
      std.any([matchFrom(branch, s, 0, i, anchoredEnd) for i in std.range(0, L(s))]);
  std.any([matchBranch(branch) for branch in branches]);

// validate a branch/core pattern without global anchors.
local validateCorePattern(core) =
  local CL = L(core);
  // recursive scan w/ state: (pi, prevCanQuantify, prevWasQuant)
  local v(pi, prevCanQuantify, prevWasQuant) =
    if pi >= CL then { ok: true, err: '' }
    else
      local c = ch(core, pi);
      if isUnsupportedMeta(c) then { ok: false, err: "Unsupported metacharacter '" + c + "'" }
      else if c == '^' then
        { ok: false, err: "Start anchor '^' must be at pattern start" }
      else if c == '$' then
        { ok: false, err: "End anchor '$' must be at pattern end" }
      else if c == '|' then
        { ok: false, err: "Alternation '|' is only supported at top level" }
      else if c == '?' || c == '*' then
        if !prevCanQuantify then { ok: false, err: "Quantifier '" + c + "' has no valid preceding atom" }
        else if prevWasQuant then { ok: false, err: 'Consecutive quantifiers not allowed' }
        else v(pi + 1, true, true)
      else if c == '[' then
        local cls = parseClass(core, pi);
        if !cls.ok then { ok: false, err: "Unclosed character class '['" }
        else
          local class_validation = validateClassContents(cls.contents);
          if !class_validation.ok then class_validation
          else v(cls.end + 1, true, false)
      else if c == '\\' then
        if pi + 1 >= CL then { ok: false, err: "Dangling escape '\\' at pattern end" }
        else
          local esc = ch(core, pi + 1);
          if esc == 'd' || esc == 'w' then v(pi + 2, true, false)
          else { ok: false, err: "Unsupported escape '\\" + esc + "'" }
      else if std.startsWith(core[pi:], '(?!') then
        local close = findParenClose(core, pi + 3);
        if close == -1 then { ok: false, err: 'Unclosed (?!...)' }
        else
          local lit = core[pi + 3:close];
          if L(lit) == 0 then { ok: false, err: "Empty negative lookahead '(?!)' not allowed" }
          else if containsAny(lit, ['[', ']', '(', ')', '?', '*', '^', '$', '.', '|']) then
            { ok: false, err: "Unsupported meta inside (?!...): '" + lit + "'" }
          else v(close + 1, false, false)
      else if std.startsWith(core[pi:], '(?<!') then
        local close = findParenClose(core, pi + 4);
        if close == -1 then { ok: false, err: 'Unclosed (?<!...)' }
        else
          local lit = core[pi + 4:close];
          if L(lit) == 0 then { ok: false, err: "Empty negative lookbehind '(?<! )' not allowed" }
          else if containsAny(lit, ['[', ']', '(', ')', '?', '*', '^', '$', '.', '|']) then
            { ok: false, err: "Unsupported meta inside (?<!...): '" + lit + "'" }
          else v(close + 1, false, false)
      else if std.startsWith(core[pi:], '(?<=') then
        local close = findParenClose(core, pi + 4);
        if close == -1 then { ok: false, err: 'Unclosed (?<=...)' }
        else
          local lit = core[pi + 4:close];
          if L(lit) == 0 then { ok: false, err: "Empty positive lookbehind '(?<= )' not allowed" }
          else if containsAny(lit, ['[', ']', '(', ')', '?', '*', '^', '$', '.', '|']) then
            { ok: false, err: "Unsupported meta inside (?<=...): '" + lit + "'" }
          else v(close + 1, false, false)
      else if c == ')' || c == ']' then
        { ok: false, err: "Unmatched '" + c + "'" }
      else
        // '.' wildcard and literals both OK as atoms
        v(pi + 1, true, false);
  v(0, false, false);

// Strict alternation guardrails so usage stays deterministic.
local alternationLeadSignature(branch) =
  local BL = L(branch);
  local loop(pi) =
    if pi >= BL then
      { ok: false, err: "Alternation branch cannot match empty string: '" + branch + "'" }
    else
      local la = parseNegLookahead(branch, pi);
      if la.ok then loop(la.end + 1)
      else
        local lb = parseNegLookbehind(branch, pi);
        if lb.ok then loop(lb.end + 1)
        else
          local lbp = parsePosLookbehind(branch, pi);
          if lbp.ok then loop(lbp.end + 1)
          else
            local c = ch(branch, pi);
            if c == '.' then
              { ok: false, err: "Alternation branch cannot start with wildcard '.': '" + branch + "'" }
            else if c == '[' then
              local cls = parseClass(branch, pi);
              if !cls.ok then { ok: false, err: "Unclosed character class '['" }
              else if cls.negate then
                { ok: false, err: "Alternation branch cannot start with negated class: '" + branch + "'" }
              else if containsAny(cls.contents, ['\\']) then
                { ok: false, err: "Alternation branch cannot start with escaped class token: '" + branch + "'" }
              else
                local after = cls.end + 1;
                local hasQ = after < BL && (ch(branch, after) == '*' || ch(branch, after) == '?');
                if hasQ then
                  { ok: false, err: "Alternation branch must start with a mandatory atom: '" + branch + "'" }
                else
                  { ok: true, sig: { chars: cls.contents } }
            else
              local after = pi + 1;
              local hasQ = after < BL && (ch(branch, after) == '*' || ch(branch, after) == '?');
              if hasQ then
                { ok: false, err: "Alternation branch must start with a mandatory atom: '" + branch + "'" }
              else
                { ok: true, sig: { chars: c } };
  loop(0);

local signaturesOverlap(sig1, sig2) =
  if L(sig1.chars) == 0 || L(sig2.chars) == 0 then false
  else std.any([std.member(sig2.chars, ch(sig1.chars, i)) for i in std.range(0, L(sig1.chars) - 1)]);

// validate(pattern) -> { ok, err }
local validate(pattern) =
  local P = pattern;
  local PL = L(P);
  local anchoredStart = PL > 0 && ch(P, 0) == '^';
  local anchoredEnd = PL > 0 && ch(P, PL - 1) == '$';
  local coreStart = if anchoredStart then 1 else 0;
  local coreEnd = if anchoredEnd then PL - 1 else PL;
  local core = P[coreStart:coreEnd];
  local branches = splitTopLevelAlternatives(core);
  local branchEmpty = [b for b in branches if b == ''];
  if L(branchEmpty) > 0 then
    { ok: false, err: "Alternation '|' cannot have empty branches" }
  else
    local branchValidity = [validateCorePattern(b) for b in branches];
    local invalidBranches = [r for r in branchValidity if !r.ok];
    if L(invalidBranches) > 0 then invalidBranches[0]
    else if L(branches) <= 1 then { ok: true, err: '' }
    else
      local leadSignatures = [alternationLeadSignature(b) for b in branches];
      local invalidLeads = [r for r in leadSignatures if !r.ok];
      if L(invalidLeads) > 0 then invalidLeads[0]
      else
        local sigs = [r.sig for r in leadSignatures];
        local hasOverlap(i, j) =
          if i >= L(sigs) - 1 then false
          else if j >= L(sigs) then hasOverlap(i + 1, i + 2)
          else if signaturesOverlap(sigs[i], sigs[j]) then true
          else hasOverlap(i, j + 1);
        if hasOverlap(0, 1) then
          { ok: false, err: 'Alternation branches have overlapping starting characters' }
        else
          { ok: true, err: '' };

local assertValid(pattern) =
  local res = validate(pattern);
  if res.ok then true else error res.err;

local match(pattern, s) = assertValid(pattern) && matchNoValidate(pattern, s);

{
  matchRegex:: match,
  validateRegex:: validate,
}
