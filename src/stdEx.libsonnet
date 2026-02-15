// Useful functions beyond the standard standard library.
local re = import './regex.libsonnet';

local L(s) = std.length(s);

local indexOf(arr, elem) =
  local find_results = std.find(elem, arr);
  if L(find_results) == 0 then -1 else find_results[0];

local objectFromArrays(keys, values) = {
  [keys[i]]: values[i]
  for i in std.range(0, std.length(keys) - 1)
};

local firstNonEmpty(arr, defaultValue=null) =
  local nonEmpty = [x for x in arr if x != null && x != '' && x != [] && x != {}];
  if L(nonEmpty) == 0 then defaultValue else nonEmpty[0];

local splitAny(s, delimiters) =
  assert std.isString(s);
  assert std.isArray(delimiters);
  if L(s) == 0 then []
  else
    local delimiterSet = { [d]: true for d in delimiters if d != '' };
    local addPiece(parts, piece) = if piece == '' then parts else parts + [piece];
    local loop(i, current, parts) =
      if i >= L(s) then addPiece(parts, current)
      else
        local ch = std.substr(s, i, 1);
        if std.objectHas(delimiterSet, ch) then
          loop(i + 1, '', addPiece(parts, current))
        else
          loop(i + 1, current + ch, parts);
    loop(0, '', []);

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

local capitalizeWord(w) =
  if L(w) == 0 then '' else
    std.asciiUpper(w[0:1]) + std.asciiLower(w[1:]);

local splitWords(s) =
  std.split(std.strReplace(std.strReplace(s, '-', ' '), '_', ' '), ' ');

local pascalCase(s) =
  std.join('', [capitalizeWord(w) for w in splitWords(s)]);

local camelCase(s) =
  local words = splitWords(s);
  if L(words) == 0 then ''
  else std.asciiLower(words[0]) + std.join('', [capitalizeWord(w) for w in words[1:]]);

local titleCase(s) =
  std.join(' ', [capitalizeWord(w) for w in std.split(s, ' ')]);

local manifestYamlWithRunBlocks(
  value,
  newline='\n',
  top_level_newline='\n\n',
  key_sort_func=defaultYamlTopLevelKeySorter
) =
  local raw = std.manifestYamlDoc(value, quote_keys=false);
  local lines = std.split(raw, '\n');
  local flatten(arrays) = std.foldl(function(acc, x) acc + x, arrays, []);
  local isTopLevelHeader(line) =
    std.length(line) > 0 &&
    std.substr(line, 0, 1) != ' ' &&
    std.length(std.findSubstr(':', line)) > 0;
  local multiline_threshold = 1;
  local normalize_yaml_key_quotes(line) =
    // YAML 1.1 treats "on" as a boolean-like token, so Jsonnet manifests it quoted.
    // Github Actions expects the literal key `on`, so we normalize that key for consistency/readability.
    if std.startsWith(line, '"on":')
    then 'on:' + std.substr(line, 5, std.length(line) - 5)
    else line;
  local transform_line(line) =
    local normalized_line = normalize_yaml_key_quotes(line);
    local split_on_quoted = std.split(normalized_line, ': "');
    local has_quoted_value = std.length(split_on_quoted) > 1 && std.endsWith(normalized_line, '"');
    if has_quoted_value && std.length(std.split(line, '\\n')) > multiline_threshold then
      local prefix_part = split_on_quoted[0];
      local key_tokens = [token for token in std.split(prefix_part, ' ') if token != ''];
      local key = key_tokens[std.length(key_tokens) - 1];
      local indent = std.substr(prefix_part, 0, std.length(prefix_part) - std.length(key));
      local value_with_suffix = std.join(
        ': "',
        std.slice(split_on_quoted, 1, std.length(split_on_quoted), 1)
      );
      local value = std.substr(value_with_suffix, 0, std.length(value_with_suffix) - 1);
      local unescaped = std.strReplace(
        std.strReplace(
          std.strReplace(value, '\\\\', '\\'),
          '\\"',
          '"'
        ),
        '\\n',
        '\n'
      );
      local script_lines = std.split(unescaped, '\n');
      local list_item_suffix = '- ';
      local is_list_item = std.endsWith(indent, list_item_suffix);
      local block_indent =
        if is_list_item
        then std.substr(indent, 0, std.length(indent) - std.length(list_item_suffix)) + '  '
        else indent;
      [indent + key + ': |'] + [
        block_indent + '  ' + script_line
        for script_line in script_lines
      ]
    else
      [normalized_line];
  local rendered_lines = flatten([transform_line(line) for line in lines]);
  local is_top_level_object = std.length(rendered_lines) > 0 && isTopLevelHeader(rendered_lines[0]);
  local grouped_lines =
    if !is_top_level_object then null else
      std.foldl(
        function(acc, line)
          if isTopLevelHeader(line) then
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

{
  manifestProperties: manifestProperties,
  manifestJson: manifestJsonEx,
  manifestJsonEx: manifestJsonEx,
  manifestYamlWithRunBlocks: manifestYamlWithRunBlocks,
  pascalCase: pascalCase,
  camelCase: camelCase,
  titleCase: titleCase,
  indexOf: indexOf,
  firstNonEmpty: firstNonEmpty,
  splitAny: splitAny,
  objectFromArrays: objectFromArrays,
  matchRegex: re.match,
  validateRegex: re.validate,
}
