import ast
import inspect
import itertools
import unittest

import decorator
import robot.api.parsing
import robot.parsing.model
import robot.running.model
import robotidy.transformers
import functools
import typing
from robot.parsing.parser.blockparsers import TestCaseParser

"""
inspired by parsers.py SuiteBuilder(suite, FileSettings(defaults)).build(model)

model -> suite

generic visitor to know what we're missing out on

want to get comment lines separately and then add them back to the result, there's no point duplicating
the full parsing logic just to handle comments
"""

def checked_args(func: typing.Callable) -> typing.Callable:
    """Decorator to check call arguments against type-annotated parameters at runtime."""
    @functools.wraps(func)
    def inner(*args, **kwargs):
        __tracebackhide__ = True
        exc = None
        positionals = iter(args)
        for name, param in inspect.signature(func).parameters.items():
            try:
                value = kwargs[name] if name in kwargs else next(positionals)
                if param.annotation is not inspect.Parameter.empty:
                    assert isinstance(value, param.annotation), f"param {name=} is not of {param.annotation}"
            except StopIteration as e:
                # caller called us wrongly, remember the exception and actually let the call happen,
                # that should fail and be more informative than anything we may raise ourselves
                exc = e
        return func(*args, **kwargs)
        if exc:
            # this may never happen, but let's be sure not to swallow an error
            raise Exception("error while checking parameters") from exc
    return inner


class GenericVisitor(ast.NodeVisitor):
    _permitted_generic = []

    def generic_visit(self, node: ast.AST):
        print(f"generic visit {node.__class__.__name__}, {list(ast.iter_fields(node))=}")
        # if node.__class__.__name__ not in self._permitted_generic:
        #     print("\tunexpected generic visit")
        return super().generic_visit(node)

# class Another(robotidy.transformers.Transformer):
# class Another(robot.api.parsing.ModelVisitor):
class Another(GenericVisitor):
    variables = []


    def visit_Comment(self, node: robot.api.parsing.Comment):  # noqa
        print("comment", node.get_value(robot.api.parsing.Comment.type))
        return node
    def visit_CommentSection(self, node: robot.api.parsing.CommentSection):  # noqa
        print("commetsection", node.body)
        return node

    #     def visit_Variable(self, node):
    #         self.suite.resource.variables.create(name=node.name,
    #                                              value=node.value,
    #                                              lineno=node.lineno,
    #                                              error=format_error(node.errors))
    # def visit_VariableSection(self, node: robot.api.parsing.VariableSection):
    #     print("variablesection", node.body)
    #     for n in node.body:
    #         if isinstance(n, robot.api.parsing.Variable):
    #             self.variables.append(robot.running.model.Variable(n.name, n.value))
    #             # print("variable", n.name, n.value)
    #     return node
    # def visit_KeywordSection(self, node):  # noqa
    #     print("keyword")
    #     return node
    #
    # def visit_TestCaseSection(self, node: robot.api.parsing.TestCaseSection):
    #     print("testcasesection")
    #     test_cases = TestCaseParser().parse(node.body)
    #
    # def visit_TestCase(self, node: robot.api.parsing.TestCase):
    #     print(f"test case, {node.name}")
    #     for b in node.body:
    #         self.visit(b)
    #     return



    def visit_InvalidSection(self, node: ast.AST):
        raise Exception(f"invalid section, {node}")


class TestCaseParser(GenericVisitor):
    def parse(self, nodes: list[ast.AST]):
        for node in nodes:
            self.visit(node)

    @checked_args
    def visit_TestCase(self, node: robot.api.parsing.TestCase):  # noqa
        print(f"testcase {node.name=}, {node.header=}")
        for stmt in node.body:
            self.visit(stmt)
        return node

    def visit_KeywordCall(self, node: robot.api.parsing.KeywordCall):  # noqa
        print(f"keywordcall {node.keyword=}, {node.get_value(robot.api.parsing.Comment.type)}")
        return node


class TestChecked(unittest.TestCase):
    def test_wrong(self):

        @checked_args
        def f(a):
            pass

        f()
