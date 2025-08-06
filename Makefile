######
# Test proxy commands to run bdd test from root directory

TEST_DIR=testbdd

.PHONY: run-tests
run-tests:
	@(cd $(TEST_DIR) && $(MAKE) $@)

.PHONY: run-smoke-tests
run-smoke-tests:
	@(cd $(TEST_DIR) && $(MAKE) $@)

## Tool Binaries
KUBECTL ?= kubectl
KUSTOMIZE ?= $(LOCALBIN)/kustomize-$(KUSTOMIZE_VERSION)
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen
ENVTEST ?= $(LOCALBIN)/setup-envtest-$(ENVTEST_VERSION)
GOLANGCI_LINT = $(LOCALBIN)/golangci-lint-$(GOLANGCI_LINT_VERSION)

## Tool Versions
KUSTOMIZE_VERSION ?= v5.4.1
CONTROLLER_TOOLS_VERSION ?= v0.15.0
ENVTEST_VERSION ?= release-0.18
GOLANGCI_LINT_VERSION ?= v1.57.2

KIND_VERSION ?= v0.20.0
KNATIVE_VERSION ?= v1.13.2
TIMEOUT_SECS ?= 180s

KNATIVE_SERVING_PREFIX ?= "https://github.com/knative/serving/releases/download/knative-$(KNATIVE_VERSION)"
KNATIVE_EVENTING_PREFIX ?= "https://github.com/knative/eventing/releases/download/knative-$(KNATIVE_VERSION)"
KUSTOMIZE_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"

.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary.
$(KUSTOMIZE): $(LOCALBIN)
	$(call go-install-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v5,$(KUSTOMIZE_VERSION))

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
	@echo "⬇️ Ensuring controller-gen is installed..."
	@test -s $(CONTROLLER_GEN) || (GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION) > /dev/null 2>&1 && echo "✅  controller-gen installed successfully!")

$(CONTROLLER_GEN):
	@mkdir -p $(LOCALBIN) # Ensure LOCALBIN exists

.PHONY: envtest
envtest: $(ENVTEST) ## Download setup-envtest locally if necessary.
$(ENVTEST): $(LOCALBIN)
	$(call go-install-tool,$(ENVTEST),sigs.k8s.io/controller-runtime/tools/setup-envtest,$(ENVTEST_VERSION))

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	$(call go-install-tool,$(GOLANGCI_LINT),github.com/golangci/golangci-lint/cmd/golangci-lint,${GOLANGCI_LINT_VERSION})

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary (ideally with version)
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f $(1) ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
mv "$$(echo "$(1)" | sed "s/-$(3)$$//")" $(1) ;\
}
endef

.PHONY: clean
clean:
	rm -rf bin/

.PHONY: bump-version
new_version = ""
snapshot = ""
bump-version:
	./hack/bump-version.sh $(new_version) $(snapshot)

.PHONY: install-operator-sdk
install-operator-sdk:
	@echo "📦 Installing Operator SDK..."
	@./hack/install-operator-sdk.sh > /dev/null 2>&1


.PHONY: addheaders
addheaders:
	@echo "📝 Adding headers to files..."
	@./hack/addheaders.sh > /dev/null 2>&1

.PHONY: before-pr
before-pr: generate-all test ## Run generate-all before executing tests.
	@echo "✅  Your working branch is done."


.PHONY: install-kind
install-kind:
	command -v kind >/dev/null || go install sigs.k8s.io/kind@$(KIND_VERSION)

.PHONY: create-cluster
create-cluster: install-kind
	kind get clusters | grep kind >/dev/null || ./hack/ci/create-kind-cluster-with-registry.sh $(BUILDER)

.PHONY: deploy-knative
deploy-knative:
	kubectl apply -f https://github.com/knative/operator/releases/download/knative-$(KNATIVE_VERSION)/operator.yaml
	kubectl wait  --for=condition=Available=True deploy/knative-operator -n default --timeout=$(TIMEOUT_SECS)
	kubectl apply -f ./test/testdata/knative_serving_eventing.yaml
	kubectl wait  --for=condition=Ready=True KnativeServing/knative-serving -n knative-serving --timeout=$(TIMEOUT_SECS)
	kubectl wait  --for=condition=Ready=True KnativeEventing/knative-eventing -n knative-eventing --timeout=$(TIMEOUT_SECS)
	
.PHONY: delete-cluster
delete-cluster: install-kind
	kind delete cluster && $(BUILDER) rm -f kind-registry
