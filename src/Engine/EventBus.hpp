#pragma once
#include <functional>
#include <vector>
#include <memory>
#include <string>
#include <unordered_map>
#include <iostream>

enum class EventType {
    WindowResize,
    WindowClose,
    MouseMove,
    MouseClick,
    MouseRelease,
    KeyDown,
    KeyUp,
    TextInput
};

struct Event {
    EventType type;
    virtual ~Event() = default;
};

struct WindowResizeEvent : public Event {
    int width, height;
    WindowResizeEvent(int w, int h) : width(w), height(h) { type = EventType::WindowResize; }
};

struct MouseEvent : public Event {
    int x, y;
    int button; // 0 for none, 1 for left, 2 for middle, 3 for right
    MouseEvent(EventType t, int _x, int _y, int _btn = 0) : x(_x), y(_y), button(_btn) { type = t; }
};

struct KeyEvent : public Event {
    std::string key;
    KeyEvent(EventType t, const std::string& k) : key(k) { type = t; }
};

using EventCallback = std::function<void(const Event&)>;

class EventBus {
public:
    static EventBus& GetInstance() {
        static EventBus instance;
        return instance;
    }

    void Subscribe(EventType type, EventCallback callback) {
        subscribers[type].push_back(callback);
    }

    void Dispatch(const Event& event) {
        if (subscribers.find(event.type) != subscribers.end()) {
            for (auto& callback : subscribers[event.type]) {
                callback(event);
            }
        }
    }

private:
    EventBus() {}
    std::unordered_map<EventType, std::vector<EventCallback>> subscribers;
};
