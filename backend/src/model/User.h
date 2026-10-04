#pragma once
#include <string>

struct User
{
    long long id = 0;
    std::string email;
    std::string first_name;
    std::string last_name;
    std::string phone;
    bool is_active = true;
    std::string created_at;
};

struct CreateUserInput
{
    std::string email;
    std::string password;
    std::string first_name;
    std::string last_name;
    std::string phone;
};

struct CreateUserWithHomeInput
{
    CreateUserInput user;
    std::string home_id;
    std::string role;
};
