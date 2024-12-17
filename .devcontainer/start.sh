#!/bin/bash

# devcontainer up --workspace-folder=. --remove-existing-container
devcontainer up --workspace-folder=.
devcontainer exec --workspace-folder=. bash
