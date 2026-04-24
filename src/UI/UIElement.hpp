#pragma once
#include "../Engine/Renderer.hpp"
#include "../Engine/EventBus.hpp"
#include <vector>
#include <memory>

class UIElement {
public:
    UIElement() : m_rect(0,0,0,0), m_parent(nullptr) {}
    virtual ~UIElement() = default;

    virtual void Draw(Renderer* renderer) = 0;
    virtual void OnEvent(const Event& event) {}

    void AddChild(std::shared_ptr<UIElement> child) {
        child->m_parent = this;
        m_children.push_back(child);
    }

    void SetRect(const Rect& rect) { m_rect = rect; }
    Rect GetRect() const { return m_rect; }

    // Check if mouse event is inside this element
    bool Contains(int x, int y) const {
        return x >= m_rect.x && x <= (m_rect.x + m_rect.w) &&
               y >= m_rect.y && y <= (m_rect.y + m_rect.h);
    }

protected:
    Rect m_rect;
    UIElement* m_parent;
    std::vector<std::shared_ptr<UIElement>> m_children;
};
