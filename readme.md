# Cool-Vcpkg

## Overview

A CMake module that provides a more idiomatic CMake experience for Vcpkg. It is designed to address some of the
shortcomings of the vcpkg offering while staying completely within CMake-land.

Cool-Vcpkg is not intended to fragment the vcpkg ecosystem in any way. A design goal for the project is to live in
complete harmony with, and default to, the official vcpkg workflow as much as possible. There is still work to be done
to that end, but this project does not introduce any new standards, configuration files, anything whatsoever to vcpkg.

We are only automating the generation and inclusion of Vcpkg configuration files.

In my opinion, one of the main drawbacks of using vcpkg is the requirement to manually author separate configuration and
manifest files for each build configuration. If you have multiple build configurations, one must first author each
manifest and configuration file, decide where they should live, and when it comes to configuration time install the
correct one to the CMAKE_BINARY_DIR (or wherever they wish to have their vcpkg_installed directory to be).
This workflow was cumbersome and I wanted to only use CMake, so this automates a lot of that machinery.

## Why should I use this?

It addresses some shortcomings of vcpkg, including:

- Automatic Initialization
  - Vcpkg will bootstrap itself if it doesn't detect a vcpkg executable in the VCPKG_ROOT directory. However, it will
  not clone the vcpkg repository if it doesn't exist there.
- Versioning
  - Versioning is only supported in manifest mode, so for all intents and purposes we are all locked into that workflow.
  If we are using manifests, might as well make it comfortable.
- Per-Port Triplet Customization Awkwardness
  - Vcpkg (foolishly) assumes that your want each of your targets to use the same triplet.
  And if you don't want that, you will find yourself essentially writing toolchain files for each combination of those
  dependencies. Yet another configuration file that you need to manage per-build.
- Pre-`project()` Initialization
  - Vcpkg CMake integration expects that you set up everything vcpkg-related before the first call to `project()`.
  This is a bit annoying, because we like to have a `project()` call at the top of our CMakeLists.txt files. After, the
  cmake_minimum_required() of course.

## Usage Note

Cool-Vcpkg is not intended to replace the 'Ports' system that vcpkg uses to build and distribute dependencies. This is a
completely separate thing.

This implementation is currently suited to top-level projects, which only pull in other dependencies. Cool-Vcpkg hasn't
been tested in a project which is a dependency (subproject, subdirectory, vcpkg port, or otherwise). It is a design goal
to support nested Cool-Vcpkg-ed project before a v1 release but there is still work and testing to be done on that
front. Currently, if CMAKE_TOOLCHAIN_FILE is previously defined, Cool-Vcpkg will be disabled to prevent any potential
frustration.

If your project uses Cool-Vcpkg, and you are also offering a vcpkg port, you should just keep it simple and set
`COOL_VCPKG_ENABLED` to `OFF` in your portfile. This workflow just has not been tested yet, and we don't want to
complicate things.

## Installation

### Clone from GitHub

The builtin CMake `FetchContent` module can be used to pull in the latest version of cool-vcpkg from Github. Automatically
adding the module location to the `CMAKE_MODULE_PATH` is an opt-in feature; use it by pointing to the `automatic-setup`
source subdirectory.

```cmake
# Pull in the latest version every time
include(FetchContent)
FetchContent_Declare(
        cool_vcpkg_latest
        GIT_REPOSITORY  https://github.com/XJ-0461/cool-vcpkg.git
        GIT_TAG         latest
        SOURCE_SUBDIR   automatic-setup
)
FetchContent_MakeAvailable(cool_vcpkg_latest)
include(CoolVcpkg)
```

### Include in your project manually

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
        ROOT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/my-vcpkg
)
```
> **Note**: The `DEFAULT_TRIPLET` must be one of the out-of-the-box triplets that vcpkg supports (including the
> community triplets). The list of which can be found in the
> [vcpkg repository](https://github.com/microsoft/vcpkg/tree/master/triplets) under `triplets/`.

> **Note**: The `ROOT_DIRECTORY` specified above is in a shared location. If I have multiple build configurations
> running concurrently, vcpkg will only be cloned and bootstrapped once. If one wanted (for whatever reason) to have a
> separate vcpkg installation for each build they could use something like `${CMAKE_CURRENT_BINARY_DIR}/my-vcpkg`.

Declare the packages that you want to install with `cool_vcpkg_DeclarePackage()`.

```cmake
cool_vcpkg_DeclarePackage(
        NAME cnats
        VERSION 3.8.2
        LIBRARY_LINKAGE dynamic # Override x64-linux triplet linkage static -> dynamic
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
)
```

## Contributing

Please feel free to open an issue or pull request if you have any suggestions or improvements. Especially around
developer experience, documentation, logging, and error messages.

## Implementation Notes

CMake doesn't do the whole 'public' and 'private' functions and variables thing.

- Public members are prefixed with `cool_vcpkg_` and `PascalCase` names.
- Private members have a leading underscore `_cool_vcpkg_` (leading underscore) and `lower_snake_case` names.
- Options follow the typical CMake `SCREAMING_SNAKE_CASE` convention and are prefixed with `COOL_VCPKG_`.

## Todo

- Harmonious coexistence with official vcpkg offering
  - Essentially, if there are top level VCPKG options set, we should respect those. For example, we are implicitly
  setting stuff like `VCPKG_MANIFEST_INSTALL`, `VCPKG_MANIFEST_DIR`, and `VCPKG_MANIFEST_MODE`. If these are already set
  by the time we get to setting up the CoolVcpkg stuff, we should have behavior that respects them, and log it to the
  user.
- Nested cool-vcpkg enabled projects.
  - If this doesn't work then the project is useless.
  - Lots of testing.
