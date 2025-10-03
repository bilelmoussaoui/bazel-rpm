cc_library(
    name = "glib2",
    hdrs = glob([
        "include/glib-2.0/**/*.h",
        "lib64/glib-2.0/include/**/*.h",
    ]),
    includes = [
        "include/glib-2.0",
        "lib64/glib-2.0/include",
    ],
    linkopts = [
        "-lglib-2.0",
        "-lgobject-2.0",
        "-lgio-2.0",
    ],
    visibility = ["//visibility:public"],
)