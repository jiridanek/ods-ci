# Robot Framework to Python/JavaScript Transpiler

This transpiler converts Robot Framework test suites and keywords into equivalent Python or JavaScript code.

## Overview

The transpiler is designed to bridge the gap between Robot Framework test automation and traditional programming languages, allowing tests to be run as native Python or JavaScript code.

## Architecture

### Core Components

1. **SuiteRunner** (`transpiler.py`): Main transpiler engine that processes Robot Framework test suites
2. **PyCodeWriter** (`py_code_writer.py`): Generates Python code from transpiled Robot Framework constructs
3. **JSCodeWriter** (`js_code_writer.py`): Generates JavaScript code from transpiled Robot Framework constructs
4. **CodeWriterUtils** (`code_writer_utils.py`): Utility functions for formatting and code generation

### Key Features

- **Multi-language Support**: Can transpile to both Python and JavaScript
- **Test Suite Processing**: Handles complete Robot Framework test suites including imports, variables, keywords, and test cases
- **Variable Management**: Properly handles Robot Framework variables and their scope
- **Control Flow Translation**: Converts Robot Framework control structures (IF/ELSE, FOR loops, WHILE, TRY/CATCH) to target language equivalents
- **Keyword Translation**: Converts Robot Framework keywords to functions/methods

## Usage

### Basic Usage

```python
from transpiler import SuiteRunner
from robot.running import TestSuiteBuilder

# Build Robot Framework test suite
builder = TestSuiteBuilder()
testsuite = builder.build("path/to/test_suite.robot")

# Create transpiler
runner = SuiteRunner(testsuite)
runner.run()

# Get generated Python code
python_code = runner.get_python_code()
```

### JavaScript Output

```python
from transpiler import SuiteRunner
from js_code_writer import JSCodeWriter

# Create transpiler with JavaScript output
runner = SuiteRunner(testsuite, writer_class=JSCodeWriter)
runner.run()
```

## Transpilation Details

### Variable Handling

Robot Framework variables are converted as follows:
- `${variable}` → `variable` (Python/JavaScript variable)
- `@{list}` → `list` (array variable)
- `&{dict}` → `dict` (object/dictionary variable)

### Control Flow Translation

| Robot Framework           | Python                | JavaScript                       |
|---------------------------|-----------------------|----------------------------------|
| `IF condition`            | `if condition:`       | `if (condition) {`               |
| `ELSE IF condition`       | `elif condition:`     | `else if (condition) {`          |
| `ELSE`                    | `else:`               | `else {`                         |
| `FOR ${item} IN @{items}` | `for item in items:`  | `for (let item of items) {`      |
| `FOR ${i} IN RANGE 10`    | `for i in range(10):` | `for (let i = 0; i < 10; i++) {` |
| `WHILE condition`         | `while condition:`    | `while (condition) {`            |

### Keyword Translation

Robot Framework keywords are converted to functions:

```robot
*** Keywords ***
Login To System
    [Arguments]    ${username}    ${password}
    Input Text    id=username    ${username}
    Input Text    id=password    ${password}
    Click Button    id=login
```

Becomes Python:
```python
def login_to_system(username, password):
    input_text("id=username", username)
    input_text("id=password", password)
    click_button("id=login")
```

## Limitations

1. **Library Support**: Only specific Robot Framework libraries are supported for import
2. **Complex Expressions**: Some complex Robot Framework expressions may not transpile correctly
3. **Custom Libraries**: Custom Robot Framework libraries need manual implementation in target language
4. **Resource Files**: Resource file imports are processed but may require additional configuration

## Supported Libraries

The transpiler skips these Python-implemented libraries (as they're already available):
- OperatingSystem
- OpenShiftLibrary
- String
- Process
- yaml
- Collections
- SeleniumLibrary
- RequestsLibrary
- DateTime
- Screenshot

## Testing

Run the test suite:
```bash
python -m pytest test_transpiler.py
```

## Development

### Adding New Language Support

To add support for a new target language:

1. Create a new code writer class inheriting from `PyCodeWriter`
2. Override methods for language-specific syntax
3. Implement the `format_argument` class method for argument formatting
4. Update control flow methods (if, for, while, etc.)

### Extending Functionality

The transpiler can be extended by:
- Adding new variable types in `format_variable`
- Supporting additional Robot Framework constructs
- Implementing missing library functions
- Adding new control flow patterns

## Examples

### Simple Test Case

Robot Framework:
```robot
*** Test Cases ***
Example Test
    ${result}=    Calculate    2    2
    Should Be Equal    ${result}    4
```

Python output:
```python
def test_example_test():
    result = calculate(2, 2)
    should_be_equal(result, 4)
```

### Complex Control Flow

Robot Framework:
```robot
*** Test Cases ***
Complex Test
    FOR    ${item}    IN    @{items}
        IF    ${item} > 10
            Log    Item is greater than 10
        ELSE
            Log    Item is 10 or less
        END
    END
```

Python output:
```python
def test_complex_test():
    for item in items:
        if item > 10:
            log("Item is greater than 10")
        else:
            log("Item is 10 or less")
```

## File Structure

```
transpiler/
 ├── init.py # Package initialization
 ├── transpiler.py # Main transpiler engine (SuiteRunner)
 ├── py_code_writer.py # Python code generation
 ├── js_code_writer.py # JavaScript code generation
 ├── code_writer_utils.py # Utility functions
 ├── test_transpiler.py # Unit tests
 └── README.md # This file
```

## Notes

- The transpiler uses Robot Framework's internal APIs for parsing and analysis
- Generated code requires the corresponding test libraries to be implemented in the target language
- Variable interpolation and string formatting are handled during transpilation
- The transpiler maintains Robot Framework's execution semantics where possible

## Limitations

This package was developed to transpile the ods-ci test suite at a particular point of time with a particular Robot Framework version.
It is likely that after the test migration is completed, the transpiling code will fall into disrepair.
