import enum
import io
import os
import pathlib
import struct
import subprocess
import tempfile
import pytest
from pydust import config, zigexe
from pydantic import BaseModel


pydust_conf = config.load()


def pytest_collect_file(file_path, path, parent):
    """Grab any Zig roots for PyTest collection."""
    if file_path.suffix == ".zig":
        for ext_module in pydust_conf.ext_modules:
            if pathlib.Path(ext_module.root).absolute() == file_path.absolute():
                return ZigFile.from_parent(parent, path=file_path)



class RequestTag(enum.Enum):
    # Tells the compiler to shut down cleanly.
    # No body.
    exit = 0
    # Tells the compiler to detect changes in source files and update the
    # affected output compilation artifacts.
    # If one of the compilation artifacts is an executable that is
    # running as a child process, the compiler will wait for it to exit
    # before performing the update.
    # No body.
    update = 1
    # Tells the compiler to execute the executable as a child process.
    # No body.
    run = 2
    # Tells the compiler to detect changes in source files and update the
    # affected output compilation artifacts.
    # If one of the compilation artifacts is an executable that is
    # running as a child process, the compiler will perform a hot code
    # swap.
    # No body.
    hot_update = 3
    # Ask the test runner for metadata about all the unit tests that can
    # be run. Server will respond with a `test_metadata` message.
    # No body.
    query_test_metadata = 4
    # Ask the test runner to run a particular test.
    # The message body is a u32 test index.
    run_test = 5


class ResponseTag(enum.Enum):
    # Body is a UTF-8 string.
    zig_version = 0
    # Body is an ErrorBundle.
    error_bundle = 1
    # Body is a UTF-8 string.
    progress = 2
    # Body is a EmitBinPath.
    emit_bin_path = 3
    # Body is a TestMetadata
    test_metadata = 4
    # Body is a TestResults
    test_results = 5


class Header(BaseModel):
    tag: int
    bytes_len: int = 0

    def pack(self):
        return struct.pack('<II', self.tag, self.bytes_len)

    @classmethod
    def unpack(cls, buffer):
        (tag, bytes_len) = struct.unpack('<II', buffer.read(8))
        return cls(tag=tag, bytes_len=bytes_len)


class ZigFile(pytest.File):
    def collect(self):
        """Collect all the tests that exist within this Zig root.

        First compile using 'zig test'
        Then spin up the test server and query it for the test metadata.
        """
        ext_module = [e for e in pydust_conf.ext_modules if pathlib.Path(e.root).absolute() == self.path][0]
        
        # First we compile the test binary
        with zigexe.build_argv('test', ext_module) as argv:
            subprocess.check_call(argv)

        # Then query the test metadata
        proc = subprocess.Popen([ext_module.test_bin, '--listen=-'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        try:
            # Zig first sends us its version.
            h = Header.unpack(proc.stdout)
            assert h.tag == ResponseTag.zig_version.value
            _zig_version = proc.stdout.read(h.bytes_len).decode('utf-8')

            # Then we can request test metadata
            proc.stdin.write(Header(tag=RequestTag.query_test_metadata.value).pack())
            proc.stdin.flush()

            h = Header.unpack(proc.stdout)
            assert h.tag == ResponseTag.test_metadata.value
            test_metas = self._read_test_metadata(proc.stdout.read(h.bytes_len))
        finally:
            proc.kill()
            proc.wait()

        for test in test_metas:
            # TODO(ngates): we could override the path here if test_metadata provided source provenance.
            yield ZigItem.from_parent(self, name=test['name'], ext_module=ext_module, test_meta=test)

    @staticmethod
    def _read_test_metadata(buffer):
        (string_bytes_len, tests_len) = struct.unpack('<II', buffer[:8])
        buffer = buffer[8:]

        # Extract byte offsets into the test metadata where each of the values occurs.
        # End offsets are null-terminated bytes.
        # Wrap the buffer so we can consume from it nicely in a loop
        fileobj = io.BytesIO(buffer)
        names = [struct.unpack('<I', fileobj.read(4))[0] for _ in range(tests_len)]
        async_frame_sizes = [struct.unpack('<I', fileobj.read(4))[0] for _ in range(tests_len)]
        expected_panic_msgs = [struct.unpack('<I', fileobj.read(4))[0] for _ in range(tests_len)]

        # We use the original buffer to extract string data since it's easier to find the next null terminator
        data = buffer[-string_bytes_len:]
        tests = []
        for i, (name, afs, ep) in enumerate(zip(names, async_frame_sizes, expected_panic_msgs)):
            test_name = data[name:data.index(b'\0', name)].decode('utf-8')
            if test_name.startswith('test.'):
                test_name = test_name[len('test.'):]
            tests.append({
                'idx': i,
                'name': test_name,
                'async_frame_size': data[afs:data.index(b'\0', afs)].decode('utf-8') if afs else None,
                'expected_panics': data[ep:data.index(b'\0', ep)].decode('utf-8') if ep else None,
            })

        return tests


class ZigItem(pytest.Item):
    def __init__(self, *, ext_module, test_meta, **kwargs):
        super().__init__(**kwargs)
        self.ext_module = ext_module
        self.test_meta = test_meta

        self._stderr = None

    def runtest(self):
        stderr = tempfile.NamedTemporaryFile()
        proc = subprocess.Popen(
            [self.ext_module.test_bin, '--listen=-'], 
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr,
        )
        try:
            # Zig first sends us its version.
            h = Header.unpack(proc.stdout)
            assert h.tag == ResponseTag.zig_version.value
            _zig_version = proc.stdout.read(h.bytes_len).decode('utf-8')

            # Then we can request the test to run
            proc.stdin.write(Header(tag=RequestTag.run_test.value, bytes_len=4).pack())
            proc.stdin.write(struct.pack('<I', self.test_meta['idx']))
            proc.stdin.flush()

            h = Header.unpack(proc.stdout)
            assert h.tag == ResponseTag.test_results.value

            _test_idx, flags = struct.unpack('<II', proc.stdout.read(8))
            fail = bool(flags & 0x01)
            skip = bool(flags & 0x02)
            leak = bool(flags & 0x04)
            # TODO(ngates): log_error_count: u29 isn't currently passed back but should be

            with open(stderr.name, 'r') as f:
                self.add_report_section('call', 'stderr', f.read())
        finally:
            proc.kill()
            proc.wait()
            stderr.close()

        if skip:
            self.add_marker(pytest.mark.skip)

        if leak:
            self.add_report_section('call', 'memory leaks', f"Zig detected a memory leak in '{self.nodeid}'")

        if fail or leak:
            raise Exception("Failure in Zig test")

    def repr_failure(self, excinfo):
        """Called when self.runtest() raises an exception."""
        return str(excinfo)

    def reportinfo(self):
        return self.path, 0, self.test_meta['name']