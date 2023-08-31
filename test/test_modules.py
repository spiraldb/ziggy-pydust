from example import modules


def test_module_docstring():
    assert modules.__doc__.startswith("A docstring for the example module.")


def test_modules_function():
    assert modules.hello() == "Hello!"


def test_modules_state():
    assert modules.whoami() == "Nick"


def test_modules_mutable_state():
    assert modules.count() == 0
    modules.increment()
    modules.increment()
    assert modules.count() == 2
