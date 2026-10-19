"""Keep the implementation inventory aligned with Python source, offline.

This checks inventory coverage, not a requirement for identical language APIs.
The shared capability contract, not the count of declarations, guides Swift design.
AST inspection avoids importing runtime dependencies or executing image/network code.
"""

import ast
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
PYTHON_PACKAGE = ROOT / 'python' / 'dicom4ortho'
MAPPING = ROOT / 'apple' / 'Documentation' / 'APIParity.md'
MODULES = (
    'model', 'm_orthodontic_photograph', 'controller', 'm_dent_oip', 'utils', 'm_tooth_codes',
)
PUBLIC_PROTOCOLS = {'__init__', '__len__', '__iter__'}
STATUSES = {'Partial', 'Missing', 'Difference', 'Excluded', 'Decision'}


def _source(module: str) -> ast.Module:
    return ast.parse((PYTHON_PACKAGE / f'{module}.py').read_text(encoding='utf-8'))


def _signature(function: ast.FunctionDef) -> str:
    """Readable signature without receiver/annotations, retaining argument defaults."""
    decorators = [ast.unparse(node) for node in function.decorator_list]
    if 'property' in decorators or any(value.endswith('.setter') for value in decorators):
        return function.name
    arguments = function.args
    positional = arguments.posonlyargs + arguments.args
    defaults = [None] * (len(positional) - len(arguments.defaults)) + arguments.defaults
    parts = []
    for index, (argument, default) in enumerate(zip(positional, defaults)):
        if argument.arg not in {'self', 'cls'}:
            suffix = '' if default is None else '=' + ast.unparse(default)
            parts.append(argument.arg + suffix)
        if arguments.posonlyargs and index + 1 == len(arguments.posonlyargs):
            parts.append('/')
    if arguments.vararg:
        parts.append('*' + arguments.vararg.arg)
    elif arguments.kwonlyargs:
        parts.append('*')
    for argument, default in zip(arguments.kwonlyargs, arguments.kw_defaults):
        suffix = '' if default is None else '=' + ast.unparse(default)
        parts.append(argument.arg + suffix)
    if arguments.kwarg:
        parts.append('**' + arguments.kwarg.arg)
    return function.name + '(' + ', '.join(parts) + ')'


class TestAPIParityMapping(unittest.TestCase):
    """New/renamed Python operations must receive an explicit inventory disposition."""

    def setUp(self):
        self.mapping = MAPPING.read_text(encoding='utf-8')
        self.rows = {}
        for line in self.mapping.splitlines():
            if not line.startswith('|'):
                continue
            cells = line.split('|')
            if len(cells) < 4 or cells[2].strip() not in STATUSES:
                continue
            for symbol in re.findall(r'`([^`]+)`', cells[1]):
                self.assertNotIn(symbol, self.rows, f'Duplicate inventory row for {symbol}')
                self.rows[symbol] = cells[2].strip()

    def test_every_declared_public_operation_has_a_status_and_current_signature(self):
        expected = set()
        for module in MODULES:
            for node in _source(module).body:
                if isinstance(node, ast.ClassDef) and not node.name.startswith('_'):
                    definitions = [(node.name, member) for member in node.body]
                else:
                    definitions = [(module, node)]
                for owner, member in definitions:
                    if isinstance(member, ast.FunctionDef) and (
                        not member.name.startswith('_') or member.name in PUBLIC_PROTOCOLS
                    ):
                        expected.add(owner + '.' + _signature(member))
        operations = {symbol for symbol in self.rows
                      if symbol.split('.', 1)[0] in {
                          'DicomBase', 'PhotographBase', 'OrthodonticPhotograph',
                          'OrthodonticSeries', 'OrthodonticStudy', 'OrthodonticController',
                          'utils', 'm_tooth_codes',
                      } or symbol.startswith(('DicomCode.to_',))}
        self.assertEqual(expected, operations)
        self.assertIn(f'**{len(expected)} declared operations/properties**', self.mapping)

    def test_all_consumed_photograph_constructor_keywords_are_mapped(self):
        expected = set()
        for module in ('model', 'm_orthodontic_photograph'):
            for node in _source(module).body:
                if not isinstance(node, ast.ClassDef) or node.name not in {
                    'DicomBase', 'PhotographBase', 'OrthodonticPhotograph',
                }:
                    continue
                for function in node.body:
                    if not isinstance(function, ast.FunctionDef) or function.name != '__init__':
                        continue
                    for call in ast.walk(function):
                        if not isinstance(call, ast.Call) or not isinstance(call.func, ast.Attribute):
                            continue
                        if call.func.attr == 'get' and isinstance(call.func.value, ast.Name) \
                                and call.func.value.id in {'kwargs', 'metadata'}:
                            key = call.args[0]
                        elif call.func.attr == '_optional_metadata':
                            key = call.args[1]
                        else:
                            continue
                        if isinstance(key, ast.Constant) and isinstance(key.value, str):
                            expected.add(key.value)
        keyword_rows = {symbol for symbol in self.rows if '.' not in symbol}
        self.assertEqual(expected, keyword_rows)
        self.assertRegex(self.mapping, rf'\*\*{len(expected)} consumed photograph\s+constructor keywords\*\*')

    def test_public_terminology_data_fields_are_mapped(self):
        expected = set()
        for node in _source('m_dent_oip').body:
            if isinstance(node, ast.ClassDef) and not node.name.startswith('_'):
                for field in node.body:
                    if isinstance(field, ast.AnnAssign) and isinstance(field.target, ast.Name):
                        expected.add(node.name + '.' + field.target.id)
        data_rows = {symbol for symbol in self.rows if symbol.startswith(
            ('DicomCode.', 'AdaImageType.', 'OrthoView.')) and '(' not in symbol}
        self.assertEqual(expected, data_rows)
        self.assertIn(f'**{len(expected)} terminology fields**', self.mapping)
