# The NONE tells CMake to not check for compilers as they are not needed
project ( tomb NONE )
cmake_minimum_required ( VERSION 2.6 )
include ( dist.cmake )
install_data ( README COPYING )
install_lua_executable ( tomb tomb.lua )
