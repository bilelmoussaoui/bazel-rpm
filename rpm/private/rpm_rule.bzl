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
    """Collect all transitive headers from cc_library targets."""
    transitive_headers = []

    for lib_target in ctx.attr.libraries:
        if CcInfo in lib_target:
            cc_info = lib_target[CcInfo]
            # Get all headers from transitive dependencies
            all_headers = cc_info.compilation_context.headers.to_list()
            transitive_headers.extend(all_headers)

    return transitive_headers

def _generate_files_list(ctx):
    """Generate %files section for spec file."""
    files = []

    # Add binaries
    for binary in ctx.files.binaries:
        files.append("{}/{}".format(ctx.attr.binary_dir, binary.basename))

    # Add libraries
    for library in ctx.files.libraries:
        files.append("{}/{}".format(ctx.attr.library_dir, library.basename))

    # Add explicit headers
    for header in ctx.files.headers:
        files.append("{}/{}".format(ctx.attr.header_dir, header.basename))

    # Add transitive headers from cc_library targets in libraries attribute
    transitive_headers = _collect_transitive_headers(ctx)
    for header in transitive_headers:
        files.append("{}/{}".format(ctx.attr.header_dir, header.basename))

    # Add configs
    for config in ctx.files.configs:
        files.append("{}/{}".format(ctx.attr.config_dir, config.basename))

    # Add data files
    for data_file in ctx.files.data:
        files.append("{}/{}".format(ctx.attr.data_dir, data_file.basename))

    return "\n".join(files)

def _generate_file_copy_scripts(ctx):
    """Generate file copy script snippets for different file types."""
    generated_files = []

    def _generate_copies(files, target_dir, file_type):
        if not files:
            return ""

        copies = []
        for file in files:
            copy_script_file = ctx.actions.declare_file("{}_{}_copy_{}.sh".format(ctx.label.name, file_type, file.basename))
            ctx.actions.expand_template(
                template = ctx.file._copy_file_template,
                output = copy_script_file,
                substitutions = {
                    "{FILE_TYPE}": file_type,
                    "{SOURCE_PATH}": file.path,
                    "{TARGET_DIR}": target_dir,
                    "{BASENAME}": file.basename,
                },
            )
            copies.append(copy_script_file.path)
            generated_files.append(copy_script_file)
        return "\n".join(["source {}".format(copy) for copy in copies])

    # Collect all headers (explicit + transitive from cc_library targets)
    all_headers = list(ctx.files.headers)
    transitive_headers = _collect_transitive_headers(ctx)
    all_headers.extend(transitive_headers)

    return {
        "binaries": _generate_copies(ctx.files.binaries, ctx.attr.binary_dir, "binary"),
        "libraries": _generate_copies(ctx.files.libraries, ctx.attr.library_dir, "library"),
        "headers": _generate_copies(all_headers, ctx.attr.header_dir, "header"),
        "configs": _generate_copies(ctx.files.configs, ctx.attr.config_dir, "config"),
        "data": _generate_copies(ctx.files.data, ctx.attr.data_dir, "data"),
        "generated_files": generated_files,
    }

def _stage_files(ctx, buildroot):
    """Stage files in buildroot directory using templates."""

    # Create a tar archive with all the files we want to package
    staging_tar = ctx.actions.declare_file("{}_staging.tar".format(ctx.label.name))
    staging_script = ctx.actions.declare_file("{}_stage.sh".format(ctx.label.name))

    # Generate file copy scripts
    copy_scripts = _generate_file_copy_scripts(ctx)
    all_script_files = copy_scripts["generated_files"]

    # Generate staging sections
    stage_binaries = ""
    stage_binaries_file = None
    if ctx.files.binaries:
        stage_binaries_file = ctx.actions.declare_file("{}_stage_binaries.sh".format(ctx.label.name))
        ctx.actions.expand_template(
            template = ctx.file._stage_binaries_template,
            output = stage_binaries_file,
            substitutions = {
                "{BINARY_DIR}": ctx.attr.binary_dir,
                "{BINARY_COPIES}": copy_scripts["binaries"],
            },
        )
        stage_binaries = stage_binaries_file.path
        all_script_files.append(stage_binaries_file)

    stage_libraries = ""
    stage_libraries_file = None
    if ctx.files.libraries:
        stage_libraries_file = ctx.actions.declare_file("{}_stage_libraries.sh".format(ctx.label.name))
        ctx.actions.expand_template(
            template = ctx.file._stage_libraries_template,
            output = stage_libraries_file,
            substitutions = {
                "{LIBRARY_DIR}": ctx.attr.library_dir,
                "{LIBRARY_COPIES}": copy_scripts["libraries"],
            },
        )
        stage_libraries = stage_libraries_file.path
        all_script_files.append(stage_libraries_file)

    stage_headers = ""
    stage_headers_file = None

    # Collect all headers (explicit + transitive from cc_library targets)
    all_headers = list(ctx.files.headers)
    transitive_headers = _collect_transitive_headers(ctx)
    all_headers.extend(transitive_headers)

    if all_headers:
        stage_headers_file = ctx.actions.declare_file("{}_stage_headers.sh".format(ctx.label.name))
        ctx.actions.expand_template(
            template = ctx.file._stage_headers_template,
            output = stage_headers_file,
            substitutions = {
                "{HEADER_DIR}": ctx.attr.header_dir,
                "{HEADER_COPIES}": copy_scripts["headers"],
            },
        )
        stage_headers = stage_headers_file.path
        all_script_files.append(stage_headers_file)

    stage_configs = ""
    stage_configs_file = None
    if ctx.files.configs:
        stage_configs_file = ctx.actions.declare_file("{}_stage_configs.sh".format(ctx.label.name))
        ctx.actions.expand_template(
            template = ctx.file._stage_configs_template,
            output = stage_configs_file,
            substitutions = {
                "{CONFIG_DIR}": ctx.attr.config_dir,
                "{CONFIG_COPIES}": copy_scripts["configs"],
            },
        )
        stage_configs = stage_configs_file.path
        all_script_files.append(stage_configs_file)

    stage_data = ""
    stage_data_file = None
    if ctx.files.data:
        stage_data_file = ctx.actions.declare_file("{}_stage_data.sh".format(ctx.label.name))
        ctx.actions.expand_template(
            template = ctx.file._stage_data_template,
            output = stage_data_file,
            substitutions = {
                "{DATA_DIR}": ctx.attr.data_dir,
                "{DATA_COPIES}": copy_scripts["data"],
            },
        )
        stage_data = stage_data_file.path
        all_script_files.append(stage_data_file)

    # Generate main staging script
    ctx.actions.expand_template(
        template = ctx.file._stage_files_template,
        output = staging_script,
        substitutions = {
            "{STAGE_BINARIES}": "source {}".format(stage_binaries) if stage_binaries else "# No binaries to stage",
            "{STAGE_LIBRARIES}": "source {}".format(stage_libraries) if stage_libraries else "# No libraries to stage",
            "{STAGE_HEADERS}": "source {}".format(stage_headers) if stage_headers else "# No headers to stage",
            "{STAGE_CONFIGS}": "source {}".format(stage_configs) if stage_configs else "# No configs to stage",
            "{STAGE_DATA}": "source {}".format(stage_data) if stage_data else "# No data files to stage",
        },
        is_executable = True,
    )

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