import pytest

from example import result_types


def test_pyobject():
    assert result_types.pyobject() == "hello"


def test_pystring():
    assert result_types.pystring() == "hello world"


def test_zigvoid():
    result_types.zigvoid()


def test_zigbool():
    assert result_types.zigbool()


def test_zigu32():
    assert result_types.zigu32() == 32


def test_zigu64():
    assert result_types.zigu64() == 8589934592


@pytest.mark.xfail(strict=True)
def test_zigu128():
    assert result_types.zigu128() == 9223372036854775809


def test_zigi32():
    assert result_types.zigi32() == -32


def test_zigi64():
    assert result_types.zigi64() == -8589934592


@pytest.mark.xfail(strict=True)
def test_zigi128():
    assert result_types.zigi128() == -9223372036854775809


def test_zigf16():
    assert result_types.zigf16() == 32720.0


def test_zigf32():
    assert result_types.zigf32() == 2.71000028756788e38


def test_zigf64():
    assert result_types.zigf64() == 2.7100000000000003e39


def test_zigstruct():
    assert result_types.zigstruct() == {"foo": 1234, "bar": True}
