#!/bin/bash

set -e

# Disable leak checking for now, there are some issues (or false positives)
# that we still need to fix
export ASAN_OPTIONS="detect_leaks=0"

export LSAN_OPTIONS="suppressions=$(pwd)/test/lsan_suppress.txt"
export CC

# Standard build
for CC in gcc gcc-6 clang; do
    mkdir build-${CC}; cd build-${CC}
    if [ ${CC} == 'gcc-6' ]; then
        build_opts='-D b_lundef=false'
    else
        build_opts=''
    fi
    meson -D werror=true ${build_opts} ../
    ninja

    sudo chown root:root util/fusermount3
    sudo chmod 4755 util/fusermount3
    TEST_WITH_VALGRIND=true ninja tests
    cd ..
done
(cd build-$CC; sudo ninja install)

# Sanitized build
CC=clang
for san in undefined address; do
    mkdir build-${san}; cd build-${san}
    # b_lundef=false is required to work around clang
    # bug, cf. https://groups.google.com/forum/#!topic/mesonbuild/tgEdAXIIdC4
    meson -D b_sanitize=${san} -D b_lundef=false -D werror=true ..
    ninja

    # Test as root and regular user
    sudo ninja tests
    sudo chown root:root util/fusermount3
    sudo chmod 4755 util/fusermount3
    ninja tests
    cd ..
done

# Autotools build
CC=gcc
./makeconf.sh
./configure
make
sudo python3 -m pytest test/
sudo make install

# Documentation
doxygen doc/Doxyfile

