Feature: Auxiliary Workflows
  The plugin also provides helper workflows outside the main test and submit path.

  Background:
    Given the plugin is set up

  Scenario: Create a custom test directory
    When the user creates a custom test directory for the current file
    Then the plugin creates the test directory for the current file if needed
    And the plugin creates "custom-1.in" and "custom-1.out" inside that directory

  Rule: Debugging is a separate workflow that can be launched from the result viewer

  Scenario: Start debugging for the selected case
    Given the result viewer is showing results for a source file
    And the selected test case exists
    When the user starts the debug workflow from the result viewer
    Then the plugin launches debugging for the source file with that case's input

  Scenario: Report missing debug capability
    Given the result viewer is showing results for a source file
    And the current environment does not provide the required debug capability
    When the user starts the debug workflow from the result viewer
    Then the plugin reports that debugging is unavailable

  Rule: Login is a service-specific helper and remains decoupled from the main flow

  Scenario: Start a service login workflow
    Given the user chooses a supported online judge service
    When the user starts the login workflow for that service
    Then the plugin uses that service's login procedure
