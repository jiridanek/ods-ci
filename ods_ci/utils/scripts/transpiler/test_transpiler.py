import ast
import itertools
import pathlib
import shutil
import unittest

import robot.api
from robot.running import TestSuiteBuilder

from ..fetch_new_tests import extract_test_cases_from_ref
from .js_code_writer import JSCodeWriter
from .transpiler import SuiteRunner


class TestNamePrinter(ast.NodeVisitor):

    def visit_File(self, node):
        print(f"File '{node.source}' has following tests:")
        # Must call `generic_visit` to visit also child nodes.
        self.generic_visit(node)

    def visit_TestCaseName(self, node):
        print(f"- {node.name} (on line {node.lineno})")


# want test suite builder, I guess, and want to reimplement the runner, pretty much
class TestTranspiler(unittest.TestCase):
    def test_get_tests(self):
        a, b = extract_test_cases_from_ref("/Users/jdanek/IdeaProjects/ods-ci/ods_ci", None)
        print(a, b)

    def test_ast(self):
        import robot.api
        model = robot.api.get_model(
            "/Users/jdanek/IdeaProjects/ods-ci/ods_ci/tests/Tests/0500__ide/0501__ide_jupyterhub/image-iteration.robot")
        print(model)
        printer = TestNamePrinter()
        printer.visit(model)
        print(model.sections[0])
        print(ast.dump(model))

    def test_build_suite(self):
        REPO_ROOT = pathlib.Path(__file__).parent.parent.parent.parent.parent
        builder = TestSuiteBuilder()
        # testsuite = builder.build(REPO_ROOT / "ods_ci" / "tests/")
        testsuite = builder.build(REPO_ROOT / "ods_ci")

        # testsuite.run()

        runner = SuiteRunner(testsuite, )
        runner.run()
        code = runner.code
        assert len(code) > 42

        path = pathlib.Path("expected_result.txt")
        # path.write_text(code)
        if path.exists():
            expected_result = path.read_text()
            assert sorted(expected_result.splitlines()) == sorted(code.splitlines())
        else:
            raise FileNotFoundError(path)

        # print(code)

    def test_build_js_suite(self):
        REPO_ROOT = pathlib.Path(__file__).parent.parent.parent.parent.parent
        builder = TestSuiteBuilder()
        # testsuite = builder.build(REPO_ROOT / "ods_ci" / "tests/")
        testsuite = builder.build(REPO_ROOT / "ods_ci")

        # testsuite.run()

        runner = SuiteRunner(testsuite, JSCodeWriter)
        runner.run()
        code = runner.code
        assert len(code) > 42

        base = pathlib.Path(__file__).parent.parent.parent.parent.resolve().absolute()

        output = pathlib.Path("./output").absolute()

        shutil.rmtree(output, ignore_errors=True)
        output.mkdir(parents=True, exist_ok=True)

        for cf, f in runner.code_files.items():
            if pathlib.Path(cf).is_relative_to(base):
                rel = output / pathlib.Path(cf).relative_to(base)
                print(rel)
                if not rel.name.endswith(".robot") and not rel.name.endswith(".resource"):
                    continue
                rel = rel.with_suffix(rel.suffix + ".js")
                # if not rel.parent.exists():
                rel.parent.mkdir(parents=True, exist_ok=True)
                text = '\n\n'.join(itertools.chain([f.constants], f.keywords.values(), f.test_methods))
                rel.write_text(text)
                # print(text)

        return

        path = pathlib.Path("expected_result_js.txt")
        content = []
        for file, text in code.items():
            content.append(f"// ***** {file} **** \n\n {text}")
        expected = '\n'.join(content)
        path.write_text(expected)
        if path.exists():
            pass
            # expected_result = path.read_text()
            # asserting on the full strings takes too long to calculate diff
            # assert expected_result.splitlines() == expected.splitlines()
        else:
            raise FileNotFoundError(path)

        # print(code)

    def test_quickstart_example1(self):
        """https://github.com/robotframework/QuickStartGuide/blob/master/QuickStart.rst#workflow-tests"""
        sources = """*** Test Cases ***
User can create an account and log in
    Create Valid User    fred    P4ssw0rd
    Attempt to Login with Credentials    fred    P4ssw0rd
    Status Should Be    Logged In

User cannot log in with bad password
    Create Valid User    betty    P4ssw0rd
    Attempt to Login with Credentials    betty    wrong
    Status Should Be    Access Denied"""

        testsuite = robot.api.TestSuite.from_string(sources)
        runner = SuiteRunner(testsuite, )
        runner.run()

        assert runner.code_generated_test_methods[""] == """def test_user_can_create_an_account_and_log_in():
    create_valid_user('fred', 'P4ssw0rd')
    attempt_to_login_with_credentials('fred', 'P4ssw0rd')
    status_should_be('Logged In')


def test_user_cannot_log_in_with_bad_password():
    create_valid_user('betty', 'P4ssw0rd')
    attempt_to_login_with_credentials('betty', 'wrong')
    status_should_be('Access Denied')
"""

    def test_quickstart_parameterized1(self):
        """https://github.com/robotframework/QuickStartGuide/blob/master/QuickStart.rst#data-driven-tests"""
        sources = """*** Test Cases ***
Invalid password
    [Template]    Creating user with invalid password should fail
    abCD5            ${PWD INVALID LENGTH}
    abCD567890123    ${PWD INVALID LENGTH}
    123DEFG          ${PWD INVALID CONTENT}
    abcd56789        ${PWD INVALID CONTENT}
    AbCdEfGh         ${PWD INVALID CONTENT}
    abCD56+          ${PWD INVALID CONTENT}
"""

        testsuite = robot.api.TestSuite.from_string(sources)
        runner = SuiteRunner(testsuite, )
        runner.run()

    def test_quickstart_userkeywords1(self):
        """https://github.com/robotframework/QuickStartGuide/blob/master/QuickStart.rst#user-keywords"""
        sources = """*** Keywords ***
Clear login database
    Remove file    ${DATABASE FILE}

Create valid user
    [Arguments]    ${username}    ${password}
    Create user    ${username}    ${password}
    Status should be    SUCCESS

Creating user with invalid password should fail
    [Arguments]    ${password}    ${error}
    Create user    example    ${password}
    Status should be    Creating user failed: ${error}

Login
    [Arguments]    ${username}    ${password}
    Attempt to login with credentials    ${username}    ${password}
    Status should be    Logged In

# Keywords below used by higher level tests. Notice how given/when/then/and
# prefixes can be dropped. And this is a comment.

A user has a valid account
    Create valid user    ${USERNAME}    ${PASSWORD}

She changes her password
    Change password    ${USERNAME}    ${PASSWORD}    ${NEW PASSWORD}
    Status should be    SUCCESS

She can log in with the new password
    Login    ${USERNAME}    ${NEW PASSWORD}

She cannot use the old password anymore
    Attempt to login with credentials    ${USERNAME}    ${PASSWORD}
    Status should be    Access Denied"""

        testsuite = robot.api.TestSuite.from_string(sources)
        runner = SuiteRunner(testsuite, )
        runner.run()


def test_named_args():
    sources = """*** Test Cases ***
Verify something
    Perform Dashboard API Endpoint PUT Call   endpoint=${CM_ENDPOINT_PT0}
    Run Query And Check Output    query_code=${QUERY_CATALOGS_PY}
    ...    expected_output=['system' 'tpch']"""
    testsuite = robot.api.TestSuite.from_string(sources)
    runner = SuiteRunner(testsuite, )
    runner.run()

    assert runner.code_generated_test_methods[""] == """def test_verify_something():
    perform_dashboard_api_endpoint_put_call(endpoint=CM_ENDPOINT_PT0)
    run_query_and_check_output(query_code=QUERY_CATALOGS_PY, expected_output="['system' 'tpch']")
"""
