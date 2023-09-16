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

from example import buffers


def test_view():
    buffer = buffers.ConstantBuffer(1, 10)
    view = memoryview(buffer)
    for i in range(10):
        assert view[i] == 1
    view.release()


# --8<-- [start:sum]
def test_sum():
    import numpy as np

    arr = np.array([1, 2, 3, 4, 5], dtype=np.int64)
    assert buffers.sum(arr) == 15


# --8<-- [end:sum]
