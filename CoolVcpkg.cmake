
cmake_minimum_required(VERSION 3.28)

include_guard(GLOBAL)

# When including this module, check that we are up-to-date (as long as the user has not opted out of it)
set(_cool_vcpkg_version 0.1.1 CACHE INTERNAL "Version of the cool-vcpkg CMake module" FORCE)

option(COOL_VCPKG_ENABLED "Enable the cool-vcpkg CMake module" ON)
option(COOL_VCPKG_CHECK_FOR_UPDATES "Enable checking for latest updates from the github repository" ON)
set(COOL_VCPKG_DEFAULT_TRIPLET "" CACHE STRING
        "Default triplet to build targets with when custom options are not applied.")
set_property(CACHE COOL_VCPKG_DEFAULT_TRIPLET PROPERTY
        STRINGS
        # Official triplets
        arm64-android arm64-osx arm64-uwp arm64-windows arm-neon-android x64-android x64-linux x64-osx x64-uwp
        x64-windows x64-windows-static x86-windows
        # Community triplets
        arm-android arm-ios arm-linux-release arm-linux arm-mingw-dynamic arm-mingw-static arm-uwp-static-md arm-uwp
        arm-windows-static arm-windows arm64-ios-release arm64-ios-simulator-release arm64-ios-simulator arm64-ios
        arm64-linux-release arm64-linux arm64-mingw-dynamic arm64-mingw-static arm64-osx-dynamic arm64-osx-release
        arm64-uwp-static-md arm64-windows-static-md arm64-windows-static-release arm64-windows-static arm64ec-windows
        armv6-android loongarch32-linux-release loongarch32-linux loongarch64-linux-release loongarch64-linux
        mips64-linux ppc64le-linux-release ppc64le-linux riscv32-linux-release riscv32-linux riscv64-linux-release
        riscv64-linux s390x-linux-release s390x-linux wasm32-emscripten x64-freebsd x64-ios x64-linux-dynamic
        x64-linux-release x64-mingw-dynamic x64-mingw-static x64-openbsd x64-osx-dynamic x64-osx-release
        x64-uwp-static-md x64-windows-release x64-windows-static-md-release x64-windows-static-md
        x64-windows-static-release x64-xbox-scarlett-static x64-xbox-scarlett x64-xbox-xboxone-static x64-xbox-xboxone
        x86-android x86-freebsd x86-ios x86-linux x86-mingw-dynamic x86-mingw-static x86-uwp-static-md x86-uwp
        x86-windows-static-md x86-windows-static x86-windows-v120
)
#option(COOL_VCPKG_COMMAND_ECHO "Enable output for the vcpkg commands? Such as (bootstrap, install, etc.)" OFF)
#option(COOL_VCPKG_DEBUG_OUTPUT "Enable debug output for the cool-vcpkg CMake module" OFF)

# Private
# A code stream is like a string builder, with the ability to increment and decrement the indentation level
# Inefficient I'm sure but it doesn't matter, really.
# The data structure is a cmake list[0: indent_size, 1: current_indent_level, 2: string]
function(_cool_vcpkg_code_stream)

    set(options INCREMENT_INDENT DECREMENT_INDENT SET_INDENT_SIZE APPEND GET SET)
    set(oneValueArgs VARIABLE INDENT_SIZE VALUE OUTPUT_VARIABLE)
    cmake_parse_arguments(code_stream "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT DEFINED code_stream_VARIABLE)
        message(FATAL_ERROR "_cool_vcpkg_code_stream() requires a VARIABLE argument.")
    endif()

    # Do all of our work on a copy, at the end we will determine how to return it to the user.
    # based on their OUTPUT_VARIABLE argument.
    set(working_copy ${${code_stream_VARIABLE}})

    list(LENGTH working_copy working_copy_length)
    if (working_copy_length EQUAL 0)
        list(APPEND working_copy "0") # indent size
        list(APPEND working_copy "0") # current indent level
        list(APPEND working_copy "R") # string
    elseif (NOT working_copy_length EQUAL 3)
        message(FATAL_ERROR "The VARIABLE argument has an invalid data structure. _cool_vcpkg_code_stream() will create the data "
                "structure if the VARIABLE is the empty string, otherwise it expects a list of length 3.")
    endif()

    if (code_stream_SET_INDENT_SIZE)

        if (NOT DEFINED code_stream_INDENT_SIZE)
            message(FATAL_ERROR "_cool_vcpkg_code_stream(SET_INDENT_SIZE) requires an INDENT_SIZE argument.")
        endif()

        list(REMOVE_AT working_copy 0)
        list(INSERT working_copy 0 ${code_stream_INDENT_SIZE})

    endif (code_stream_SET_INDENT_SIZE)

    if (code_stream_INCREMENT_INDENT)
        list(GET working_copy 1 current_indent_level)
        list(REMOVE_AT working_copy 1)
        math(EXPR new_indent_level "${current_indent_level} + 1")
        list(INSERT working_copy 1 ${new_indent_level})
    endif (code_stream_INCREMENT_INDENT)

    if (code_stream_DECREMENT_INDENT)
        list(GET working_copy 1 current_indent_level)
        list(REMOVE_AT working_copy 1)
        math(EXPR new_indent_level "${current_indent_level} - 1")
        if (new_indent_level LESS 0)
            message(FATAL_ERROR "_cool_vcpkg_code_stream(DECREMENT_INDENT) is attempting to reduce the indent level below 0. "
                    "Your INCREMENT_INDENT and DECREMENT_INDENT calls are unbalanced.")
        endif()
        list(INSERT working_copy 1 ${new_indent_level})
    endif (code_stream_DECREMENT_INDENT)

    if (code_stream_APPEND)

        if (NOT DEFINED code_stream_VALUE)
            message(FATAL_ERROR "_cool_vcpkg_code_stream(APPEND) requires a VALUE argument.")
        endif()

        list(GET working_copy 0 indent_size)
        list(GET working_copy 1 current_indent_level)
        list(POP_BACK working_copy current_string)

        # Add indents to the VALUE string
        set(replacement_string "")
        if (NOT indent_size EQUAL 0)
            string(APPEND replacement_string " ")
        endif()
        string(REPEAT "${replacement_string}" ${indent_size} replacement_string)
        string(REPEAT "${replacement_string}" ${current_indent_level} replacement_string)

        string(REGEX REPLACE "\n" "\n${replacement_string}" code_stream_VALUE ${code_stream_VALUE})
        string(APPEND current_string "${code_stream_VALUE}")
        list(APPEND working_copy "${current_string}")

    endif (code_stream_APPEND)

    if (code_stream_GET)

        if (NOT DEFINED code_stream_OUTPUT_VARIABLE)
            message(FATAL_ERROR "_cool_vcpkg_code_stream(GET) requires an OUTPUT_VARIABLE argument.")
        endif()

        list(GET working_copy 2 output_string)
        string(SUBSTRING ${output_string} 1 -1 output_string)
        set(${code_stream_OUTPUT_VARIABLE} ${output_string} PARENT_SCOPE)
        return()

    endif (code_stream_GET)

    if (code_stream_SET)

        if (NOT DEFINED code_stream_VALUE)
            message(FATAL_ERROR "_cool_vcpkg_code_stream(SET) requires a VALUE argument.")
        endif()

        list(POP_BACK working_copy current_string)
        string(PREPEND code_stream_VALUE "R")
        list(APPEND working_copy ${code_stream_VALUE})

    endif (code_stream_SET)

    if (DEFINED code_stream_OUTPUT_VARIABLE)
        set(${code_stream_OUTPUT_VARIABLE} ${working_copy} PARENT_SCOPE)
    else()
        set(${code_stream_VARIABLE} ${working_copy} PARENT_SCOPE)
    endif()

endfunction()

# Private
# Add a bunch of excess trailing slashes to a path to ensure that it will be normalized correctly. I cant
# reliably get NORMAL_PATH to append the trailing slash.
function(_cool_vcpkg_normalize_path)
    set(oneValueArgs PATH OUTPUT_VARIABLE)
    cmake_parse_arguments(normalize_path "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT DEFINED normalize_path_PATH)
        message(FATAL_ERROR "_cool_vcpkg_normalize_path() requires a PATH argument.")
    endif()

    if (NOT DEFINED normalize_path_OUTPUT_VARIABLE)
        message(FATAL_ERROR "_cool_vcpkg_normalize_path() requires an OUTPUT_VARIABLE argument.")
    endif()

    set(pre_normalized "${normalize_path_PATH}")
    string(APPEND pre_normalized "///")
    cmake_path(NORMAL_PATH pre_normalized OUTPUT_VARIABLE normalized)
    set(${normalize_path_OUTPUT_VARIABLE} ${normalized} PARENT_SCOPE)

endfunction()

# Private
# Utility function to sleep for a random amount of milliseconds up to MAX_WAIT.
function(_cool_vcpkg_random_wait MAX_WAIT)
    # Generate a random number between 0 and MAX_WAIT
    string(RANDOM LENGTH 6 ALPHABET "0123456789" random_wait_value)
    math(EXPR random_wait_value "${random_wait_value} % ${MAX_WAIT}")
    # Convert milliseconds to seconds
    math(EXPR random_wait_value "${random_wait_value} / 1000")
    # Execute the sleep command
    execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep "${random_wait_value}")
endfunction()

# Private
# Utility function to get the latest release version information from the cool-vcpkg github repository.
function(_cool_vcpkg_check_latest_release_info)

    if (NOT DEFINED _cool_vcpkg_latest_version OR _cool_vcpkg_latest_version STREQUAL "")
        set(api_url "https://api.github.com/repos/XJ-0461/cool-vcpkg/releases/latest")
        file(DOWNLOAD ${api_url} ${CMAKE_CURRENT_BINARY_DIR}/cool_vcpkg_latest_release_info.json
                STATUS download_status
                TIMEOUT 10
        )
        file(READ ${CMAKE_CURRENT_BINARY_DIR}/cool_vcpkg_latest_release_info.json latest_release_info)
        string(JSON latest_version_string
                ERROR_VARIABLE latest_version_string_error
                GET "${latest_release_info}"
                "tag_name"
        )
        if (NOT latest_version_string STREQUAL "NOTFOUND")
            string(SUBSTRING "${latest_version_string}" 1 -1 latest_version_string)
        else()
            set(latest_version_string 0.0.0)
        endif()

        set(_cool_vcpkg_latest_version "${latest_version_string}" CACHE INTERNAL
                "The latest version of cool-vcpkg from the github repo. Defaults to 0.0.0 if there was an error" FORCE
        )
    endif()

    if ("${_cool_vcpkg_latest_version}" VERSION_GREATER "${_cool_vcpkg_version}")
        message(WARNING "There is a newer version of cool-vcpkg available: v${_cool_vcpkg_latest_version}")
    endif()

    file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/cool_vcpkg_latest_release_info.json)

endfunction()

macro(cool_vcpkg_WriteVcpkgConfigurationFile)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_write_vcpkg_configuration_file(${args})
    endif()
endmacro()

function(_cool_vcpkg_write_vcpkg_configuration_file)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_WriteVcpkgConfigurationFile"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_write_vcpkg_configuration_file" OUTPUT_VARIABLE args
    )

    set(multiValueArgs OVERLAY_TRIPLETS_PATHS)
    cmake_parse_arguments(vcpkg_config_file "${options}" "${oneValueArgs}" "${multiValueArgs}" ${args})

    set(config_file "")
    _cool_vcpkg_code_stream(SET_INDENT_SIZE VARIABLE config_file INDENT_SIZE 4)
    _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE config_file
            VALUE "{\n\"$schema\": \"https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg-configuration.schema.json\",\n\"overlay-triplets\": ["
    )
    _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE config_file VALUE "\n")

    # Vcpkg Configuration section
    list(LENGTH vcpkg_config_file_OVERLAY_TRIPLETS_PATHS overlay_triplets_count)
    if (overlay_triplets_count GREATER 0)
        set(actually_create_file TRUE)
    endif()

    set(append_comma FALSE)
    foreach (overlay_triplet_path IN LISTS vcpkg_config_file_OVERLAY_TRIPLETS_PATHS)
        if (append_comma)
            _cool_vcpkg_code_stream(APPEND VARIABLE config_file VALUE ",\n")
        endif()
        _cool_vcpkg_code_stream(APPEND VARIABLE config_file VALUE "\"./custom-triplets/\"")
        set(append_comma TRUE)
    endforeach()
    _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE config_file VALUE "\n]")
    _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE config_file VALUE "\n}")

    _cool_vcpkg_code_stream(GET VARIABLE config_file OUTPUT_VARIABLE config_file_output)
    fiLe(CONFIGURE
            OUTPUT ${_cool_vcpkg_manifest_path}/vcpkg-configuration.json
            CONTENT "${config_file_output}"
            @ONLY
    )

endfunction()

macro(cool_vcpkg_WriteVcpkgManifestFile)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_write_vcpkg_manifest_file(${args})
    endif()
endmacro()

function(_cool_vcpkg_write_vcpkg_manifest_file)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_WriteVcpkgManifestFile"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_write_vcpkg_manifest_file" OUTPUT_VARIABLE args
    )

    set(oneValueArgs BUILTIN_BASELINE)
    set(multiValueArgs TARGETS OVERLAY_TRIPLETS_PATHS)
    cmake_parse_arguments(write_vcpkg_manifest_file "${options}" "${oneValueArgs}" "${multiValueArgs}" ${args})

    set(builtin_baseline "f7423ee180c4b7f40d43402c2feb3859161ef625")
    if (NOT _cool_vcpkg_current_commit_hash STREQUAL "")
        set(builtin_baseline "${_cool_vcpkg_current_commit_hash}")
    else()
        message(WARNING "No commit hash could be determined for the current vcpkg checkout. This shouldn't be the case."
                "Using builtin-baseline '${builtin_baseline}' a commit from June 14, 2024"
        )
    endif()
    if (DEFINED write_vcpkg_manifest_file_BUILTIN_BASELINE AND NOT write_vcpkg_manifest_file_BUILTIN_BASELINE STREQUAL "")
        set(builtin_baseline "${write_vcpkg_manifest_file_BUILTIN_BASELINE}")
    endif()

    set(manifest "")
    _cool_vcpkg_code_stream(SET_INDENT_SIZE VARIABLE manifest INDENT_SIZE 4)
    _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE manifest
            VALUE "{\n\"$schema\": \"https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg.schema.json\",\n\"dependencies\": [")
    _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE manifest VALUE "\n")

    # dependencies section
    set(append_comma FALSE)
    foreach(target IN LISTS write_vcpkg_manifest_file_TARGETS)

        if (append_comma)
            _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE ",\n")
        endif()
        _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE manifest VALUE "{\n\"name\": \"${target}\"")

        _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE ",\n\"default-features\": ")
        if (_cool_vcpkg_declared_package_${target}_use_default_features)
            _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE "true")
        else()
            _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE "false")
        endif()

        set(has_emitted_features FALSE)
        foreach(feature IN LISTS _cool_vcpkg_declared_package_${target}_features)
            if (NOT has_emitted_features)
                _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE ",\n\"features\": [")
                _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE manifest VALUE "\n")
                set(has_emitted_features TRUE)
            else()
                _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE ",\n")
            endif()
            _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE "\"${feature}\"")
        endforeach()
        if (has_emitted_features)
            _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE manifest VALUE "\n]")
        endif()

        # todo: there is a place for this version>= mechanism due to the trickiness with version formats not being
        # comparable (even when it looks trivial) ill figure it out later. For now I've learned that the
        # 'overrides' section works better because I'm guessing it does an exact string compare.
        #        if (NOT "${_cool_vcpkg_declared_package_${target}_version}" STREQUAL "")
        #            _cool_vcpkg_code_stream(APPEND VARIABLE manifest
        #                    VALUE ",\n\"version>=\": \"${_cool_vcpkg_declared_package_${target}_version}\""
        #            )
        #        endif()

        _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE manifest VALUE "\n}")
        set(append_comma TRUE)
    endforeach()

    _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE manifest VALUE "\n],")

    _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE "\n\"builtin-baseline\": \"${builtin_baseline}\"")

    # Overrides section
    set(included_override_section FALSE)
    foreach (target IN LISTS write_vcpkg_manifest_file_TARGETS)
        if (NOT "${_cool_vcpkg_declared_package_${target}_version}" STREQUAL "")
            if (NOT included_override_section)
                _cool_vcpkg_code_stream(APPEND VARIABLE manifest VALUE ",\n\"overrides\": [")
                set(included_override_section TRUE)
            endif()
            _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE manifest VALUE "\n{")
            _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE manifest
                    VALUE "\n\"name\": \"${target}\",\n\"version\": \"${_cool_vcpkg_declared_package_${target}_version}\"")
            _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE manifest VALUE "\n}")
        endif()
    endforeach()

    if (included_override_section)
        _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE manifest VALUE "\n]")
    endif()

    _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE manifest VALUE "\n}")

    set(_cool_vcpkg_manifest_path ${_cool_vcpkg_build_local_directory} CACHE INTERNAL
            "Path to this configuration's vcpkg manifest and vcpkg-configuration files" FORCE
    )

    _cool_vcpkg_code_stream(GET VARIABLE manifest OUTPUT_VARIABLE manifest_output)
    fiLe(CONFIGURE
            OUTPUT ${_cool_vcpkg_manifest_path}/vcpkg.json
            CONTENT "${manifest_output}"
    )

endfunction()

macro(cool_vcpkg_WriteVcpkgCustomTripletFile)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_write_vcpkg_custom_triplet_file(${args})
    endif()
endmacro()

# Creates a custom triplet file which can allow different vcpkg dependencies to be built and included into the project
# with different linkages and architectures.
function(_cool_vcpkg_write_vcpkg_custom_triplet_file)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_WriteVcpkgCustomTripletFile"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_write_vcpkg_custom_triplet_file" OUTPUT_VARIABLE args
    )

    set(multiValueArgs TARGETS)
    cmake_parse_arguments(custom_triplet_file "${options}" "${oneValueArgs}" "${multiValueArgs}" ${args})

    set(triplet_file "")
    _cool_vcpkg_code_stream(SET_INDENT_SIZE VARIABLE triplet_file INDENT_SIZE 8)
    string(APPEND comment_string "This custom triplet file was generated by cool-vcpkg. Custom triplet files "
            "allow users include vcpkg dependencies with different linkages and architectures in the same project.")
    _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file VALUE "# ${comment_string}\n\n")

    _cool_vcpkg_normalize_path(PATH "${_cool_vcpkg_root_directory}/triplets/" OUTPUT_VARIABLE triplet_dir)
    set(fallback_logic "")
    string(APPEND fallback_logic
            "if (EXISTS \"${triplet_dir}${_cool_vcpkg_default_triplet}.cmake\")\n"
            "        include(\"${triplet_dir}${_cool_vcpkg_default_triplet}.cmake\")\n"
            "elseif (EXISTS \"${triplet_dir}community/${_cool_vcpkg_default_triplet}.cmake\")\n"
            "        include(\"${triplet_dir}community/${_cool_vcpkg_default_triplet}.cmake\")\n"
            "else()\n"
            "        message(FATAL_ERROR \"Triplet file not found: ${_cool_vcpkg_default_triplet}\")\n"
            "endif()\n\n"
    )
    _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file VALUE "${fallback_logic}")

    set(actually_create_file FALSE) # We only want to create the file if there are any customizations.
    # dependencies section
    foreach(target IN LISTS custom_triplet_file_TARGETS)
        set(has_customizations FALSE)
        _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file VALUE "if ($")
        _cool_vcpkg_code_stream(INCREMENT_INDENT APPEND VARIABLE triplet_file VALUE "{PORT} MATCHES \"${target}\")")

        set(temp "${_cool_vcpkg_declared_package_${target}_target_architecture}")
        if (NOT "${temp}" STREQUAL "")
            _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file
                    VALUE "\nset(VCPKG_TARGET_ARCHITECTURE ${temp})"
            )
            set(has_customizations TRUE)
        endif()

        set(temp "${_cool_vcpkg_declared_package_${target}_crt_linkage}")
        if (NOT "${temp}" STREQUAL "")
            _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file
                    VALUE "\nset(VCPKG_CRT_LINKAGE ${temp})"
            )
            set(has_customizations TRUE)
        endif()

        set(temp "${_cool_vcpkg_declared_package_${target}_library_linkage}")
        if (NOT "${temp}" STREQUAL "")
            _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file
                    VALUE "\nset(VCPKG_LIBRARY_LINKAGE ${temp})"
            )
            set(has_customizations TRUE)
        endif()

        if (NOT has_customizations)
            _cool_vcpkg_code_stream(APPEND VARIABLE triplet_file VALUE "\n# This target does not have any customizations.")
        else()
            set(actually_create_file TRUE)
        endif()

        _cool_vcpkg_code_stream(DECREMENT_INDENT APPEND VARIABLE triplet_file VALUE "\nendif()\n\n")

    endforeach()

    if (NOT actually_create_file)
        message(DEBUG "No customizations to vcpkg targets were made, skipping custom triplet file generation.")
        return()
    endif()

    set(_cool_vcpkg_custom_triplet_path "${_cool_vcpkg_build_local_directory}/custom-triplets/" CACHE INTERNAL
            "Path to where the generated custom triplets live. This is what enables us to easily choose the linkages and bitness of our targets." FORCE)
    _cool_vcpkg_normalize_path(PATH "${_cool_vcpkg_custom_triplet_path}" OUTPUT_VARIABLE _cool_vcpkg_custom_triplet_path)

    _cool_vcpkg_code_stream(GET VARIABLE triplet_file OUTPUT_VARIABLE custom_triplet_output)
    fiLe(CONFIGURE
            OUTPUT ${_cool_vcpkg_custom_triplet_path}/cool-vcpkg-custom-triplet.cmake
            CONTENT "${custom_triplet_output}"
            @ONLY
    )

endfunction()

# This should only be included once per run, otherwise it will call internal _find_package recursively forever and
# cause an error.
macro(cool_vcpkg_IncludeVcpkgToolchainFile)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_include_vcpkg_toolchain_file(${args})
    endif()
endmacro()

# This should only be included once per run, otherwise it will call internal _find_package recursively forever and
# cause an error.
macro(_cool_vcpkg_include_vcpkg_toolchain_file)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_IncludeVcpkgToolchainFile"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_include_vcpkg_toolchain_file" OUTPUT_VARIABLE args
    )

    if (DEFINED _cool_vcpkg_is_bootstrapped)

        if (NOT DEFINED _cool_vcpkg_toolchain_file)
            message(FATAL_ERROR "_cool_vcpkg_toolchain_file is not defined. "
                    "User should not see this error message, please report this issue.")
        endif()

        if ("${_cool_vcpkg_toolchain_file}" STREQUAL "")
            message(FATAL_ERROR "_cool_vcpkg_toolchain_file is an empty string. "
                    "User should not see this error message, please report this issue.")
        endif()

        if (NOT DEFINED cool_vcpkg_toolchain_file_included)
            include("${_cool_vcpkg_toolchain_file}")
            set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" CACHE STRING "Where find_package() will search for packages.")
        endif()
        set(cool_vcpkg_toolchain_file_included TRUE)

    endif()

endmacro()

macro(cool_vcpkg_RunBootstrapScript)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_run_bootstrap_script(${args})
    endif()
endmacro()

macro(_cool_vcpkg_run_bootstrap_script)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_RunBootstrapScript"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_run_bootstrap_script" OUTPUT_VARIABLE args
    )

    #disabled by default
    set(collect_metrics "-disableMetrics")
    if (_cool_vcpkg_is_collecting_metrics)
        set(collect_metrics "")
    endif()

    set(command_echo "")
    if (COOL_VCPKG_COMMAND_ECHO)
        set(command_echo "COMMAND_ECHO STDOUT")
    endif()

    message(STATUS "Running bootstrap script for vcpkg.")
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        execute_process(
                COMMAND ./bootstrap-vcpkg.bat ${collect_metrics}
                WORKING_DIRECTORY ${_cool_vcpkg_root_directory}
                ${command_echo}
        )
    else()
        execute_process(
                COMMAND ./bootstrap-vcpkg.sh ${collect_metrics}
                WORKING_DIRECTORY ${_cool_vcpkg_root_directory}
                ${command_echo}
        )
    endif()

    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(_cool_vcpkg_executable ${_cool_vcpkg_root_directory}/vcpkg.exe CACHE INTERNAL
                "Path to the vcpkg executable" FORCE
        )
    else()
        set(_cool_vcpkg_executable ${_cool_vcpkg_root_directory}/vcpkg CACHE INTERNAL
                "Path to the vcpkg executable" FORCE
        )
    endif()

endmacro()

macro(cool_vcpkg_CloneVcpkgRepository)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_clone_vcpkg_repository(${args})
    endif()
endmacro()

function(_cool_vcpkg_clone_vcpkg_repository)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_CloneVcpkgRepository"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_clone_vcpkg_repository" OUTPUT_VARIABLE args
    )

    # Part 1: Clone the git repo
    include(FetchContent)
    set(FETCHCONTENT_BASE_DIR ${_cool_vcpkg_root_directory})
    FetchContent_Declare(
            vcpkg_temp
            GIT_REPOSITORY https://github.com/microsoft/vcpkg.git
            #                GIT_TAG 2024.05.24
            DOWNLOAD_NO_EXTRACT FALSE
    )
    if (NOT vcpkg_temp_POPULATED)
        FetchContent_Populate(vcpkg_temp)
    endif()

    # Part 2: Copy to desired destination
    file(COPY ${_cool_vcpkg_root_directory}/vcpkg_temp-src/ DESTINATION ${_cool_vcpkg_root_directory})

    # Part 3: Clean up the FetchContent artifacts
    file(REMOVE_RECURSE
            ${_cool_vcpkg_root_directory}/vcpkg_temp-build
            ${_cool_vcpkg_root_directory}/vcpkg_temp-src
            ${_cool_vcpkg_root_directory}/vcpkg_temp-subbuild
    )

endfunction()

function(_cool_vcpkg_find_current_commit_hash)

    set(_cool_vcpkg_current_commit_hash "" CACHE INTERNAL
            "Commit hash of the vcpkg repository that we checked out during the configure stage" FORCE
    )
    find_package(Git)
    if (Git_FOUND)
        # run process to get the current commit hash
        message(STATUS "Getting the current commit hash of the vcpkg repository.")
        execute_process(
                COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
                WORKING_DIRECTORY ${_cool_vcpkg_root_directory}/
                OUTPUT_VARIABLE vcpkg_commit_hash
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        set(_cool_vcpkg_current_commit_hash ${vcpkg_commit_hash} CACHE INTERNAL
                "Commit hash of the vcpkg repository that we checked out during the configure stage" FORCE
        )
    endif()

endfunction()

function(_cool_vcpkg_create_root_directory)
    set(oneValueArgs LOCATION)
    cmake_parse_arguments(create_root_directory "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    _cool_vcpkg_normalize_path(PATH "${create_root_directory_LOCATION}" OUTPUT_VARIABLE vcpkg_root_directory_location)

    _cool_vcpkg_random_wait(3000) # try to guard against race conditions
    if (NOT EXISTS ${vcpkg_root_directory_location})
        file(MAKE_DIRECTORY ${vcpkg_root_directory_location})
    endif()

endfunction()

macro(cool_vcpkg_SetUpVcpkg)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_set_up_vcpkg(${args})
    endif()
endmacro()

# Use SHARED_REPOSITORY to specify a location which multiple build types can share, otherwise a fresh vcpkg clone will
# be performed for each build type.
# After bootstrapping will internally set:
# _cool_vcpkg_is_bootstrapped:                     BOOL
# _cool_vcpkg_is_bootstrapping_overridden:         BOOL
# _cool_vcpkg_is_bootstrapping_overridden_reason:  STRING
# _cool_vcpkg_root_directory:                      PATH
# _cool_vcpkg_executable:                          FILEPATH
# _cool_vcpkg_is_collecting_metrics:               BOOL
# _cool_vcpkg_using_shared_repository:             BOOL
# _cool_vcpkg_toolchain_file:                      FILEPATH
# _cool_vcpkg_current_commit_hash:                 STRING
macro(_cool_vcpkg_set_up_vcpkg)

    _cool_vcpkg_check_guarded(ARGUMENTS "${ARGV}" PUBLIC_FUNCTION_NAME "cool_vcpkg_SetUpVcpkg"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_set_up_vcpkg" OUTPUT_VARIABLE args
    )

    set(options COLLECT_METRICS)
    set(oneValueArgs ROOT_DIRECTORY DEFAULT_TRIPLET CHAIN_LOAD_TOOLCHAIN)
    set(multiValueArgs OVERLAY_PORT_LOCATIONS)
    cmake_parse_arguments(bootstrap_vcpkg "${options}" "${oneValueArgs}" "${multiValueArgs}" "${args}")

    if (COOL_VCPKG_CHECK_FOR_UPDATES)
        _cool_vcpkg_check_latest_release_info()
    endif()

    if (NOT bootstrap_vcpkg_COLLECT_METRICS)
        list(APPEND VCPKG_BOOTSTRAP_OPTIONS "-disableMetrics")
    endif()

    if (DEFINED COOL_VCPKG_DEFAULT_TRIPLET AND NOT "${COOL_VCPKG_DEFAULT_TRIPLET}" STREQUAL "")
        if (DEFINED bootstrap_vcpkg_DEFAULT_TRIPLET)
            message(WARNING "COOL_VCPKG_DEFAULT_TRIPLET is already set to ${COOL_VCPKG_DEFAULT_TRIPLET}."
                    "Will not override with the argument to cool_vcpkg_SetUpVcpkg(DEFAULT_TRIPLET "
                    "${bootstrap_vcpkg_DEFAULT_TRIPLET}).")
        else()
            set(bootstrap_vcpkg_DEFAULT_TRIPLET ${COOL_VCPKG_DEFAULT_TRIPLET})
        endif()
        set(_cool_vcpkg_default_triplet ${COOL_VCPKG_DEFAULT_TRIPLET} CACHE INTERNAL
                "Some targets may be specified to be built with specific linkages and bitness. For all others, use this triplet." FORCE
        )
    elseif (DEFINED bootstrap_vcpkg_DEFAULT_TRIPLET)
        set(_cool_vcpkg_default_triplet ${bootstrap_vcpkg_DEFAULT_TRIPLET} CACHE INTERNAL
                "Some targets may be specified to be built with specific linkages and bitness. For all others, use this triplet." FORCE
        )
    else()
        message(FATAL_ERROR "DEFAULT_TRIPLET is not defined. Please set COOL_VCPKG_DEFAULT_TRIPLET or pass it as an "
                "argument to cool_vcpkg_SetUpVcpkg(DEFAULT_TRIPLET <x64-linux|x64-windows|etc..>)"
        )
    endif()

    if (DEFINED bootstrap_vcpkg_CHAIN_LOAD_TOOLCHAIN)
        set(VCPKG_CHAINLOAD_TOOLCHAIN ${bootstrap_vcpkg_CHAIN_LOAD_TOOLCHAIN})
    endif()

    list(LENGTH bootstrap_vcpkg_OVERLAY_PORT_LOCATIONS overlay_port_locations_count)
    if (overlay_port_locations_count GREATER 0)
        list(APPEND VCPKG_OVERLAY_PORTS "${bootstrap_vcpkg_OVERLAY_PORT_LOCATIONS}")
    endif()

    # Determine if any options have changed since last time. If so, we will re-bootstrap.
    if (DEFINED _cool_vcpkg_is_bootstrapped)

        # Check if the COLLECT_METRICS option has changed.
        set(previously_collecting_metrics 0)
        if (_cool_vcpkg_is_collecting_metrics)
            set(previously_collecting_metrics 1)
        endif()
        set(now_collecting_metrics 0)
        if (bootstrap_vcpkg_COLLECT_METRICS)
            set(now_collecting_metrics 1)
        endif()
        if (NOT (previously_collecting_metrics EQUAL now_collecting_metrics))
            message(STATUS "COLLECT_METRICS option has changed from ${_cool_vcpkg_is_collecting_metrics} to "
                    "${bootstrap_vcpkg_COLLECT_METRICS}.")
            set(rebootstrap_vcpkg TRUE)
        endif()

        # Check if the SHARED_REPOSITORY option has changed.
        set(previously_using_shared_repo 0)
        if (_cool_vcpkg_using_shared_repository)
            set(previously_using_shared_repo 1)
        endif()
        set(now_using_shared_repo 0)
        if (DEFINED bootstrap_vcpkg_SHARED_REPOSITORY AND NOT "${bootstrap_vcpkg_SHARED_REPOSITORY}" STREQUAL "")
            set(now_using_shared_repo 1)
        endif()
        if (NOT (previously_using_shared_repo EQUAL now_using_shared_repo))
            message(STATUS "SHARED_REPOSITORY option has changed from ${root_directory_parent} to "
                    "${bootstrap_vcpkg_SHARED_REPOSITORY}")
            set(rebootstrap_vcpkg TRUE)
        endif()

    endif (DEFINED _cool_vcpkg_is_bootstrapped)

    if (DEFINED _cool_vcpkg_root_directory)
        _cool_vcpkg_normalize_path(PATH "${_cool_vcpkg_root_directory}" OUTPUT_VARIABLE _cool_vcpkg_root_directory)
    endif()

    set(_cool_vcpkg_is_collecting_metrics FALSE CACHE INTERNAL "Does the user want vcpkg to collect metrics?" FORCE)
    if (${bootstrap_vcpkg_COLLECT_METRICS})
        set(collect_metrics_option_string "COLLECT_METRICS")
        set(_cool_vcpkg_is_collecting_metrics TRUE CACHE INTERNAL "Does the user want vcpkg to collect metrics?" FORCE)
    endif()

    # If CMAKE_TOOLCHAIN_FILE is already set respect that and abort.
    # Likewise, if this function has already been run previously, detect that with the _cool_vcpkg_toolchain_file
    # variable and abort.
    # Otherwise continue with setup.
    set(exit_early FALSE)
    if (DEFINED CMAKE_TOOLCHAIN_FILE)
        message(STATUS "CMAKE_TOOLCHAIN_FILE is already set to ${CMAKE_TOOLCHAIN_FILE}. "
                "Will not bootstrap a vcpkg setup.")
        set(_cool_vcpkg_is_bootstrapping_overridden TRUE CACHE INTERNAL "is overridden?" FORCE)
        set(_cool_vcpkg_is_bootstrapping_overridden_reason "CMAKE_TOOLCHAIN_FILE_ALREADY_SET" CACHE INTERNAL
                "Reason for overriding the setup process" FORCE
        )
        set(exit_early TRUE)
    elseif (_cool_vcpkg_is_bootstrapped AND NOT rebootstrap_vcpkg)
        message(STATUS "${PROJECT_NAME} has already called cool_vcpkg_SetUpVcpkg(), will not bootstrap a vcpkg setup again.")
        _cool_vcpkg_find_current_commit_hash()
        set(exit_early TRUE)
    endif()

    if (NOT exit_early)

        if (rebootstrap_vcpkg)
            message(STATUS "cool_vcpkg_SetUpVcpkg() options have changed since last time. Setting up again.")
        endif()

        if (DEFINED COOL_VCPKG_ROOT_DIRECTORY AND NOT "${COOL_VCPKG_ROOT_DIRECTORY}" STREQUAL "")
            if (DEFINED bootstrap_vcpkg_ROOT_DIRECTORY)
                message(WARNING "COOL_VCPKG_ROOT_DIRECTORY is already set to ${COOL_VCPKG_ROOT_DIRECTORY}. "
                        "Will not override with the argument to cool_vcpkg_SetUpVcpkg(ROOT_DIRECTORY "
                        "${bootstrap_vcpkg_ROOT_DIRECTORY}).")
            else()
                set(bootstrap_vcpkg_ROOT_DIRECTORY ${COOL_VCPKG_ROOT_DIRECTORY})
            endif()
            _cool_vcpkg_normalize_path(PATH "${COOL_VCPKG_ROOT_DIRECTORY}" OUTPUT_VARIABLE directory)
            set(_cool_vcpkg_root_directory ${directory} CACHE INTERNAL
                    "Where is the main vcpkg repository installed?" FORCE
            )
        elseif (DEFINED bootstrap_vcpkg_ROOT_DIRECTORY)
            _cool_vcpkg_normalize_path(PATH "${bootstrap_vcpkg_ROOT_DIRECTORY}" OUTPUT_VARIABLE directory)
            set(_cool_vcpkg_root_directory ${directory} CACHE INTERNAL
                    "Where is the main vcpkg repository installed?" FORCE
            )
        else()
            message(FATAL_ERROR "ROOT_DIRECTORY is not defined. Please set COOL_VCPKG_ROOT_DIRECTORY or pass it as an "
                    "argument to cool_vcpkg_SetUpVcpkg(ROOT_DIRECTORY </path/to/vcpkg/>)"
            )
        endif()

        _cool_vcpkg_normalize_path(PATH "${CMAKE_CURRENT_BINARY_DIR}/cool-vcpkg/" OUTPUT_VARIABLE local_dir)
        set(_cool_vcpkg_build_local_directory "${local_dir}" CACHE INTERNAL "Location of manifest file" FORCE)

        set(_cool_vcpkg_declared_packages "" CACHE INTERNAL "targets list" FORCE)
        set(_cool_vcpkg_declared_package_versions "" CACHE INTERNAL "versions for each target in the targets list" FORCE)

        _cool_vcpkg_check_vcpkg_root_directory_exists(LOCATION ${_cool_vcpkg_root_directory})
        if (NOT _cool_vcpkg_root_directory_verified)
            _cool_vcpkg_make_vcpkg_available()
        endif()
        _cool_vcpkg_find_current_commit_hash()

        set(_cool_vcpkg_toolchain_file ${_cool_vcpkg_root_directory}scripts/buildsystems/vcpkg.cmake
                CACHE FILEPATH "Computed path to the vcpkg toolchain file." FORCE)
        set(_cool_vcpkg_is_bootstrapped TRUE CACHE INTERNAL "Has vcpkg been bootstrapped?" FORCE)

    endif (NOT exit_early)

endmacro()

# Clone Vcpkg repo and make it available for use.
# A vcpkg repo can be shared amongst build configurations, projects/subprojects. We will only clone it once for each
# project that is purporting to use it.
# We bootstrap vcpkg manually because if there are multiple cmake configurations running concurrently, we only need to
# run the bootstrap script once.
function(_cool_vcpkg_make_vcpkg_available)

    _cool_vcpkg_create_root_directory(LOCATION ${_cool_vcpkg_root_directory})

    _cool_vcpkg_random_wait(3000)
    if (EXISTS ${_cool_vcpkg_root_directory}/cool-vcpkg.lock)
        while (EXISTS ${_cool_vcpkg_root_directory}/cool-vcpkg.lock)
            message(STATUS "cool-vcpkg.lock file exists, waiting for vcpkg to be cloned and bootstrapped.")
            execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep "10")
        endwhile()
    else()
        file(TOUCH ${_cool_vcpkg_root_directory}/cool-vcpkg.lock)
        cool_vcpkg_CloneVcpkgRepository()
        cool_vcpkg_RunBootstrapScript()
        file(REMOVE ${_cool_vcpkg_root_directory}/cool-vcpkg.lock)
    endif()

endfunction()

macro(cool_vcpkg_DeclarePackage)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_declare_package(${args})
    endif()
endmacro()

# Will create cache variables for each package declared..
# - _cool_vcpkg_declared_package_<package_name>_target_architecture : string
# - _cool_vcpkg_declared_package_<package_name>_crt_linkage : string
# - _cool_vcpkg_declared_package_<package_name>_library_linkage : string
# - _cool_vcpkg_declared_package_<package_name>_features : list
macro(_cool_vcpkg_declare_package)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_DeclarePackage"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_declare_package" OUTPUT_VARIABLE args
    )

    set(oneValueArgs NAME PORT_OVERLAY_LOCATION TARGET_ARCHITECTURE CRT_LINKAGE LIBRARY_LINKAGE VERSION USE_DEFAULT_FEATURES)
    set(multiValueArgs TRIPLETS FEATURES)
    cmake_parse_arguments(declare_package "${options}" "${oneValueArgs}" "${multiValueArgs}" ${args})

    set(usage_help_text "Usage: DeclarePackage(NAME <package_name> [TRIPLET <triplet>] [VERSION <version>] [FEATURES <feature0> ...]).")

    if ((NOT DEFINED declare_package_NAME) OR (declare_package_NAME STREQUAL ""))
        message(FATAL_ERROR "DeclarePackage() requires a NAME argument. ${usage_help_text}")
    endif()

    if ((NOT DEFINED declare_package_USE_DEFAULT_FEATURES) OR (declare_package_NAME STREQUAL ""))
        set(declare_package_USE_DEFAULT_FEATURES TRUE)
    endif()

    list(APPEND _cool_vcpkg_declared_packages ${declare_package_NAME})

    set(_cool_vcpkg_declared_package_${declare_package_NAME}_version "${declare_package_VERSION}" CACHE INTERNAL "" FORCE)
    set(_cool_vcpkg_declared_package_${declare_package_NAME}_use_default_features "${declare_package_USE_DEFAULT_FEATURES}" CACHE INTERNAL "" FORCE)
    set(_cool_vcpkg_declared_package_${declare_package_NAME}_features "${declare_package_FEATURES}" CACHE INTERNAL "" FORCE)
    set(_cool_vcpkg_declared_package_${declare_package_NAME}_target_architecture "${declare_package_TARGET_ARCHITECTURE}" CACHE INTERNAL "" FORCE)
    set(_cool_vcpkg_declared_package_${declare_package_NAME}_crt_linkage "${declare_package_CRT_LINKAGE}" CACHE INTERNAL "" FORCE)
    set(_cool_vcpkg_declared_package_${declare_package_NAME}_library_linkage "${declare_package_LIBRARY_LINKAGE}" CACHE INTERNAL "" FORCE)

endmacro()

macro(cool_vcpkg_InstallPackages)
    if (COOL_VCPKG_ENABLED)
        set(args "${ARGV};FROM_GUARDED")
        _cool_vcpkg_install_packages(${args})
    endif()
endmacro()

macro(_cool_vcpkg_install_packages)

    _cool_vcpkg_check_guarded(ARGUMENTS ${ARGV} PUBLIC_FUNCTION_NAME "cool_vcpkg_InstallPackages"
            PRIVATE_FUNCTION_NAME "_cool_vcpkg_install_packages" OUTPUT_VARIABLE args
    )

    cool_vcpkg_WriteVcpkgCustomTripletFile(TARGETS ${_cool_vcpkg_declared_packages})
    set(VCPKG_OVERLAY_TRIPLETS "${_cool_vcpkg_custom_triplet_path}/" CACHE STRING "cool-vcpkg generates the custom triplet to use for this project" FORCE)
    set(VCPKG_TARGET_TRIPLET "cool-vcpkg-custom-triplet" CACHE STRING "cool-vcpkg generates the custom triplet to use for this project" FORCE)

    cool_vcpkg_WriteVcpkgManifestFile(
            TARGETS ${_cool_vcpkg_declared_packages}
            OVERLAY_TRIPLETS_PATHS ${_cool_vcpkg_custom_triplet_path}
    )

    cool_vcpkg_WriteVcpkgConfigurationFile(OVERLAY_TRIPLETS_PATHS ${_cool_vcpkg_custom_triplet_path})

    set(VCPKG_MANIFEST_MODE TRUE CACHE BOOL "cool-vcpkg automatically sets to TRUE" FORCE)
    set(VCPKG_MANIFEST_DIR ${_cool_vcpkg_manifest_path} CACHE PATH "cool-vcpkg automatically sets this value" FORCE)
    set(VCPKG_INSTALLED_DIR ${_cool_vcpkg_manifest_path}/vcpkg_installed/ CACHE PATH "cool-vcpkg automatically sets this value" FORCE)
    set(VCPKG_MANIFEST_INSTALL TRUE CACHE BOOL "cool-vcpkg automatically sets to TRUE" FORCE)

    set(debug_argument "")
    if (COOL_VCPKG_DEBUG)
        set(debug_argument "--debug --debug-env")
    endif()

    set(command_echo "")
    if (COOL_VCPKG_COMMAND_ECHO)
        set(command_echo "COMMAND_ECHO STDOUT")
    endif()

    # Previously had this to manually run the install command, but I dont need it if I set the VCPKG_* options manually.
    # debated keeping them separate so that I wouldn't step all over the users previously set values though. Still work
    # to be done.
    #    execute_process(
    #            COMMAND "${_cool_vcpkg_executable}" install
    #            --triplet "cool-vcpkg-custom-triplet"
    #            --vcpkg-root "${_cool_vcpkg_root_directory}"
    #            "--x-wait-for-lock"
    #            "--x-manifest-root=${_cool_vcpkg_manifest_path}"
    #    )

    cool_vcpkg_IncludeVcpkgToolchainFile()

endmacro()

# To ensure that vcpkg has been cloned (in some way or another), check for existence of:
# - .vcpkg-root
# - bootstrap-vcpkg.bat
# - bootstrap-vcpkg.sh
# - vcpkg toolchain file
# Sets _cool_vcpkg_root_directory_verified = TRUE when these files are found, FALSE otherwise.
function(_cool_vcpkg_check_vcpkg_root_directory_exists)

    set(oneValueArgs LOCATION)
    cmake_parse_arguments(check_root_directory "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT DEFINED check_root_directory_LOCATION)
        message(FATAL_ERROR "CheckVcpkgRootDirectoryExists() requires a LOCATION argument, a path to your vcpkg root "
                "directory. This directory will contain [ .vcpkg-root, bootstrap-vcpkg.bat, bootstrap-vcpkg.sh ]")
    endif()

    set(root_directory_exists TRUE)
    if (NOT EXISTS "${check_root_directory_LOCATION}/.vcpkg-root"                           OR
            NOT EXISTS "${check_root_directory_LOCATION}/bootstrap-vcpkg.bat"               OR
            NOT EXISTS "${check_root_directory_LOCATION}/bootstrap-vcpkg.sh"                OR
            NOT EXISTS "${check_root_directory_LOCATION}/scripts/buildsystems/vcpkg.cmake"
    )
        set(root_directory_exists FALSE)
    endif()

    set(_cool_vcpkg_root_directory_verified ${root_directory_exists} CACHE BOOL INTERNAL FORCE)

endfunction()

set(_cool_vcpkg_check_guard_count "0" CACHE INTERNAL "How many private procedures have you called directly?" FORCE)
function(_cool_vcpkg_check_guarded)
    set(oneValueArgs PUBLIC_FUNCTION_NAME PRIVATE_FUNCTION_NAME OUTPUT_VARIABLE)
    set(multiValueArgs ARGUMENTS)
    cmake_parse_arguments(check_guarded "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT DEFINED check_guarded_PUBLIC_FUNCTION_NAME)
        message(FATAL_ERROR "_cool_vcpkg_check_guarded() does not have PUBLIC_FUNCTION_NAME argument defined. This is "
                "an internal error, my bad. Please report this.")
    endif()

    if (NOT DEFINED check_guarded_PRIVATE_FUNCTION_NAME)
        message(FATAL_ERROR "_cool_vcpkg_check_guarded() does not have PRIVATE_FUNCTION_NAME argument defined. This is "
                "an internal error, my bad. Please report this.")
    endif()

    list(FIND check_guarded_ARGUMENTS "FROM_GUARDED" found_location)
    if (NOT found_location EQUAL -1)
        list(REMOVE_AT check_guarded_ARGUMENTS ${found_location})
        set(${check_guarded_OUTPUT_VARIABLE} "${check_guarded_ARGUMENTS}" PARENT_SCOPE)
    elseif (found_location EQUAL -1)
        if (${_cool_vcpkg_check_guard_count} EQUAL 0)
            message(WARNING "You called a private procedure ${check_guarded_PRIVATE_FUNCTION_NAME} directly. Use the "
                    "public procedure ${check_guarded_PUBLIC_FUNCTION_NAME} instead."
            )
        elseif(${_cool_vcpkg_check_guard_count} EQUAL 1)
            message(WARNING "I said, you called a private procedure ${check_guarded_PRIVATE_FUNCTION_NAME} "
                    "directly. Use the public procedure ${check_guarded_PUBLIC_FUNCTION_NAME} instead. This is your "
                    "final warning mkay."
            )
        elseif(${_cool_vcpkg_check_guard_count} EQUAL 2)
            message(WARNING "You called a private procedure ${check_guarded_PRIVATE_FUNCTION_NAME} directly. Use "
                    "the public procedure ${check_guarded_PUBLIC_FUNCTION_NAME} instead. This is your real final "
                    "warning!"
            )
        else()
            message(WARNING "You called a private procedure ${check_guarded_PRIVATE_FUNCTION_NAME} directly. Use "
                    "the public procedure ${check_guarded_PUBLIC_FUNCTION_NAME} instead. Come on. please stop."
            )
        endif()
        math(EXPR _cool_vcpkg_check_guard_count "${_cool_vcpkg_check_guard_count} + 1" OUTPUT_FORMAT DECIMAL)
    endif()

endfunction()
