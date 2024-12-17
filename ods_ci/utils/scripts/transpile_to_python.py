#!/usr/bin/env python3

"""
Examples
Input:
poetry run ods_ci/utils/scripts/fetch_tests.py --test-repo git@github.com:red-hat-data-services/ods-ci.git --ref1 releases/2.8.0 --ref2-auto true --selector-attribute creatordate -A new-arg-file.txt
Output:
---| Computing differences |----
Done. Found 30 new tests in releases/2.8.0 which were not present in origin/releases/2.7.0

Input:
poetry run ods_ci/utils/scripts/fetch_tests.py --test-repo git@github.com:red-hat-data-services/ods-ci.git --ref1 master  --ref2-auto true --selector-attribute creatordate -A new-arg-file.txt
Output:
---| Computing differences |----
Done. Found 14 new tests in master which were not present in origin/releases/2.9.0

"""

import argparse
import io
import os
import pathlib
import re
import shutil
import unittest
import unittest.mock

import robot.running.namespace
from robot.model import SuiteVisitor
from robot.running import TestSuiteBuilder
import robot.variables.scopes
import robot.conf.settings
import robot.api.parsing
import robot.api.interfaces
import robot.running.model

from ods_ci.utils.scripts.util import execute_command


class TestCasesFinder(SuiteVisitor):
    def __init__(self):
        self.tests = []

    def visit_test(self, test):
        self.tests.append(test)


def get_repository(test_repo):
    """
    If $test_repo is a remote repo, the function clones it in "ods-ci-temp" directory.
    If $test_repo is a local path, the function checks the path exists.
    """
    repo_local_path = "./ods_ci/ods-ci-temp"
    cloned = False
    if "http" in test_repo or "git@" in test_repo:
        print("Cloning repo ", test_repo)
        cloned = True
        execute_command(f"git clone {test_repo} {repo_local_path}")
    elif not os.path.exists(test_repo):
        raise FileNotFoundError(f"local path {test_repo} was not found")
    else:
        print("Using local repo ", test_repo)
        repo_local_path = test_repo
    return repo_local_path, cloned


def checkout_repository(ref):
    """
    Checkouts the repository at current directory to the given branch/commit ($ref)
    """
    execute_command(f"git checkout {ref}")
    execute_command("git checkout")


def get_branch(ref_to_exclude, selector_attribute):
    """
    List the remote branches and sort by selector_attribute date (ASC order), exclude $ref_to_exclude and get latest
    """
    ref_to_exclude_esc = ref_to_exclude.replace("/", r"\/")
    cmd = f"git branch -r --sort={selector_attribute} | grep releases/"
    if "master" not in ref_to_exclude and "main" not in ref_to_exclude:
        cmd += rf" | sed  's/.*{ref_to_exclude_esc}$/current/g' |  grep -zPo '[\S\s]+(?=current)'"
    ret = execute_command(cmd)
    branches = ret.split(" ")
    branch = branches[-1].split("\x00")[0].strip().replace("\n", "")
    if not branch or "fatal:" in branch:
        raise Exception("Failed to auto-selecting ref_2 branch.")
    print(f"Done. {branch} branch selected as ref_2")
    return branch


def extract_test_cases_from_ref(repo_local_path, ref, auto=False, selector_attribute=None, ref_to_exclude=None):
    """
    Navigate to the $test_repo directory, checkouts the target branch/commit ($ref) and extracts
    the test case titles leveraging RobotFramework TestSuiteBuilder() and TestCasesFinder() classes
    """
    curr_dir = os.getcwd()
    try:
        os.chdir(repo_local_path)
        if auto:
            print("\n---| Auto-selecting ref_2 branch")
            ref = get_branch(ref_to_exclude, selector_attribute)
        print(f"\n---| Extracting test cases from {ref} branch/commit |---")
        # checkout_repository(ref)
        builder = TestSuiteBuilder()
        testsuite = builder.build("tests/")
        finder = TestCasesFinder()
        tests = []
        testsuite.visit(finder)
        for test in finder.tests:
            # print (f'"{test.tags}"') # for future reference in order to fetch test tags
            tests.append(test.name)
        print(f"\nDone. Found {len(tests)} test cases")
    except Exception as err:
        print(err)
        os.chdir(curr_dir)
        raise
    os.chdir(curr_dir)
    return tests, ref


def generate_rf_argument_file(tests, output_filepath):
    """
    Writes the RobotFramework argument file containing the test selection args
    to include the extracted new tests in previous stage of this script.
    """
    content = ""
    for testname in tests:
        content += f"--test {testname.strip()}\n"
    try:
        with open(output_filepath, "w") as argfile:
            argfile.write(content)
    except Exception as err:
        print("Failed to generate argument file")
        print(err)


def extract_new_test_cases(test_repo, ref_1, ref_2, ref_2_auto, selector_attribute, output_argument_file):
    """
    Wrapping function for all the new tests extraction stages.
    """
    repo_local_path, cloned = get_repository(test_repo)
    tests_1, _ = extract_test_cases_from_ref(repo_local_path, ref_1)
    tests_2, ref_2 = extract_test_cases_from_ref(repo_local_path, ref_2, ref_2_auto, selector_attribute, ref_1)
    print("\n---| Computing differences |----")
    new_tests = list(set(tests_1) - set(tests_2))
    if len(new_tests) == 0:
        print(f"[WARN] Done. No new tests found in {ref_1} with respect to {ref_2}!")
        print("Skip argument file creation")
    else:
        print(f"Done. Found {len(new_tests)} new tests in {ref_1} which were not present in {ref_2}")
        if output_argument_file is not None:
            print("\n---| Generating RobotFramework arguments file |----")
            generate_rf_argument_file(new_tests, output_argument_file)
            print("Done.")
    if cloned:
        print(f"\n---| Deleting cloned repo in {repo_local_path} |----")
        shutil.rmtree(repo_local_path)


class Args(argparse.Namespace):
    output_argument_file: argparse.FileType('w')
    test_repo: str


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        usage=argparse.SUPPRESS,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Script to fetch newly added test cases",
    )

    parser.add_argument(
        "-A",
        "--output-argument-file",
        help="generate argument file for RobotFramework to include test cases. It expects to receive a file path",
        action="store",
        dest="output_argument_file",
        default=None,
    )
    parser.add_argument(
        "--test-repo",
        help="ODS-CI repository. It accepts either local path or URL",
        action="store",
        dest="test_repo",
        default="https://github.com/red-hat-data-services/ods-ci",
    )

    args = parser.parse_args()

    extract_new_test_cases(
        args.test_repo,
        args.ref_1,
        args.ref_2,
        args.ref_2_auto,
        args.selector_attribute,
        args.output_argument_file,
    )

import ast


class TestNamePrinter(ast.NodeVisitor):

    def visit_File(self, node):
        print(f"File '{node.source}' has following tests:")
        # Must call `generic_visit` to visit also child nodes.
        self.generic_visit(node)

    def visit_TestCaseName(self, node):
        print(f"- {node.name} (on line {node.lineno})")


# want test suite builder, I guess, and want to reimplement the runner, pretty much
class TestGetSuite(unittest.TestCase):
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
        REPO_ROOT = pathlib.Path(__file__).parent.parent.parent.parent
        builder = TestSuiteBuilder()
        # testsuite = builder.build(REPO_ROOT / "ods_ci" / "tests/")
        testsuite = builder.build(REPO_ROOT / "ods_ci")

        # testsuite.run()

        runner = SuiteRunner(testsuite)
        runner.run()
        code = runner.get_python_code()
        assert len(code) > 42

        print(code)

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
        runner = SuiteRunner(testsuite)
        runner.run()

        assert runner.get_python_code() == """def User_can_create_an_account_and_log_in():
    Create_Valid_User('fred', 'P4ssw0rd')
    Attempt_to_Login_with_Credentials('fred', 'P4ssw0rd')
    Status_Should_Be('Logged In')


def User_cannot_log_in_with_bad_password():
    Create_Valid_User('betty', 'P4ssw0rd')
    Attempt_to_Login_with_Credentials('betty', 'wrong')
    Status_Should_Be('Access Denied')
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
        runner = SuiteRunner(testsuite)
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
        runner = SuiteRunner(testsuite)
        runner.run()



def format_functionname(name: str) -> str:
    name = name.lower()
    name = name.translate(str.maketrans(' -', '__', '"'))
    return name

def format_assignment(value: str) -> str:
    if (m := re.match(r'^[$@&]\{([^{]+)}\s*=?\s*$', value)) is not None:
        return m.group(1)
    raise ValueError(value)

def format_variable(value: str) -> str:
    """variable or actually a variable expression

    such as `@{DICTIONARY}[classifiers]`
    """
    if (m := re.match(r'^[$@&]\{([^{]+)}(.*)$', value)) is not None:
        return m.group(1) + m.group(2)
    raise ValueError(value)

def format_argument(value: str) -> str:
    if not value:
        return value
    if re.match(r'^[$@]\{[^{]+}$', value):
        return value[2:-1]
    if re.search(r'[$@]\{', value):
        return "f'" + value.replace("${", "{").replace("@{", "{") + "'"
    if value[0] in ("'", '"'):
        return value
    return f"'{value}'"

def format_condition(expression: str) -> str:
    # negative lookahead for escaped $, todo: add this everywhere, and single regex?
    expression = re.sub(r'(?!\\)[$&@]\{([^}]+)}', r'\1', expression)
    expression = re.sub(r'(?!\\)[$&@](\w+)', r'\1', expression)
    return expression

class CodeWriter():
    def __init__(self):
        self.buffer = io.StringIO()
        self.indent = 0

    def begin(self, line: str):
        self.buffer.write((" " * 4 * self.indent) + line + "\n")
        self.indent += 1

    def add(self, line: str):
        self.buffer.write((" " * 4 * self.indent) + line + "\n")

    def end(self):
        self.indent -= 1

    def print(self):
        print(self.buffer.getvalue())


class SuiteRunner(SuiteVisitor):
    def __init__(self, testsuite: robot.running.model.TestSuite):
        self.testsuite = testsuite

        self.usedkeywords = set()
        self.userkeywords = {}
        self.generated_test_methods: list[str] = []

    def get_python_code(self) -> str:
        code = ""
        for kw in self.usedkeywords:
            if kw in self.userkeywords:
                if code:
                    code += "\n\n"
                code += self.userkeywords[kw]
            else:
                print(f"keyword not found in userdefined {kw}")
        if code:
            code += "\n\n"
        code += '\n\n'.join(self.generated_test_methods)

        return code

    def run(self):
        self.testsuite.visit(self)

    def start_suite(self, suite: robot.running.model.TestSuite):
        settings = robot.conf.settings.RobotSettings()
        variables = robot.variables.scopes.VariableScopes(settings)
        ns = robot.running.namespace.Namespace(variables, suite, suite.resource, languages=None)

        robot.running.context.EXECUTION_CONTEXTS.start_suite(suite, ns, unittest.mock.Mock(), dry_run=True)
        variables.start_suite()
        ns.start_suite()

        print(suite.resource.variables)
        print(f"Starting suite '{suite.name}'")

        for imp in suite.resource.imports:
            imp: robot.running.model.Import
            match imp.type:
                case "RESOURCE":
                    if "MustGather" in imp.name:
                        print("baf")
                    target = imp.directory / imp.name
                    ns.import_resource(target)
                case "LIBRARY":
                    pass
                    # target = imp.directory / imp.name
                    # ns.import_library(target)
                case default:
                    raise Exception(f"'{imp.type}' is an unexpected resource type")
            print(f"  Import '{imp.name}'")

        # these are python libraries, essentially
        for libname, libvalue in ns.libraries.mapping.items():
            print("libname", libname, libvalue)
            name = "getwebelement"  ## normalized names
            if libvalue.handlers_for(name):
                print(f"Library '{libname}' has a handler for {name}")

        # we may not have undefined variables
        variables.set_local_variable("${AWS_ACCESS_KEY_ID}", "fake")
        variables.set_local_variable("${AWS_SECRET_ACCESS_KEY}", "fake")
        variables.set_local_variable("${AWS_BUCKET}", "fake")
        variables.set_local_variable("${MODELS_BUCKET}", "fake")
        variables.set_local_variable("${AWS_STORAGE_BUCKET}", "fake")
        variables.set_local_variable("${AWS_DEFAULT_ENDPOINT}", "fake")

        variables.set_local_variable("${NOTEBOOK_USER_NAME}", "fake")
        variables.set_local_variable("${NOTEBOOK_USER_PASSWORD}", "fake")
        variables.set_local_variable("${PIP_INDEX_URL}", "fake")
        variables.set_local_variable("${PIP_TRUSTED_HOST}", "fake")
        # here are the variables from the imported files, the values are interpolated
        for variable, variablevalue in variables.as_dict().items():
            print(f"variable '{variable}'", variablevalue)

        # user_keywords: robot.running.userkeyword.UserLibrary = ns._kw_store.user_keywords
        # for keyword in user_keywords.handlers:
        user_keywords: list[robot.running.userkeyword.UserLibrary] = ns._kw_store.resources.values()
        for keyword in (kw for handlers in user_keywords for kw in handlers.handlers):
            keyword: robot.running.userkeyword.UserKeywordHandler
            print(keyword)
            # if not hasattr(keyword, "body"):
            #     continue
            cw = CodeWriter()
            fname = format_functionname(keyword.name)
            cw.begin(f"def {fname}(*args, **kwargs):")
            self.translate_body(keyword.body, cw)
            # todo have to namespace these
            self.userkeywords[fname] = cw.buffer.getvalue()

            # if "gather" in keyword.name:
            if "Add and Run JupyterLab Code Cell" in keyword.name:
                print("baf")

        for keyword in suite.resource.keywords:
            cw = CodeWriter()
            fname = format_functionname(keyword.name)
            cw.begin(f"def {fname}(*args, **kwargs):")
            self.translate_body(keyword.body, cw)
            self.userkeywords[fname] = cw.buffer.getvalue()

            if keyword.name == "Get must-gather Logs":
                print("baf")

            self.userkeywords[fname] = cw.buffer.getvalue()

    def end_suite(self, suite: robot.running.model.TestSuite):
        robot.running.context.EXECUTION_CONTEXTS.end_suite()
        print(f"Ending suite '{suite.name}'")
        return "b"

    def visit_test(self, test: robot.running.model.TestCase):
        cw = CodeWriter()
        cw.begin(f"def {test.name.replace(' ', '_')}():")

        print(f"Visiting test '{test.name}' {type(test.body)}")
        body: robot.running.model.Body = test.body

        self.translate_body(body, cw)
        cw.end()
        self.generated_test_methods.append(cw.buffer.getvalue())

        cw.print()

    def visit_keyword(self, keyword: robot.running.model.Keyword):
        if not hasattr(keyword, 'body'):
            return
        cw = CodeWriter()
        cw.begin(f"def {keyword.name.replace(' ', '_')}():")

        print(f"Visiting keyword '{keyword.name}' {type(keyword.body)}")
        body: robot.running.model.Body = keyword.body

        self.translate_body(body, cw)
        cw.end()
        self.generated_test_methods.append(cw.buffer.getvalue())

        cw.print()

    def translate_body(self, body: robot.running.model.Body, cw: CodeWriter):
        for x in body:
            match x:
                case robot.running.model.Keyword():
                    x: robot.running.model.Keyword
                    name = format_functionname(x.name)

                    self.usedkeywords.add(format_functionname(name))

                    args = []
                    kwargs = {}
                    for arg in x.args:
                        parts = arg.split('=', maxsplit=1)
                        if len(parts) == 1:
                            args.append(format_argument(parts[0]))
                        else:
                            kwargs[parts[0]] = format_argument(parts[1])
                    expression = f"{name}({', '.join(args)}{',' if args and kwargs else ''}{', '.join(k + '=' + v for k, v in kwargs.items())})"
                    if x.assign:
                        lhs = ', '.join([format_assignment(arg) for arg in x.assign])
                        cw.add(f"{lhs} = {expression}")
                    else:
                        cw.add(expression)
                case robot.running.model.If():
                    print("if")
                    for y in x.body:
                        match y:
                            case robot.running.model.IfBranch():
                                print("ifbranch", y.type, y.condition, y.body)
                                if y.type == "IF":
                                    cw.begin(f"if {format_condition(y.condition)}:")
                                elif y.type == "ELSE IF":
                                    cw.begin(f"elif {format_condition(y.condition)}:")
                                elif y.type == "ELSE":
                                    cw.begin(f"else:")
                                else:
                                    raise Exception(f"Unexpected type '{y.type}'")

                                self.translate_body(y.body, cw)

                                cw.end()

                case robot.running.model.For():
                    x: robot.running.model.For
                    print("for")
                    variables = ', '.join(format_variable(v) for v in x.variables)
                    match x.flavor:
                        case "IN":
                            values = ', '.join(format_variable(v) for v in x.values)
                            cw.begin(f"for {variables} in {values}:")
                        case "IN ENUMERATE":
                            values = ', '.join(format_variable(v) for v in x.values)
                            if x.start:
                                cw.begin(f"for {variables} in enumerate({values}, start={x.start}):")
                            else:
                                cw.begin(f"for {variables} in enumerate({values}):")
                        case "IN RANGE":
                            values = ', '.join(x.values)
                            cw.begin(f"for {variables} in range({values}):")
                        case default:
                            raise Exception(f"Unexpected for '{x.flavor}'")
                    self.translate_body(x.body, cw)
                    cw.end()
                case robot.running.model.While():
                    x: robot.running.model.While
                    cw.begin(f"while {format_condition(x.condition)}:")
                    self.translate_body(x.body, cw)
                    cw.end()
                case x if isinstance(x, robot.running.Try) or isinstance(x, robot.running.model.Try):
                    x: robot.running.model.Try
                    for y in x.body:
                        match y:
                            case robot.running.TryBranch():
                                y: robot.running.TryBranch
                                print("trybranch", y.type, y.patterns, y.body)
                                if y.type == "TRY":
                                    cw.begin(f"try:")
                                elif y.type == "EXCEPT":
                                    cw.begin(f"except {y.patterns}:")
                                elif y.type == "ELSE":
                                    cw.begin(f"else:")
                                elif y.type == "FINALLY":
                                    cw.begin(f"finally:")
                                else:
                                    raise Exception(f"Unexpected try pattern type '{y.type}'")
                                self.translate_body(y.body, cw)
                                cw.end()
                            case default:
                                raise Exception(f"Unexpected try pattern type '{y.type}'")

                    # for y in x.except_branches:
                    #     cw.begin(f"except {y.patterns}:")
                    #     self.translate_body(y.body, cw)
                    #     cw.end()
                    # if x.else_branch:
                    #     cw.begin(f"else:")
                    #     self.translate_body(x.else_branch, cw)
                    #     cw.end()
                    # if x.finally_branch:
                    #     cw.begin(f"finally:")
                    #     self.translate_body(x.finally_branch, cw)
                    #     cw.end()
                case robot.running.model.Return():
                    cw.add("return 'something'")
                case robot.running.model.Break():
                    cw.add("break")
                case robot.running.model.Continue():
                    cw.add("continue")
                case default:
                    raise Exception(f"default {type(x)}")


class Context:
    def get_runner(self, _):
        return BodyRunner(self)

    @property
    def dry_run(self):
        return False


class BodyRunner:

    def __init__(self, context, run=True, templated=False):
        self._context = context
        self._run = run
        self._templated = templated

    def run(self, body, *args, **kwargs):
        print("body", body)
        errors = []
        passed = None
        for step in iter(body):
            # try:
            step.run(self._context, self._run, self._templated)
        # except ExecutionPassed as exception:
        #     exception.set_earlier_failures(errors)
        #     passed = exception
        #     self._run = False
        # except ExecutionFailed as exception:
        #     errors.extend(exception.get_errors())
        #     self._run = exception.can_continue(self._context, self._templated)
        if passed:
            raise passed
        # if errors:
        #     raise ExecutionFailures(errors)
