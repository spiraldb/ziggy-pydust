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
import time
from concurrent.futures import ThreadPoolExecutor

from example import gil


# --8<-- [start:gil]
def test_gil():
    now = time.time()
    with ThreadPoolExecutor(10) as pool:
        for _ in range(10):
            # Sleep for 100ms
            pool.submit(gil.sleep, 100)

    # This should take ~10 * 100ms. Add some leniency and check for >900ms.
    duration = time.time() - now
    assert duration > 0.9


def test_gil_release():
    now = time.time()
    with ThreadPoolExecutor(10) as pool:
        for _ in range(10):
            pool.submit(gil.sleep_release, 100)

    # This should take ~1 * 100ms. Add some leniency and check for <500ms.
    duration = time.time() - now
    assert duration < 0.5


# --8<-- [end:gil]
