cc_library(
    name = "pango",
    hdrs = glob([
        "include/pango-1.0/**/*.h",
    ]),
    includes = [
        "include/pango-1.0",
    ],
    linkopts = [
        "-lpango-1.0",
        "-lpangocairo-1.0",
    ],
    deps = [
        "@system_cairo//:cairo",
        "@system_harfbuzz//:harfbuzz",
    ],
    visibility = ["//visibility:public"],
)