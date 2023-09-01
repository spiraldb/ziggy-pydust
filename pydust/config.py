import functools
import os

import tomllib
from pydantic import BaseModel, Field


class ExtModule(BaseModel):
    """Config for a single Zig extension module."""

    name: str
    root: str
    limited_api: bool = True

    @property
    def libname(self):
        return self.name.rsplit(".", maxsplit=1)[-1]

    @property
    def install_prefix(self):
        return os.path.join(*self.name.split(".")[:-1])

    @property
    def install_path(self):
        # FIXME(ngates): for non-limited API
        assert self.limited_api, "Only limited API modules are supported right now"
        return os.path.join(*self.name.split(".")) + ".abi3.so"

    @property
    def test_bin(self):
        return os.path.join("zig-out", self.libname + ".test.bin")


class ToolPydust(BaseModel):
    """Model for tool.pydust section of a pyproject.toml."""

    root: str = "src/"

    # We rename pluralized config sections so the pyproject.toml reads better.
    ext_modules: list[ExtModule] = Field(alias="ext_module", default_factory=list)


@functools.cache
def load() -> ToolPydust:
    with open("pyproject.toml", "rb") as f:
        pyproject = tomllib.load(f)
    return ToolPydust(**pyproject["tool"].get("pydust", {}))
