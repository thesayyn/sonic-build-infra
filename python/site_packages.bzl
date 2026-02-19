load("@rules_python//python:defs.bzl", "PyInfo")
load("@tar.bzl", "tar", "mutate")

def _export_pyinfo(ctx):
    files = []
    for dep in ctx.attr.srcs:
        files.append(dep[PyInfo].transitive_sources)
    return DefaultInfo(files = depset([], transitive = files))

export_py_info = rule(
    implementation = _export_pyinfo,
    doc = "Export `PyInfo.transitive_sources` as DefaultInfo.",
    attrs = {
        "srcs": attr.label_list(providers = [PyInfo])
    }
)

def site_packages(name, srcs, **kwargs):
    """
    Conveninece macro to create a tar with a bunch of python dependencies.
    srcs must export the required files with `PyInfo`.
    """
    export_py_info(
        name = name + "_info",
        srcs = srcs,
    )
    tar(
        name = name,
        srcs = [":" + name + "_info"],
        **kwargs
    )
