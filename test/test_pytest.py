import pytest

from example import pytest as ex_pytest


def test_exceptions():
    with pytest.raises(ValueError) as exc:
        ex_pytest.raise_value_error("hello!")
    assert str(exc.value) == "hello!"
