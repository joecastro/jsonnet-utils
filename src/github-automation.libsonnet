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
  local empty_trigger_keys = [k for k in trigger_keys if merged_triggers[k] == {}];
  local normalize_trigger_value(value) =
    if value == {}
    then null
    else value;
  local normalized_triggers =
    if std.length(trigger_keys) > 0 && std.length(empty_trigger_keys) == std.length(trigger_keys)
    then empty_trigger_keys
    else {
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
  environment=null
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
  local lines = run_lines;
  local is_multiline = std.length(lines) > 1;
  if is_multiline then
    local body_lines =
      if std.length(lines) > 0 && lines[0] == 'set -euo pipefail'
      then std.slice(lines, 1, std.length(lines), 1)
      else lines;
    std.join('\n', ['echo ' + shellQuoteSingle(name), 'set -euo pipefail'] + body_lines)
  else
    std.join('\n', lines);

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

local default_yaml_top_level_key_order = ['name', 'on'];
local defaultYamlTopLevelKeySorter(key) =
  local index = stdEx.indexOf(default_yaml_top_level_key_order, key);
  if index != -1 then '%03d' % index + key else '999' + key;

local normalizeGithubWorkflowYaml(
  raw,
  key_sort_func=defaultYamlTopLevelKeySorter,
  reorder_top_level=true,
  normalize_on_key=true,
  normalize_empty_on_events=true
      ) =
  local normalized = std.foldl(
    function(state, line)
      local normalized_on_key_line =
        if normalize_on_key && std.startsWith(line, '"on":')
        then 'on:' + std.substr(line, 5, std.length(line) - 5)
        else line;
      local is_top_level = std.length(normalized_on_key_line) > 0 && !std.startsWith(normalized_on_key_line, ' ');
      local is_on_direct_child =
        normalize_empty_on_events &&
        state.in_on &&
        std.startsWith(line, '  ') &&
        !std.startsWith(line, '    ');
      local normalized_line =
        if is_on_direct_child && std.endsWith(normalized_on_key_line, ': null')
        then std.substr(normalized_on_key_line, 0, std.length(normalized_on_key_line) - 5)
        else if is_on_direct_child && std.endsWith(normalized_on_key_line, ': {}')
        then std.substr(normalized_on_key_line, 0, std.length(normalized_on_key_line) - 3)
        else normalized_on_key_line;
      {
        lines: state.lines + [normalized_line],
        in_on:
          if !normalize_empty_on_events
          then false
          else if is_top_level then normalized_line == 'on:' else state.in_on,
      },
    std.split(raw, '\n'),
    { lines: [], in_on: false }
  );
  local rendered_lines = normalized.lines;
  if !reorder_top_level then
    std.join('\n', rendered_lines)
  else
    local top_level_header_indexes =
      if std.length(rendered_lines) == 0 then [] else [
        i
        for i in std.range(0, std.length(rendered_lines) - 1)
        if std.length(rendered_lines[i]) > 0 &&
           !std.startsWith(rendered_lines[i], ' ') &&
           stdEx.containsAny(rendered_lines[i], [':'])
      ];
    local is_top_level_object =
      std.length(top_level_header_indexes) > 0 &&
      top_level_header_indexes[0] == 0;
    local reorder_top_level_lines =
      if !is_top_level_object then rendered_lines else
        local section_count = std.length(top_level_header_indexes);
        local section_indexes = std.range(0, section_count - 1);
        local section_lines = [
          std.slice(
            rendered_lines,
            top_level_header_indexes[i],
            if i + 1 < section_count then top_level_header_indexes[i + 1] else std.length(rendered_lines),
            1
          )
          for i in section_indexes
        ];
        local key_from_header(header) =
          local split = std.split(header, ':');
          split[0];
        local ordered_section_indexes = std.sort(
          section_indexes,
          function(i) key_sort_func(key_from_header(rendered_lines[top_level_header_indexes[i]]))
        );
        [std.join('\n', section_lines[i]) for i in ordered_section_indexes];
    if !is_top_level_object
    then std.join('\n', reorder_top_level_lines)
    else std.join('\n\n', reorder_top_level_lines);

local manifest_yaml_profiles = {
  pretty: {
    render_mode: 'pretty',
    unquote_safe_strings: true,
    reorder_top_level: false,
  },
  fast: {
    render_mode: 'fast',
    reorder_top_level: true,
  },
};

local default_manifest_yaml_options = {
  profile: 'fast',
  render_mode: 'fast',
  unquote_safe_strings: true,
  reorder_top_level: true,
  normalize_on_key: true,
  normalize_empty_on_events: true,
  key_sort_func: defaultYamlTopLevelKeySorter,
};

local manifestYamlOptions(options={}) =
  local provided =
    if std.type(options) == 'boolean'
    then { profile: if options then 'fast' else 'pretty' }
    else options;
  local profile_name =
    if std.objectHas(provided, 'profile')
    then provided.profile
    else default_manifest_yaml_options.profile;
  local profile_options =
    if std.objectHas(manifest_yaml_profiles, profile_name)
    then manifest_yaml_profiles[profile_name]
    else error 'Unknown manifestYaml profile: ' + profile_name;
  default_manifest_yaml_options + profile_options + provided;

local manifestYamlWithOptions(value, options={}) =
  local opts = manifestYamlOptions(options);
  local raw =
    if opts.render_mode == 'fast'
    then std.manifestYamlDoc(value, quote_keys=false)
    else stdEx.manifestYamlWithRunBlocks(
      value,
      key_sort_func=opts.key_sort_func,
      unquote_safe_strings=opts.unquote_safe_strings
    );
  normalizeGithubWorkflowYaml(
    raw,
    key_sort_func=opts.key_sort_func,
    reorder_top_level=opts.reorder_top_level,
    normalize_on_key=opts.normalize_on_key,
    normalize_empty_on_events=opts.normalize_empty_on_events
  );

local manifestYamlPretty(value, options={}) =
  manifestYamlWithOptions(value, { profile: 'pretty' } + options);

local manifestYamlFast(value, options={}) =
  manifestYamlWithOptions(value, { profile: 'fast' } + options);

local manifestYaml(value, options={}, fast=null) =
  local normalized_options =
    if fast == null
    then options
    else if std.type(options) != 'object'
    then { profile: if fast then 'fast' else 'pretty' }
    else options { profile: if fast then 'fast' else 'pretty' };
  manifestYamlWithOptions(value, normalized_options);

{
  manifestYaml: manifestYaml,
  manifestYamlPretty: manifestYamlPretty,
  manifestYamlFast: manifestYamlFast,
  manifestYamlOptions: manifestYamlOptions,
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
