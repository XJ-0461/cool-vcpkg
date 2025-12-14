# Cool-Vcpkg

Pure CMake module for a better Vcpkg experience.

## Overview

Cool-Vcpkg provides a more idiomatic CMake experience by:
- Automatically bootstrapping (and optionally cloning) vcpkg
- Generating the required vcpkg files (manifest/config + overlay triplet) per build configuration
- Enabling per-port triplet customization without hand-authoring multiple toolchain/config variants

Cool-Vcpkg does **not** replace vcpkg ports, registries, or baseline/versioning mechanisms. It only automates file
generation and integration from CMake.

## Examples

[cool-vcpkg-examples](https://github.com/XJ-0461/cool-vcpkg-examples)

## Motivation

It addresses some shortcomings of vcpkg, including:

- Automatic Initialization
  - Vcpkg will bootstrap itself if it doesn't detect a vcpkg executable in the `VCPKG_ROOT` directory.
- Versioning
  - Versioning your dependencies is **only supported** in manifest mode. That means you're probably using manifest mode.
  Automate the manifest mode details.
- Per-Port Triplet Customization Awkwardness
  - Vcpkg assumes that your want each of your targets to use the same triplet.
  And if you don't want that, you will find yourself writing toolchain files for every combination of those
  dependencies. Yet another configuration file that you need to manage per-build.
- Pre-`project()` Initialization
  - Vcpkg CMake integration expects that you set up everything vcpkg-related before the first call to `project()`.
  This is a bit annoying, because we like to have a `project()` call at the top of our CMakeLists.txt files. After, the
  `cmake_minimum_required()` of course.
- Yet Another Package Manager Configuration File
  - Integrating vcpkg into your project means maintaining yet another configuration file and pre-build step in the build
  process outside the CMake ecosystem. Requiring users to learn/clone/install vcpkg is a barrier to entry for new users.

## Usage Note

This project is best suited for top-level CMake project or end-user applications.
Check the [FAQ](#FAQ) for more details.

## Installation Options

### Clone from GitHub

The builtin CMake `FetchContent` module can be used to pull in the latest version of cool-vcpkg from GitHub.
Automatically adding the module location to the `CMAKE_MODULE_PATH` is an opt-in feature; use it by pointing to the
`automatic-setup` source subdirectory.

```cmake
# Pull in the latest version every time
include(FetchContent)
FetchContent_Declare(
        cool_vcpkg_latest
        GIT_REPOSITORY  https://github.com/XJ-0461/cool-vcpkg.git
        GIT_TAG         v0.1.3
        SOURCE_SUBDIR   automatic-setup
)
FetchContent_MakeAvailable(cool_vcpkg_latest)
include(CoolVcpkg)
```

### Manually Include in Project

You can simply add this module into your project somewhere (perhaps in a `cmake` directory?) and include as you normally
would in your project. Enable the `COOL_VCPKG_CHECK_FOR_UPDATES` option to warn you if you are not using the latest
version of the module.

Your project may look something like:

```text
my-cmake-project
├── cmake
│   ├── cool-vcpkg
│   │   └── automatic-setup
│   └── toolchain
├── extras
│   └── source
├── my-custom-vcpkg-port
│   └── cnats
└── source
```

## Usage

Bootstrap Vcpkg with a call to `cool_vcpkg_SetUpVcpkg()`. If there is no Vcpkg repository cloned to that location, then
it will clone and bootstrap it for you.

```cmake
cool_vcpkg_SetUpVcpkg(
        COLLECT_METRICS
        DEFAULT_TRIPLET x64-linux # Uses static linkage by default
        ROOT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/shared-location/my-vcpkg
)
```
> **Note**: The `DEFAULT_TRIPLET` must be one of the out-of-the-box triplets that vcpkg supports (including the
> community triplets). The list of which can be found in the
> [vcpkg repository](https://github.com/microsoft/vcpkg/tree/master/triplets) under `triplets/`.

> **Note**: The `ROOT_DIRECTORY` specified above can be a shared location. If you have multiple build configurations
> pointing to the same vcpkg root directory (e.g. debug/release, different platforms, or even different projects)
> vcpkg will only be cloned and bootstrapped once. If one wanted (for whatever reason) to have a
> separate vcpkg installation for each build they could use something like `${CMAKE_CURRENT_BINARY_DIR}/my-vcpkg`.

Declare the packages that you want to install with `cool_vcpkg_DeclarePackage()`.

```cmake
cool_vcpkg_DeclarePackage(
        NAME cnats
        VERSION 3.8.2
        LIBRARY_LINKAGE dynamic # Override x64-linux triplet linkage: static -> dynamic
)
cool_vcpkg_DeclarePackage(NAME nlohmann-json)
cool_vcpkg_DeclarePackage(NAME gtest)
cool_vcpkg_DeclarePackage(NAME lua)
```

Install the packages with `cool_vcpkg_InstallPackages()`.

```cmake
cool_vcpkg_InstallPackages()
```

You can see that vcpkg is using the files generated from cool-vcpkg by checking out the CMake output log.

```text
...
Detecting compiler hash for triplet cool-vcpkg-custom-triplet...
...
/build/dir/path/cool-vcpkg/custom-triplets/cool-vcpkg-custom-triplet.cmake: info: loaded overlay triplet from here
...
```

Include the package as intended by the package's authors.

```cmake
find_package(cnats CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)
find_package(Lua REQUIRED)
```

## API Documentation

#### cool_vcpkg_SetUpVcpkg()

```cmake
cool_vcpkg_SetUpVcpkg(
        ROOT_DIRECTORY <path>
        DEFAULT_TRIPLET <triplet>
        [COLLECT_METRICS]
        [CHAIN_LOAD_TOOLCHAIN <toolchain-file>]
        [OVERLAY_PORT_LOCATIONS <port-path>...]
)
```

#### cool_vcpkg_DeclarePackage()

```cmake
cool_vcpkg_DeclarePackage(
        NAME <name>
        [TARGET_ARCHITECTURE <architecture>]
        [CRT_LINKAGE <linkage>]
        [LIBRARY_LINKAGE <linkage>]
        [VERSION <version>]
        [FEATURES <feature>...]
        [USE_DEFAULT_FEATURES ON|OFF]
)
```

## Contributing

Please feel free to open an issue or pull request if you have any suggestions or improvements. Especially around
developer experience, documentation, logging, and error messages.

## FAQ

### When should I use this?

This implementation is currently suited to top-level projects, which only pull in other dependencies. Cool-Vcpkg hasn't
been tested in a project which is a dependency (subproject, subdirectory, vcpkg port, or otherwise). It is a goal
to ensure nested Cool-Vcpkg-ed project works before a v1 release but there is still work and testing to be done on that
front. If you have a use case for this, please open an issue to discuss it. I'm open to contributions as well.

### Can I use this in a vcpkg port?

Currently, if CMAKE_TOOLCHAIN_FILE is previously defined, Cool-Vcpkg will be disabled to prevent any potential
frustration.

If your project uses Cool-Vcpkg, and you are also offering a vcpkg port, you should just keep it simple and set
`COOL_VCPKG_ENABLED` to `OFF` in your portfile. This workflow just has not been tested, and we don't want to complicate
things.

### Version identifiers

Prepend a `v` to the GIT_TAG version specifier in the `FetchContent_Declare()` call. Do **not** prepend the `v` in the
`VERSION` argument to `cool_vcpkg_DeclarePackage()`.

### Where do I find packages?

[vcpkg.link](https://vcpkg.link/)

### Anything else?

I like driving my builds with `CMakePresets.json` files.

`CMakeLists.txt`
```cmake
cool_vcpkg_DeclarePackage(
        NAME soci
        VERSION "${SociVersion}"
        LIBRARY_LINKAGE "${SociLibraryLinkage}"
        FEATURES "${SociFeatures}"
)
```

`CMakePresets.json`

```json
{
  "SociVersion": {
    "type": "STRING",
    "value": "4.0.3#3"
  },
  "SociLibraryLinkage": {
    "type": "STRING",
    "value": "dynamic"
  },
  "SociFeatures": {
    "type": "STRING",
    "value": "odbc;postgresql;sqlite3"
  }
}
```

## Implementation Notes

CMake doesn't do the whole 'public' and 'private' functions and variables thing.

- Public members are prefixed with `cool_vcpkg_` and `PascalCase` names.
- Private members have a leading underscore `_cool_vcpkg_` and `lower_snake_case` names.
- Options are prefixed with `COOL_VCPKG_` and follow the typical CMake `SCREAMING_SNAKE_CASE` convention.

## Todo

- Continue to ensure harmonious coexistence with official vcpkg offering
  - Essentially, if there are top level VCPKG options set, we should respect those. For example, we are implicitly
  setting stuff like `VCPKG_MANIFEST_INSTALL`, `VCPKG_MANIFEST_DIR`, and `VCPKG_MANIFEST_MODE`. If these are already set
  by the time we get to setting up the Cool-Vcpkg stuff, we should have behavior that respects them, and log it to the
  user.
- Nested cool-vcpkg enabled projects.
  - Lots of testing.

## Quick Start

```cmake
cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(
    <YOUR_PROJECT_NAME>
    VERSION 0.1.0
    LANGUAGES CXX
)

include(FetchContent)
FetchContent_Declare(
        cool_vcpkg_latest
        GIT_REPOSITORY  https://github.com/XJ-0461/cool-vcpkg.git
        GIT_TAG         v0.1.3
        SOURCE_SUBDIR   automatic-setup
)
FetchContent_MakeAvailable(cool_vcpkg_latest)
include(CoolVcpkg)

cool_vcpkg_SetUpVcpkg(
    DEFAULT_TRIPLET x64-linux
    ROOT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/node_modules_or_whatever"
)

cool_vcpkg_DeclarePackage(
    NAME <DESIRED_PACKAGE>
    VERSION <DESIRED_PACKAGE_VERSION>
    FEATURES <OPTIONAL_FEATURE_LIST>
)

cool_vcpkg_InstallPackages()

find_package(<DESIRED_PACKAGE_NAME_THAT_DOESNT_NECESSARILY_MATCH_VCPKG_PACKAGE_NAME> CONFIG REQUIRED)

# ---- Create library ----

add_executable(
    simple-web-service
    source/main.cpp
)

target_link_libraries(
    simple-web-service
    PRIVATE
    Crow::Crow
    nlohmann_json::nlohmann_json
)
```