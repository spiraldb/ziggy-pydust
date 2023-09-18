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

import pytest

from example import classes


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


# --8<-- [end:properties]


def test_hierarchy():
    assert issubclass(classes.Dog, classes.Animal)
    assert isinstance(classes.Dog("Dug"), classes.Animal)


def test_make_noise():
    with pytest.raises(AttributeError):
        classes.Animal(0).make_noise()
    d = classes.Dog("Dug")

    assert d.make_noise() == "bark..."
    assert d.make_noise(is_loud=True) == "Bark!"


def test_init():
    with pytest.raises(TypeError) as exc_info:
        classes.Animal()
    assert str(exc_info.value) == "expected 1 argument"


def test_super():
    owner = classes.Owner()
    adopted = owner.name_puppy("Dug")
    assert isinstance(adopted, classes.Dog)
    assert adopted.get_name() == "Dug"
    assert adopted.get_kind_name() == "Dog named Dug"
    assert adopted.get_kind() == 1


def test_length():
    assert len(classes.Dog("foo")) == 4


def test_str_and_repr():
    dog = classes.Dog("foo")
    assert str(dog) == "Dog named foo"
    assert repr(dog) == "Dog(foo)"


def test_add():
    foo = classes.Dog("foo")
    assert str(foo + "bar") == "Dog named foobar"
