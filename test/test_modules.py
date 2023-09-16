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

from example import modules


def test_module_docstring():
    assert modules.__doc__.startswith("Zig multi-line strings make it easy to define a docstring...")


def test_modules_function():
    assert modules.hello("Nick") == "Hello, Nick. It's Ziggy"


def test_modules_state():
    assert modules.whoami() == "Ziggy"


def test_modules_mutable_state():
    assert modules.count() == 0
    modules.increment()
    modules.increment()
    assert modules.count() == 2
