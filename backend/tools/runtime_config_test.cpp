#include "config/RuntimeConfig.h"
#include <iostream>
#include <optional>
#include <string>

int main()
{
    int checks = 0;
    auto expect = [&](bool result) { ++checks; if (!result) throw std::runtime_error("Configuration assertion failed"); };
    expect(parse_service_port(std::nullopt, 1883, "MQTT") == 1883);
    expect(parse_service_port(std::nullopt, 8080, "API") == 8080);
    for (const std::string value : {"1", "65535", "28883", "18080"})
        expect(parse_service_port(value, 8080, "API") == std::stoi(value));
    for (const std::string value : {"", "0", "65536", "-1", "abc", " ", " 80", "80 ", "+80", "1.5", "999999999999999999999999999999"}) {
        bool rejected = false;
        try { (void)parse_service_port(value, 8080, "API"); }
        catch (const std::runtime_error& error) { rejected = std::string(error.what()) == "API must be an integer in range 1-65535"; }
        // The error names the setting, never echoes the supplied value.
        expect(rejected);
    }
    std::cout << checks << " configuration assertions passed\n";
}

