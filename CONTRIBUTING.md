# Contributing to Perun AAI

## General guidelines

See general guidelines for [contributing to Perun AAI](https://gitlab.ics.muni.cz/perun/common/-/blob/main/CONTRIBUTING.md).

Additional rules are outlined in this document.

## Commit Message Guidelines

Use the name of the service as the conventional commit message scope where applicable.

### Breaking Changes

Use `BREAKING CHANGE:`

- for new required configuration (e.g. OIDC configuration)
- whenever a name of a service changes

## Code style

### Perl

- use `use strict` and `use warnings`
- use own global variables with caution (key word `our`)
- always use `local` for defined global variables (e.g. `$`, `$"`, ...)
- brackets for function calls are not necessary if it doesn't hurt code readability
- comment your code - the more, the better
  - for each function comment input, output
    and how does it modify global variables (if used)
  - see `man perlstyle`

### Python

- lint and format your code with [ruff](https://docs.astral.sh/ruff/)
- add names of new Python files into the `PYTHON_FILES` variable in `.gitlab-ci.yml`
