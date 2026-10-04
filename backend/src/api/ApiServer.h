#pragma once
#include <string>
class Database;
class ApiServer {
public:
    explicit ApiServer(Database& database);
    void start(const std::string& host, int port);
private:
    Database& database_;
};
