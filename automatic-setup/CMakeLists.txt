
# This CMakeLists file is used to support the FetchContent_Declare() FetchContent_MakeAvailable() method of including
# the cool-vcpkg cmake module in your project. This method requires an internet connection (obviously); a limitation
# that should be taken into account for your project.
# Nobody likes a module that insists on itself, which is why we have this tucked away as an opt-in feature.
#[[
FetchContent_Declare(
        cool-vcpkg
        GIT_REPOSITORY  https://github.com/XJ-0461/cool-vcpkg.git
        GIT_TAG         latest
        SOURCE_SUBDIR   automatic-setup
)
FetchContent_MakeAvailable(cool-vcpkg)
include(CoolVcpkg)
#]]

# Include the cool-vcpkg module in the top-level of this project.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../")
set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
list(REMOVE_DUPLICATES CMAKE_MODULE_PATH)
