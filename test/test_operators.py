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

import operator

import pytest

from example import operators


@pytest.mark.parametrize(
    "op,expected",
    [
        (operator.add, 5),
        (operator.sub, 1),
        (operator.mul, 6),
        (operator.mod, 1),
        (operator.pow, 9),
        (operator.lshift, 12),
        (operator.rshift, 0),
        (operator.and_, 2),
        (operator.xor, 1),
        (operator.or_, 3),
        (operator.truediv, 1),
        (operator.floordiv, 1),
        (operator.matmul, 6),
    ],
)
def test_ops(op, expected):
    ops = operators.Ops(3)
    other = operators.Ops(2)

    assert op(ops, other).num() == expected
    assert ops.num() == 3


@pytest.mark.parametrize(
    "iop,expected",
    [
        (operator.iadd, 5),
        (operator.isub, 1),
        (operator.imul, 6),
        (operator.imod, 1),
        (operator.ipow, 9),
        (operator.ilshift, 12),
        (operator.irshift, 0),
        (operator.iand, 2),
        (operator.ixor, 1),
        (operator.ior, 3),
        (operator.itruediv, 1),
        (operator.ifloordiv, 1),
        (operator.imatmul, 6),
    ],
)
def test_iops(iop, expected):
    ops = operators.Ops(3)
    other = operators.Ops(2)

    iop(ops, other)
    assert ops.num() == expected


def test_divmod():
    ops = operators.Ops(3)
    other = operators.Ops(2)

    assert divmod(ops, other) == (1, 1)


# --8<-- [start:test_ops]
def test_custom_ops():
    op = operators.Operator(3)

    assert op / 2 == 1
    assert op / 2.0 == 1.5
    assert (op / operators.Operator(3)).num() == 1


# --8<-- [end:test_ops]


def test_lessThan():
    cmp1 = operators.Comparator(0)
    cmp2 = operators.Comparator(1)

    assert cmp1 < cmp2
    assert cmp1 <= cmp2
    assert cmp1 != cmp2


def test_equals():
    cmp1 = operators.Comparator(1)
    cmp2 = operators.Comparator(1)

    assert cmp1 == cmp2


def test_greaterThan():
    cmp1 = operators.Comparator(2)
    cmp2 = operators.Comparator(1)

    assert cmp1 > cmp2
    assert cmp1 >= cmp2
    assert cmp1 != cmp2


def test_justequals():
    cmp1 = operators.Equals(1)
    cmp2 = operators.Equals(1)

    assert cmp1 == cmp2
    assert not cmp1 != cmp2
    assert cmp1 != operators.Equals(2)

    with pytest.raises(TypeError):
        assert cmp1 > cmp2
    with pytest.raises(TypeError):
        assert cmp1 >= cmp2
    with pytest.raises(TypeError):
        assert cmp1 < cmp2
    with pytest.raises(TypeError):
        assert cmp1 <= cmp2


# Test short circuit logic in pydust that handles
# cases where __eq__ expects same types but values clearly are not
def test_justequals_different_type():
    cmp1 = operators.Equals(1)
    cmp2 = 2

    assert not cmp1 == cmp2
    assert cmp1 != cmp2


def test_justLessThan():
    cmp1 = operators.LessThan("abc")
    cmp2 = operators.LessThan("abd")

    assert cmp1 < cmp2
    assert cmp1 <= cmp2
    assert not (cmp1 > cmp2)
    assert not (cmp1 >= cmp2)
    assert not (cmp1 == cmp2)
    assert cmp1 != cmp2
