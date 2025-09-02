local vs = import './vscode.libsonnet';
local pkgDef = import './packageDefinitions.libsonnet';

local Extension(name, publisher, displayName, description, version, repository, homepage, minimumVsCodeApiVersion, categories, activationEvents, main) = {
    name: name,
    publisher: publisher,
    displayName: displayName,
    description: description,
    version: version,
    repository: repository,
    homepage: homepage,
    engines: {
        vscode: '^' + minimumVsCodeApiVersion,
    },
    categories: categories,
    activationEvents: activationEvents,
    main: main,
    license: 'UNLICENSED',
};

local Command(name, command, icon, when=null) = {
    name:: name,
    command:: command,
    icon:: icon,
    when:: when,
};

local FullCommandDefinition(title, category, command, icon=null, when=null) = {
    title: title,
    category: category,
    command: command,
    [if when != null then 'enablement']: when,
    [if icon != null then 'icon']: '$(' + icon.key + ')',
};

local ColorDefinition = {
    Factory(extensionName):
        function(key, description, defaultDark, defaultLight, defaultHighContrast) {
            key:: extensionName + '.' + key,
            projection:: {
                id: extensionName + '.' + key,
                description: description,
                defaults: {
                    dark: defaultDark,
                    light: defaultLight,
                    highContrast: defaultHighContrast,
                },
            }
        },
};

local TaskDefinition(type) = {
    type:: type,
};

local AspectDefinition(extension, name, commandPrefix, commands) = {
    name:: name,
    commandPrefix:: commandPrefix,
    commands:: commands,
    taskDefinition:: TaskDefinition(name + ' Task'),
    contextKey:: name + "Available",
    commands_projection:: [
        FullCommandDefinition(x.name, name, extension.name + '.' + commandPrefix + '.' + x.command, x.icon, x.when)
        for x in commands
    ],
    projection:: {
        title: name,
        commandPrefix: commandPrefix,
        commandKeys: [commandPrefix + '.' + x.command for x in commands],
        contextKey: name + 'Available',
        taskDefinition: name + ' Task',
    },
};

local TypedPropertyFunction = function(type, key, description, default)
    local hasMarkdown = std.length(std.findSubstr('[', description)) > 0;
    {
        key: key,
        projection: {
            type: type,
            [if hasMarkdown then 'markdownDescription' else 'description']: description,
            default: default,
            //scope: 'application'
        }
};

local ConfigurationProperty = {
    Factory(extensionName): {
        String: function(key, description, default="") TypedPropertyFunction('string', extensionName + '.' + key, description, default),
        Boolean: function(key, description, default=false) TypedPropertyFunction('boolean', extensionName + '.' + key, description, default),
        Number: function(key, description, default=0) TypedPropertyFunction('number', extensionName + '.' + key, description, default),
        Array: function(key, description, default=[]) TypedPropertyFunction('array', extensionName + '.' + key, description, default),
    }
};

local ActivityBarViewsContainer(id, title, icon) = {
    id: id,
    title: title,
    icon: icon,
};

local View(key, id, title, when=null, icon=null, group=null) = {
    key:: key,
    id:: id,
    title:: title,
    when:: when,
    icon:: icon,
    group:: group,
};

local ViewItemDefinition(key, id, title, when=null, icon=null) = {
    key:: key,
    id:: id,
    title:: title,
    when:: when,
    icon:: icon,
};

local WelcomeView(key, id, title, when=null, icon=null) = {
    key:: key,
    id:: id,
    title:: title,
    when:: when,
    icon:: icon,
};

local ViewCommand(key, command, icon, group=null, when=null) = {
    key:: key,
    command:: command,
    icon:: icon,
    group:: group,
    when:: when,

    projection:: {
        key: key,
        command: command,
        [if icon != null then 'icon']: '$(' + icon.key + ')',
        [if group != null then 'group']: group,
        [if when != null then 'when']: when,
    },
};

{
    bind(extensionName):: {
        ColorDefinition: ColorDefinition.Factory(extensionName),
        ConfigurationProperty: ConfigurationProperty.Factory(extensionName),
    },
    Extension:: Extension,
    Command:: Command,
    ViewCommand:: ViewCommand,
    View:: View,
    WelcomeView:: WelcomeView,
    FullCommandDefinition:: FullCommandDefinition,
    AspectDefinition:: AspectDefinition,
    TaskDefinition:: TaskDefinition,
    ActivityBarViewsContainer:: ActivityBarViewsContainer,
}
