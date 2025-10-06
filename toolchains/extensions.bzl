"""Module extensions for RPM toolchain."""

load(":rpm_toolchain.bzl", "rpm_toolchain_repo")

def _rpm_toolchain_impl(module_ctx):  # @unused
    """Implementation of rpm_toolchain module extension."""
    rpm_toolchain_repo(name = "rpm_toolchain")

rpm_toolchain = module_extension(
    implementation = _rpm_toolchain_impl,
    doc = "Extension to set up RPM toolchain",
)
