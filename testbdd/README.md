# BDD test suite (`testbdd`)

This module contains the BDD scenarios for the OpenShift Serverless Logic operator. Scenarios are written in [Gherkin](https://cucumber.io/docs/gherkin/) and executed by [Godog](https://github.com/cucumber/godog). Cluster access, OLM/YAML installers and configuration flags come from the [`bddframework`](../bddframework/README.md) module.

- [How it works](#how-it-works)
- [Running the suite](#running-the-suite)
- [Tags](#tags)
- [Parameters](#parameters)
- [Results and logs](#results-and-logs)
- [Cleanup and troubleshooting](#cleanup-and-troubleshooting)
- [Writing tests](#writing-tests)

## How it works

```text
make run-tests key=value ...         testbdd/Makefile turns every key=value into --key "value"
  └─ hack/run-tests.sh               maps options to Go test flags (--tests.*, --godog.*)
      └─ go test ./testbdd           main_test.go -> executor.ExecuteBDDTests()
          ├─ BeforeSuite             installs the operator (OLM) unless a scenario installs it itself
          ├─ per scenario            creates a random namespace bdd-xxxx, runs the steps, deletes the namespace
          └─ AfterSuite              uninstalls what the suite installed, deletes the test CatalogSource
```

Key behaviour of the executor ([`executor/bdd_executor.go`](executor/bdd_executor.go)):

- `@disabled`, `@performance` and `@upgradeTests` scenarios are **excluded automatically** unless you request them explicitly.
- With `operator_installation_source=olm`, `BeforeSuite` creates the CatalogSource `bdd-tests-kogito-catalog` (from `operator_catalog_image`) in `openshift-marketplace`. It then subscribes to `logic-operator` in `openshift-operators`.
- If `operator.version` or `upgrade.from_version` is set, `BeforeSuite` **only** creates the CatalogSource. The scenario then installs the operator with a dedicated step.
- Each scenario runs in a fresh namespace, which is deleted afterwards unless `keep_namespace=true` is set.

## Running the suite

**Prerequisites:**
- Go
- `oc` on `PATH`
- `oc login` to an OpenShift cluster with OLM

The kubeconfig used by `oc` is also used by the suite (`$KUBECONFIG` or `~/.kube/config`).

Run commands from the repository root with `make -C testbdd run-tests ...`, or from this directory with `make run-tests ...`. The root [`Makefile`](../Makefile) also proxies `make run-tests`.

### Dry run (list scenarios, no cluster changes)

```bash
make -C testbdd run-tests dry_run=true cr_deployment_only=true tags="@previewMode"
```

### Profile and platform tags with an index (IIB) image

Use this for `@devMode`, `@previewMode` and `@gitOpsMode`:

```bash
export IIB_IMAGE="registry-proxy.engineering.redhat.com/rh-osbs/iib:<INDEX>"

make -C testbdd run-tests \
  cr_deployment_only=true \
  operator_installation_source=olm \
  operator_catalog_image="$IIB_IMAGE" \
  operator_image_tag="olm-install-ignored" \
  tags="@devMode" \
  format=pretty \
  2>&1 | tee bdd-devMode.log
```

> **Why `operator_image_tag`?** When `operator_image_tag` is empty, the installer falls back to the **community** catalog ([`installers/sonataflow_installer.go`](installers/sonataflow_installer.go)). In OLM mode the value itself is not used, so any non-empty placeholder works.

> **Do not set `operator.version` for these tags.** It disables the global install, and these scenarios have no install step of their own.

### `@platform`: the scenario installs a specific version itself

```bash
make -C testbdd run-tests \
  cr_deployment_only=true \
  operator_installation_source=olm \
  operator_catalog_image="$IIB_IMAGE" \
  "operator.version=1.39.0" \
  tags="@platform" \
  format=pretty \
  2>&1 | tee bdd-platform.log
```

The step `SonataFlow Operator is installed via OLM` installs `logic-operator.v<operator.version>`. It uses the custom catalog when `operator_catalog_image` is set, otherwise `redhat-operators`.

### `@upgradeTests`: OLM upgrade

The from-version is installed from **`redhat-operators`**. The to-version must be available in the **index image**.

```bash
make -C testbdd run-tests \
  cr_deployment_only=true \
  operator_installation_source=olm \
  operator_catalog_image="$IIB_IMAGE" \
  "upgrade.from_version=1.38.2" \
  "upgrade.to_version=1.39.0" \
  "upgrade.to_kogito_runtime_version=9.106.0.redhat-00005" \
  "upgrade.to_quarkus_core_version=3.33.3.redhat-00007" \
  tags="@upgradeTests" \
  format=pretty \
  2>&1 | tee bdd-upgrade.log
```

- **Runtime versions:** `upgrade.to_kogito_runtime_version` and `upgrade.to_quarkus_core_version` have **no default**. They build the expected Data Index/Job Service startup log line after the upgrade, for example `data-index-service-postgresql <kogito> on JVM (powered by Quarkus <quarkus>) started in`. Take them from the release notes or from the Data Index pod log of the target version.
- **GitOps images:** the gitops part of the scenario uses `quay.io/dhanak/callbackstatetimeouts:<from_version>` and `:<to_version>` ([`callbackstatetimeouts_gitops.yaml`](../test/testdata/callbackstate-timeouts/gitops/callbackstatetimeouts_gitops.yaml)). Both tags must exist.
- **Before running,** check that the from-version is available:

  ```bash
  oc get packagemanifests -n openshift-marketplace -l catalog=redhat-operators \
    -o jsonpath='{range .items[?(@.metadata.name=="logic-operator")].status.channels[*]}{.name}{": "}{range .entries[*]}{.name}{" "}{end}{"\n"}{end}'
  ```

- **Design notes:** the scenario flow and the planned work are described in [`_agents/upgrade-tests.md`](../_agents/upgrade-tests.md) and [`tasks/`](../tasks).

### `@installation` / `@smoke`: YAML install

These scenarios use the step `SonataFlow Operator is deployed`, which applies `operator.yaml` (`operator_yaml_uri`). They patch the operator image and the related images:

```bash
make -C testbdd run-tests \
  cr_deployment_only=true \
  operator_image_tag="<registry>/openshift-serverless-1-logic-rhel9-operator:<tag>" \
  "operator.related_image.base_builder=<registry>/openshift-serverless-1-logic-swf-builder-rhel9:<tag>" \
  tags="@installation" \
  format=pretty
```

The script [`run_custom_operator_test.sh`](../run_custom_operator_test.sh) shows a full example with all related images.

## Tags

| Tag | Feature file(s) | Operator install | Extra parameters |
|---|---|---|---|
| `@devMode` | [`platform_default.feature`](features/sonataflow/platform/platform_default.feature), [`platform_with_data_index_and_job_service.feature`](features/sonataflow/platform/platform_with_data_index_and_job_service.feature) | Global (`BeforeSuite`) | none |
| `@previewMode` | [`platform_configmap_properties.feature`](features/sonataflow/platform/platform_configmap_properties.feature), `platform_with_data_index_and_job_service.feature` | Global | none |
| `@gitOpsMode` | `platform_default.feature`, `platform_with_data_index_and_job_service.feature` | Global | none |
| `@platform` | [`platform_service_custom_labels.feature`](features/sonataflow/platform/platform_service_custom_labels.feature) | Scenario step (OLM) | `operator.version` |
| `@upgradeTests` | [`operator_upgrade.feature`](features/operator/operator_upgrade.feature) | Scenario steps (OLM) | `upgrade.*` (see above) |
| `@installation` | [`install_logic_operator_yaml.feature`](features/installation/install_logic_operator_yaml.feature) | Scenario step (YAML) | `operator_image_tag`, related images |
| `@smoke` | [`deploy_job_service.feature`](features/job-service/deploy_job_service.feature), [`deploy_data_index_service.feature`](features/data-index/deploy_data_index_service.feature) | Scenario step (YAML) | `operator_image_tag` |
| `@workflows100` | [`deploy_100_workflows_with_di_js_postgresql.feature`](features/sonataflow/performance/deploy_100_workflows_with_di_js_postgresql.feature) | Global | none (heavy) |
| `@disabled` | any | | always skipped |

Tag expressions:
- `"@a"`: scenarios with tag `a`
- `"~@a"`: exclude tag `a`
- `"@a && ~@b"`: `a` but not `b`
- `"@a,@b"`: `a` or `b`

Tags are case-sensitive. The `smoke=true` option is the same as `tags="@smoke"`.

## Parameters

Pass parameters to `make run-tests` as `key=value`. Run `../hack/run-tests.sh --help` for the full list. The most relevant ones:

| Parameter | Purpose |
|---|---|
| `tags` | Godog tag expression (see above) |
| `feature` | Run a single feature file, path relative to `testbdd/` (for example `features/operator/operator_upgrade.feature`) |
| `format` | `pretty` or `junit` (default) |
| `cr_deployment_only` | Deploy via CRs only (no CLI). **Always set this.** |
| `operator_installation_source` | `olm` or `yaml` (default `yaml`) |
| `operator_catalog_image` | Index (IIB) image used for the `bdd-tests-kogito-catalog` CatalogSource |
| `operator_image_tag` | Operator image. Required for YAML installs; must be non-empty for global OLM installs (see above). |
| `operator_yaml_uri` | URL or path of `operator.yaml` for YAML installs |
| `operator.related_image.<name>` | Override related images for YAML installs: `jobs_service_postgresql`, `jobs_service_ephemeral`, `data_index_postgresql`, `data_index_ephemeral`, `db_migrator_tool`, `base_builder`, `devmode` |
| `operator.version` | Operator version installed by the `SonataFlow Operator is installed via OLM` step |
| `upgrade.from_version` / `upgrade.to_version` | Upgrade source and target versions |
| `upgrade.to_kogito_runtime_version` / `upgrade.to_quarkus_core_version` | Versions expected in Data Index/Job Service logs after the upgrade |
| `olm_namespace` | Namespace for cluster-wide operators (default `openshift-operators`) |
| `timeout` | Overall timeout in minutes (default 240) |
| `load_factor` | Multiplier for all step timeouts on slow clusters (default 1) |
| `debug` | Verbose logging |
| `dry_run` | Show scenarios without running them |
| `show_scenarios` / `show_steps` | Print the selected scenarios (and steps) before running |
| `keep_namespace` | Keep scenario namespaces after the run, for debugging |
| `namespace_name` | Use a fixed namespace name instead of `bdd-xxxx` |
| `local_cluster` | Set for local, non-OpenShift clusters (Kind, Minikube) |
| `domain_suffix` | Domain suffix for exposed services on non-OpenShift clusters |
| `enable_clean_cluster` | Run `hack/clean-cluster-operators.sh` and `hack/clean-crds.sh` before and after. **Warning:** this deletes *all* subscriptions, CSVs and InstallPlans in `openshift-operators` and `operators`. |

## Results and logs

| Location | Content |
|---|---|
| Console | Godog output; `format=pretty` is the most readable |
| `logs/junit.xml` | JUnit report |
| `logs/<namespace>/` | Pod logs collected for each scenario namespace (`bdd-xxxx`) and for `openshift-operators`, `openshift-serverless-logic`, `openshift-marketplace` |
| `logs/operator.yaml` | Patched `operator.yaml` (YAML installs only) |
| `/tmp/bdd-exit-code.txt` | Exit code of the last run |

Useful log lines to confirm which operator was installed:

```bash
grep -E "Installing custom Kogito operator CatalogSource|Subscribing to operator|Installing SonataFlow operator via OLM|community catalog" bdd-<tag>.log
```

A line `Installing SonataFlow operator using community catalog.` in `BeforeSuite` means the community operator was installed instead of the one from your index image.

## Cleanup and troubleshooting

The suite cleans up after itself in normal runs. Check for leftovers after an interrupted run (Ctrl-C or a panic) and after `@upgradeTests` runs:

```bash
oc get subscription,csv -n openshift-operators | grep logic-operator
```

Remove leftovers:

```bash
oc delete subscription logic-operator -n openshift-operators --ignore-not-found
oc get csv -n openshift-operators -o name | grep logic-operator | xargs -r oc delete -n openshift-operators
oc delete catalogsource bdd-tests-kogito-catalog -n openshift-marketplace --ignore-not-found

# old InstallPlans that reference logic-operator
oc get installplan -n openshift-operators \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.clusterServiceVersionNames[*]}{"\n"}{end}' \
  | awk '/logic-operator\./ {print $1}' | xargs -r oc delete installplan -n openshift-operators
```

Clean up the subscription and CSV first. A leftover subscription is reused as-is by the next run, even if it points to a different catalog.

| Symptom | Cause / fix |
|---|---|
| `panic: The 'domain_suffix' argument is required using Kubernetes cluster` | The suite did not detect OpenShift. Check `oc whoami --show-server` and `$KUBECONFIG`, then log in again. On Kind or Minikube, set `local_cluster=true`. |
| CatalogSource never `READY` | The cluster cannot pull the index image. Check the pull secret and the mirror configuration (ICSP/IDMS) for the registry. |
| `Error bumping events ... could not find the requested resource` | Harmless. The framework still calls the deprecated v1beta1 events API. |
| `Error while retrieving log ... no route to host` on port 10250 | A node's kubelet is unreachable for log collection. Only logs are lost; check `oc get nodes`. |
| Upgrade teardown logs `Error uninstalling service from cluster` | Known issue: the subscription source changes during the upgrade. Use the cleanup commands above. |
| Namespaces stuck in `Terminating` | `hack/clean-stuck-namespaces.sh` runs at the end of every run; run it manually if needed. |

## Writing tests

### Layout

| Path | Content |
|---|---|
| `features/<area>/*.feature` | Scenarios. Give each scenario a tag from the [Tags](#tags) table, or a new tag documented there. |
| `steps/*.go` | Step definitions, registered in [`steps/data.go`](steps/data.go) via `register...Steps(ctx, data)` |
| `installers/` | Operator and Postgres installers (OLM and YAML) |
| `executor/` | Suite hooks, tag handling, global install/uninstall |
| `../test/testdata/` | YAML fixtures (workflows, platforms, Postgres) |
| `../test/yaml.go` | Path accessors for fixtures (`GetSonataFlow...()`) |

Generic steps (namespace creation and similar) live in [`bddframework/pkg/steps`](../bddframework/pkg/steps) and are registered as well.

### Adding a scenario

1. Reuse existing steps where possible. To list every scenario and step for a tag without changing the cluster:

   ```bash
   make -C testbdd run-tests dry_run=true show_steps=true cr_deployment_only=true tags="@previewMode"
   ```

   You can also search the step regular expressions: `grep -rn 'ctx.Step(' testbdd/steps bddframework/pkg/steps`.

2. Put cluster fixtures in `test/testdata/<area>/` and add an accessor in `test/yaml.go`.
3. Start with `Given Namespace is created`. Each scenario gets its own namespace, available in steps as `data.Namespace`.
4. Tag the scenario and document the tag in this README.

### Adding a step

```go
// steps/<area>.go - register in the area's register function
ctx.Step(`^SonataFlow "([^"]*)" does something within (\d+) minutes?$`, data.sonataFlowDoesSomethingWithinMinutes)

func (data *Data) sonataFlowDoesSomethingWithinMinutes(name string, timeoutInMin int) error {
    return framework.WaitForOnOpenshift(data.Namespace, "SonataFlow "+name+" does something", timeoutInMin,
        func() (bool, error) {
            // return true when the condition is met; return an error only for unrecoverable failures
            return false, nil
        })
}
```

Guidelines:
- **Poll, don't sleep.** If a step takes a `within N minutes` argument, use `framework.WaitFor...` with that timeout.
- **Assert everything the step text promises.** If the text says `expectedResponseContains '...'`, compare the response.
- **Use the right namespace:**
  - workload resources: `data.Namespace`
  - cluster operator resources (CSV, subscriptions, `logic-operator-builder-config`): `framework.GetClusterOperatorNamespace()`
  - operator install namespace: `installers.LogicOperatorNamespace`
- **Use the product names** (`logic-operator`) for OLM resources, not `sonataflow-operator`.
- **New parameters:** add the flag and getter in [`bddframework/pkg/config/config.go`](../bddframework/pkg/config/config.go), then add the name to `STRING_TEST_PARAMS` or `BOOLEAN_TEST_PARAMS` in [`hack/run-tests.sh`](../hack/run-tests.sh). Otherwise `make run-tests` rejects it.

More patterns (placeholders, gitops templating, waiting helpers) are in [`_agents/step-authoring.md`](../_agents/step-authoring.md).

### Validate before a PR

```bash
(cd bddframework && go vet ./...)
(cd testbdd && go vet ./...)
make -C testbdd run-tests dry_run=true cr_deployment_only=true tags="<your tag>"
```

Then run the affected tags on a cluster and attach the summary (`N scenarios (N passed)`) to the PR.
