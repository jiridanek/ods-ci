import re
import string

from .py_code_writer import PyCodeWriter
from .code_writer_utils import format_string, format_assignment


class JSCodeWriter(PyCodeWriter):
    def __init__(self):
        super().__init__()

    def has_defined(self, var: str):
        for level in self.scope:
            if var in level:
                return True
        return False

    def add(self, line: str):
        self.buffer.write((" " * 4 * self.indent) + line + "\n")

    # this is not tracking scope of the Robot variable and assumes that
    # if it could've been the one in scope, then we do mean that one
    def add_assignment(self, assign: list[str], rhs):
        vars = [format_assignment(arg) for arg in assign]
        lhs = ', '.join(vars)

        if all(self.has_defined(var) for var in vars):
            keyword = ""
        else:
            keyword = "let "

        if len(assign) == 1:
            self.add(f"{keyword}{lhs} = {rhs}")
        else:
            self.add(f"{keyword}[{lhs}] = {rhs}")
        self.scope[-1].extend(vars)

    def begin(self, line: str):
        super().begin(line)

    def begin_test(self, name: str):
        self.begin_function(name, [])

    def begin_function(self, name: str, parameters: list[str]):
        self.begin(f"function {name}({', '.join(parameters)}) {{")

    def begin_if(self, condition: str):
        self.begin(f"if ({condition}) {{")

    def begin_elif(self, condition: str):
        self.begin(f"else if ({condition}) {{")

    def begin_else(self):
        self.begin(f"else {{")

    def begin_for_in(self, variables: list[str], values: list[str]):
        vars = ', '.join(variables)
        if len(variables) > 1:
            vars = f"[{vars}]"
        vals = ', '.join(values)
        self.begin(f"for (let {vars} of {vals}) {{")

    def begin_for_enumerate(self, variables: list[str], values: list[str], start: int | None):
        """https://stackoverflow.com/questions/10179815/get-loop-counter-index-using-for-of-syntax-in-javascript"""
        vars = ', '.join(variables)
        if len(variables) > 1:
            vars = f"[{vars}]"
        vals = ', '.join(values)
        if start:
            self.begin(f"for (let {vars} of enumerate({vals}, start={start})) {{")
        else:
            self.begin(f"for (let {vars} of enumerate({vals})) {{")

    def begin_for_range(self, variables: list[str], values: list[str]):
        assert len(variables) == 1, variables
        if len(values) == 1:
            values = [0] + [values[0]]
        if len(values) == 2:
            values.append(1)
        assert len(values) == 3, values
        self.begin(f"for (let {variables[0]} = {values[0]}; {variables[0]} < {values[1]}; {variables[0]} += {values[2]}) {{")

    def end(self):
        super().end()
        self.add("}")

    def print(self):
        print(self.buffer.getvalue())

    @classmethod
    def format_argument(cls, value: str) -> str:
        if not value:
            return value
        if re.match(r'^[$@]\{[^{]+}$', value):
            return value[2:-1]
        if re.search(r'[$@]\{', value):
            fstring = value.replace("@{", "${").replace("&{", "${")
            return "`" + fstring + "`"
        # properly quoted string, todo: need to add negative lookbehind for the final quote must not be escaped
        if re.match(r'''^(?P<q>["']) ( (\\(?P=q)) | ( . (?! (?P=q) ) ) )* (?P=q)$''', value, re.VERBOSE):
            return value
        if all(x in string.digits for x in value):
            return value
        return format_string(value)
