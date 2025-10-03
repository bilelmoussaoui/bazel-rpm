cc_library(
    name = "graphene",
    hdrs = glob([
        "include/graphene-1.0/**/*.h",
        "lib64/graphene-1.0/include/**/*.h",
    ]),
    includes = [
        "include/graphene-1.0",
        "lib64/graphene-1.0/include",
    ],
    linkopts = [
        "-lgraphene-1.0",
    ],
    visibility = ["//visibility:public"],
)