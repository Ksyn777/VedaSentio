#pragma once

// Test-only boundary double: never linked into vedasentio_backend.
#include <chrono>
#include <memory>
#include <stdexcept>
#include <string>

namespace mqtt {
using exception = std::runtime_error;
struct message {
    std::string get_topic() const { return {}; }
    std::string to_string() const { return {}; }
};
using const_message_ptr = std::shared_ptr<const message>;
class callback {
public:
    virtual ~callback() = default;
    virtual void connected(const std::string&) {}
    virtual void connection_lost(const std::string&) {}
    virtual void message_arrived(const_message_ptr) {}
};
struct connect_options {
    bool clean = false;
    int minimum = 0;
    int maximum = 0;
};
class connect_options_builder {
    connect_options options_;
public:
    connect_options_builder& user_name(const std::string&) { return *this; }
    connect_options_builder& password(const std::string&) { return *this; }
    connect_options_builder& clean_session(bool value) { options_.clean = value; return *this; }
    connect_options_builder& automatic_reconnect(std::chrono::seconds low, std::chrono::seconds high) {
        options_.minimum = static_cast<int>(low.count());
        options_.maximum = static_cast<int>(high.count());
        return *this;
    }
    connect_options finalize() const { return options_; }
};
namespace test {
inline callback* receiver = nullptr;
inline connect_options options;
inline int connects = 0, subscriptions = 0, subscription_waits = 0;
inline bool fail_subscription = false, in_callback = false;
inline bool waited_in_callback = false;
inline std::string topic;
inline int qos = -1;
inline void notify_connected() {
    in_callback = true;
    receiver->connected("test connection");
    in_callback = false;
}
}
struct token {
    bool connection;
    void wait() {
        if (test::in_callback) test::waited_in_callback = true;
        if (connection) test::notify_connected();
        else ++test::subscription_waits;
    }
};
class async_client {
public:
    async_client(const std::string&, const std::string&) {}
    void set_callback(callback& value) { test::receiver = &value; }
    std::shared_ptr<token> connect(const connect_options& options) {
        ++test::connects;
        test::options = options;
        return std::make_shared<token>(token{true});
    }
    std::shared_ptr<token> subscribe(const std::string& topic, int qos) {
        if (test::fail_subscription) throw exception("test subscribe failure");
        ++test::subscriptions;
        test::topic = topic;
        test::qos = qos;
        return std::make_shared<token>(token{false});
    }
};
}
