#pragma once

#include <string>

class Database
{
public:
    explicit Database(std::string connection_string);

    void test_connection() const;

    void save_event(
        const std::string& topic,
        const std::string& payload
    ) const;

private:
    std::string connection_string_;
};
