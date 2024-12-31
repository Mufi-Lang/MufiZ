#!/bin/bash
wc -l build.zig src/objects/*.zig src/*.zig src/stdlib/*.zig > lines_count.txt
