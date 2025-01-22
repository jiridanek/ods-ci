# The Transpiler package transpiles your Robot Framework tests to pure Python

## Implementation

A `robotidy.Translator` that goes through the files.

Suite does not have the comments present, so it becomes impossible to preserve them in the generated code

A `robot.api.SuiteVisitor` that goes through a suite and produces equivalent Python code.

See `../fetch_tests.py` for a short script that uses the same functionality to list all Robot test names in the suite.

## Design choices

* https://docs.python.org/3.11/library/ast.html#ast.unparse
* https://libcst.readthedocs.io/en/latest/index.html (Guido mentions in https://www.youtube.com/watch?v=atSMXLwtIBo&t=139s)
* https://astor.readthedocs.io/en/latest/

## Limitations

This package was developed to transpile the ods-ci test suite at a particular point of time with a particular Robot Framework version.
It is likely that after the test migration si completed, the transpiling code will fall into disrepair.
