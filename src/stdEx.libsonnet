// Useful functions beyond the standard standard library.
local re = import './regex.libsonnet';
local str = import './stringUtils.libsonnet';

local L = std.length;
local indexOf = str.indexOf;
local containsAny = str.containsAny;
local charsOf = str.charsOf;
local firstChar = str.firstChar;

local objectFromArrays(keys, values) = {
  [keys[i]]: values[i]
  for i in std.range(0, L(keys) - 1)
};

local firstNonEmpty(arr, defaultValue=null) =
  local nonEmpty = [x for x in arr if x != null && x != '' && x != [] && x != {}];
  if L(nonEmpty) == 0 then defaultValue else nonEmpty[0];

local isStringBooleanLike(s) =
  local boolean_like_strings = [
    'y', 'yes', 'n', 'no',
    'true', 'false',
    'on', 'off',
  ];
  indexOf(boolean_like_strings, std.asciiLower(s)) != -1;

local isStringNullLike(s) =
  local null_like_strings = ['null', '~'];
  indexOf(null_like_strings, std.asciiLower(s)) != -1;

local isStringNumberLike(s) =
  local ascii_digits = charsOf('0123456789');
  local second = if L(s) > 1 then std.substr(s, 1, 1) else '';
  containsAny(firstChar(s), ascii_digits) ||
  (containsAny(firstChar(s), charsOf('+-.')) && containsAny(second, ascii_digits));

local isYamlImplicitScalarLike(s) =
  isStringBooleanLike(s) ||
  isStringNullLike(s) ||
  isStringNumberLike(s);

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
local defaultYamlTopLevelKeySorter(key) =
  local index = indexOf(default_yaml_top_level_key_order, key);
  if index != -1 then '%03d' % index + key else '999' + key;

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

// Conservative "safe to unquote" check for YAML plain scalars.
// We avoid YAML-significant starts/separators and common implicit scalar values.
local yamlIsSafePlainScalar(s) =
  !re.matchRegex('^[,@>]', s) &&
  !isYamlImplicitScalarLike(s) &&
  !re.matchRegex('^[-?:] ', s) &&
  !re.matchRegex(': | #|\t|\r', s) &&
  re.matchRegex('^[\\w\\d -./@():;,+<=>!?$^~]*[^ :]$', s);

local yamlDecodeDoubleQuotedScalar(value) =
  assert std.isString(value);
  local backslash_token = '__YAML_ESCAPED_BACKSLASH__';
  local escaped_backslashes = std.strReplace(value, '\\\\', backslash_token);
  local unescaped_quotes = std.strReplace(escaped_backslashes, '\\"', '"');
  local unescaped_newlines = std.strReplace(unescaped_quotes, '\\n', '\n');
  local restored_backslashes = std.strReplace(unescaped_newlines, backslash_token, '\\');
  restored_backslashes;

local yamlParseQuotedScalarLine(line) =
  local split_on_quoted = std.split(line, ': "');
  local has_quoted_value = L(split_on_quoted) > 1 && std.endsWith(line, '"');
  if !has_quoted_value then null else
    local prefix = split_on_quoted[0];
    local value_with_suffix = std.join(
      ': "',
      std.slice(split_on_quoted, 1, L(split_on_quoted), 1)
    );
    local quoted_value = std.substr(value_with_suffix, 0, L(value_with_suffix) - 1);
    local key_tokens = [token for token in std.split(prefix, ' ') if token != ''];
    local key = key_tokens[L(key_tokens) - 1];
    local indent = std.substr(prefix, 0, L(prefix) - L(key));
    {
      prefix: prefix,
      key: key,
      indent: indent,
      quoted_value: quoted_value,
    };

local yamlParseQuotedListItemLine(line) =
  local split_on_quoted = std.split(line, '- "');
  local has_quoted_value = L(split_on_quoted) > 1 && std.endsWith(line, '"');
  if !has_quoted_value then null else
    local indent = split_on_quoted[0];
    local value_with_suffix = std.join(
      '- "',
      std.slice(split_on_quoted, 1, L(split_on_quoted), 1)
    );
    local quoted_value = std.substr(value_with_suffix, 0, L(value_with_suffix) - 1);
    {
      indent: indent,
      quoted_value: quoted_value,
    };

local yamlToRunBlockLines(parsed_line) =
  local decoded = yamlDecodeDoubleQuotedScalar(parsed_line.quoted_value);
  local list_item_suffix = '- ';
  local block_indent =
    if std.endsWith(parsed_line.indent, list_item_suffix)
    then std.substr(parsed_line.indent, 0, L(parsed_line.indent) - L(list_item_suffix)) + '  '
    else parsed_line.indent;
  [parsed_line.indent + parsed_line.key + ': |'] + [
    block_indent + '  ' + script_line
    for script_line in std.split(decoded, '\n')
  ];

local yamlIsTopLevelHeader(line) =
  L(line) > 0 &&
  !std.startsWith(line, ' ') &&
  containsAny(line, [':']);

local yamlNormalizeKeyQuotes(line) =
  // YAML 1.1 treats "on" as a boolean-like token, so Jsonnet manifests it quoted.
  // Github Actions expects the literal key `on`, so we normalize that key for consistency/readability.
  if std.startsWith(line, '"on":')
  then 'on:' + std.substr(line, 5, L(line) - 5)
  else line;

// YAML manifest with targeted post-processing:
// - normalize top-level `"on"` key to `on`
// - convert encoded multiline quoted scalars into YAML `|` blocks (for run scripts)
// - optionally dequote conservative, safe single-line string scalars
// - sort top-level sections via `key_sort_func` and join sections with `top_level_newline`
local manifestYamlWithRunBlocks(
  value,
  newline='\n',
  top_level_newline='\n\n',
  key_sort_func=defaultYamlTopLevelKeySorter,
  unquote_safe_strings=true
) =
  local raw = std.manifestYamlDoc(value, quote_keys=false);
  local lines = std.split(raw, '\n');
  local flatten(arrays) = std.foldl(function(acc, x) acc + x, arrays, []);
  local transform_line(line) =
    local normalized_line = yamlNormalizeKeyQuotes(line);
    local parsed_line = yamlParseQuotedScalarLine(normalized_line);
    local parsed_list_item_line = yamlParseQuotedListItemLine(normalized_line);
    local decoded_quoted_value =
      if parsed_line == null then '' else yamlDecodeDoubleQuotedScalar(parsed_line.quoted_value);
    local decoded_list_item_quoted_value =
      if parsed_list_item_line == null then '' else yamlDecodeDoubleQuotedScalar(parsed_list_item_line.quoted_value);
    if parsed_line == null then
      if parsed_list_item_line != null && unquote_safe_strings && yamlIsSafePlainScalar(decoded_list_item_quoted_value)
      then [parsed_list_item_line.indent + '- ' + decoded_list_item_quoted_value]
      else [normalized_line]
    else if containsAny(decoded_quoted_value, ['\n']) then
      yamlToRunBlockLines(parsed_line)
    else
      if unquote_safe_strings && yamlIsSafePlainScalar(decoded_quoted_value)
      then [parsed_line.prefix + ': ' + decoded_quoted_value]
      else [normalized_line];
  local rendered_lines = flatten([transform_line(line) for line in lines]);
  local is_top_level_object = L(rendered_lines) > 0 && yamlIsTopLevelHeader(rendered_lines[0]);
  local grouped_lines =
    if !is_top_level_object then null else
      std.foldl(
        function(acc, line)
          if yamlIsTopLevelHeader(line) then
            acc {
              order: acc.order + [line],
              groups: acc.groups + { [line]: [line] },
              current: line,
            }
          else if acc.current == null then
            acc
          else
            acc {
              groups: acc.groups + { [acc.current]: acc.groups[acc.current] + [line] },
            },
        rendered_lines,
        { order: [], groups: {}, current: null }
      );
  local reorder_top_level_lines =
    if grouped_lines == null then rendered_lines else
      local key_from_header(header) = std.split(header, ':')[0];
      local ordered_headers = std.sort(grouped_lines.order, function(h) key_sort_func(key_from_header(h)));
      [std.join(newline, grouped_lines.groups[h]) for h in ordered_headers];
  if grouped_lines == null
  then std.join(newline, reorder_top_level_lines)
  else std.join(top_level_newline, reorder_top_level_lines);

str + re + {
  manifestProperties: manifestProperties,
  manifestJson: manifestJsonEx,
  manifestJsonEx: manifestJsonEx,
  manifestYamlWithRunBlocks: manifestYamlWithRunBlocks,
  firstNonEmpty: firstNonEmpty,
  objectFromArrays: objectFromArrays,
}
