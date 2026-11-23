#pragma once

#include <nlohmann/json.hpp>

#include <string>

// FCM HTTP v1 response parsing without HTTP, database or Firebase secrets.
namespace push_response
{
inline bool is_unregistered(const std::string& response_body) noexcept
{
    try
    {
        const nlohmann::json response = nlohmann::json::parse(response_body);
        if (!response.is_object())
        {
            return false;
        }

        const auto error = response.find("error");
        if (error == response.end() || !error->is_object())
        {
            return false;
        }

        const auto details = error->find("details");
        if (details == error->end() || !details->is_array())
        {
            return false;
        }

        for (const auto& item : *details)
        {
            if (!item.is_object())
            {
                continue;
            }
            const auto code = item.find("errorCode");
            if (code != item.end() && code->is_string() &&
                code->get<std::string>() == "UNREGISTERED")
            {
                return true;
            }
        }
    }
    catch (...)
    {
        // Malformed FCM responses must not deactivate a valid token.
    }
    return false;
}
} // namespace push_response
