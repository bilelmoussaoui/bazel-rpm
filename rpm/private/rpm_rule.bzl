"""Implementation of rpm_package rule."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")

def _rpm_package_impl(ctx):
    """Implementation function for rpm_package rule."""

    # Declare output files
    rpm_file = ctx.actions.declare_file("{}.rpm".format(ctx.label.name))
    spec_file = ctx.actions.declare_file("{}.spec".format(ctx.label.name))
    buildroot = ctx.actions.declare_directory("{}_buildroot".format(ctx.label.name))

    # Generate spec file
    _generate_spec_file(ctx, spec_file)

    # Stage files in buildroot
    _stage_files(ctx, buildroot)

    # Build RPM
    _build_rpm(ctx, spec_file, buildroot, rpm_file)

    return [DefaultInfo(files = depset([rpm_file]))]

def _generate_spec_file(ctx, spec_file):
    """Generate RPM spec file."""

    # Generate requires section
    requires_section = ""
    if ctx.attr.requires:
        requires_section = "\n".join(["Requires: {}".format(req) for req in ctx.attr.requires])

    # Basic spec file template
    spec_content = """Name: {name}
Version: {version}
Release: {release}
Summary: {summary}
License: {license}
BuildArch: {arch}
{requires}

%description
{description}

%files
{files_list}

%changelog
* Mon Jan 01 2024 Bazel <bazel@example.com>
- Initial package
""".format(
        name = ctx.attr.package_name or ctx.label.name,
        version = ctx.attr.version,
        release = ctx.attr.release,
        summary = ctx.attr.summary or "Package built with Bazel",
        license = ctx.attr.license,
        arch = ctx.attr.architecture,
        requires = requires_section,
        description = ctx.attr.description or "Package built with Bazel rules_rpm",
        files_list = _generate_files_list(ctx),
    )

    ctx.actions.write(
        output = spec_file,
        content = spec_content,
    )

def _collect_transitive_headers(ctx):
    """Collect headers from cc_library targets based on inclusion policy."""
    if not ctx.attr.include_transitive_headers:
        return []

    transitive_headers = []

    for lib_target in ctx.attr.libraries:
        if CcInfo in lib_target:
            cc_info = lib_target[CcInfo]
            # Get all headers from transitive dependencies
            all_headers = cc_info.compilation_context.headers.to_list()
            transitive_headers.extend(all_headers)

    return transitive_headers

def _collect_direct_headers(ctx):
    """Collect only direct headers from cc_library targets."""
    direct_headers = []
    seen_basenames = {}
    for lib_target in ctx.attr.libraries:
        if CcInfo in lib_target:
            cc_info = lib_target[CcInfo]
            # Get only direct headers (not transitive)
            for header in cc_info.compilation_context.direct_headers:
                if header.basename not in seen_basenames:
                    seen_basenames[header.basename] = True
                    direct_headers.append(header)
    return direct_headers

def _collect_cc_headers(ctx):
    """Collect all headers: explicit headers + cc_library headers."""
    all_headers = list(ctx.files.headers)
    if ctx.attr.include_transitive_headers:
        cc_headers = _collect_transitive_headers(ctx)
    else:
        cc_headers = _collect_direct_headers(ctx)
    all_headers.extend(cc_headers)
    return all_headers

def _generate_files_list(ctx):
    """Generate %files section for spec file."""
    files = []

    # Add binaries
    for binary in ctx.files.binaries:
        files.append("{}/{}".format(ctx.attr.binary_dir, binary.basename))

    # Add libraries
    for library in ctx.files.libraries:
        files.append("{}/{}".format(ctx.attr.library_dir, library.basename))

    # Add all headers (explicit + from cc_library targets)
    all_headers = _collect_cc_headers(ctx)
    for header in all_headers:
        files.append("{}/{}".format(ctx.attr.header_dir, header.basename))

    # Add configs
    for config in ctx.files.configs:
        files.append("{}/{}".format(ctx.attr.config_dir, config.basename))

    # Add data files
    for data_file in ctx.files.data:
        files.append("{}/{}".format(ctx.attr.data_dir, data_file.basename))

    return "\n".join(files)

def _generate_file_copy_scripts(ctx):
    """Generate a single consolidated script that handles all file copying."""

    # Collect all headers (explicit + from cc_library targets)
    all_headers = _collect_cc_headers(ctx)

    # Helper function to generate copy commands for a file type
    def _generate_copy_section(files, target_dir, file_type):
        if not files:
            return "# No {file_type}s to stage".format(file_type=file_type)

        commands = []
        commands.append("# Stage {file_type} files to {target_dir}".format(file_type=file_type, target_dir=target_dir))
        commands.append("echo \"Staging {file_type}s to {target_dir}\"".format(file_type=file_type, target_dir=target_dir))
        commands.append("mkdir -p \"$TEMP_STAGE{target_dir}\"".format(target_dir=target_dir))

        for file in files:
            commands.append("""echo "Staging {file_type}: {source_path} -> $TEMP_STAGE{target_dir}/{basename}"
if [ -L "{source_path}" ]; then
    REAL_FILE=$(readlink -f "{source_path}")
    echo "Dereferencing symlink: $REAL_FILE"
    cp "$REAL_FILE" "$TEMP_STAGE{target_dir}/{basename}"
else
    cp "{source_path}" "$TEMP_STAGE{target_dir}/{basename}"
fi""".format(
                file_type=file_type,
                source_path=file.path,
                target_dir=target_dir,
                basename=file.basename,
            ))

        return "\n".join(commands)

    # Generate all copy sections
    copy_sections = []
    copy_sections.append(_generate_copy_section(ctx.files.binaries, ctx.attr.binary_dir, "binary"))
    copy_sections.append(_generate_copy_section(ctx.files.libraries, ctx.attr.library_dir, "library"))
    copy_sections.append(_generate_copy_section(all_headers, ctx.attr.header_dir, "header"))
    copy_sections.append(_generate_copy_section(ctx.files.configs, ctx.attr.config_dir, "config"))
    copy_sections.append(_generate_copy_section(ctx.files.data, ctx.attr.data_dir, "data"))

    # Create single consolidated script
    consolidated_script = ctx.actions.declare_file("{}_copy_all_files.sh".format(ctx.label.name))
    script_content = "\n\n".join(copy_sections)

    ctx.actions.write(
        output = consolidated_script,
        content = script_content,
    )

    return {
        "copy_script": consolidated_script.path,
        "generated_files": [consolidated_script],
    }

def _stage_files(ctx, buildroot):
    """Stage files in buildroot directory using templates."""

    # Create a tar archive with all the files we want to package
    staging_tar = ctx.actions.declare_file("{}_staging.tar".format(ctx.label.name))
    staging_script = ctx.actions.declare_file("{}_stage.sh".format(ctx.label.name))

    # Generate single consolidated copy script
    copy_scripts = _generate_file_copy_scripts(ctx)
    all_script_files = copy_scripts["generated_files"]

    # Generate main staging script using the consolidated copy script
    ctx.actions.expand_template(
        template = ctx.file._stage_files_template,
        output = staging_script,
        substitutions = {
            "{STAGE_DATA}": "source {}".format(copy_scripts["copy_script"]),
        },
        is_executable = True,
    )

    # Collect all headers for inputs
    all_headers = _collect_cc_headers(ctx)

    # Run staging script to create tar and extract to buildroot
    ctx.actions.run(
        inputs = ctx.files.binaries + ctx.files.libraries + all_headers + ctx.files.configs + ctx.files.data + all_script_files,
        outputs = [staging_tar, buildroot],
        executable = staging_script,
        arguments = [staging_tar.path, buildroot.path],
        mnemonic = "RpmStageFiles",
        progress_message = "Staging files for RPM %s" % ctx.label.name,
    )

def _build_rpm(ctx, spec_file, buildroot, rpm_file):
    """Build the RPM package using isolated /tmp directory."""

    # Generate build script from template
    build_script = ctx.actions.declare_file("{}_build.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._build_rpm_template,
        output = build_script,
        substitutions = {
            "{SPEC_FILE}": spec_file.path,
            "{BUILDROOT_PATH}": buildroot.path,
            "{RPM_OUTPUT}": rpm_file.path,
            "{SPEC_BASENAME}": spec_file.basename,
        },
        is_executable = True,
    )

    # Run the build script
    ctx.actions.run(
        inputs = [spec_file, buildroot],
        outputs = [rpm_file],
        executable = build_script,
        mnemonic = "RpmBuild",
        progress_message = "Building RPM %s" % ctx.label.name,
    )

rpm_package = rule(
    implementation = _rpm_package_impl,
    attrs = {
        "binaries": attr.label_list(
            allow_files = True,
            doc = "Binary files to include in the package",
        ),
        "libraries": attr.label_list(
            allow_files = True,
            doc = "Library files to include in the package",
        ),
        "headers": attr.label_list(
            allow_files = True,
            doc = "Header files to include in the package",
        ),
        "configs": attr.label_list(
            allow_files = True,
            doc = "Configuration files to include in the package",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Data files to include in the package",
        ),
        "package_name": attr.string(
            doc = "Name of the RPM package (defaults to rule name)",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Version of the package",
        ),
        "release": attr.string(
            default = "1",
            doc = "Release number of the package",
        ),
        "summary": attr.string(
            doc = "Short summary of the package",
        ),
        "description": attr.string(
            doc = "Detailed description of the package",
        ),
        "license": attr.string(
            default = "Apache-2.0",
            doc = "License of the package",
        ),
        "architecture": attr.string(
            default = "x86_64",
            doc = "Target architecture",
        ),
        "binary_dir": attr.string(
            default = "/usr/bin",
            doc = "Directory to install binaries",
        ),
        "library_dir": attr.string(
            default = "/usr/lib64",
            doc = "Directory to install libraries",
        ),
        "header_dir": attr.string(
            default = "/usr/include",
            doc = "Directory to install header files",
        ),
        "config_dir": attr.string(
            default = "/etc",
            doc = "Directory to install configuration files",
        ),
        "data_dir": attr.string(
            default = "/usr/share",
            doc = "Directory to install data files",
        ),
        "requires": attr.string_list(
            doc = "List of RPM package dependencies",
        ),
        "include_transitive_headers": attr.bool(
            default = False,
            doc = "Include transitive headers from cc_library dependencies. Set to False to include only direct headers (recommended for most use cases).",
        ),
        "_copy_file_template": attr.label(
            default = "//rpm/private/templates:copy_file.sh.tpl",
            allow_single_file = True,
        ),
        "_stage_files_template": attr.label(
            default = "//rpm/private/templates:stage_files.sh.tpl",
            allow_single_file = True,
        ),
        "_stage_binaries_template": attr.label(
            default = "//rpm/private/templates:stage_binaries.sh.tpl",
            allow_single_file = True,
        ),
        "_stage_libraries_template": attr.label(
            default = "//rpm/private/templates:stage_libraries.sh.tpl",
            allow_single_file = True,
        ),
        "_stage_headers_template": attr.label(
            default = "//rpm/private/templates:stage_headers.sh.tpl",
            allow_single_file = True,
        ),
        "_stage_configs_template": attr.label(
            default = "//rpm/private/templates:stage_configs.sh.tpl",
            allow_single_file = True,
        ),
        "_stage_data_template": attr.label(
            default = "//rpm/private/templates:stage_data.sh.tpl",
            allow_single_file = True,
        ),
        "_build_rpm_template": attr.label(
            default = "//rpm/private/templates:build_rpm.sh.tpl",
            allow_single_file = True,
        ),
    },
    toolchains = ["//toolchains:rpm_toolchain_type"],
    doc = "Creates an RPM package from Bazel targets",
)
