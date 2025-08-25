import re


def test_unquote():
    for inp, outp in (
            ("", ""),
            ("''", ""),
            ('''"expected_output=['system' 'tpch']"''', "expected_output=['system' 'tpch']"),
    ):
        assert format_unquote(inp) == outp


def format_unquote(value: str) -> str:
    quoted_string = re.match(r"""^(?P<q>["'])
    (
        (\\(?P=q))
        | ((?!(?P=q)).)
    )*
    (?P=q)$""", value, re.VERBOSE)
    if quoted_string:
        return value[1:-1]
    return value


def format_functionname(name: str) -> str:
    name = name.lower()
    name = name.translate(str.maketrans(' -/()', '_____', '"'))
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


def format_string(value: str) -> str:
    if "'" in value:
        if '"' in value:
            return repr(value)
        return '"' + value + '"'
    return "'" + value + "'"


def format_condition(expression: str) -> str:
    # negative lookahead for escaped $, todo: add this everywhere, and single regex?
    # also doing the quotes removal
    expression = re.sub(r'(?P<q>"?)(?!\\)[$&@]\{([^}]+)}(?P=q)', r'\2', expression)
    expression = re.sub(r'(?P<q>"?)(?!\\)[$&@](\w+)(?P=q)', r'\2', expression)
    return expression
