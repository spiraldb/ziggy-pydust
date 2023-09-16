"""
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import inspect

import pytest

from example import functions


def test_double():
    assert functions.double(10) == 20
    with pytest.raises(TypeError, match="expected int"):
        functions.double(0.1)


def test_args_signature():
    assert inspect.signature(functions.double) == inspect.Signature(
        [inspect.Parameter("x", kind=inspect._ParameterKind.POSITIONAL_ONLY)]
    )


def test_kwargs():
    assert functions.with_kwargs(10.0) == 20
    assert functions.with_kwargs(100.0) == 42
    assert functions.with_kwargs(100.0, y=99.0) == 99
    with pytest.raises(TypeError, match="unexpected kwarg 'k'"):
        functions.with_kwargs(1.0, y=9.0, k=-2)
    with pytest.raises(TypeError) as exc_info:
        functions.with_kwargs(y=9.0)
    assert str(exc_info.value) == "expected 1 arg"


def test_kw_signature():
    assert inspect.signature(functions.with_kwargs) == inspect.Signature(
        [
            inspect.Parameter("x", kind=inspect._ParameterKind.POSITIONAL_ONLY),
            inspect.Parameter("y", kind=inspect._ParameterKind.KEYWORD_ONLY, default=42.0),
        ]
    )
