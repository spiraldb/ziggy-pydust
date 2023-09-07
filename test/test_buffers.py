"""
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
"""

from array import array

from example import buffers


def test_view():
    buffer = buffers.ConstantBuffer(1, 10)
    view = memoryview(buffer)
    for i in range(10):
        assert view[i] == 1
    view.release()


def test_sum():
    # array implements a buffer protocol
    arr = array("l", [1, 2, 3, 4, 5])
    assert buffers.sum(arr) == 15
