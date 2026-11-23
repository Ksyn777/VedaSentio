cmake_minimum_required(VERSION 3.20)

set(VCPKG_MANIFEST_DIR "${CMAKE_CURRENT_LIST_DIR}/.." CACHE PATH "")

project(VedaSentioBackend LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

enable_testing()

find_package(PahoMqttCpp CONFIG REQUIRED)
find_package(libpqxx CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(httplib CONFIG REQUIRED)
find_package(unofficial-sodium CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)

add_library(vedasentio_security STATIC
    src/security/CryptoService.cpp
)

target_include_directories(
    vedasentio_security
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(
    vedasentio_security
    PUBLIC
    unofficial-sodium::sodium
)

add_library(vedasentio_auth STATIC
    src/auth/PasswordHasher.cpp
    src/auth/JwtService.cpp
)

target_include_directories(
    vedasentio_auth
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(
    vedasentio_auth
    PUBLIC
    unofficial-sodium::sodium
    nlohmann_json::nlohmann_json
)

add_library(vedasentio_identity STATIC
    src/users/UserRepository.cpp
)

target_include_directories(
    vedasentio_identity
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(
    vedasentio_identity
    PUBLIC
    vedasentio_security
    vedasentio_auth
    libpqxx::pqxx
)

add_library(vedasentio_event_parser STATIC
    src/mqtt/SensorEventParser.cpp
)

target_include_directories(
    vedasentio_event_parser
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(
    vedasentio_event_parser
    PUBLIC
    nlohmann_json::nlohmann_json
)

add_executable(
    vedasentio_backend
    src/main.cpp
    src/database/Database.cpp
    src/mqtt/MqttClient.cpp
    src/api/ApiServer.cpp
    src/alarms/AlarmRepository.cpp
    src/push/PushNotificationService.cpp
)

target_compile_definitions(
    vedasentio_backend
    PRIVATE
    PAHO_MQTTPP_IMPORTS
)

target_include_directories(
    vedasentio_backend
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(
    vedasentio_backend
    PRIVATE
    PahoMqttCpp::paho-mqttpp3-shared
    libpqxx::pqxx
    nlohmann_json::nlohmann_json
    httplib::httplib
    OpenSSL::Crypto
    winhttp
    vedasentio_security
    vedasentio_auth
    vedasentio_identity
    vedasentio_event_parser
)

add_executable(
    vedasentio_crypto_test
    tools/crypto_test.cpp
)

target_link_libraries(
    vedasentio_crypto_test
    PRIVATE
    vedasentio_security
)

add_executable(
    vedasentio_user_security_test
    tools/user_security_test.cpp
)

target_link_libraries(
    vedasentio_user_security_test
    PRIVATE
    vedasentio_identity
)

add_executable(
    vedasentio_create_dev_user
    tools/create_dev_user.cpp
)

target_link_libraries(
    vedasentio_create_dev_user
    PRIVATE
    vedasentio_identity
)

add_executable(
    vedasentio_atomic_user_test
    tools/atomic_user_test.cpp
)

target_link_libraries(
    vedasentio_atomic_user_test
    PRIVATE
    vedasentio_identity
)

add_executable(
    vedasentio_alarm_flow_test
    tools/alarm_flow_test.cpp
    src/database/Database.cpp
    src/alarms/AlarmRepository.cpp
)

target_include_directories(
    vedasentio_alarm_flow_test
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(
    vedasentio_alarm_flow_test
    PRIVATE
    libpqxx::pqxx
    nlohmann_json::nlohmann_json
)

add_executable(
    vedasentio_event_parser_test
    tools/sensor_event_parser_test.cpp
)

target_link_libraries(
    vedasentio_event_parser_test
    PRIVATE
    vedasentio_event_parser
)

add_test(
    NAME vedasentio_event_parser_test
    COMMAND vedasentio_event_parser_test
)

# Compile the real client against a test-only transport boundary. The backend
# target continues to use the real Paho headers and libraries above.
add_executable(vedasentio_mqtt_reconnect_test
    tools/mqtt_reconnect_lifecycle_test.cpp
    src/mqtt/MqttClient.cpp
)
target_include_directories(vedasentio_mqtt_reconnect_test BEFORE PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/tools/mqtt_test_support
)
target_link_libraries(vedasentio_mqtt_reconnect_test PRIVATE vedasentio_event_parser)
add_test(NAME vedasentio_mqtt_reconnect_test COMMAND vedasentio_mqtt_reconnect_test)

# Validate production FCM error parsing without Firebase credentials or network.
add_executable(
    vedasentio_fcm_response_test
    tools/fcm_response_parser_test.cpp
)

target_link_libraries(
    vedasentio_fcm_response_test
    PRIVATE
    nlohmann_json::nlohmann_json
)

add_test(
    NAME fcm_response_parser
    COMMAND vedasentio_fcm_response_test
)
