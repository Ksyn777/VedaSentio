#pragma once

#include <string>

class AlarmRepository;
class Database;
class JwtService;
class UserRepository;

class ApiServer
{
public:
    ApiServer(
        Database& database,
        UserRepository& users,
        JwtService& jwt,
        AlarmRepository& alarms
    );

    void start(
        const std::string& host,
        int port
    );

private:
    Database& database_;
    UserRepository& users_;
    JwtService& jwt_;
    AlarmRepository& alarms_;
};
