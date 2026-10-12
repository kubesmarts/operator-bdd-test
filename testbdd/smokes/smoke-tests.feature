Feature: Deploy SonataFlow Operator

 @smoke
 Scenario: Verify SonataFlow Operator Deployment
    When SonataFlow Operator is deployed
    Then SonataFlow Operator has 1 pod running