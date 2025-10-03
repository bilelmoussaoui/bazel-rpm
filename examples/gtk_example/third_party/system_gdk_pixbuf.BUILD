cc_library(
    name = "gdk_pixbuf",
    hdrs = glob([
        "include/gdk-pixbuf-2.0/**/*.h",
    ]),
    includes = [
        "include/gdk-pixbuf-2.0",
    ],
    linkopts = [
        "-lgdk_pixbuf-2.0",
    ],
    deps = ["@system_glib2//:glib2"],
    visibility = ["//visibility:public"],
)