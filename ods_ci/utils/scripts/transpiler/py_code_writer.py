import io
import re
import string

from .code_writer_utils import format_string, format_assignment


class PyCodeWriter():
    def __init__(self):
        self.buffer = io.StringIO()
        self.scope: list[list[str]] = [[]]

    @property
    def indent(self) -> int:
        return len(self.scope) - 1

    def add(self, line: str):
        self.buffer.write((" " * 4 * self.indent) + line + "\n")

    def add_assignment(self, assign: list[str], rhs):
        lhs = ', '.join([format_assignment(arg) for arg in assign])
        self.add(f"{lhs} = {rhs}")

    def begin(self, line: str):
        self.add(line)
        self.scope.append([])

    def begin_test(self, name: str):
        self.begin_function(name, [])

    def begin_function(self, name: str, parameters: list[str]):
        self.begin(f"def {name}({', '.join(parameters)}):")

    def begin_if(self, condition: str):
        self.begin(f"if {condition}:")

    def begin_elif(self, condition: str):
        self.begin(f"elif {condition}:")

    def begin_else(self):
        self.begin(f"else:")

    def begin_for_in(self, variables: list[str], values: list[str]):
        self.begin(f"for {', '.join(variables)} in {', '.join(values)}:")

    def begin_for_enumerate(self, variables: list[str], values: list[str], start: int | None):
        if start:
            self.begin(f"for {', '.join(variables)} in enumerate({', '.join(values)}, start={start}):")
        else:
            self.begin(f"for {', '.join(variables)} in enumerate({', '.join(values)}):")

    def begin_for_range(self, variables: str, values: str):
        """https://stackoverflow.com/questions/10179815/get-loop-counter-index-using-for-of-syntax-in-javascript"""
        self.begin(f"for {', '.join(variables)} in range({', '.join(values)}):")

    def end(self):
        self.scope.pop()

    def print(self):
        print(self.buffer.getvalue())

    @classmethod
    def format_argument(cls, value: str) -> str:
        if not value:
            return value
        if re.match(r'^[$@]\{[^{]+}$', value):
            return value[2:-1]
        if re.search(r'[$@]\{', value):
            fstring = value.replace("${", "{").replace("@{", "{")
            return "f" + format_string(fstring)
        # properly quoted string, todo: need to add negative lookbehind for the final quote must not be escaped
        if re.match(r'''^(?P<q>["']) ( (\\(?P=q)) | ( . (?! (?P=q) ) ) )* (?P=q)$''', value, re.VERBOSE):
            return value
        if all(x in string.digits for x in value):
            return value
        return format_string(value)
