Feature: Result Viewer
  The result viewer is the main interaction surface for inspecting test results
  and operating on test cases.

  Background:
    Given the plugin is set up
    And the result viewer is showing results for a source file

  Rule: The result viewer is a reusable, single working surface

  Scenario: Reuse one result viewer instance
    When the plugin shows a new test result
    Then it reuses the existing result viewer buffer
    And it replaces the viewer content with the newest result

  Scenario: Auto-open behavior is configurable
    Given result-viewer auto-open is enabled
    When the plugin starts a test workflow
    Then the result viewer opens automatically

  Scenario: The viewer position is configurable
    Given the result-viewer position is configured
    When the plugin opens the result viewer
    Then it opens in the configured position

  Rule: The viewer is keyboard-driven, but concrete key bindings are configurable

  Scenario: Keyboard actions are available from the viewer
    When the user focuses the result viewer
    Then the user can trigger rerun, submit, preview, add, edit, copy, delete, and debug by key operation

  Scenario: Help reflects the active key bindings
    When the result viewer renders its help section
    Then the help is generated from the currently active viewer actions and key bindings
    And the help can be folded or unfolded

  Rule: Test cases are selected by viewer structure, not by preview text

  Scenario: Toggle preview from a case-related line
    Given the cursor is on a case header line or another line belonging to a case
    When the user toggles preview
    Then the plugin opens or closes the preview for that case

  Scenario: Long previews may be truncated without changing selection behavior
    Given a test case has long input or output
    When the user previews that test case in the result viewer
    Then the plugin may truncate the displayed preview according to configuration
    And the selected case for later actions remains the same regardless of truncation

  Rule: Sample cases are protected, custom cases are editable

  Scenario: Prevent direct edit of sample cases
    Given the selected test case is a sample case
    When the user tries to edit that case
    Then the plugin refuses to edit it directly
    And the plugin tells the user to copy it before editing

  Scenario: Prevent deletion of sample cases
    Given the selected test case is a sample case
    When the user tries to delete that case
    Then the plugin refuses to delete it

  Scenario: Add a new custom case
    When the user adds a new custom case from the result viewer
    Then the plugin creates the next "custom-N" input and output files as empty files
    And the plugin opens those files for editing

  Scenario: Copy a case into a new custom case
    Given the selected test case exists on disk
    When the user copies that case from the result viewer
    Then the plugin creates the next "custom-N" input and output files
    And the plugin copies the selected case content into them
    And the plugin opens the new files for editing

  Scenario: Edit a custom case
    Given the selected test case is a custom case
    When the user edits that case from the result viewer
    Then the plugin opens the input and output files for that case

  Scenario: Delete a custom case after confirmation
    Given the selected test case is a custom case
    When the user confirms deletion of that case
    Then the plugin removes that case's input and output files

  Rule: The viewer keeps enough context to operate on the source file

  Scenario: Keep source context for later actions
    When the plugin updates the result viewer with a new result
    Then the viewer stores the source file path, source window context, and selected case context

  Scenario: Validate stale viewer context per action
    Given the result viewer is showing stale file or case context
    When the user triggers an action from the result viewer
    Then the plugin validates only the context required by that action
    And unrelated actions can still proceed if their required context is valid
