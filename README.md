# bazel-rpm

Bazel rules for building RPM packages.

## Setup

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_rpm", version = "0.1.0")

rpm_toolchain = use_extension("@rules_rpm//toolchains:extensions.bzl", "rpm_toolchain")
use_repo(rpm_toolchain, "rpm_toolchain")
register_toolchains("@rules_rpm//toolchains:linux_x86_64")
```

## Usage

```starlark
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_rpm//rpm:defs.bzl", "rpm_package")

cc_binary(
    name = "hello_world",
    srcs = ["main.cpp"],
)

rpm_package(
    name = "hello_world_rpm",
    binaries = [":hello_world"],
    version = "1.0.0",
    summary = "Hello World application",
    requires = ["systemd", "openssl"],  # Optional dependencies
)
```

## Build

```bash
bazel build //:hello_world_rpm
rpm -qpil bazel-bin/hello_world_rpm.rpm
```

See `examples/` for more examples.

---

*Co-authored by Claude*
