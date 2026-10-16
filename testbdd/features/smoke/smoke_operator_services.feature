Feature: Smoke test — operator install and supporting services
  As a pipeline gate
  I want to verify the operator is running and can deploy Data Index and Job Service
  So that I know the installation is healthy before running the full test suite

  @smoke
  Scenario: Operator is running and Data Index and Job Service deploy at the expected versions
    Then SonataFlow Operator is running
    Given Namespace is created
    When Postgres is deployed
    When SonataFlowPlatform with DataIndexAndJobsService using Postgres is deployed
    Then Data Index and Job Service run the expected Kogito and Quarkus versions within 5 minutes
