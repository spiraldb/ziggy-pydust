import pytest

from example import classes


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
