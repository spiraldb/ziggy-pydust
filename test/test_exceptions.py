import pytest

from example import exceptions


def test_exceptions():
    with pytest.raises(ValueError) as exc:
        exceptions.raise_value_error("hello!")
    assert str(exc.value) == "hello!"
