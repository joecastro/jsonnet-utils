local T = import './test.libsonnet';
local env = import '../src/env.libsonnet';

// Build sample properties
local P = env.Property;
local G = env.PropertyGroup;
local E = env.Env;

local p1 = P('FOO', 'one', 'first prop');
local p2 = P('BAR', 'two');

// Group with title and without; and optional toggles comment-value
local g_required = G('Core', [p1, p2], false);
local g_optional = G('Optional', [p1, p2], true);

// Override FOO only
local o1 = P('FOO', 'override', 'replaced');

[
    T.suite('Property', [
        T.equal('Property no-comment lines',
            P('A', '1').renderLines(),
            ['A=1']),
        T.equal('Property comment lines',
            P('A', '1', 'note').renderLines(),
            ['# note', 'A=1']),
        T.equal('Property commentValue=true prefixes value with #',
            P('A', '1', 'note').renderLines(true),
            ['# note', '#A=1']),
    ]),

    T.suite('PropertyGroup', [
        T.equal('PropertyGroup required renderLines',
            g_required.renderLines(),
            [
                '## Core',
                '# first prop',
                'FOO=one',
                'BAR=two']),
        T.equal('PropertyGroup optional renderLines (comment values)',
            g_optional.renderLines(),
            [
                '## Optional',
                '# first prop',
                '#FOO=one',
                '#BAR=two']),
        T.equal('PropertyGroup.mergeOverrides overrides by name',
            g_required.mergeOverrides([o1]).renderLines(),
            [
                '## Core',
                '# replaced',
                'FOO=override',
                'BAR=two']),
    ]),

    T.suite('Env', [
        T.equal('Env renderLines layout',
            E('dev', ['Project Env'], [g_required], [o1], ['EOF']).renderLines(),
            [
                '# Project Env',
                '',
                '## Core',
                '# replaced',
                'FOO=override',
                'BAR=two',
                '',
                '# EOF'
            ]),
        T.equal('Env with multiple groups and overrides that span groups',
            E(
                'dev',
                [
                    'Project Env',
                    'With second header line'
                ],
                [G(
                    'First group',
                    [
                        P('FOO', 'one', 'first comment'),
                        P('BAR', 'two', 'second comment'),
                        P('ZIP'),
                    ]),
                    G('Second group',
                    [
                        P('BAZ', 'three'),
                        P('QUX', 'four', "second group's property comment"),
                    ]),
                ],
                [P('FOO', 'override'), P('QUX', 'override2', 'new comment')]
                ).renderLines(),
            [
                '# Project Env',
                '# With second header line',
                '',
                '## First group',
                '# first comment',
                'FOO=override',
                '# second comment',
                'BAR=two',
                'ZIP=',
                '',
                '## Second group',
                'BAZ=three',
                '# new comment',
                'QUX=override2',
            ]),
    ]),
]
