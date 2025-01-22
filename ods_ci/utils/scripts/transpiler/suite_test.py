import inspect
import pathlib
import pickle
import pprint
import unittest

import robot.api
import robot.api.interfaces

# https://libcst.readthedocs.io/en/latest/tutorial.html#Generate-Source-Code
import libcst as cst
import libcst.codegen

from . import transpiler

# import ufmt

import robotidy.transformers

class Transpiler(robot.api.SuiteVisitor):
    def __init__(self):
        pass

    # def visit_suite(self, suite):
    #     print('Visiting suite')

    # def visit_test(self, test: robot.api.interfaces.running.TestCase):
    #     print(test.name)
    #     print('Visiting test')
    #     if test.has_setup:
    #         test.setup.visit(self)
    #     test.body.visit(self)
    #     if test.has_teardown:
    #         test.teardown.visit(self)
    #     return "baf"

    def visit_CommentSection(self, node):  # noqa
        print("commetsection")


class SuiteTest(unittest.TestCase):
    def test_transpile_suite(self):
        visitor = Transpiler()

        string = """
*** Test Cases ***
User can create an account and log in
    Create Valid User    fred    P4ssw0rd
    Attempt to Login with Credentials    fred    P4ssw0rd
    Status Should Be    Logged In

User cannot log in with bad password
    # comment
    Create Valid User    betty    P4ssw0rd
    Attempt to Login with Credentials    betty    wrong
    Status Should Be    Access Denied
        """

        suite = robot.api.TestSuite.from_string(string)
        suite.visit(visitor)

        model = robot.api.get_model(string)

        # pprint.pprint({k: getattr(suite, k) for k in dir(suite)})
        # pprint.pprint(better_repr(model, visited=set()))

        # another = Another()
        # another.visit(model)

    def test_cst(self):
        sample = cst.parse_module("3 + 4")
        print(sample)
        code = cst.Module([
            cst.SimpleStatementLine([
                cst.Expr(
                    cst.BinaryOperation(cst.Integer("1"), cst.Add(), cst.Integer("2"))
                )])])
        print(code.code)
        # code.with_changes()


    def test_transpilatorer(self):
        string = """
*** Test Cases ***
User can create an account and log in
    Create Valid User    fred    P4ssw0rd
    Attempt to Login with Credentials    fred    P4ssw0rd  # line comment
    Status Should Be    Logged In

User cannot log in with bad password
    # comment
    Create Valid User    betty    P4ssw0rd
    Attempt to Login with Credentials    betty    wrong
    Status Should Be    Access Denied
        """

        visitor = transpiler.Another()
        model = robot.api.get_model(string)
        visitor.visit(model)

    def test_transpilatorer_some_actual(self):
        visitor = transpiler.Another()
        model = robot.api.get_model(pathlib.Path('/Users/jdanek/IdeaProjects/ods-ci/ods_ci/tests/Tests/0500__ide/0501__ide_jupyterhub/autoscaling-gpus.robot'))
        visitor.visit(model)

def better_repr(obj, visited: set):
    if isinstance(obj, (int, str, float, bool)):
        return repr(obj)
    if inspect.isfunction(obj) or inspect.ismethod(obj) or inspect.isbuiltin(obj) or inspect.ismethodwrapper(obj):
        return repr(obj)
    if inspect.isclass(obj):
        return repr(obj)
    if obj is None:
        return repr(obj)
    if id(obj) in visited:
        return repr(obj)
    if not inspect.isbuiltin(obj):
        # print(obj)
        result = repr({k: better_repr(getattr(obj, k), visited={*visited, id(obj)}) for k in dir(obj)
                       if k not in ('self', 'cls', '__abstractmethods__', '__annotations__')})
        return result
    return repr(obj)
