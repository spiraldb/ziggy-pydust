import pytest

from example import classes


def test_hierarchy():
    assert issubclass(classes.Dog, classes.Animal)
    assert isinstance(classes.Dog("Pupper's name"), classes.Animal)


def test_make_noise():
    with pytest.raises(AttributeError):
        classes.Animal(1).make_noise()
    assert classes.Dog("Pupper's name").make_noise() == "Bark!"


def test_adopt():
    owner = classes.Owner()
    adopted = owner.adopt_puppy("Cute pupper's name")
    assert isinstance(adopted, classes.Dog)
    assert adopted.get_name() == "Cute pupper's name"
    assert adopted.get_state() == 1
