// Core environment defaults and guard command helpers.
local stdEx = import './stdEx.libsonnet';

// Declarative property and grouping helpers for .env layout
local Property(name, value=null, comment=null) = {
    name: name,
    value: value,
    comment: comment,
    hasComment():: comment != null && comment != '',
    renderProperty(commentValue=false):: (if commentValue then '#' else '') + stdEx.manifestProperties({ [name]: value }),
    renderComment():: if self.hasComment() then '# ' + comment else '',
    renderLines(commentValue=false):: if self.hasComment()
        then [ self.renderComment(), self.renderProperty(commentValue) ]
        else [ self.renderProperty(commentValue) ],
};

local PropertyGroup(title, props, optional=false) = {
    title: title,
    props: props,
    optional: optional,
    hasTitle():: title != null && title != '',
    renderTitle():: if self.hasTitle() then '## ' + title else '',
    renderLines()::
        local titleLines = if self.hasTitle() then [ self.renderTitle() ] else [];
        local bodyLines = std.flattenArrays([ p.renderLines(self.optional) for p in props ]);
        titleLines + bodyLines,
    mergeOverrides(overrides) ::
        local overrideMap = stdEx.objectFromArrays([p.name for p in overrides], [p for p in overrides]);
        local mergedProperties = [
            if std.objectHas(overrideMap, p.name) then
                local o = overrideMap[p.name];
                local oComment = if o.hasComment() then o.comment else p.comment;
                Property(p.name, o.value, oComment)
            else p
            for p in props
        ];
        PropertyGroup(self.title, mergedProperties, self.optional),
};

local flattenArraysWithSeparator(arrays, separator) =
    assert std.isArray(arrays);
    assert std.isArray(separator);
    local nonEmpty = [a for a in arrays if std.length(a) > 0];
    if std.length(nonEmpty) == 0 then []
    else
        nonEmpty[0] + std.flattenArrays([
            separator + nonEmpty[i]
            for i in std.range(1, std.length(nonEmpty) - 1)
        ]);

local Env(appEnv, header=[], groups=[], overrides=[], footer=[]) =
    local overriddenGroups = [ g.mergeOverrides(overrides) for g in groups ];
    {
        name: stdEx.titleCase(appEnv),
        appEnv: appEnv,
        fileName: if appEnv == '' then '.env' else '.env.' + appEnv,
        header: header,
        groups: overriddenGroups,
        props: { [p.name]: p.value for p in std.flattenArrays([ g.props for g in overriddenGroups if ! g.optional ]) },
        footer: footer,
        renderHeaderLines():: [ '# ' + h for h in header ],
        renderFooterLines():: [ '# ' + f for f in footer ],
        renderLines():: flattenArraysWithSeparator([
             self.renderHeaderLines(),
             flattenArraysWithSeparator([ g.renderLines() for g in self.groups ], ['']),
             self.renderFooterLines(),
         ], ['']),
    };

{
    Property: Property,
    PropertyGroup: PropertyGroup,
    Env: Env,
}
