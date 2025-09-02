local T = import './test.libsonnet';
local re = import '../src/regex.libsonnet';

local blocks = {
  validate: [
    // expect: validity for this project's minimal engine
    // py_expect: validity for Python's enhanced regex engine
    { name: "validate: '+' unsupported",                 pattern: 'a+',      expect: false, py_expect: true },
    { name: "validate: '^' only at start",               pattern: 'a^b',     expect: false, py_expect: true },
    { name: "validate: '$' only at end",                 pattern: 'a$b',     expect: false, py_expect: true },
    { name: 'validate: unclosed class',                  pattern: '[abc',    expect: false, py_expect: false },
    { name: "validate: empty (?!...) not allowed",       pattern: '(?!)',    expect: false, py_expect: true },
    { name: "validate: meta inside (?!...) not allowed", pattern: '(?!a*b)', expect: false, py_expect: true },
    { name: "validate: lookbehind",                      pattern: '^first.*(?<!:third)$', expect: true, py_expect: true },
    { name: "validate: negative lookbehind literal",     pattern: '(?<!foo)', expect: true, py_expect: true },
    { name: "validate: positive lookbehind literal",     pattern: '(?<=foo)', expect: true, py_expect: true },
    { name: "validate: lookbehind with wildcard (py-only)", pattern: '(?<=a.c)', expect: false, py_expect: true },
    { name: "validate: negative lookahead with wildcard (py-only)", pattern: '(?!a.c)', expect: false, py_expect: true },
    { name: "validate: negative lookbehind with wildcard (py-only)", pattern: '(?<!a.c)', expect: false, py_expect: true },
    { name: "validate: positive lookahead (py-only)",    pattern: '(?=foo)', expect: false, py_expect: true },
    { name: "validate: lookbehind non-fixed (both invalid)", pattern: '(?<=a*b)', expect: false, py_expect: false },
    { name: "validate: lookbehind at end",               pattern: '^first.*(?<!:third)$', expect: true, py_expect: true },
    { name: "validate: valid simple",                    pattern: 'abc',      expect: true,  py_expect: true },
  ],
  match: [
    { name: 'match: simple contains',          pattern: 'abc',      subject: 'xxabcy', expect: true },
    { name: 'match: ^ at start true',          pattern: '^abc',     subject: 'abc',    expect: true },
    { name: 'match: ^ at start false',         pattern: '^abc',     subject: 'zabc',   expect: false },
    { name: 'match: ^...$ exact true',         pattern: '^abc$',    subject: 'abc',    expect: true },
    { name: 'match: ^...$ exact false',        pattern: '^abc$',    subject: 'abcc',   expect: false },
    { name: 'match: dot wildcard',             pattern: 'a.c',      subject: 'axc',    expect: true },
    { name: 'match: class include',            pattern: 'a[xyz]c',  subject: 'ayc',    expect: true },
    { name: 'match: class neg include',        pattern: 'a[^xyz]c', subject: 'aQc',    expect: true },
    { name: 'match: class neg exclude',        pattern: 'a[^xyz]c', subject: 'axc',    expect: false },
    { name: "match: '*' quantifier",           pattern: 'ab*c',     subject: 'abbbc',  expect: true },
    { name: "match: '?' present",              pattern: 'ab?c',     subject: 'abc',    expect: true },
    { name: "match: '?' absent",               pattern: 'ab?c',     subject: 'ac',     expect: true },
    { name: 'match: (?!foo) blocks at pos',    pattern: '^(?!foo)bar',         subject: 'foobar', expect: false },
    { name: 'match: (?!foo) allows later pos', pattern: '(?!foo)bar',          subject: 'xxbar',  expect: true },
    { name: 'match: (?<=) at start fails',     pattern: '(?<=foo)bar',          subject: 'bar',    expect: false },
    { name: 'match: (?<=) find preceded',      pattern: '(?<=foo)bar',          subject: 'xxfoobar', expect: true },
    { name: 'match: negative lookbehind excludes suffix', pattern: '^first.*(?<!:third)$', subject: 'first:second', expect: true },
    { name: 'match: negative lookbehind matches forbidden suffix', pattern: '^first.*(?<!:third)$',  subject: 'first:second:third',  expect: false },
  ],
};

{
  blocks: blocks,
  tests:
    [ T.truthy(v.name, re.validate(v.pattern).ok, re.validate(v.pattern)) for v in blocks.validate if v.expect ]
    + [ T.falsy(v.name, re.validate(v.pattern).ok, re.validate(v.pattern)) for v in blocks.validate if !v.expect ]
    + [
        (local val = re.validate(m.pattern);
         if val.ok then
           if m.expect then T.truthy(m.name, re.match(m.pattern, m.subject))
           else T.falsy(m.name, re.match(m.pattern, m.subject))
         else
           T.truthy(m.name, false, { err: 'Invalid pattern for minimal engine: ' + val.err })
        )
      for m in blocks.match
      ],
}
