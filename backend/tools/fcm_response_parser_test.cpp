#include "../src/push/FcmResponseParser.h"

#include <iostream>
#include <stdexcept>
#include <string>

void check(const char* name, const std::string& body, bool expected)
{
    if (push_response::is_unregistered(body) != expected)
    {
        throw std::runtime_error(std::string("FCM parser regression: ") + name);
    }
}

int main()
{
    try
    {
        check("valid UNREGISTERED",
              R"({"error":{"code":404,"details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}})",
              true);
        check("UNREGISTERED after unrelated detail",
              R"({"error":{"details":[null,{"errorCode":"OTHER"},{"errorCode":"UNREGISTERED"}]}})",
              true);
        check("invalid argument must retain token",
              R"({"error":{"code":400,"details":[{"errorCode":"INVALID_ARGUMENT"}]}})",
              false);
        check("transient unavailable must retain token",
              R"({"error":{"code":503,"status":"UNAVAILABLE"}})",
              false);
        check("status string alone must not deactivate",
              R"({"error":{"status":"UNREGISTERED"}})",
              false);
        check("details not an array",
              R"({"error":{"details":"UNREGISTERED"}})",
              false);
        check("unexpected detail types",
              R"({"error":{"details":[1,false,{},{"errorCode":19}]}})",
              false);
        check("success response",
              R"({"name":"projects/ci/messages/1"})",
              false);
        check("malformed JSON", "{error", false);
        check("empty JSON", "{}", false);
        check("null JSON", "null", false);

        std::cout << "[FCM] PASS: 11 response cases.\n";
        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr << "[FCM] FAILED: " << error.what() << '\n';
        return 1;
    }
}
