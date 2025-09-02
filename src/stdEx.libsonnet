// Useful functions beyond the standard standard library.
local re = import './regex.libsonnet';

local L(s) = std.length(s);

local indexOf(arr, elem) =
    local find_results = std.find(elem, arr);
    if L(find_results) == 0 then -1 else find_results[0];

// Copied from jsonnet std library. Added a key_sort_func parameter to sort
// JSON properties in a preferred order (e.g. for idiomatic readability in package.json).

local manifestJsonEx(value, indent, newline, key_val_sep, key_sort_func) =
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
                    [[new_indent + aux(v[i], path + [i], new_indent)] for i in range])
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

local manifestProperties(value) =
    assert std.isObject(value);
    std.join('\n', ['%s=%s' % [k, propertyValueOf(value[k])] for k in std.sort(std.objectFields(value))]);

// Generic JSON manifest (no key ordering tweaks)
local manifestJson(value) = std.manifestJsonEx(value);

local capitalizeWord(w) =
  if L(w) == 0 then '' else
  std.asciiUpper(w[0:1]) + std.asciiLower(w[1:]);

local splitWords(s) =
  std.split(std.strReplace(std.strReplace(s, "-", " "), "_", " "), " ");

local pascalCase(s) =
  std.join('', [capitalizeWord(w) for w in splitWords(s)]);

local camelCase(s) =
  local words = splitWords(s);
  if L(words) == 0 then ''
  else std.asciiLower(words[0]) + std.join('', [capitalizeWord(w) for w in words[1:]]);

local titleCase(s) =
  std.join(' ', [capitalizeWord(w) for w in std.split(s, " ")]);

{
    manifestProperties: manifestProperties,
    manifestJson: manifestJson,
    manifestJsonEx: manifestJsonEx,
    pascalCase: pascalCase,
    camelCase: camelCase,
    titleCase: titleCase,
    indexOf: indexOf,
    matchRegex: re.match,
    validateRegex: re.validate,
}
