local re = import '../src/regex.libsonnet';
local T = import './test.libsonnet';

local blocks = {
  validate: [
    // expect: validity for this project's minimal engine
    // py_expect: validity for Python's enhanced regex engine
    { name: "validate: '+' unsupported", pattern: 'a+', expect: false, py_expect: true },
    { name: "validate: '^' only at start", pattern: 'a^b', expect: false, py_expect: true },
    { name: "validate: '$' only at end", pattern: 'a$b', expect: false, py_expect: true },
    { name: 'validate: unclosed class', pattern: '[abc', expect: false, py_expect: false },
    { name: 'validate: empty (?!...) not allowed', pattern: '(?!)', expect: false, py_expect: true },
    { name: 'validate: meta inside (?!...) not allowed', pattern: '(?!a*b)', expect: false, py_expect: true },
    { name: 'validate: lookbehind', pattern: '^first.*(?<!:third)$', expect: true, py_expect: true },
    { name: 'validate: negative lookbehind literal', pattern: '(?<!foo)', expect: true, py_expect: true },
    { name: 'validate: positive lookbehind literal', pattern: '(?<=foo)', expect: true, py_expect: true },
    { name: 'validate: lookbehind with wildcard (py-only)', pattern: '(?<=a.c)', expect: false, py_expect: true },
    { name: 'validate: negative lookahead with wildcard (py-only)', pattern: '(?!a.c)', expect: false, py_expect: true },
    { name: 'validate: negative lookbehind with wildcard (py-only)', pattern: '(?<!a.c)', expect: false, py_expect: true },
    { name: 'validate: positive lookahead (py-only)', pattern: '(?=foo)', expect: false, py_expect: true },
    { name: 'validate: lookbehind non-fixed (both invalid)', pattern: '(?<=a*b)', expect: false, py_expect: false },
    { name: 'validate: lookbehind at end', pattern: '^first.*(?<!:third)$', expect: true, py_expect: true },
    { name: 'validate: valid simple', pattern: 'abc', expect: true, py_expect: true },
    { name: 'validate: alternation top-level literal', pattern: 'cat|dog', expect: true, py_expect: true },
    { name: 'validate: alternation with lookbehind', pattern: '(?<=x)foo|bar', expect: true, py_expect: true },
    { name: 'validate: alternation empty branch', pattern: 'a|', expect: false, py_expect: true },
    { name: 'validate: alternation overlapping starts', pattern: 'cat|cow', expect: false, py_expect: true },
    { name: 'validate: alternation optional start', pattern: 'a?|bc', expect: false, py_expect: true },
    { name: 'validate: alternation wildcard start', pattern: '.a|bc', expect: false, py_expect: true },
    { name: 'validate: alternation negated class start', pattern: '[^ab]c|de', expect: false, py_expect: true },
    { name: 'validate: escape digit token', pattern: '^\\d\\d$', expect: true, py_expect: true },
    { name: 'validate: escape word token', pattern: '^\\w\\w$', expect: true, py_expect: true },
    { name: 'validate: unsupported escape', pattern: '^\\s+$', expect: false, py_expect: true },
    { name: 'validate: class with digit token', pattern: '^[\\d][\\d]$', expect: true, py_expect: true },
    { name: 'validate: class with word token', pattern: '^[\\w][\\w]$', expect: true, py_expect: true },
    { name: 'validate: class unsupported escape', pattern: '^[\\q]$', expect: false, py_expect: false },
  ],
  match: [
    { name: 'match: simple contains', pattern: 'abc', subject: 'xxabcy', expect: true },
    { name: 'match: ^ at start true', pattern: '^abc', subject: 'abc', expect: true },
    { name: 'match: ^ at start false', pattern: '^abc', subject: 'zabc', expect: false },
    { name: 'match: ^...$ exact true', pattern: '^abc$', subject: 'abc', expect: true },
    { name: 'match: ^...$ exact false', pattern: '^abc$', subject: 'abcc', expect: false },
    { name: 'match: dot wildcard', pattern: 'a.c', subject: 'axc', expect: true },
    { name: 'match: class include', pattern: 'a[xyz]c', subject: 'ayc', expect: true },
    { name: 'match: class neg include', pattern: 'a[^xyz]c', subject: 'aQc', expect: true },
    { name: 'match: class neg exclude', pattern: 'a[^xyz]c', subject: 'axc', expect: false },
    { name: "match: '*' quantifier", pattern: 'ab*c', subject: 'abbbc', expect: true },
    { name: "match: '?' present", pattern: 'ab?c', subject: 'abc', expect: true },
    { name: "match: '?' absent", pattern: 'ab?c', subject: 'ac', expect: true },
    { name: 'match: (?!foo) blocks at pos', pattern: '^(?!foo)bar', subject: 'foobar', expect: false },
    { name: 'match: (?!foo) allows later pos', pattern: '(?!foo)bar', subject: 'xxbar', expect: true },
    { name: 'match: (?<=) at start fails', pattern: '(?<=foo)bar', subject: 'bar', expect: false },
    { name: 'match: (?<=) find preceded', pattern: '(?<=foo)bar', subject: 'xxfoobar', expect: true },
    { name: 'match: negative lookbehind excludes suffix', pattern: '^first.*(?<!:third)$', subject: 'first:second', expect: true },
    { name: 'match: negative lookbehind matches forbidden suffix', pattern: '^first.*(?<!:third)$', subject: 'first:second:third', expect: false },
    { name: 'match: negative lookbehind at end', pattern: '^first:second:', subject: 'first:second:third', expect: true },
    { name: 'match: alternation literal branch', pattern: 'cat|dog', subject: 'xxdog', expect: true },
    { name: 'match: alternation no branch match', pattern: 'cat|dog', subject: 'xxpig', expect: false },
    { name: 'match: alternation with lookbehind branch', pattern: '(?<=x)foo|bar', subject: 'zxfoo', expect: true },
    { name: 'match: digit escape token', pattern: '^\\d\\d$', subject: '42', expect: true },
    { name: 'match: digit escape token false', pattern: '^\\d\\d$', subject: '4a', expect: false },
    { name: 'match: word escape token underscore', pattern: '^\\w\\w$', subject: 'a_', expect: true },
    { name: 'match: class digit token', pattern: '^[\\d][\\d]$', subject: '09', expect: true },
    { name: 'match: class word token', pattern: '^[\\w][\\w]$', subject: '_Z', expect: true },
  ],
};

{
  blocks: blocks,
  suites: [
    T.suite(
      'validate',
      [T.truthy(v.name, re.validateRegex(v.pattern).ok, re.validateRegex(v.pattern)) for v in blocks.validate if v.expect]
      + [T.falsy(v.name, re.validateRegex(v.pattern).ok, re.validateRegex(v.pattern)) for v in blocks.validate if !v.expect]
    ),

    T.suite(
      'match',
      [
        (
          local val = re.validateRegex(m.pattern);
          if val.ok then
            if m.expect then T.truthy(m.name, re.matchRegex(m.pattern, m.subject))
            else T.falsy(m.name, re.matchRegex(m.pattern, m.subject))
          else
            T.truthy(m.name, false, { err: 'Invalid pattern for minimal engine: ' + val.err })
        )
        for m in blocks.match
      ]
    ),
  ],
}
