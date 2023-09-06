import inspect

import pytest

from example import functions


def test_double():
    assert functions.double(10) == 20
    with pytest.raises(TypeError, match="expected int"):
        functions.double(0.1)


def test_text_signature():
    assert inspect.signature(functions.double) == inspect.Signature(
        [inspect.Parameter("x", kind=inspect._ParameterKind.POSITIONAL_ONLY)]
    )
