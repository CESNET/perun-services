See general guidelines for [contributing to Perun AAI](https://gitlab.ics.muni.cz/perun/common/-/blob/main/CONTRIBUTING.md).

In addition:
- For perl sources:
  - Use `use strict` and `use warnings`.
  - Use own global variables with caution (key word `our`).
  - For defined global variables (e.g. formatting ones `$`, `$"`, ...) always use `local`.
  - Brackets for function calls are not necessary, if it doesn't hurt code readability.
  - Code commenting - the more, the better. For each function we comment input, output a how does it modify global variables (if used).
  - `man perlstyle`
- For Python sources:
  - lint and format your code with [ruff](https://docs.astral.sh/ruff/)
  - add names of new Python files into the `PYTHON_FILES` variable in `.gitlab-ci.yml`
