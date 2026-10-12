# BDD framework (`bddframework`)

Reusable Go module that the test suite in [`testbdd`](../testbdd/README.md) builds on. It wraps cluster access, operator installation (OLM and YAML), configuration flags, and a set of generic Gherkin steps.

The module is an extract of the test framework from the [Kogito operator](https://github.com/apache/incubator-kie-kogito-operator). Some packages (Infinispan, Kafka, Keycloak, Hyperfoil, Grafana, MongoDB) are inherited from it and are not used by the current scenarios.

## Packages

| Package | Purpose |
|---|---|
| [`pkg/config`](pkg/config) | All `--tests.*` command-line flags and their getters (`config.GetOperatorCatalogImage()`, `config.GetUpgradeToVersion()`, ...) |
| [`pkg/framework`](pkg/framework) | Cluster helpers: Kubernetes client, namespaces, pods/deployments, logs, waiting (`WaitFor*`), OLM (CatalogSource, Subscription, CSV), command execution (`CreateCommand`) |
| [`pkg/framework/client`](pkg/framework/client) | Kubernetes/OpenShift client and OpenShift detection (`IsOpenshift()`) |
| [`pkg/installers`](pkg/installers) | `ServiceInstaller` implementations: `OlmClusterWideServiceInstaller`, `YamlClusterWideServiceInstaller`, ...; tracks what was installed so the suite can uninstall it |
| [`pkg/steps`](pkg/steps) | Generic steps shared by suites (for example `Namespace is created`) and the base `Data` struct |
| [`pkg/gherkin`](pkg/gherkin) | Feature parsing and tag filtering (used for dry runs and `show_scenarios`) |
| [`pkg/meta`](pkg/meta), [`pkg/api`](pkg/api), [`pkg/types`](pkg/types) | Scheme registration and shared types |

## Frequently used helpers

```go
// Poll until the condition is true or the timeout (in minutes, scaled by load_factor) expires
framework.WaitForOnOpenshift(namespace, "description", timeoutInMin, func() (bool, error) { ... })

// Pods and deployments
framework.WaitForPodsWithLabel(namespace, "label-key", "label-value", count, timeoutInMin)
framework.GetDeployment(namespace, name)

// Run oc/kubectl
out, err := framework.CreateCommand("oc", "get", "csv", "-n", namespace).Execute()

// OLM
framework.GetClusterOperatorNamespace()      // openshift-operators on OpenShift
framework.GetCustomKogitoOperatorCatalog()   // bdd-tests-kogito-catalog (from operator_catalog_image)
framework.GetProductCatalog()                // redhat-operators

// Logging
framework.GetLogger(namespace).Info("message", "key", value)
```

## Adding a configuration flag

1. Add a field to the `env` struct, a `set.StringVar`/`set.BoolVar` call in `BindFlags`, and a getter in [`pkg/config/config.go`](pkg/config/config.go). Flags are registered with the `tests.` prefix.
2. Add the flag name (without the prefix) to `STRING_TEST_PARAMS` or `BOOLEAN_TEST_PARAMS` in [`hack/run-tests.sh`](../hack/run-tests.sh), so `make run-tests key=value` accepts it.
3. Document the flag in [testbdd/README.md](../testbdd/README.md#parameters).

## Development

```bash
cd bddframework
go vet ./...
make test        # go mod tidy, go fmt, go vet, go test ./...
```

Changes here affect the whole suite. Also vet the `testbdd` module and dry-run a few tags (see [testbdd/README.md](../testbdd/README.md#validate-before-a-pr)).
