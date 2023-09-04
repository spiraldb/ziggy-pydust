from example import buffers


def test_view():
    buffer = buffers.ConstantBuffer(1, 10)
    view = memoryview(buffer)
    for i in range(10):
        assert view[i] == 1
    view.release()
