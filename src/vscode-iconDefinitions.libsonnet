local StandardIcon(key) = {
    key:: key,
    id:: '$(' + key + ')',
};

local IconDefinition(key, description, fontPath, fontCharacter) = StandardIcon(key) +
{
    projection:: {
        description: description,
        default: {
            fontPath: fontPath,
            fontCharacter: fontCharacter,
        }
    },
};

// Minimal set of codicons; extend as needed
local vscode_codicons = {
    rocket: StandardIcon('rocket'),
    beaker: StandardIcon('beaker'),
};

{
    StandardIcon:: StandardIcon,
    IconDefinition:: IconDefinition,
    CodIcons:: vscode_codicons,
}

