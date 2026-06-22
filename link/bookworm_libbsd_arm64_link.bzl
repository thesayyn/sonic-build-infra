"""Link helpers for Bookworm libbsd on native aarch64 exec platforms.

Debian linker scripts from @bookworm / rules_distroless embed absolute paths such
as /usr/lib/aarch64-linux-gnu/libbsd.so.0.11.7. Ubuntu arm64 hosts often ship a
newer SONAME (0.12.x). Remap that path to a copy of the hermetic apt .so in the
Bazel action graph (see src/libteam/libteam.BUILD for background).
"""

_AARCH64_CPU = "@@platforms//cpu:aarch64"

# Bookworm snapshot libbsd0 arm64 (rules_distroless++apt repo name is stable in this tree).
_DEFAULT_LIBBSD_EXPORT = "@@rules_distroless++apt+bookworm_libbsd0-arm64_0.11.7-2//:export"

_DEFAULT_HOST_SONAME = "/usr/lib/aarch64-linux-gnu/libbsd.so.0.11.7"

_DEFAULT_COPY_TARGET = ":copy_bookworm_libbsd_so_arm64"

def bookworm_libbsd_arm64_copy(
        name = "copy_bookworm_libbsd_so_arm64",
        libbsd_export = _DEFAULT_LIBBSD_EXPORT,
        visibility = None):
    """Materialize libbsd.so.0.11.7 from the Bookworm arm64 apt package for --remap-inputs."""
    native.genrule(
        name = name,
        srcs = [libbsd_export],
        outs = ["bookworm_libbsd_so_0_11_7_arm64"],
        cmd = "for f in $(locations {export}); do case $$f in *libbsd.so.0.11.7) cp \"$$f\" $@; exit 0;; esac; done; exit 1".format(
            export = libbsd_export,
        ),
        tags = ["manual"],
        target_compatible_with = [_AARCH64_CPU],
        visibility = visibility,
    )

def _remap_linkopt(copy = _DEFAULT_COPY_TARGET, host_soname = _DEFAULT_HOST_SONAME):
    return "-Wl,--remap-inputs={}=$(execpath {})".format(host_soname, copy)

def bookworm_libbsd_arm64_linkopts(*, copy = _DEFAULT_COPY_TARGET, base = []):
    """Append aarch64-only -Wl,--remap-inputs for rules_cc linkopts (concat after base)."""
    return base + select({
        _AARCH64_CPU: [_remap_linkopt(copy = copy)],
        "//conditions:default": [],
    })

def bookworm_libbsd_arm64_additional_linker_inputs(*, copy = _DEFAULT_COPY_TARGET):
    """additional_linker_inputs for rules_cc targets using bookworm_libbsd_arm64_linkopts."""
    return select({
        _AARCH64_CPU: [copy],
        "//conditions:default": [],
    })

# rules_go does not expand $(execpath) in clinkopts. For CGO, add an empty cc_library
# with bookworm_libbsd_arm64_linkopts() + bookworm_libbsd_arm64_additional_linker_inputs()
# to go_library cdeps (see sonic-gnmi/sonic_data_client/BUILD.bazel).

