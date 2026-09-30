#!/usr/bin/env bash
# Re-export every STL in stl/ from clawdmeter_devkitc_st7796.scad.
# Usage: ./build.sh   (needs OpenSCAD on PATH)
set -euo pipefail
cd "$(dirname "$0")"
scad=clawdmeter_devkitc_st7796.scad
mkdir -p stl/multicolor

build() {  # build <out.stl> <openscad -D args...>
    local out=$1; shift
    openscad -q -o "$out" "$@" "$scad" && echo "  $out"
}

build stl/shell.stl    -D 'part="shell"' &
build stl/lid.stl      -D 'part="lid"' &
build stl/fit_test.stl -D 'part="fit_test"' &
for a in 25 30 35; do
    build "stl/stand_$a.stl" -D 'part="stand"' -D "stand_angle=$a" &
done
build stl/multicolor/lid.stl -D 'part="lid"' -D 'art_style="inlay"' &
for n in back skin flesh pit; do
    build "stl/multicolor/inlay_$n.stl" -D "part=\"inlay_$n\"" -D 'art_style="inlay"' &
done
fail=0
for pid in $(jobs -p); do wait "$pid" || fail=1; done
exit $fail
