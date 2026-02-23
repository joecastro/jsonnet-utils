local stdEx = import '../../src/stdEx.libsonnet';
local vs = import '../../src/vscode.libsonnet';

local tasks = [
  vs.npmTestTask(),
  vs.npmTask('npm: format:jsonnet', 'format:jsonnet', 'Format Jsonnet files') + {
    presentation: {
      reveal: 'always',
    },
  },
  vs.npmTask('npm: bootstrap', 'bootstrap', 'Generate config files from Jsonnet') + {
    presentation: {
      reveal: 'always',
    },
  },
  vs.npmTask('npm: lint', 'lint', 'Run ESLint') + {
    problemMatcher: ['$eslint-stylish'],
    presentation: {
      reveal: 'always',
    },
  },
  vs.npmTask('npm: lint:fix', 'lint:fix', 'Run ESLint with auto-fix') + {
    problemMatcher: ['$eslint-stylish'],
    presentation: {
      reveal: 'always',
    },
  },
];

stdEx.manifestJsonEx({
  version: '2.0.0',
  tasks: tasks,
})
