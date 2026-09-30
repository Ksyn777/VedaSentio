cmake_minimum_required(VERSION 3.20)

set(VCPKG_MANIFEST_DIR "${CMAKE_CURRENT_LIST_DIR}/.." CACHE PATH "")

project(VedaSentioBackend LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PahoMqttCpp CONFIG REQUIRED)

add_executable(vedasentio_backend
    src/main.cpp
)

target_compile_definitions(vedasentio_backend
    PRIVATE
    PAHO_MQTTPP_IMPORTS
)

target_link_libraries(vedasentio_backend
    PRIVATE
    PahoMqttCpp::paho-mqttpp3-shared
)