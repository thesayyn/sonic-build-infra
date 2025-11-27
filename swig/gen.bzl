load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cpp_toolchain", "use_cc_toolchain")

def _swig_gen_cc_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # Collect all include paths from compilation context of deps and hdrs
    compilation_contexts = []
    for dep in ctx.attr.deps:
        if CcInfo in dep:
            compilation_contexts.append(dep[CcInfo].compilation_context)
    for hdr in ctx.files.hdrs:
        compilation_contexts.append(cc_common.create_compilation_context(
            headers = depset([hdr]),
            includes = depset([hdr.dirname]),
        ))

    # Merge all compilation contexts
    compilation_context = cc_common.merge_compilation_contexts(
        compilation_contexts = compilation_contexts,
    )


    # Output files
    cpp_out = ctx.outputs.cpp_out
    python_out = ctx.outputs.python_out

    # Base name for generated files (from interface file)
    interface_file = ctx.file.interface

    # Arguments for SWIG
    args = ctx.actions.args()
    args.add("-c++")
    args.add("-python")
    args.add("-Wall")
    args.add("-keyword")
    args.add("-DSWIGWORDSIZE64")  # Important for 64-bit

    # Get include flags (-Ipath)
    include_args = []
    for include in compilation_context.includes.to_list():
        args.add("-I" +  include)
    for external_include in compilation_context.external_includes.to_list():
        args.add("-I" + external_include)


    args.add("-o", cpp_out.path)
    args.add("-outdir", python_out.dirname)
    args.add(interface_file.path)

    # Inputs: interface + all headers + transitive deps
    inputs = depset(
        direct = [interface_file] + ctx.files.hdrs,
        transitive = [compilation_context.headers],
    )

    # Tools: SWIG + C++ toolchain (for potential headers)
    tools = [ctx.executable._swig]

    ctx.actions.run(
        executable = ctx.executable._swig,
        arguments = [args],
        inputs = inputs,
        outputs = [cpp_out, python_out],
        tools = tools,
        mnemonic = "SwigGenCC",
        progress_message = "Generating SWIG bindings for %{label}",
    )

    return [
        DefaultInfo(files = depset([python_out, cpp_out])),
        OutputGroupInfo(
            cpp = depset([cpp_out]),
            python = depset([python_out]),
        ),
    ]

swig_gen = rule(
    implementation = _swig_gen_cc_impl,
    attrs = {
        "interface": attr.label(
            mandatory = True,
            allow_single_file = [".i"],
            doc = "The .i SWIG interface file",
        ),
        "hdrs": attr.label_list(
            allow_files = True,
            doc = "Public headers needed for SWIG processing",
        ),
        "deps": attr.label_list(
            doc = "cc_library dependencies that provide headers/includes",
            providers = [CcInfo],
        ),
        "cpp_out": attr.output(
            mandatory = True,
            doc = "Output C++ wrapper file (e.g. swsscommon_wrap.cpp)",
        ),
        "python_out": attr.output(
            mandatory = True,
            doc = "Output Python module (e.g. swsscommon.py)",
        ),
        "_swig": attr.label(
            default = "@swig//:swig",
            executable = True,
            cfg = "exec",
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
