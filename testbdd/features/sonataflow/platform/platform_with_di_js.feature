Feature: Deploy SonataFlowPlatform with Data Index and Job Service using Postgres database
  As a developer
  I want to deploy examples with Data Index and Job Service using Postgresql
  So that I can verify the examples deployed on top of this platform behave expectedly

  # Note: devMode scenarios do not belong in this file. DevMode workflows are entirely
  # self-contained — they never connect to Data Index or Job Service even when those pods
  # are running in the same namespace. DevMode scenarios live in platform_default.feature
  # where the Background deploys a bare platform, avoiding unnecessary Postgres and DI/JS setup.

  Background:
    Given Namespace is created
    When Postgres is deployed
    When SonataFlowPlatform with DataIndexAndJobsService using Postgres is deployed
    Then Data Index and Job Service run the expected Kogito and Quarkus versions within 5 minutes

  @previewMode
  Scenario: Deploy callbackstatetimeouts example in preview mode and verify its functionality
    When SonataFlow callbackstatetimeouts example is deployed
    Then SonataFlow "callbackstatetimeouts" has the condition "Running" set to "True" within 5 minutes
    Then HTTP POST request on non-dev SonataFlow "callbackstatetimeouts" is successful within 1 minute with path "callbackstatetimeouts", expectedResponseContains '"workflowdata":{"message":"Hello"}"' and body:
    """json
    {"message": "Hello"
    }
    """
   
  @gitOpsMode
  Scenario: Deploy greeting example in gitops mode and verify its functionality  
    When SonataFlow greeting gitops example is deployed
    Then SonataFlow "greeting" has the condition "Running" set to "True" within 5 minutes
    Then HTTP POST request on non-dev SonataFlow "greeting" is successful within 1 minute with path "greeting", expectedResponseContains '""workflowdata":{"name":"Petr Pavel","language":"Spanish","greeting":"Saludos desde JSON Workflow, "}' and body:
    """json
    {"name":"Petr Pavel",
    "language":"Spanish"
    }
    """