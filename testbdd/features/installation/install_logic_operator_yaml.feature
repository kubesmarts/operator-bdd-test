Feature: Validate Logic Operator OLM installation
  As a platform engineer
  I want to verify the Logic Operator installed via OLM is fully operational
  So that I can confirm the installation is healthy before running functional tests

  @installation
  Scenario: Operator pod is running and operator-owned resources exist
    Then SonataFlow Operator is running
    And Service "logic-operator-controller-manager-metrics-service" exists
    And ConfigMap "logic-operator-builder-config" exists
    And ConfigMap "logic-operator-controllers-config" exists
    And ConfigMap "logic-operator-builder-config" contains following strings:
      | FROM ${RELATED_IMAGE_BASE_BUILDER} AS builder                |
      | FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.24 |
