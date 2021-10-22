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

if [ -n "$OSTYPE" ]; then
  if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
  fi
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

echo "3.4.0" > VERSION.txt

pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            packages="$(cygpath -m "$stage/packages")"

            if [ "$AUTOBUILD_ADDRSIZE" = 32 ]
            then
                echo "32bit builds not supported!"
                exit 1
            else
              echo "64bit build not implemented yet"
              exit 1
                targetarch=x64
            fi
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
            mkdir -p $stage/include
            cp -r builds/install/linux-static/include $stage/include/${PROJECT}
            mkdir -p $stage/lib
            cp -r builds/install/linux-static/lib/* $stage/lib/release
        ;;
    esac

  mkdir -p "$stage/LICENSES"
  cp "LICENSE" "$stage/LICENSES/${PROJECT}.txt"
  cp ../VERSION.txt "$stage/"
popd
