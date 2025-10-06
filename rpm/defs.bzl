"""Public API for rules_rpm."""

load("//rpm/private:rpm_rule.bzl", _rpm_package = "rpm_package")

# Public API
rpm_package = _rpm_package
