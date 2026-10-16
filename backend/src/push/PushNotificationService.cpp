#include "PushNotificationService.h"

#include <nlohmann/json.hpp>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <pqxx/pqxx>

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <winhttp.h>

#include <chrono>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#ifndef NOMINMAX
#define NOMINMAX
#endif

namespace
{
struct HttpResponse
{
    unsigned long status_code = 0;
    std::string body;
};

void close_http_handles(
    HINTERNET request,
    HINTERNET connection,
    HINTERNET session
)
{
    if (request != nullptr)
    {
        WinHttpCloseHandle(
            request
        );
    }

    if (connection != nullptr)
    {
        WinHttpCloseHandle(
            connection
        );
    }

    if (session != nullptr)
    {
        WinHttpCloseHandle(
            session
        );
    }
}

std::wstring to_wide_string(
    const std::string& text
)
{
    if (text.empty())
    {
        return std::wstring();
    }

    const int required_length =
        MultiByteToWideChar(
            CP_UTF8,
            0,
            text.c_str(),
            static_cast<int>(
                text.size()
            ),
            nullptr,
            0
        );

    if (required_length <= 0)
    {
        throw std::runtime_error(
            "Unable to convert UTF-8 text to UTF-16."
        );
    }

    std::wstring result(
        required_length,
        L'\0'
    );

    MultiByteToWideChar(
        CP_UTF8,
        0,
        text.c_str(),
        static_cast<int>(
            text.size()
        ),
        result.data(),
        required_length
    );

    return result;
}

HttpResponse send_https_post(
    const std::wstring& host,
    const std::wstring& path,
    const std::wstring& headers,
    const std::string& body
)
{
    HINTERNET session =
        WinHttpOpen(
            L"VedaSentio/1.0",
            WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
            WINHTTP_NO_PROXY_NAME,
            WINHTTP_NO_PROXY_BYPASS,
            0
        );

    if (session == nullptr)
    {
        throw std::runtime_error(
            "WinHttpOpen failed."
        );
    }

    WinHttpSetTimeouts(
        session,
        10000,
        10000,
        15000,
        15000
    );

    HINTERNET connection =
        WinHttpConnect(
            session,
            host.c_str(),
            INTERNET_DEFAULT_HTTPS_PORT,
            0
        );

    if (connection == nullptr)
    {
        close_http_handles(
            nullptr,
            nullptr,
            session
        );

        throw std::runtime_error(
            "WinHttpConnect failed."
        );
    }

    const wchar_t* accepted_types[] =
    {
        L"application/json",
        nullptr
    };

    HINTERNET request =
        WinHttpOpenRequest(
            connection,
            L"POST",
            path.c_str(),
            nullptr,
            WINHTTP_NO_REFERER,
            accepted_types,
            WINHTTP_FLAG_SECURE
        );

    if (request == nullptr)
    {
        close_http_handles(
            nullptr,
            connection,
            session
        );

        throw std::runtime_error(
            "WinHttpOpenRequest failed."
        );
    }

    const BOOL request_sent =
        WinHttpSendRequest(
            request,
            headers.c_str(),
            static_cast<DWORD>(-1L),
            body.empty()
                ? WINHTTP_NO_REQUEST_DATA
                : const_cast<char*>(
                    body.data()
                  ),
            static_cast<DWORD>(
                body.size()
            ),
            static_cast<DWORD>(
                body.size()
            ),
            0
        );

    if (!request_sent)
    {
        const DWORD error_code =
            GetLastError();

        close_http_handles(
            request,
            connection,
            session
        );

        throw std::runtime_error(
            "WinHttpSendRequest failed. Error code: " +
            std::to_string(
                error_code
            )
        );
    }

    if (
        !WinHttpReceiveResponse(
            request,
            nullptr
        )
    )
    {
        const DWORD error_code =
            GetLastError();

        close_http_handles(
            request,
            connection,
            session
        );

        throw std::runtime_error(
            "WinHttpReceiveResponse failed. Error code: " +
            std::to_string(
                error_code
            )
        );
    }

    DWORD status_code = 0;
    DWORD status_code_size =
        sizeof(
            status_code
        );

    if (
        !WinHttpQueryHeaders(
            request,
            WINHTTP_QUERY_STATUS_CODE |
            WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX,
            &status_code,
            &status_code_size,
            WINHTTP_NO_HEADER_INDEX
        )
    )
    {
        close_http_handles(
            request,
            connection,
            session
        );

        throw std::runtime_error(
            "Unable to read HTTP response status."
        );
    }

    std::string response_body;

    while (true)
    {
        DWORD available_bytes = 0;

        if (
            !WinHttpQueryDataAvailable(
                request,
                &available_bytes
            )
        )
        {
            close_http_handles(
                request,
                connection,
                session
            );

            throw std::runtime_error(
                "Unable to read HTTP response."
            );
        }

        if (available_bytes == 0)
        {
            break;
        }

        std::vector<char> buffer(
            available_bytes
        );

        DWORD downloaded_bytes = 0;

        if (
            !WinHttpReadData(
                request,
                buffer.data(),
                available_bytes,
                &downloaded_bytes
            )
        )
        {
            close_http_handles(
                request,
                connection,
                session
            );

            throw std::runtime_error(
                "Unable to read HTTP response body."
            );
        }

        response_body.append(
            buffer.data(),
            downloaded_bytes
        );
    }

    close_http_handles(
        request,
        connection,
        session
    );

    HttpResponse response;
    response.status_code =
        status_code;
    response.body =
        std::move(
            response_body
        );

    return response;
}

std::string base64_url_encode(
    const std::string& value
)
{
    const int encoded_length =
        4 *
        (
            static_cast<int>(
                value.size()
            ) +
            2
        ) /
        3;

    std::vector<unsigned char> encoded(
        encoded_length +
        1
    );

    const int actual_length =
        EVP_EncodeBlock(
            encoded.data(),
            reinterpret_cast<
                const unsigned char*
            >(
                value.data()
            ),
            static_cast<int>(
                value.size()
            )
        );

    std::string result(
        reinterpret_cast<char*>(
            encoded.data()
        ),
        actual_length
    );

    for (char& character : result)
    {
        if (character == '+')
        {
            character = '-';
        }
        else if (character == '/')
        {
            character = '_';
        }
    }

    while (
        !result.empty() &&
        result.back() == '='
    )
    {
        result.pop_back();
    }

    return result;
}

std::string sign_with_private_key(
    const std::string& text,
    const std::string& private_key
)
{
    BIO* private_key_bio =
        BIO_new_mem_buf(
            private_key.data(),
            static_cast<int>(
                private_key.size()
            )
        );

    if (private_key_bio == nullptr)
    {
        throw std::runtime_error(
            "Unable to create private key buffer."
        );
    }

    EVP_PKEY* signing_key =
        PEM_read_bio_PrivateKey(
            private_key_bio,
            nullptr,
            nullptr,
            nullptr
        );

    BIO_free(
        private_key_bio
    );

    if (signing_key == nullptr)
    {
        throw std::runtime_error(
            "Unable to read Firebase service account private key."
        );
    }

    EVP_MD_CTX* signing_context =
        EVP_MD_CTX_new();

    if (signing_context == nullptr)
    {
        EVP_PKEY_free(
            signing_key
        );

        throw std::runtime_error(
            "Unable to create signing context."
        );
    }

    if (
        EVP_DigestSignInit(
            signing_context,
            nullptr,
            EVP_sha256(),
            nullptr,
            signing_key
        ) != 1
    )
    {
        EVP_MD_CTX_free(
            signing_context
        );

        EVP_PKEY_free(
            signing_key
        );

        throw std::runtime_error(
            "Unable to initialize Firebase JWT signature."
        );
    }

    if (
        EVP_DigestSignUpdate(
            signing_context,
            text.data(),
            text.size()
        ) != 1
    )
    {
        EVP_MD_CTX_free(
            signing_context
        );

        EVP_PKEY_free(
            signing_key
        );

        throw std::runtime_error(
            "Unable to prepare Firebase JWT signature."
        );
    }

    size_t signature_length = 0;

    if (
        EVP_DigestSignFinal(
            signing_context,
            nullptr,
            &signature_length
        ) != 1
    )
    {
        EVP_MD_CTX_free(
            signing_context
        );

        EVP_PKEY_free(
            signing_key
        );

        throw std::runtime_error(
            "Unable to calculate Firebase JWT signature length."
        );
    }

    std::vector<unsigned char> signature(
        signature_length
    );

    if (
        EVP_DigestSignFinal(
            signing_context,
            signature.data(),
            &signature_length
        ) != 1
    )
    {
        EVP_MD_CTX_free(
            signing_context
        );

        EVP_PKEY_free(
            signing_key
        );

        throw std::runtime_error(
            "Unable to sign Firebase JWT."
        );
    }

    EVP_MD_CTX_free(
        signing_context
    );

    EVP_PKEY_free(
        signing_key
    );

    signature.resize(
        signature_length
    );

    return std::string(
        reinterpret_cast<char*>(
            signature.data()
        ),
        signature.size()
    );
}

std::string notification_title_for_alarm(
    const Alarm& alarm
)
{
    if (alarm.alarm_type == "sos")
    {
        return "VedaSentio - ALARM SOS";
    }

    if (alarm.alarm_type == "smoke")
    {
        return "VedaSentio - ALARM DYMU";
    }

    if (alarm.alarm_type == "co")
    {
        return "VedaSentio - ALARM CO";
    }

    if (alarm.alarm_type == "gas")
    {
        return "VedaSentio - ALARM GAZU";
    }

    if (alarm.alarm_type == "flood")
    {
        return "VedaSentio - ALARM ZALANIA";
    }

    if (alarm.alarm_type == "device_offline")
    {
        return "VedaSentio - URZADZENIE OFFLINE";
    }

    return "VedaSentio - ALARM";
}

std::string notification_body_for_alarm(
    const Alarm& alarm,
    const std::string& home_name,
    const std::string& device_name
)
{
    if (alarm.alarm_type == "sos")
    {
        return
            "Nacisnieto przycisk SOS - " +
            home_name;
    }

    if (alarm.alarm_type == "smoke")
    {
        return
            "Wykryto dym - " +
            home_name;
    }

    if (alarm.alarm_type == "co")
    {
        return
            "Wykryto tlenek wegla - " +
            home_name;
    }

    if (alarm.alarm_type == "gas")
    {
        return
            "Wykryto gaz - " +
            home_name;
    }

    if (alarm.alarm_type == "flood")
    {
        return
            "Wykryto zalanie - " +
            home_name;
    }

    if (alarm.alarm_type == "device_offline")
    {
        return
            device_name +
            " nie odpowiada - " +
            home_name;
    }

    return
        "Wykryto nowe zdarzenie alarmowe - " +
        home_name;
}

bool response_contains_unregistered_token(
    const std::string& response_body
)
{
    try
    {
        const nlohmann::json response =
            nlohmann::json::parse(
                response_body
            );

        if (!response.contains("error"))
        {
            return false;
        }

        const auto& error =
            response["error"];

        if (
            error.contains("details") &&
            error["details"].is_array()
        )
        {
            for (
                const auto& detail :
                error["details"]
            )
            {
                if (
                    detail.contains("errorCode") &&
                    detail["errorCode"].is_string() &&
                    detail["errorCode"].get<std::string>() ==
                        "UNREGISTERED"
                )
                {
                    return true;
                }
            }
        }
    }
    catch (...)
    {
        return false;
    }

    return false;
}
}

PushNotificationService::PushNotificationService(
    std::string database_connection_string,
    std::string service_account_file_path
)
    : database_connection_string_(
          std::move(
              database_connection_string
          )
      ),
      cached_access_token_expires_at_(
          std::chrono::system_clock::time_point{}
      )
{
    std::ifstream service_account_file(
        service_account_file_path
    );

    if (!service_account_file.is_open())
    {
        throw std::runtime_error(
            "Unable to open Firebase service account JSON file."
        );
    }

    nlohmann::json service_account;

    service_account_file
        >> service_account;

    if (
        !service_account.contains("project_id") ||
        !service_account.contains("client_email") ||
        !service_account.contains("private_key")
    )
    {
        throw std::runtime_error(
            "Firebase service account JSON is incomplete."
        );
    }

    firebase_project_id_ =
        service_account["project_id"]
            .get<std::string>();

    service_account_email_ =
        service_account["client_email"]
            .get<std::string>();

    service_account_private_key_ =
        service_account["private_key"]
            .get<std::string>();

    std::cout
        << "[PUSH] Firebase server credentials loaded for project "
        << firebase_project_id_
        << ".\n";
}

std::vector<std::string>
PushNotificationService::get_active_tokens_for_home(
    const std::string& home_id
) const
{
    pqxx::connection connection(
        database_connection_string_
    );

    pqxx::read_transaction transaction(
        connection
    );

    const pqxx::result result =
        transaction.exec(
            R"SQL(
                SELECT DISTINCT
                    mobile_push_tokens.fcm_token
                FROM mobile_push_tokens
                JOIN user_homes
                    ON user_homes.user_id =
                       mobile_push_tokens.user_id
                JOIN users
                    ON users.id =
                       mobile_push_tokens.user_id
                WHERE user_homes.home_id = $1
                  AND user_homes.role IN ('owner', 'caregiver')
                  AND mobile_push_tokens.is_active = TRUE
                  AND users.is_active = TRUE
                ORDER BY mobile_push_tokens.fcm_token
            )SQL",
            pqxx::params{
                home_id
            }
        );

    std::vector<std::string> tokens;
    tokens.reserve(
        result.size()
    );

    for (const auto& row : result)
    {
        tokens.push_back(
            row["fcm_token"]
                .as<std::string>()
        );
    }

    return tokens;
}

std::string PushNotificationService::get_home_name(
    const std::string& home_id
) const
{
    pqxx::connection connection(
        database_connection_string_
    );

    pqxx::read_transaction transaction(
        connection
    );

    const pqxx::result result =
        transaction.exec(
            R"SQL(
                SELECT name
                FROM homes
                WHERE id = $1
                LIMIT 1
            )SQL",
            pqxx::params{
                home_id
            }
        );

    if (result.empty())
    {
        return home_id;
    }

    return result[0]["name"]
        .as<std::string>();
}

std::string PushNotificationService::get_device_name(
    const std::string& home_id,
    const std::string& device_id
) const
{
    pqxx::connection connection(
        database_connection_string_
    );

    pqxx::read_transaction transaction(
        connection
    );

    const pqxx::result result =
        transaction.exec(
            R"SQL(
                SELECT name
                FROM devices
                WHERE home_id = $1
                  AND id = $2
                LIMIT 1
            )SQL",
            pqxx::params{
                home_id,
                device_id
            }
        );

    if (result.empty())
    {
        return device_id;
    }

    const std::string device_name =
        result[0]["name"]
            .as<std::string>();

    if (device_name.empty())
    {
        return device_id;
    }

    return device_name;
}

void PushNotificationService::mark_token_as_inactive(
    const std::string& firebase_cloud_messaging_token
) const
{
    pqxx::connection connection(
        database_connection_string_
    );

    pqxx::work transaction(
        connection
    );

    transaction.exec(
        R"SQL(
            UPDATE mobile_push_tokens
            SET
                is_active = FALSE,
                updated_at = NOW()
            WHERE fcm_token = $1
        )SQL",
        pqxx::params{
            firebase_cloud_messaging_token
        }
    );

    transaction.commit();
}

std::string PushNotificationService::create_service_account_jwt() const
{
    const auto now =
        std::chrono::system_clock::now();

    const long long issued_at =
        std::chrono::duration_cast<
            std::chrono::seconds
        >(
            now.time_since_epoch()
        ).count();

    const long long expires_at =
        issued_at +
        3600;

    const nlohmann::json jwt_header =
    {
        {"alg", "RS256"},
        {"typ", "JWT"}
    };

    const nlohmann::json jwt_claims =
    {
        {
            "iss",
            service_account_email_
        },
        {
            "scope",
            "https://www.googleapis.com/auth/firebase.messaging"
        },
        {
            "aud",
            "https://oauth2.googleapis.com/token"
        },
        {
            "iat",
            issued_at
        },
        {
            "exp",
            expires_at
        }
    };

    const std::string unsigned_jwt =
        base64_url_encode(
            jwt_header.dump()
        ) +
        "." +
        base64_url_encode(
            jwt_claims.dump()
        );

    const std::string signature =
        sign_with_private_key(
            unsigned_jwt,
            service_account_private_key_
        );

    return
        unsigned_jwt +
        "." +
        base64_url_encode(
            signature
        );
}

std::string PushNotificationService::get_access_token()
{
    const auto now =
        std::chrono::system_clock::now();

    if (
        !cached_access_token_.empty() &&
        now +
            std::chrono::seconds(
                60
            ) <
            cached_access_token_expires_at_
    )
    {
        return cached_access_token_;
    }

    const std::string signed_jwt =
        create_service_account_jwt();

    const std::string request_body =
        "grant_type="
        "urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"
        "&assertion=" +
        signed_jwt;

    const HttpResponse response =
        send_https_post(
            L"oauth2.googleapis.com",
            L"/token",
            L"Content-Type: application/x-www-form-urlencoded\r\n",
            request_body
        );

    if (
        response.status_code < 200 ||
        response.status_code >= 300
    )
    {
        throw std::runtime_error(
            "Google OAuth token request failed. HTTP status: " +
            std::to_string(
                response.status_code
            )
        );
    }

    const nlohmann::json token_response =
        nlohmann::json::parse(
            response.body
        );

    if (
        !token_response.contains("access_token") ||
        !token_response["access_token"].is_string()
    )
    {
        throw std::runtime_error(
            "Google OAuth response does not contain access_token."
        );
    }

    cached_access_token_ =
        token_response["access_token"]
            .get<std::string>();

    int expires_in_seconds =
        3600;

    if (
        token_response.contains("expires_in") &&
        token_response["expires_in"].is_number_integer()
    )
    {
        expires_in_seconds =
            token_response["expires_in"]
                .get<int>();
    }

    cached_access_token_expires_at_ =
        now +
        std::chrono::seconds(
            expires_in_seconds
        );

    return cached_access_token_;
}

bool PushNotificationService::send_message_to_token(
    const Alarm& alarm,
    const std::string& home_name,
    const std::string& device_name,
    const std::string& firebase_cloud_messaging_token,
    const std::string& access_token
)
{
    nlohmann::json message;

    message["message"]["token"] =
        firebase_cloud_messaging_token;

    message["message"]["notification"]["title"] =
        notification_title_for_alarm(
            alarm
        );

    message["message"]["notification"]["body"] =
        notification_body_for_alarm(
            alarm,
            home_name,
            device_name
        );

    message["message"]["data"]["alarm_id"] =
        std::to_string(
            alarm.id
        );

    message["message"]["data"]["home_id"] =
        alarm.home_id;

    message["message"]["data"]["device_id"] =
        alarm.device_id;

    message["message"]["data"]["alarm_type"] =
        alarm.alarm_type;

    message["message"]["data"]["severity"] =
        alarm.severity;

    message["message"]["android"]["priority"] =
        "high";

    std::wstring headers =
        L"Content-Type: application/json; charset=utf-8\r\n"
        L"Authorization: Bearer ";

    headers +=
        to_wide_string(
            access_token
        );

    headers +=
        L"\r\n";

    const std::string endpoint =
        "/v1/projects/" +
        firebase_project_id_ +
        "/messages:send";

    const HttpResponse response =
        send_https_post(
            L"fcm.googleapis.com",
            to_wide_string(
                endpoint
            ),
            headers,
            message.dump()
        );

    if (
        response.status_code >= 200 &&
        response.status_code < 300
    )
    {
        return true;
    }

    if (
        response_contains_unregistered_token(
            response.body
        )
    )
    {
        mark_token_as_inactive(
            firebase_cloud_messaging_token
        );

        std::cerr
            << "[PUSH] Inactive FCM token disabled in database.\n";

        return false;
    }

    std::cerr
        << "[PUSH] FCM request failed. HTTP status: "
        << response.status_code
        << '\n';

    return false;
}

void PushNotificationService::send_alarm_notification(
    const Alarm& alarm
)
{
    const std::vector<std::string> active_tokens =
        get_active_tokens_for_home(
            alarm.home_id
        );

    if (active_tokens.empty())
    {
        std::cout
            << "[PUSH] No active owner/caregiver devices for home "
            << alarm.home_id
            << ".\n";

        return;
    }

    const std::string home_name =
        get_home_name(
            alarm.home_id
        );

    const std::string device_name =
        get_device_name(
            alarm.home_id,
            alarm.device_id
        );

    const std::string access_token =
        get_access_token();

    int sent_notifications = 0;

    for (
        const std::string& firebase_cloud_messaging_token :
        active_tokens
    )
    {
        if (
            send_message_to_token(
                alarm,
                home_name,
                device_name,
                firebase_cloud_messaging_token,
                access_token
            )
        )
        {
            ++sent_notifications;
        }
    }

    std::cout
        << "[PUSH] Alarm notification sent to "
        << sent_notifications
        << " of "
        << active_tokens.size()
        << " registered devices.\n";
}
