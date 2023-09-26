import pytest

from example import classes


def test_zigonly():
    zigonly = classes.ZigOnlyMethod(3)
    with pytest.raises(AttributeError) as exc_info:
        zigonly.get_number()
    assert str(exc_info.value) == "'example.classes.ZigOnlyMethod' object has no attribute 'get_number'"

    assert zigonly.reexposed() == 3
