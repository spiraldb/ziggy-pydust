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

import sys

import pytest

from example import classes


# --8<-- [start:constructor]
def test_constructor():
    from example import classes

    assert isinstance(classes.ConstructableClass(20), classes.ConstructableClass)


# --8<-- [end:constructor]


# --8<-- [start:subclass]
def test_subclasses():
    d = classes.Dog("labrador")
    assert d.breed() == "labrador"
    assert d.species() == "dog"
    assert isinstance(d, classes.Animal)


# --8<-- [end:subclass]


# --8<-- [start:staticmethods]
def test_static_methods():
    assert classes.Math.add(10, 30) == 40


# --8<-- [end:staticmethods]


# --8<-- [start:properties]
def test_properties():
    u = classes.User("Dave")
    assert u.email is None

    u.email = "dave@dave.com"
    assert u.email == "dave@dave.com"

    with pytest.raises(ValueError) as exc_info:
        u.email = "dave"
    assert str(exc_info.value) == "Invalid email address for Dave"

    assert u.greeting == "Hello, Dave!"


# --8<-- [end:properties]


# --8<-- [start:attributes]
def test_attributes():
    c = classes.Counter()
    assert c.count == 0
    c.increment()
    c.increment()
    assert c.count == 2


# --8<-- [end:attributes]


def test_hash():
    h = classes.Hash(42)
    assert hash(h) == -7849439630130923510


def test_refcnt():
    # Verify that initializing a class does not leak a reference to the module.
    rc = sys.getrefcount(classes)
    classes.Hash(42)
    assert sys.getrefcount(classes) == rc
