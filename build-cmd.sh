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
        
        # -------------------------- linux, linux64 --------------------------
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
            unset DISTCC_HOSTS CFLAGS CPPFLAGS CXXFLAGS

            # Default target per autobuild build --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE}"
            SIMD_FLAGS="-msse -msse2 -msse3 -mssse3 -msse4 -msse4.1 -msse4.2 -mcx16 -mpopcnt -mpclmul -maes"
            DEBUG_COMMON_FLAGS="$opts -Og -g -fPIC -DPIC $SIMD_FLAGS"
            RELEASE_COMMON_FLAGS="$opts -O3 -g -fPIC -DPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2 $SIMD_FLAGS"
            DEBUG_CFLAGS="$DEBUG_COMMON_FLAGS"
            RELEASE_CFLAGS="$RELEASE_COMMON_FLAGS"
            DEBUG_CXXFLAGS="$DEBUG_COMMON_FLAGS -std=c++17"
            RELEASE_CXXFLAGS="$RELEASE_COMMON_FLAGS -std=c++17"
            DEBUG_CPPFLAGS="-DPIC"
            RELEASE_CPPFLAGS="-DPIC -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi
            # clean up directories
            rm -rf "${stage:?}/lib"
            rm -rf "${stage:?}/include"
            mkdir -p "build_debug"
            pushd "build_debug"
                cmake ../ -G"Ninja" \
                    -DCMAKE_BUILD_TYPE=Debug \
                    -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_CXX_STANDARD=17 \
                    -DCMAKE_C_FLAGS="$DEBUG_CFLAGS" \
                    -DCMAKE_CXX_FLAGS="$DEBUG_CXXFLAGS" \
                    -DCMAKE_INSTALL_PREFIX="$stage/debug"

                cmake --build . --config Debug --parallel $AUTOBUILD_CPU_COUNT

                # conditionally run unit tests
                #if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                #    ctest -C Release
                #fi
                
                cmake --install . --config Debug
                
                # FIXME: Delete files that shouldn't be there
                # rm -r "$stage/include"
                # Move files to the right place
                mkdir -p "$stage/lib"
                mv "$stage/debug/lib" "$stage/lib/debug"
            popd

            # Release
            mkdir -p "build_release"
            pushd "build_release"
                cmake ../ -G"Ninja" \
                    -DCMAKE_BUILD_TYPE=Release \
                    -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_CXX_STANDARD=17 \
                    -DCMAKE_C_FLAGS="$RELEASE_CFLAGS" \
                    -DCMAKE_CXX_FLAGS="$RELEASE_CXXFLAGS" \
                    -DCMAKE_INSTALL_PREFIX="$stage/release"

                cmake --build . --config Release --parallel $AUTOBUILD_CPU_COUNT

            #     # conditionally run unit tests
            #     #if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            #     #    ctest -C Release
            #     #fi

                cmake --install . --config Release
                
                # FIXME: Temporary workaround for files in the wrong folder
                mkdir -p "$stage/include/"
                mv "$stage/release/include" "$stage/include/${PROJECT}"
                mv "$stage/release/lib" "$stage/lib/release"
            popd
        ;;
    esac

  mkdir -p "$stage/LICENSES"
  cp "LICENSE" "$stage/LICENSES/${PROJECT}.txt"
popd
