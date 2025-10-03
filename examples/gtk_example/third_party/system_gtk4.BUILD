cc_library(
    name = "gtk4",
    hdrs = glob([
        "include/gtk-4.0/**/*.h",
    ]),
    includes = [
        "include/gtk-4.0",
    ],
    linkopts = [
        "-lgtk-4",
    ],
    deps = [
        "@system_glib2//:glib2",
        "@system_cairo//:cairo",
        "@system_pango//:pango",
        "@system_gdk_pixbuf//:gdk_pixbuf",
        "@system_graphene//:graphene",
    ],
    visibility = ["//visibility:public"],
)