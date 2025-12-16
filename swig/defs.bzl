"""SWIG rules for generating Python bindings."""

load(":extract.bzl", _swig_lib_deb = "swig_lib_deb")
load(":gen.bzl", _swig_gen = "swig_gen")

swig_lib_deb = _swig_lib_deb
swig_gen = _swig_gen
