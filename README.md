# Operator BDD Test Suite

Behaviour-Driven Development (BDD) end-to-end tests for the **OpenShift Serverless Logic (OSL) operator** (`logic-operator`) and its upstream counterpart, the SonataFlow operator.

The suite deploys the operator on a real cluster, deploys the `SonataFlowPlatform` with services (Data Index, Job Service, Postgres) and workflows, and verifies the behaviour. Scenarios are written in [Gherkin](https://cucumber.io/docs/gherkin/) and executed by [Godog](https://github.com/cucumber/godog), the official Cucumber implementation for Go.

## What is covered

| Area | Tag | What it verifies |
|---|---|---|
| Dev profile | `@devMode` | Workflows deployed in dev mode on the default platform and on a Data Index/Job Service/Postgres platform |
| Preview profile | `@previewMode` | In-cluster builds, workflow/Data Index/Job Service managed ConfigMap properties |
| GitOps profile | `@gitOpsMode` | Workflows deployed from pre-built images |
| Platform | `@platform` | Custom pod-template labels propagated to Data Index and Job Service deployments |
| Operator upgrade | `@upgradeTests` | OLM upgrade from a GA version to a candidate version, with service and workflow migration |
| YAML installation | `@installation` | Operator installed from `operator.yaml`, ConfigMaps, end-to-end workflow call |
| Smoke | `@smoke` | Operator, Data Index and Job Service deployment |
| Performance | `@workflows100` | 100 workflows on one platform |

See [testbdd/README.md](testbdd/README.md#tags) for the full list and which tags need which parameters.

## Repository layout

```text
.
├── bddframework/   Reusable Go module: cluster client, OLM/YAML installers, config flags, generic steps
├── testbdd/        Go module with the test suite: feature files, step definitions, executor
│   ├── features/   Gherkin scenarios (*.feature), grouped by area
│   ├── steps/      Step definitions (Go) used by the feature files
│   ├── installers/ Operator/Postgres installers specific to OSL
│   └── executor/   Godog suite wiring (tags, BeforeSuite/AfterSuite, cleanup)
├── test/           Test data (YAML fixtures under test/testdata) and path helpers (test/yaml.go)
├── hack/           Scripts: run-tests.sh (test entrypoint), cluster cleanup, local helpers
├── tasks/          Design and planning notes (upgrade tests)
├── _agents/        Condensed context for AI coding assistants (also useful as a quick reference)
└── .github/        CI workflow (Kind-based run)
```

The two Go modules are tied together by [`go.work`](go.work). `testbdd` imports `bddframework`.

## Quick start

### Prerequisites

- Go (version per [`go.work`](go.work); the toolchain is downloaded automatically when needed)
- `oc` (OpenShift) or `kubectl` on `PATH`. Several steps call `oc` directly, so `oc` is recommended.
- An OpenShift cluster with OLM, and a kubeconfig that targets it (`oc login ...`)
- For OLM installs of candidate builds: pull access from the cluster to the index (IIB) image registry

### Verify the cluster connection

```bash
oc whoami --show-server
oc get clusterversion
```

If the suite cannot detect OpenShift (for example because of an expired token or the wrong kubeconfig), it fails with `The 'domain_suffix' argument is required using Kubernetes cluster`.

### See what would run (needs a cluster login, changes nothing)

```bash
make -C testbdd run-tests dry_run=true cr_deployment_only=true tags="@devMode"
```

### Run one tag against an index (IIB) image

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

Repeat with `tags="@previewMode"`, `tags="@gitOpsMode"` and so on. Run one tag at a time to keep failures easy to read.

The upgrade scenario, the `@platform` scenario and the YAML install path need extra parameters; see [Running the suite](testbdd/README.md#running-the-suite).

### Results

- Console output (use `format=pretty` for readable output)
- `testbdd/logs/junit.xml`: JUnit report
- `testbdd/logs/<namespace>/`: pod logs collected per scenario namespace and for the operator namespaces
- `/tmp/bdd-exit-code.txt`: exit code of the last run

## Contributing

- **Add or change scenarios:** see [Writing tests](testbdd/README.md#writing-tests) in the test suite README.
- **Framework helpers** (cluster access, waiting, OLM): see [bddframework/README.md](bddframework/README.md).
- **Before opening a PR,** run `go vet` in both modules:

  ```bash
  (cd bddframework && go vet ./...)
  (cd testbdd && go vet ./...)
  ```

  Also do a dry run of the tags you touched (`dry_run=true`) and, if possible, a real run on a cluster.
- New Go files carry the Apache 2.0 license header (see [`hack/boilerplate.go.txt`](hack/boilerplate.go.txt)).

## License

Apache License 2.0. See [LICENSE](LICENSE).
