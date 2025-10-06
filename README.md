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
rpm -qpil bazel-bin/hello_world_rpm-1.0.0-1.x86_64.rpm
```

## Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `binaries` | `label_list` | `[]` | Binary files to include |
| `libraries` | `label_list` | `[]` | Library files to include |
| `headers` | `label_list` | `[]` | Header files to include |
| `configs` | `label_list` | `[]` | Configuration files |
| `data` | `label_list` | `[]` | Data files |
| `version` | `string` | **required** | Package version |
| `summary` | `string` | `"Package built with Bazel"` | Short description |
| `description` | `string` | `"Package built with Bazel rules_rpm"` | Detailed description |
| `requires` | `string_list` | `[]` | Package dependencies |
| `include_transitive_headers` | `bool` | `False` | Include transitive headers from cc_library deps |
| `package_name` | `string` | rule name | Override package name |
| `release` | `string` | `"1"` | Release number |
| `license` | `string` | `"Apache-2.0"` | Package license |
| `architecture` | `string` | `"x86_64"` | Target architecture |
| `group` | `string` | `"Applications/System"` | RPM package group |
| `vendor` | `string` | `""` | Package vendor |
| `packager` | `string` | `"Bazel <bazel@example.com>"` | Package maintainer |
| `url` | `string` | `""` | Project homepage |
| `binary_dir` | `string` | `"/usr/bin"` | Binary install directory |
| `library_dir` | `string` | `"/usr/lib64"` | Library install directory |
| `header_dir` | `string` | `"/usr/include"` | Header install directory |
| `config_dir` | `string` | `"/etc"` | Config install directory |
| `data_dir` | `string` | `"/usr/share"` | Data install directory |

See `examples/` for more examples.

---

*Co-authored by Claude*
