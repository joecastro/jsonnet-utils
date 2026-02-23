// Useful functions beyond the standard standard library.
local re = import './regex.libsonnet';
local str = import './stringUtils.libsonnet';

local L = std.length;
local containsAny = str.containsAny;
local firstChar = str.firstChar;

local indexOf(arr, elem) =
  assert std.type(arr) == 'array' : 'indexOf expects first argument to be an array';
  local find_results = std.find(elem, arr);
  if L(find_results) == 0 then -1 else find_results[0];

local objectFromArrays(keys, values) = {
  [keys[i]]: values[i]
  for i in std.range(0, L(keys) - 1)
};

local firstNonEmpty(arr, defaultValue=null) =
  local nonEmpty = [x for x in arr if x != null && x != '' && x != [] && x != {}];
  if L(nonEmpty) == 0 then defaultValue else nonEmpty[0];

local isStringBooleanLike(s) =
  local boolean_like_strings = [
    'y',
    'yes',
    'n',
    'no',
    'true',
    'false',
    'on',
    'off',
  ];
  indexOf(boolean_like_strings, s) != -1;

local isStringNullLike(s) =
  local null_like_strings = ['null', '~'];
  indexOf(null_like_strings, s) != -1;

local isStringNumberLike(s) =
  local isCharIn(haystack, c) = L(std.findSubstr(c, haystack)) > 0;
  local second = if L(s) > 1 then s[1] else '';
  isCharIn('0123456789', firstChar(s)) ||
  (isCharIn('+-.', firstChar(s)) && isCharIn('0123456789', second));

local isYamlImplicitScalarLike(s) =
  isStringBooleanLike(s) ||
  isStringNullLike(s) ||
  isStringNumberLike(s);

local findFirstSubstr(needle, haystack) =
  local hits = std.findSubstr(needle, haystack);
  if L(hits) == 0 then -1 else hits[0];

local hasSubstr(needle, haystack) = findFirstSubstr(needle, haystack) != -1;

// Copied from jsonnet std library. Added optional formatting and key ordering params.
local default_json_key_order = [
  'version',
  'name',
  'id',
  'displayName',
  'private',
  'type',
  'engines',
  'packageManager',
  'scripts',
  'scripts-info',
  'devDependencies',
  'dependencies',
  'description',
  'main',
  'homepage',
  'author',
  'license',
  'repository',
];

local defaultJsonKeySorter(key) =
  local index = indexOf(default_json_key_order, key);
  if index != -1 then '%03d' % index + key else '999' + key;

local default_yaml_top_level_key_order = ['name', 'on'];

local manifestJsonEx(
  value,
  indent='  ',
  newline='\n',
  key_val_sep=': ',
  key_sort_func=defaultJsonKeySorter
      ) =
  local aux(v, path, cindent) =
    if v == true then
      'true'
    else if v == false then
      'false'
    else if v == null then
      'null'
    else if std.isNumber(v) then
      '' + v
    else if std.isString(v) then
      std.escapeStringJson(v)
    else if std.isFunction(v) then
      error 'Tried to manifest function at ' + path
    else if std.isArray(v) then
      local range = std.range(0, L(v) - 1);
      local new_indent = cindent + indent;
      local lines = ['[' + newline]
                    + std.join(
                      [',' + newline],
                      [[new_indent + aux(v[i], path + [i], new_indent)] for i in range]
                    )
                    + [newline + cindent + ']'];
      std.join('', lines)
    else if std.isObject(v) then
      local lines = ['{' + newline]
                    + std.join([',' + newline],
                               [
                                 [cindent + indent + std.escapeStringJson(k) + key_val_sep
                                  + aux(v[k], path + [k], cindent + indent)]
                                 for k in std.sort(std.objectFields(v), key_sort_func)
                               ])
                    + [newline + cindent + '}'];
      std.join('', lines);
  aux(value, [], '');

local propertyValueOf(v) =
  if v == null then
    ''
  else if std.isBoolean(v) then
    '%s' % v
  else if std.isNumber(v) then
    '' + v
  else if std.isString(v) then
    std.strReplace(v, '\n', '\\\n')
  else
    error 'Unsupported value type';

local manifestProperties(value, key_sort_func=null) =
  assert std.isObject(value);
  local keys = std.objectFields(value);
  local ordered = if key_sort_func == null then std.sort(keys) else std.sort(keys, key_sort_func);
  std.join('\n', ['%s=%s' % [k, propertyValueOf(value[k])] for k in ordered]);

// "Safe to unquote" check for YAML plain scalars.
// We avoid YAML-significant starts/separators and common implicit scalar values
// and block-list some sequences.
local yamlIsSafePlainScalar(s) =
  s != '' &&
  !isYamlImplicitScalarLike(s) &&
  !std.member('*,?@>|-&#!`{}[]*', s[0]) &&
  !hasSubstr('\\', s) &&
  !hasSubstr(': ', s) &&
  !hasSubstr(' #', s) &&
  !std.member(' :', s[L(s) - 1]);

local yamlParseQuotedValueLine(line) =
  if !std.endsWith(line, '"') then null
  else
    local scalar_split_index = findFirstSubstr(': "', line);
    if scalar_split_index != -1 && L(line) > scalar_split_index + 3 then
      local prefix = std.substr(line, 0, scalar_split_index + 2);
      local value = std.substr(line, scalar_split_index + 3, L(line) - scalar_split_index - 4);
      {
        prefix: prefix,
        quotedValue: value,
      }
    else
      local list_split_index = findFirstSubstr('- "', line);
      if list_split_index != -1 && L(line) > list_split_index + 3 then
        local prefix = std.substr(line, 0, list_split_index + 2);
        local value = std.substr(line, list_split_index + 3, L(line) - list_split_index - 4);
        {
          prefix: prefix,
          quotedValue: value,
        }
      else null;

local yamlUnquoteSafeStrings(lines) =
  [
    local parsed_line = yamlParseQuotedValueLine(line);
    if parsed_line == null then line
    else if yamlIsSafePlainScalar(parsed_line.quotedValue)
    then parsed_line.prefix + parsed_line.quotedValue
    else line
    for line in lines
  ];

local yamlNormalizeSimpleLine(
  line,
  normalize_top_level_on_key=true,
  compact_null_values=true
      ) =
  local line0 =
    if normalize_top_level_on_key && std.startsWith(line, '"on":')
    then 'on:' + std.substr(line, 5, L(line) - 5)
    else line;
  local line1 = if compact_null_values && std.endsWith(line0, ': null')
  then std.substr(line0, 0, L(line0) - 5)
  else line0;
  line1;

local manifestYamlDocLines(
  value,
  top_level_key_order=default_yaml_top_level_key_order,
  normalize_top_level_on_key=true,
  compact_null_values=true
      ) =
  assert std.type(value) == 'object' : 'manifestYamlDocLines value must be an object';
  assert top_level_key_order != null : 'manifestYamlDocLines top_level_key_order must not be null';
  local prioritized_keys = [k for k in top_level_key_order if std.objectHas(value, k)];
  local remaining_keys = [k for k in std.objectFields(value) if indexOf(prioritized_keys, k) == -1];
  local ordered_keys = prioritized_keys + remaining_keys;
  local raw_section_lines = [
    local section_lines = std.split(std.manifestYamlDoc({ [k]: value[k] }, quote_keys=false), '\n');
    [
      yamlNormalizeSimpleLine(
        line,
        normalize_top_level_on_key=normalize_top_level_on_key,
        compact_null_values=compact_null_values
      )
      for line in section_lines
    ] + ['']
    for k in ordered_keys
  ];
  local flattened = std.flattenArrays(raw_section_lines);
  std.slice(flattened, 0, L(flattened) - 1, 1);

local manifest_yaml_profiles = {
  default: {
    unquote_safe_strings: true,
    top_level_key_order: default_yaml_top_level_key_order,
    normalize_top_level_on_key: true,
    compact_null_values: true,
  },
  pretty: {},
  fast: {
    unquote_safe_strings: false,
    top_level_key_order: [],
  },
};

local manifestYamlEx(value, options='default') =
  local opts =
    if std.type(options) == 'string' then
      if std.objectHas(manifest_yaml_profiles, options)
      then manifest_yaml_profiles.default + manifest_yaml_profiles[options]
      else error
        'Unknown manifestYamlEx profile: ' + options +
        '. Available profiles: ' + std.join(', ', std.objectFields(manifest_yaml_profiles))
    else if std.type(options) == 'object'
    then manifest_yaml_profiles.default + options
    else error 'manifestYamlEx options must be an object or profile string';
  local lines0 = manifestYamlDocLines(
    value,
    top_level_key_order=opts.top_level_key_order,
    normalize_top_level_on_key=opts.normalize_top_level_on_key,
    compact_null_values=opts.compact_null_values
  );
  local lines1 = if opts.unquote_safe_strings
  then yamlUnquoteSafeStrings(lines0)
  else lines0;
  std.join('\n', lines1);

str + re + {
  _yamlUnquoteSafeStrings: yamlUnquoteSafeStrings,
  _manifestYamlDocLines: manifestYamlDocLines,
  indexOf: indexOf,
  manifestProperties: manifestProperties,
  manifestJson: manifestJsonEx,
  manifestJsonEx: manifestJsonEx,
  manifestYamlProfiles: manifest_yaml_profiles,
  manifestYamlEx: manifestYamlEx,
  firstNonEmpty: firstNonEmpty,
  objectFromArrays: objectFromArrays,
}
