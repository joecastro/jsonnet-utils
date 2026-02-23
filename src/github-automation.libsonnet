local stdEx = import './stdEx.libsonnet';

local expr(content) = '${{ ' + content + ' }}';

local permissions = {
  default: {
    contents: 'read',
    'id-token': 'write',
  },
  write: {
    contents: 'write',
    'pull-requests': 'write',
    'id-token': 'write',
  },
  deploy: {
    contents: 'read',
    actions: 'read',
    deployments: 'write',
    'id-token': 'write',
  },
};

local runners = {
  ubuntu: 'ubuntu-22.04',
  windows: 'windows-latest',
  macos: 'macos-26',
};

local environments = {
  dev: 'dev',
  staging: 'staging',
  prod: 'prod',
};

local Input(id, description, type=null, required=false, default=null, options=null) = {
  id:: id,
  arg_path:: function(scope='inputs') scope + '.' + self.id,
  arg_ref:: function(scope='inputs') expr(self.arg_path(scope)),
  arg_compare_expr:: function(comparison, scope='inputs') self.arg_path(scope) + ' ' + comparison,
  arg_compare:: function(comparison, scope='inputs') expr(self.arg_compare_expr(comparison, scope)),
  description: description,
  required: required,
  [if default != null then 'default']: default,
  [if options != null then 'options']: options,
  [if type != null then 'type']: type,
};

local inputsById(inputs) =
  assert std.type(inputs) == 'array' : 'inputs must be an array';
  std.foldl(
    function(acc, i) acc {
      [i.id]: i,
    },
    inputs,
    {}
  );

local CombinedInputExpr(inputs, join_condition='&&') =
  assert std.type(inputs) == 'array' : 'inputs must be an array';
  expr(std.join(' ' + join_condition + ' ', [i.arg_compare_expr("!= ''") for i in inputs]));

local triggers = {
  manually_invokable: {
    workflow_dispatch: {},
  },
  manually_invokable_with_inputs(inputs): {
    workflow_dispatch: {
      inputs: inputsById(inputs),
    },
  },
  on_pull_request_to_main: {
    pull_request: {
      branches: ['main'],
      types: ['opened', 'synchronize', 'reopened'],
    },
  },
  on_pull_request_to_main_with_path_filter(paths): {
    pull_request: {
      branches: ['main'],
      types: ['opened', 'synchronize', 'reopened'],
      paths: paths,
    },
  },
  on_pull_request_to_main_closed: {
    pull_request: {
      branches: ['main'],
      types: ['closed'],
    },
  },
  on_pull_request_closed_to_main_with_path_filter(paths): {
    pull_request: {
      branches: ['main'],
      types: ['closed'],
      paths: paths,
    },
  },
  on_push_to_main: {
    push: {
      branches: ['main'],
    },
  },
  on_push_to_main_with_path_filter(paths): {
    push: {
      branches: ['main'],
      paths: paths,
    },
  },
  schedule_cron(cron): {
    schedule: [
      { cron: cron },
    ],
  },
};

local Workflow(name, triggers, jobs, concurrency=null) =
  assert std.type(jobs) == 'array' : 'jobs must be an array';
  local merged_triggers = std.foldl(function(acc, t) acc + t, triggers, {});
  local trigger_keys = std.objectFields(merged_triggers);
  local normalize_trigger_value(value) =
    if value == {}
    then null
    else value;
  local normalized_triggers =
    {
      [k]: normalize_trigger_value(merged_triggers[k])
      for k in trigger_keys
    };
  local jobs_by_id = std.foldl(
    function(acc, job) acc {
      [job.id]: job,
    },
    jobs,
    {}
  );
  {
    name: name,
    on: normalized_triggers,
    jobs: jobs_by_id,
    [if concurrency != null then 'concurrency']: concurrency,
  };

local Job(
  id,
  name,
  steps,
  runs_on,
  permissions,
  env=null,
  needs=null,
  if_condition=null,
  environment=null,
  strategy=null
      ) = {
  id:: id,
  name: name,
  'runs-on': runs_on,
  steps: steps,
  permissions: permissions,
  [if env != null then 'env']: env,
  [if needs != null then 'needs']: needs,
  [if if_condition != null then 'if']: if_condition,
  [if environment != null then 'environment']: environment,
  [if strategy != null then 'strategy']: strategy,
  output_path:: function(prop, scope='needs')
    assert self.id != null : 'Job id is required when referencing outputs via output_path/output_ref';
    scope + '.' + self.id + '.outputs.' + prop,
  output_ref:: function(prop, compare_arg=null, scope='needs')
    if compare_arg != null then expr(self.output_path(prop, scope) + ' ' + compare_arg)
    else expr(self.output_path(prop, scope)),
};

local Step(
  id,
  name,
  uses=null,
  run=null,
  shell=null,
  with=null,
  env=null,
  if_condition=null,
      ) =
  {
    [if id != null then 'id']: id,
    output_path:: function(prop)
      assert self.id != null : 'Step id is required when referencing outputs via output_path/output_ref';
      'steps.' + self.id + '.outputs.' + prop,
    output_ref:: function(prop, compare_arg=null)
      if compare_arg != null then expr(self.output_path(prop) + ' ' + compare_arg)
      else expr(self.output_path(prop)),
    name: name,
    [if uses != null then 'uses']: uses,
    [if run != null then 'run']: run,
    [if shell != null then 'shell']: shell,
    [if with != null then 'with']: with,
    [if env != null then 'env']: env,
    [if if_condition != null then 'if']: if_condition,
  };

local shellQuoteSingle(s) =
  "'" + std.strReplace(s, "'", "'\"'\"'") + "'";

local normalizeBashRun(name, run_lines) =
  assert std.type(run_lines) == 'array' : 'BashShellStep run must be an array of lines';
  assert std.length(run_lines) > 0 : 'BashShellStep run must have at least one line';
  assert run_lines[0] != 'set -euo pipefail' : 'BashShellStep run should not include set -euo pipefail, it is added automatically';
  if std.length(run_lines) == 1 then
    run_lines[0]
  else
    'echo ' + shellQuoteSingle(name) + '\n' +
    'set -euo pipefail\n' +
    // Add an extra newline after the multiline string so Jsonnet's std.manifestYamlDoc will expand to run blocks.
    std.join('\n', run_lines) + '\n';

local BashShellStep(
  id,
  name,
  run,
  with=null,
  env=null,
  if_condition=null,
      ) =
  Step(
    id,
    name,
    run=normalizeBashRun(name, run),
    shell='bash',
    with=with,
    env=env,
    if_condition=if_condition
  );

local CompositeAction(name, description, inputs, steps) = {
  name: name,
  description: description,
  [if std.length(inputs) > 0 then 'inputs']: inputsById(inputs),
  runs: {
    using: 'composite',
    steps: steps,
  },
};

local checkoutStep =
  Step(
    null,
    'Checkout',
    uses='actions/checkout@v4',
    with={
      'fetch-depth': 0,
    }
  );

local createPullRequestStep(
  commit_message,
  body_lines,
  branch,
  delete_branch=true,
      ) =
  assert std.type(body_lines) == 'array' : 'createPullRequest body_lines must be an array of lines';
  Step(
    null,
    'Create pull request',
    uses='peter-evans/create-pull-request@v6',
    with={
      'commit-message': commit_message,
      title: commit_message,
      body: std.join('\n', body_lines),
      branch: branch,
      'delete-branch': delete_branch,
    }
  );

local setupNodeStep(version) =
  Step(
    null,
    'Set up Node',
    uses='actions/setup-node@v4',
    with={
      'node-version': version,
    }
  );

local setupPnpmStep(run_install=false) =
  Step(
    null,
    'Set up pnpm',
    uses='pnpm/action-setup@v4',
    with={
      run_install: run_install,
    }
  );

local cacheStep(id, name, path, key, condition=null) =
  Step(
    id,
    name,
    uses='actions/cache@v4',
    with={
      path: path,
      key: key,
    },
    if_condition=condition
  );

local uploadArtifactStep(
  id,
  name,
  artifact_name,
  path,
  retention_days=7,
  if_no_files_found='warn',
  if_condition=null
      ) =
  Step(
    id,
    name,
    uses='actions/upload-artifact@v4',
    with={
      name: artifact_name,
      path: path,
      'retention-days': retention_days,
      'if-no-files-found': if_no_files_found,
    },
    if_condition=if_condition
  );

local setupPythonStep(version) =
  Step(
    null,
    'Set up Python',
    uses='actions/setup-python@v5',
    with={
      'python-version': version,
    }
  );

local setupUvStep(enable_cache=true) =
  Step(
    null,
    'Set up uv',
    uses='astral-sh/setup-uv@v5',
    with={
      'enable-cache': enable_cache,
    }
  );

local buildJsonnetStep(version='0.21.0', if_condition=null) =
  BashShellStep(
    null,
    'Build jsonnet',
    run=[
      'JSONNET_VERSION=' + version,
      'CACHE_DIR="${HOME}/.cache/jsonnet"',
      'TARBALL="${CACHE_DIR}/jsonnet-v${JSONNET_VERSION}.tar.gz"',
      'BUILD_DIR="${CACHE_DIR}/jsonnet-v${JSONNET_VERSION}"',
      'BIN="${CACHE_DIR}/jsonnet"',
      '',
      'if [[ ! -x "${BIN}" ]]; then',
      '  mkdir -p "${CACHE_DIR}"',
      '  if [[ ! -f "${TARBALL}" ]]; then',
      '    wget -O "${TARBALL}" "https://github.com/google/jsonnet/releases/download/v${JSONNET_VERSION}/jsonnet-v${JSONNET_VERSION}.tar.gz"',
      '  fi',
      '  rm -rf "${BUILD_DIR}"',
      '  tar -xzf "${TARBALL}" -C "${CACHE_DIR}"',
      '  cd "${BUILD_DIR}"',
      '  make',
      '  cp ./jsonnet "${BIN}"',
      'fi',
      '',
      'sudo cp "${BIN}" /usr/local/bin/jsonnet',
    ],
    if_condition=if_condition
  );

local setupTerraformStep(version=null) =
  Step(
    null,
    'Set up Terraform',
    uses='hashicorp/setup-terraform@v3',
    with={
      [if version != null then 'terraform_version']: version,
    }
  );

local githubScriptStep(id, name, script, env=null) =
  Step(
    id,
    name,
    uses='actions/github-script@v7',
    with={ script: script },
    env=env
  );

local manifestYamlPretty(value, options={}) =
  stdEx.manifestYamlEx(value, stdEx.manifestYamlProfiles.pretty + options);

local manifestYamlFast(value, options={}) =
  stdEx.manifestYamlEx(value, stdEx.manifestYamlProfiles.fast + options);

{
  manifestYamlPretty: manifestYamlPretty,
  manifestYamlFast: manifestYamlFast,
  expr: expr,
  Step: Step,
  BashShellStep: BashShellStep,
  Workflow: Workflow,
  CompositeAction: CompositeAction,
  Input: Input,
  CombinedInputExpr: CombinedInputExpr,
  Job: Job,
  environments: environments,
  permissions: permissions,
  runners: runners,
  triggers: triggers,
  steps: {
    createPullRequest: createPullRequestStep,
    checkout: checkoutStep,
    setupNode: setupNodeStep,
    setupPnpm: setupPnpmStep,
    cache: cacheStep,
    uploadArtifact: uploadArtifactStep,
    setupPython: setupPythonStep,
    setupUv: setupUvStep,
    buildJsonnet: buildJsonnetStep,
    setupTerraform: setupTerraformStep,
    githubScript: githubScriptStep,
  },
}
