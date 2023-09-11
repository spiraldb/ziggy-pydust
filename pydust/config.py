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

import functools
import os

import tomllib
from pydantic import BaseModel, Field, model_validator, root_validator


class ExtModule(BaseModel):
    """Config for a single Zig extension module."""

    name: str
    root: str
    limited_api: bool = True

    @property
    def libname(self):
        return self.name.rsplit(".", maxsplit=1)[-1]

    @property
    def install_path(self):
        # FIXME(ngates): for non-limited API
        assert self.limited_api, "Only limited API modules are supported right now"
        return os.path.join(*self.name.split(".")) + ".abi3.so"

    @property
    def test_bin(self):
        return os.path.join("zig-out", "bin", self.libname + ".test.bin")


class ToolPydust(BaseModel):
    """Model for tool.pydust section of a pyproject.toml."""

    root: str = "src/"
    build_zig: str = "build.zig"

    # When true, python module definitions are configured by the user in their own build.zig file.
    # When false, ext_modules is used to auto-generated a build.zig file.
    self_managed: bool = False

    # We rename pluralized config sections so the pyproject.toml reads better.
    ext_modules: list[ExtModule] = Field(alias="ext_module", default_factory=list)

    @property
    def pydust_build_zig(self):
        return os.path.join(os.path.dirname(self.build_zig), "pydust.build.zig")

    @model_validator(mode="after")
    def validate_atts(self):
        if self.self_managed and self.ext_modules:
            raise ValueError("ext_modules cannot be defined when using Pydust in self-managed mode.")


@functools.cache
def load() -> ToolPydust:
    with open("pyproject.toml", "rb") as f:
        pyproject = tomllib.load(f)
    return ToolPydust(**pyproject["tool"].get("pydust", {}))
