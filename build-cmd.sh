#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

PROJECT=discord_rpc

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

SOURCE_DIR="discord-rpc"
BUILD_DIR="builds"

top="$(pwd)"
stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

echo "3.4.0" > "$stage/VERSION.txt"

mkdir -p "$stage/include/discord_rpc"

pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars


            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            mkdir -p "build"
            pushd "build"
                # Invoke cmake and use as official build
                cmake -G "$AUTOBUILD_WIN_CMAKE_GEN" -A "$AUTOBUILD_WIN_VSPLATFORM" -T host="$AUTOBUILD_WIN_VSHOST" .. -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DUSE_STATIC_CRT=OFF

                cmake --build . --config Debug
                cmake --build . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Debug
                    ctest -C Release
                fi

                cp -a "src/Debug/discord-rpc.lib" "$stage/lib/debug/discord-rpc.lib"
                cp -a "src/Release/discord-rpc.lib" "$stage/lib/release/discord-rpc.lib"
            popd
        ;;
    
        darwin*)
          echo "Darwin build not implemented yet!"
          exit 1
        ;;
    
        linux*)
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS
            
            # Default target per --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE}"
            #DEBUG_COMMON_FLAGS="$opts -Og -g -fPIC"
            RELEASE_COMMON_FLAGS="$opts -O3 -g -fPIC -fstack-protector-strong"
            #DEBUG_CFLAGS="$DEBUG_COMMON_FLAGS"
            RELEASE_CFLAGS="$RELEASE_COMMON_FLAGS"
            #DEBUG_CXXFLAGS="$DEBUG_COMMON_FLAGS -std=c++17"
            RELEASE_CXXFLAGS="$RELEASE_COMMON_FLAGS -std=c++17"
            #DEBUG_CPPFLAGS="-DPIC"
            RELEASE_CPPFLAGS="-DPIC -D_FORTIFY_SOURCE=2"
            
            mkdir -p "$stage/lib/release"
            mkdir -p "$stage/lib/debug"
            
            CFLAGS="$RELEASE_CFLAGS"
            CXXFLAGS="$RELEASE_CXXFLAGS"
            CPPFLAGS="$RELEASE_CPPFLAGS -I$stage/packages/include"
            LDFLAGS="-L$stage/packages/lib/release/"

            ./build.py --clean
            mkdir -p $stage/lib
            cp -r builds/install/linux-static/lib/* $stage/lib/release
        ;;
    esac

    cp -a "include/discord_rpc.h" "$stage/include/discord_rpc"
	cp -a "include/discord_register.h" "$stage/include/discord_rpc"

  mkdir -p "$stage/LICENSES"
  cp "LICENSE" "$stage/LICENSES/${PROJECT}.txt"
popd
