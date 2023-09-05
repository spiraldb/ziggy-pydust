import pytest

from example import classes


def test_hierarchy():
    assert issubclass(classes.Dog, classes.Animal)
    assert isinstance(classes.Dog("Dug"), classes.Animal)


def test_make_noise():
    with pytest.raises(AttributeError):
        classes.Animal(0).make_noise()
    assert classes.Dog("Dug").make_noise() == "Bark!"


def test_super():
    owner = classes.Owner()
    adopted = owner.name_puppy("Dug")
    assert isinstance(adopted, classes.Dog)
    assert adopted.get_name() == "Dug"
    assert adopted.get_kind_name() == "Dog named Dug"
    assert adopted.get_kind() == 1
