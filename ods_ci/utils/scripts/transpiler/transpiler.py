import dataclasses
import math
import pathlib
import re
import unittest.mock
from collections import defaultdict

import robot.api.interfaces
import robot.api.parsing
import robot.conf.settings
import robot.running.context
import robot.running.model
import robot.running.namespace
import robot.variables.scopes
from robot.model import SuiteVisitor

from .py_code_writer import PyCodeWriter
from .code_writer_utils import format_condition, format_functionname, format_string, \
    format_unquote, format_variable


@dataclasses.dataclass
class CodeFile:
    test_methods: list[str] = dataclasses.field(default_factory=list)
    keywords: dict[str, str] = dataclasses.field(default_factory=dict)
    constants: str = ""


class SuiteRunner(SuiteVisitor):
    def __init__(self, testsuite: robot.running.model.TestSuite, writer_class: type[PyCodeWriter] = PyCodeWriter):
        self.testsuite = testsuite
        self.writerClass = writer_class

        self.code: dict[str, str] = {}
        self.code_generated_test_methods: dict[str, str] = {}

        self.code_files: dict[str, CodeFile] = defaultdict(CodeFile)

        # the visitors use this to accumulate the generated code and
        # emit it to self.code at the end, end of suite at the time of writing
        self.generated_constants = ""
        self.usedkeywords = set()
        self.userkeywords = {}
        self.generated_test_methods: dict[str, list[str]] = defaultdict(list)

    def get_only_generated_methods(self):
        if self.generated_test_methods:
            return '\n\n'.join(*self.generated_test_methods.values())
        else:
            return ''

    def get_python_code(self) -> str:
        code = ""
        code += self.generated_constants + "\n\n"
        for kw in self.usedkeywords:
            if kw in self.userkeywords:
                if code:
                    code += "\n\n"
                code += self.userkeywords[kw]
            else:
                print(f"keyword not found in userdefined {kw}")
        if code:
            code += "\n\n"
        if self.generated_test_methods:
            code += '\n\n'.join(*self.generated_test_methods.values())

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

        # print(suite.resource.variables)
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
                    # actually we do want to import libraries, esp. Jupyter library
                    if imp.name in ["OperatingSystem", "OpenShiftLibrary", "String", "Process", "yaml", "Collections",
                                    "SeleniumLibrary", "RequestsLibrary", "DateTime", "Screenshot"]:
                        # skip libs implemented in Python
                        continue
                    if imp.name.endswith(".py"):
                        continue
                    target = pathlib.Path(
                        "/Users/jdanek/IdeaProjects/ods-ci/.venv/lib/python3.11/site-packages") / imp.name
                    ns.import_library(target)
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

        cw = self.writerClass()
        # here are the variables from the imported files, the values are interpolated
        for variable, variablevalue in variables.as_dict().items():
            # print(f"variable '{variable}'", variablevalue)
            if type(variablevalue) == str:
                variablevalue = format_string(variablevalue)
            cw.add_assignment([variable], variablevalue)
        self.generated_constants = cw.buffer.getvalue()

        self.code_files[str(suite.source)].constants = cw.buffer.getvalue()

        # user_keywords: robot.running.userkeyword.UserLibrary = ns._kw_store.user_keywords
        # for keyword in user_keywords.handlers:
        user_keywords: list[robot.running.userkeyword.UserLibrary] = ns._kw_store.resources.values()
        for keyword in (kw for handlers in user_keywords for kw in handlers.handlers):
            keyword: robot.running.userkeyword.UserKeywordHandler
            # print(keyword)
            # if not hasattr(keyword, "body"):
            #     continue
            cw = self.writerClass()
            fname = format_functionname(keyword.name)
            arglist = []
            for arg in keyword.arguments.argument_names:
                if arg in keyword.arguments.defaults:
                    arglist.append(arg + "=" + cw.format_argument(keyword.arguments.defaults[arg]))
                else:
                    arglist.append(arg)
            cw.begin_function(fname, arglist)
            self.translate_body(keyword.body, cw)
            cw.end()
            # todo have to namespace these
            self.userkeywords[fname] = cw.buffer.getvalue()

            # if "gather" in keyword.name:
            if "Add and Run JupyterLab Code Cell" in keyword.name:
                print("baf")

            self.code_files[str(keyword.source)].keywords[keyword.name] = cw.buffer.getvalue()

        for keyword in suite.resource.keywords:
            keyword: robot.running.model.UserKeyword
            cw = self.writerClass()
            fname = format_functionname(keyword.name)
            arglist = []
            for arg in keyword.args:
                parts = arg.split("=")
                if len(parts) == 1:
                    arglist.append(format_variable(arg))
                else:
                    arglist.append(format_variable(parts[0]) + "=" + cw.format_argument(parts[1]))
            cw.begin_function(fname, arglist)
            self.translate_body(keyword.body, cw)
            cw.end()
            self.userkeywords[fname] = cw.buffer.getvalue()

            if keyword.name == "Get must-gather Logs":
                print("baf")

            self.code_files[str(keyword.source)].keywords[keyword.name] = cw.buffer.getvalue()

            # self.userkeywords[fname] = cw.buffer.getvalue()

    def end_suite(self, suite: robot.running.model.TestSuite):
        robot.running.context.EXECUTION_CONTEXTS.end_suite()
        print(f"Ending suite '{suite.name}'")

        code = self.get_python_code()
        self.code[suite.name] = code
        # test only, to make existing tests pass
        self.code_generated_test_methods[suite.name] = self.get_only_generated_methods()

        # reset vars
        self.generated_constants = ""
        self.usedkeywords = set()
        self.userkeywords = {}
        self.generated_test_methods.clear()

    def visit_test(self, test: robot.running.model.TestCase):
        cw = self.writerClass()
        test_function_name = "test_" + format_functionname(test.name)
        cw.begin_test(test_function_name)

        print(f"Visiting test '{test.name}' {type(test.body)}")
        body: robot.running.model.Body = test.body

        self.translate_body(body, cw)
        cw.end()
        self.generated_test_methods[str(test.source)].append(cw.buffer.getvalue())

        self.code_files[str(test.source)].test_methods.append(cw.buffer.getvalue())

        # cw.print()

    # these apparently don't exist in a SuiteVisitor
    def begin_file(self):
        pass

    def end_file(self):
        pass

    # def visit_keyword(self, keyword: robot.running.model.Keyword):
    #     if not hasattr(keyword, 'body'):
    #         return
    #     cw = self.writerClass()
    #
    #
    #
    #     print(f"Visiting keyword '{keyword.name}' {type(keyword.body)}")
    #     body: robot.running.model.Body = keyword.body
    #
    #     self.translate_body(body, cw)
    #     cw.end()
    #     self.generated_test_methods.append(cw.buffer.getvalue())
    #
    #     cw.print()

    def translate_body(self, body: robot.running.model.Body, cw: PyCodeWriter):
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
                            args.append(cw.format_argument(arg))
                        else:
                            arg = format_unquote(arg)
                            first_quote = re.search(r'[^\w_]', arg)
                            if first_quote:
                                first_quote = first_quote.start()
                            else:
                                first_quote = math.inf
                            if len(parts[0]) <= first_quote:
                                kwargs[parts[0]] = cw.format_argument(parts[1])
                            else:
                                # oc get DataScienceCluster/${dsc} -n ${namespace} -o 'jsonpath={.spec.components.${component}.managementState}'
                                args.append(cw.format_argument(arg))
                    expression = f"{name}({', '.join(args)}{',' if args and kwargs else ''}{', '.join(k + '=' + v for k, v in kwargs.items())})"
                    if x.assign:
                        cw.add_assignment(x.assign, expression)
                    else:
                        cw.add(expression)
                case robot.running.model.If():
                    # print("if")
                    for y in x.body:
                        match y:
                            case robot.running.model.IfBranch():
                                y: robot.running.model.IfBranch
                                # print("ifbranch", y.type, y.condition, y.body)
                                if y.type == "IF":
                                    cw.begin_if(format_condition(y.condition))
                                elif y.type == "ELSE IF":
                                    cw.begin_elif(format_condition(y.condition))
                                elif y.type == "ELSE":
                                    cw.begin_else()
                                else:
                                    raise Exception(f"Unexpected type '{y.type}'")

                                self.translate_body(y.body, cw)

                                cw.end()

                case robot.running.model.For():
                    x: robot.running.model.For
                    # print("for")
                    variables = [format_variable(v) for v in x.variables]
                    match x.flavor:
                        case "IN":
                            values = [format_variable(v) for v in x.values]
                            cw.begin_for_in(variables, values)
                        case "IN ENUMERATE":
                            values = [format_variable(v) for v in x.values]
                            cw.begin_for_enumerate(variables, values, x.start)
                        case "IN RANGE":
                            values = [format_variable(v) if v[0] in '$@&' else cw.format_argument(v) for v in
                                      x.values]
                            cw.begin_for_range(variables, values)
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
                                # print("trybranch", y.type, y.patterns, y.body)
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

                case robot.running.model.Return():
                    x: robot.running.model.Return
                    values = []
                    for value in x.values:
                        values.append(cw.format_argument(value))
                    cw.add(f"return{' ' if values else ''}{', '.join(values)}")
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
        # print("body", body)
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

