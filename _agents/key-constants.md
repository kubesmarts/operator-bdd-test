# Key Constants and Configuration

## Operator namespaces and names

| Constant / Value | Location | Meaning |
|------------------|----------|---------|
| `installers.LogicOperatorNamespace` = `"openshift-serverless-logic"` | `sonataflow_installer.go:85` | Namespace where OSL operator pod runs |
| `installers.LogicOperatorSubscriptionName` = `"logic-operator"` | `sonataflow_installer.go:86` | OLM Subscription / CSV package name |
| `installers.LogicOperatorSubscriptionChannel` = `"stable"` | `sonataflow_installer.go:87` | OLM channel |
| `installers.LogicOperatorDeploymentName` = `"logic-operator-controller-manager"` | `sonataflow_installer.go:88` | Operator Deployment name |
| `framework.GetClusterOperatorNamespace()` → `"openshift-operators"` | `operator.go:511` | Subscription, InstallPlan, operator pod (OLM cluster-wide) |
| `framework.GetCustomKogitoOperatorCatalog().Source()` → `"bdd-tests-kogito-catalog"` | `operator.go` | Custom IIB CatalogSource name |

## ConfigMap names (workload namespace — `data.Namespace`)

| ConfigMap | Namespace | Who creates it |
|-----------|-----------|----------------|
| `callbackstatetimeouts-managed-props` | `data.Namespace` | Operator (after workflow reaches Running) |
| `sonataflow-platform-jobs-service-props` | `data.Namespace` | Operator (platform reconciliation) |
| `sonataflow-platform-data-index-service-props` | `data.Namespace` | Operator (platform reconciliation) |

## ConfigMap names (cluster operator namespace — `openshift-operators`)

| ConfigMap | Namespace | Who creates it |
|-----------|-----------|----------------|
| `logic-operator-builder-config` | `openshift-operators` | OLM (from CSV) — contains builder Dockerfile template |
| `logic-operator-controllers-config` | `openshift-operators` | OLM (from CSV) |

Steps targeting these must use `framework.GetClusterOperatorNamespace()` directly —
**not** `configMapNamespace()` or `data.OperatorNamespace`. See Task 9 steps
`ConfigMap "X" exists in cluster operator namespace` /
`ConfigMap "X" in cluster operator namespace contains following strings:`.

## CLI flags — upgrade testing

All flags prefixed `--tests.upgrade.*`:

| Flag | Default | Getter |
|------|---------|--------|
| `upgrade.from_version` | `""` | `config.GetUpgradeFromVersion()` |
| `upgrade.to_version` | `""` | `config.GetUpgradeToVersion()` |
| `upgrade.to_kogito_runtime_version` | `""` (required for `@upgradeTests`) | `config.GetUpgradeToKogitoRuntimeVersion()` |
| `upgrade.to_quarkus_core_version` | `""` (required for `@upgradeTests`) | `config.GetUpgradeToQuarkusCoreVersion()` |

## CLI flags — non-upgrade OLM install

| Flag | Default | Getter |
|------|---------|--------|
| `operator.version` | `""` | `config.GetOperatorVersion()` |
| `operator.install_version` | `""` (empty = channel head) | `config.GetOperatorInstallVersion()` |
| `operator.install_channel` | `""` (empty = `stable`) | `config.GetOperatorInstallChannel()` |
| `operator.kogito_runtime_version` | `""` (required by DI/JS version step) | `config.GetOperatorKogitoRuntimeVersion()` |
| `operator.quarkus_core_version` | `""` (required by DI/JS version step) | `config.GetOperatorQuarkusCoreVersion()` |
| `operator_installation_source` | `""` | `config.GetOperatorInstallationSource()` |
| `operator_catalog_image` | `""` | `config.GetOperatorCatalogImage()` |

`operator.version` is used by `SonataFlow Operator is installed via OLM` — only valid in `@upgradeTests` and `@installation` scenarios. Do not use for any other tag.
`operator.install_version` pins the suite-level (global) OLM install: `GetSonataFlowInstaller()` sets
`StartingCSV=logic-operator.v<version>` and `PinStartingCSV=true`, and
`framework.InstallClusterWideOperatorAtCSV` creates the Subscription with manual approval and approves only the
InstallPlan referenced by the Subscription that contains that CSV. `BeforeSuite` panics if it is combined with
`operator.version` / `upgrade.from_version`. `operator.install_channel` sets the Subscription channel of the same
install (e.g. `stable-1.37`); it has the same restrictions.
`operator.kogito_runtime_version` / `operator.quarkus_core_version` are used by
`Data Index and Job Service run the expected Kogito and Quarkus versions within N minutes`
(`sonataflowplatform.go`), placed after every `...DataIndexAndJobsService using Postgres is deployed`
step. The step fails when either flag is empty.
`upgrade.from_version` / `upgrade.to_version` are used by the upgrade scenario.
When either `upgrade.from_version` or `operator.version` is set, `BeforeSuite` skips
the global operator install.

All flags are also in `STRING_TEST_PARAMS` in `hack/run-tests.sh`.

## CSV naming pattern

```
logic-operator.v<version>
e.g. logic-operator.v1.39.0
```

Built as: `fmt.Sprintf("%s.v%s", installers.LogicOperatorSubscriptionName, version)`

OLM stamps `olm.owner: logic-operator.v<version>` label on every managed
Deployment — used by `sonataFlowOperatorRunningVersionMatchesUpgradeTarget`.

## DI / JS deployment names (workload namespace)

| Service | Deployment name | Container name |
|---------|----------------|----------------|
| Data Index | `sonataflow-platform-data-index-service` | `data-index-service` |
| Job Service | `sonataflow-platform-jobs-service` | `jobs-service` |

Container name derived by `deploymentContainerName()`: strip `sonataflow-platform-` prefix.

## Workflow profile annotations

| Profile | Annotation value | Build managed by operator? | Delete before upgrade? |
|---------|-----------------|---------------------------|----------------------|
| dev | `sonataflow.org/profile: dev` (default) | Yes (live reload) | No |
| preview | `sonataflow.org/profile: preview` | Yes (Buildah in-cluster) | **Yes** |
| gitops | `sonataflow.org/profile: gitops` | **No** — image in `spec.podTemplate.container.image` | **Yes** (rebuild + retag first) |

## Test data YAML paths (relative to `test/testdata/`)

| Accessor in `test/yaml.go` | Path |
|---------------------------|------|
| `GetSonataFlowE2eCallbackstateTimeoutsFolder()` | `callbackstate-timeouts/` |
| `GetSonataFlowCallbackstateTimeoutsGitops()` | `callbackstate-timeouts/gitops/callbackstatetimeouts_gitops.yaml` |
| `GetSFPlatformWithDIandJSWithDBMigration()` | `sonataflow/platform/.../sonataflow_platform_with_postgresql_dataindex_and_job_service_db_migration.yaml` |
| `GetSFPlatformWithDIandJSUsingPostgres()` | `sonataflow/platform/.../sonataflow_platform_with_postgresql_dataindex_and_job_service.yaml` |
| `GetSonataFlowE2eGreetingFolder()` | `greeting/` |
| `GetPostgresFolder()` | `persistence/postgres/` |

## Godog tags

| Tag | Meaning |
|-----|---------|
| `@smoke` | Pipeline gate: operator running + DI/JS deploy + version check. Run before full suite. Also selected by `smoke=true`. |
| `@devMode` | Dev-profile workflow scenarios on a bare platform. DevMode is self-contained — no DI/JS connectivity. |
| `@previewMode` | Preview-profile workflow and ConfigMap property scenarios on Postgres DI/JS platform. |
| `@gitOpsMode` | GitOps-profile workflow scenarios. Appears in bare-platform and Postgres-platform files (two infrastructure configurations). |
| `@platform` | Platform-level operator reconciliation tests (e.g. label propagation). No workflow deployed. Uses suite-level install. |
| `@upgradeTests` | Upgrade scenario — excluded from all normal runs; must be passed explicitly. Scenario-managed install. |
| `@installation` | OLM install validation: pod running, metrics Service, builder/controllers ConfigMaps. Runs in unified suite. |
| `@workflows100` | 100 workflows on one DI/JS/Postgres platform (performance/scale). |
| `@disabled` | Always skipped. |
| `@performance` | Excluded by the executor unless requested; no feature currently uses it. |
