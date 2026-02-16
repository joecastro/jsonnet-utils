local L(s) = std.length(s);

{
  containsAny(s, needles)::
    L([needle for needle in needles if L(std.findSubstr(needle, s)) > 0]) > 0,

  firstChar(s):: if L(s) == 0 then '' else s[0],

  startsWithAt(s, si, needle)::
    if si < 0 || si > L(s) then false
    else std.startsWith(s[si:], needle),

  splitAny(s, delimiters)::
    assert std.isString(s);
    assert std.isArray(delimiters);
    if L(s) == 0 then []
    else
      local delimiterSet = { [d]: true for d in delimiters if d != '' };
      local addPiece(parts, piece) = if piece == '' then parts else parts + [piece];
      local loop(i, current, parts) =
        if i >= L(s) then addPiece(parts, current)
        else
          local ch = s[i];
          if std.objectHas(delimiterSet, ch) then
            loop(i + 1, '', addPiece(parts, current))
          else
            loop(i + 1, current + ch, parts);
      loop(0, '', []),

  capitalizeWord(w)::
    if L(w) == 0 then '' else std.asciiUpper(w[0:1]) + std.asciiLower(w[1:]),

  splitWords(s):: std.split(std.strReplace(std.strReplace(s, '-', ' '), '_', ' '), ' '),

  pascalCase(s):: std.join('', [self.capitalizeWord(w) for w in self.splitWords(s)]),

  camelCase(s)::
    local words = self.splitWords(s);
    if L(words) == 0 then ''
    else std.asciiLower(words[0]) + std.join('', [self.capitalizeWord(w) for w in words[1:]]),

  kebobCase(s):: std.join('-', [std.asciiLower(w) for w in self.splitWords(s) if w != '']),

  titleCase(s):: std.join(' ', [self.capitalizeWord(w) for w in std.split(s, ' ')]),
}
