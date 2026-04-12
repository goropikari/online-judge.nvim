.PHONY: fmt
fmt:
	stylua -g '*.lua' -- .

.PHONY: lint
lint:
	typos -w

.PHONY: check
check: lint fmt

.PHONY: test
test:
	nvim --headless -u tests/minimal_init.lua \
	-c "PlenaryBustedDirectory lua/spec/online-judge { minimal_init = 'tests/minimal_init.lua' }" \
	-c qa

.PHONY: up
up:
	devcontainer up --workspace-folder=.

.PHONY: up-new
up-new:
	devcontainer up --workspace-folder=. --remove-existing-container

.PHONY: exec
exec:
	devcontainer exec --workspace-folder=. bash
