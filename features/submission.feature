Feature: Submission
  The plugin can submit the current solution directly or after running the test flow.

  Background:
    Given the plugin is set up
    And the current source file is a supported language file

  Rule: Submission targets the source file resolved for the workflow

  Scenario: Submit from a source buffer after confirmation
    Given the first line of the current file contains a supported problem URL
    And submission is not forced by environment variable
    And the user answers "y" to the submission confirmation prompt
    When the user starts the submit workflow for the current file
    Then the plugin submits the current file to the service implied by the URL
    And the plugin uses the language identifier mapped from the filetype for that service

  Scenario: Cancel submission at the confirmation prompt
    Given the first line of the current file contains a supported problem URL
    And submission is not forced by environment variable
    And the user answers anything other than "y" or "yes" to the submission confirmation prompt
    When the user starts the submit workflow for the current file
    Then the plugin does not submit the file

  Scenario: Submit from the result viewer
    Given the result viewer is showing results for a source file
    And the source file has a supported problem URL
    And submission is forced by environment variable or confirmed by the user
    When the user submits from the result viewer
    Then the plugin submits the source file shown in the viewer

  Scenario: Reject submission when the problem URL is missing
    Given the first line of the current file does not contain a problem URL
    When the user starts the submit workflow for the current file
    Then the plugin does not submit anything
    And the plugin reports that the problem URL is required

  Rule: Submit-after-test depends on test completion, not on accepted results

  Scenario: Submit after test flow completion
    Given the first line of the current file contains a supported problem URL
    And submission is forced by environment variable or confirmed by the user
    When the user starts the submit-after-test workflow for the current file
    Then the plugin runs the normal test workflow first
    And after the test workflow completes the plugin submits the file

  Scenario: Submit-after-test does not require accepted test results
    Given the first line of the current file contains a supported problem URL
    And submission is forced by environment variable or confirmed by the user
    And the test workflow finishes with a non-accepted result
    When the user starts the submit-after-test workflow for the current file
    Then the plugin still submits the file after the test workflow completes

  Scenario: Submit failure is shown in the viewer only during submit-after-test
    Given the first line of the current file contains a supported problem URL
    And submission fails
    When the user starts the submit-after-test workflow for the current file
    Then the plugin reports the submission failure
    And the result viewer shows the submission failure details
