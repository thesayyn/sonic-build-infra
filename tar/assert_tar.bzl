"Assertion helpers for tar archives"

load("@bazel_lib//lib:diff_test.bzl", "diff_test")

def assert_tar(name, tar, expected):
    """Assert that a tar archive contains the expected file listing.

    Args:
        name: name of the test target
        tar: label of the tar archive to check
        expected: label of a file containing the expected listing (one path per line)
                  Note that the contents of this line must have been created and sorted with `bsdtar -tvf | LC_ALL=C sort --key=9`.
    """
    listing = "{}_listing".format(name)

    native.genrule(
        name = listing,
        srcs = [tar],
        testonly = True,
        outs = ["{}.listing".format(name)],
        cmd = "$(BSDTAR_BIN) --verbose --list --file $(execpath {}) | LC_ALL=C sort --key=9 >$@".format(tar),
        toolchains = ["@tar.bzl//tar/toolchain:type"],
    )

    diff_test(
        name = name,
        file1 = listing,
        file2 = expected,
        timeout = "short",
    )
