Feature: Test Flow
  The plugin lets a user fetch samples, build a solution, run local tests,
  and inspect progress through the result viewer.

  Background:
    Given the plugin is set up
    And the current source file is a supported language file

  Rule: The problem URL is read from the first line of the source file

  Scenario: Reject sample download when the problem URL is missing
    Given the first line of the current file does not contain a problem URL
    When the user starts the sample-download workflow for the current file
    Then the plugin does not start a download
    And the plugin reports that the URL is not written

  Rule: Downloaded sample cases are normalized into sample-* names

  Scenario: Download and normalize sample cases
    Given the first line of the current file contains a problem URL
    And the test directory for the current file has no sample cases
    When the user starts the sample-download workflow for the current file
    Then the plugin downloads sample tests for that file
    And the plugin renames downloaded sample cases into the "sample-*" naming scheme
    And the plugin reports that the download succeeded

  Scenario: Existing custom cases do not count as downloaded samples
    Given the first line of the current file contains a problem URL
    And the test directory for the current file contains only custom cases
    When the user starts the test workflow for the current file
    Then the plugin downloads sample tests before running tests

  Scenario: Existing sample cases skip automatic re-download
    Given the first line of the current file contains a problem URL
    And the test directory for the current file contains at least one "sample-*.in/.out" pair
    When the user starts the test workflow for the current file
    Then the plugin does not re-download sample tests
    And the plugin runs tests against the existing sample cases

  Scenario: Explicit sample refresh only replaces sample cases
    Given the first line of the current file contains a problem URL
    And the test directory for the current file contains sample cases
    And the test directory for the current file contains custom cases
    When the user starts the explicit sample-refresh workflow for the current file
    Then the plugin recreates only the sample cases
    And the plugin preserves existing custom cases

  Rule: The result viewer is the progress UI for the test workflow

  Scenario: Show workflow phases while running tests
    Given the first line of the current file contains a problem URL
    And the file builds successfully
    When the user starts the test workflow for the current file
    Then the plugin opens or updates the result viewer
    And the result viewer shows the current phase as building, downloading, or testing

  Scenario: Run tests from a source buffer
    Given the first line of the current file contains a problem URL
    And the file builds successfully
    When the user starts the test workflow for the current file
    Then the plugin ensures sample tests exist for the file
    And the plugin runs "oj test" against the file's execution command
    And the result viewer shows the file path, test directory, command, and test output

  Scenario: Re-run tests from the result viewer
    Given the result viewer is showing results for a source file
    When the user reruns tests from the result viewer
    Then the plugin reruns tests for the source file shown in the viewer
    And the new result replaces the previous viewer content

  Scenario: Build failure stops the workflow
    Given the first line of the current file contains a problem URL
    And the file build fails
    When the user starts the test workflow for the current file
    Then the plugin does not download tests
    And the plugin does not run "oj test"
    And the plugin reports that the build failed
    And the result viewer shows the build failure details

  Scenario: Missing URL stops the workflow
    Given the first line of the current file does not contain a problem URL
    When the user starts the test workflow for the current file
    Then the plugin does not build or run tests
    And the plugin reports that the problem URL is required

  Rule: Comparison settings affect later test executions

  Scenario: Enable exact-match comparison
    Given exact-match comparison is disabled
    When the user enables exact-match comparison
    Then exact-match comparison becomes enabled for future test runs

  Scenario: Disable exact-match comparison and use precision-based comparison
    Given exact-match comparison is enabled
    When the user disables exact-match comparison
    Then exact-match comparison becomes disabled for future test runs
    And future test runs compare outputs with the configured precision

  Scenario: Change floating-point precision
    Given the plugin is using the default floating-point precision
    When the user sets the floating-point comparison tolerance to "1e-9"
    Then future test runs use "1e-9" as the comparison tolerance
