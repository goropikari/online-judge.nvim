# Rewriting Plan

## Goal

Rewrite the plugin to reduce orchestration and UI complexity while preserving the
user-visible workflows:

- sample download
- local test execution
- result viewer driven interaction
- submission and submit-after-test
- debug and login as auxiliary workflows

Public APIs and command shapes may change.

## Acceptance Source

- Gherkin features are the primary acceptance criteria.
- Feature files are split by end-user capability, not by implementation phase.
- Implementation phases map to subsets of those feature files.

## Key Decisions

### Scope

- Keep the main competitive-programming workflow:
  - download samples
  - run tests
  - inspect results in a dedicated viewer
  - submit
- Keep result-viewer driven operations:
  - rerun
  - submit
  - preview
  - add/edit/copy/delete custom cases
  - debug
- Drop the internal plugin-debug state dump from the maintained behavior set.

### Result Viewer

- The result viewer remains a central interaction surface.
- The viewer is not the owner of core business logic.
- The viewer delegates actions to separate use cases/services.
- The viewer is implemented as:
  - state/store
  - renderer
  - keymap/controller
- The viewer is backed by one reusable buffer.
- The viewer stores:
  - source file path
  - source window context
  - selected case context
  - latest test result
  - expanded preview state
  - cursor restoration information
  - running phase state
- Rendering is full redraw from state, not incremental text surgery.
- Line-to-meaning metadata is explicit; actions resolve from viewer structure, not by reparsing display text.
- Viewer actions are keyboard-based and configurable.
- Help is generated from the active action-to-keymap bindings and is foldable.

### Test Cases

- Test case definitions and test execution results are separate models.
- Test case identity is case-name first, with file paths as supporting data.
- Case kinds are determined by filename convention.
- Internal naming is normalized to:
  - `sample-*`
  - `custom-*`
- Downloaded sample cases are renamed into `sample-*` immediately after download.
- Existing `custom-*` cases never count as downloaded samples.
- Downloaded sample presence is determined by at least one `sample-*.in/.out` pair.
- Normal test flow does not re-download samples if sample cases already exist.
- Explicit sample refresh recreates only sample cases and preserves custom cases.
- Sample cases are read-only for edit/delete operations.
- New custom cases use `max existing custom id + 1`.
- New custom cases start as empty input/output files.
- Case editing only needs to preserve the behavior that input/output files open for editing.
- Preview truncation is display-only and must not affect case resolution.

### Test Flow

- `oj test` output is parsed into a structured, shared domain model.
- The parser lives in the test execution layer, not in the viewer.
- Parsed output keeps both:
  - structured result fields
  - raw lines when needed
- The result model is shared across:
  - viewer rendering
  - rerun
  - submit-after-test orchestration
  - debug entry
- Test-running state is explicit:
  - building
  - downloading
  - testing
  - submitting
- Failures are shown both through notifications and the viewer.
- The viewer keeps only the latest run, not history.
- Comparison settings are test-usecase concerns with setup-provided defaults and runtime overrides.

### Build / Language

- Language definitions produce execution plans.
- Build execution is handled by common runner logic.
- Execution plans include:
  - build command
  - run command
  - artifact path
  - rebuild decision inputs
- Rebuild decisions remain mtime-based.
- Build artifacts stay in plugin-managed temporary directories.
- Language definitions also provide per-service submission language IDs.
- Missing language capabilities fail per operation:
  - testing may still work without submit IDs
  - submission fails clearly if submit IDs are missing

### Source Resolution / Services

- High-level flows use resolved source context instead of reading UI state ad hoc.
- A shared `source_context_resolver` resolves file-oriented context.
- A shared `service_registry` performs online judge service matching.
- Services expose service-specific operations such as:
  - sample download
  - submit
  - login
  - problem URL helpers

### Submission

- Plain submission is independent from prior test results.
- `submit-after-test` runs the test flow first and submits after completion.
- `submit-after-test` does not require accepted test results.
- Submit failures are shown in the viewer only for the submit-after-test path.

### Debug / Login

- Debug is a separate use case invoked from the viewer.
- Debug requires:
  - source file
  - selected case
  - language-provided debug plan
- Missing debug capability fails clearly.
- Login remains service-specific and loosely coupled to the main flow.

### Async / Notifications

- High-level flows are written in async/await style.
- A thin async utility hides the implementation choice.
- Initial implementation may use `plenary.async` internally.
- The async utility also handles common UI-boundary helpers such as scheduling and command result normalization.
- Notifications go through a notifier abstraction.
- Notifier payloads are lightweight structured messages:
  - level
  - message
  - title (optional)

### Public Interface

- New public API favors high-level Lua entry points.
- Commands become thin wrappers over Lua API.
- High-level APIs default to current-buffer resolution but may accept explicit context/options.
- Setup remains centralized in `setup({ ... })`.
- Runtime-tunable test settings remain available under a grouped settings API.

## Primary Module Sketch

- `source_context_resolver`
- `service_registry`
- `language_registry` / language definitions
- `test_runner`
- `test_parser`
- `sample_manager`
- `submission_service`
- `debug_service`
- `result_viewer/store`
- `result_viewer/renderer`
- `result_viewer/controller`
- `async_util`
- `notifier`

These names are directional, not final file-structure commitments.

## Rejected Directions

- Do not keep the viewer as a monolithic owner of parsing, file mutation, and submission logic.
- Do not keep case selection based on reparsing rendered text after every UI mutation.
- Do not keep incremental buffer surgery as the primary rendering model.
- Do not force submit-after-test to require accepted test results.
- Do not preserve existing public API shape just for compatibility.
- Do not treat the existence of the test directory alone as proof that sample download already happened.

## Implementation Phases

### Phase 1

Build:

- `source_context_resolver`
- `service_registry`
- language runner foundation
- `test_parser`
- new result viewer with display + rerun

Acceptance:

- `features/test-flow.feature`
  - reject missing URL for download
  - download and normalize sample cases
  - existing custom cases do not count as downloaded samples
  - existing sample cases skip automatic re-download
  - show workflow phases while running tests
  - run tests from a source buffer
  - re-run tests from the result viewer
  - build failure stops the workflow
  - missing URL stops the workflow
  - comparison settings scenarios

Removes responsibility from old code:

- test orchestration no longer lives in `init.lua`
- parsing and viewer formatting no longer depend on the old monolithic viewer implementation

### Phase 2

Build:

- viewer preview support
- test case add/edit/copy/delete services
- viewer case operations

Acceptance:

- `features/result-viewer.feature`
  - keyboard actions are available from the viewer
  - help reflects active key bindings
  - preview toggling
  - long preview truncation behavior
  - sample protection
  - add/copy/edit/delete custom case
  - context retention and stale-context validation

Removes responsibility from old code:

- old viewer case-manipulation logic
- old preview line mutation logic

At the end of this phase, old viewer feature parity for maintained behaviors is removed.

### Phase 3

Build:

- plain submission
- submit-after-test on top of new test flow

Acceptance:

- `features/submission.feature`

Removes responsibility from old code:

- submission orchestration from `init.lua`
- submit-after-test callback chaining from old flow

### Phase 4

Build:

- debug integration on new viewer context
- service login helpers on new service layer
- public facade and config cleanup

Acceptance:

- `features/auxiliary.feature`

Removes responsibility from old code:

- old debug launch path embedded in viewer
- service-specific login wiring from old facade-heavy structure

## Review Focus Before Implementation

Before coding starts, review the plan for:

- dependency consistency between decisions
- whether each phase has a realistic vertical slice
- whether each phase maps cleanly to the feature files
