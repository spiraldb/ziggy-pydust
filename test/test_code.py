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

from pathlib import Path

from example import code


def test_line_no():
    assert code.line_number() == 21
    assert code.first_line_number() == 20


def test_function_name():
    assert code.function_name() == "test_function_name"


def test_file_name():
    assert Path(code.file_name()).name == "test_code.py"
