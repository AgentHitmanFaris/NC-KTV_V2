#pragma once
#include "UIElement.hpp"
#include <string>

// Colors from Design System
const Color C_BACKGROUND = Color::FromHex("#131313");
const Color C_SURFACE_CONTAINER_HIGH = Color::FromHex("#2a2a2a");
const Color C_SURFACE_CONTAINER_HIGHEST = Color::FromHex("#353534");
const Color C_SURFACE_CONTAINER_LOW = Color::FromHex("#1c1b1b");
const Color C_ON_SURFACE = Color::FromHex("#e5e2e1");
const Color C_ON_SURFACE_VARIANT = Color::FromHex("#c4c5d9");
const Color C_PRIMARY = Color::FromHex("#bac3ff");
const Color C_ON_PRIMARY = Color::FromHex("#001e91");
const Color C_OUTLINE = Color::FromHex("#8e8fa2");
const Color C_OUTLINE_VARIANT = Color::FromHex("#444656");

// Spacing
const int S_UNIT = 4;
const int S_XS = 4;
const int S_SM = 8;
const int S_MD = 16;
const int S_LG = 24;

class Panel : public UIElement {
public:
    Panel(Color bgColor = C_SURFACE_CONTAINER_HIGHEST, bool border = true)
        : m_bgColor(bgColor), m_border(border) {}

    void Draw(Renderer* renderer) override {
        renderer->SetColor(m_bgColor);
        renderer->FillRect(m_rect);

        if (m_border) {
            renderer->SetColor(C_OUTLINE_VARIANT);
            renderer->DrawRect(m_rect, 1.0);
        }

        for (auto& child : m_children) {
            child->Draw(renderer);
        }
    }
private:
    Color m_bgColor;
    bool m_border;
};

class Label : public UIElement {
public:
    Label(const std::string& text, const std::string& fontDesc, Color color = C_ON_SURFACE)
        : m_text(text), m_fontDesc(fontDesc), m_color(color) {}

    void Draw(Renderer* renderer) override {
        renderer->DrawTextPango(m_text, m_rect, m_fontDesc, m_color);
    }
private:
    std::string m_text;
    std::string m_fontDesc;
    Color m_color;
};

class TextInput : public UIElement {
public:
    TextInput(const std::string& placeholder = "") : m_placeholder(placeholder), m_focused(false) {}

    void Draw(Renderer* renderer) override {
        // Recessed background
        renderer->SetColor(C_SURFACE_CONTAINER_LOW);
        renderer->FillRect(m_rect);

        // Border
        renderer->SetColor(m_focused ? C_PRIMARY : C_OUTLINE_VARIANT);
        renderer->DrawRect(m_rect, 1.0);

        // Text (Placeholder logic simplified)
        Rect textRect = m_rect;
        textRect.x += S_SM; // internal padding
        textRect.y += S_SM;
        renderer->DrawTextPango(m_text.empty() ? m_placeholder : m_text, textRect, "Inter 13", m_text.empty() ? C_ON_SURFACE_VARIANT : C_ON_SURFACE);
    }

    void OnEvent(const Event& event) override {
        if (event.type == EventType::MouseClick) {
            const MouseEvent& me = static_cast<const MouseEvent&>(event);
            m_focused = Contains(me.x, me.y);
        }
    }
private:
    std::string m_text;
    std::string m_placeholder;
    bool m_focused;
};

class Button : public UIElement {
public:
    Button(const std::string& text, bool primary = false) : m_text(text), m_primary(primary), m_hovered(false) {}

    void Draw(Renderer* renderer) override {
        if (m_primary) {
            renderer->SetColor(C_PRIMARY);
            renderer->FillRect(m_rect);
            Rect textRect = {m_rect.x + 16, m_rect.y + S_SM, m_rect.w, m_rect.h};
            renderer->DrawTextPango(m_text, textRect, "Inter 13", C_ON_PRIMARY);
        } else {
            renderer->SetColor(C_SURFACE_CONTAINER_HIGHEST); // Or background
            renderer->FillRect(m_rect);
            renderer->SetColor(C_OUTLINE_VARIANT);
            renderer->DrawRect(m_rect, 1.0);
            Rect textRect = {m_rect.x + 16, m_rect.y + S_SM, m_rect.w, m_rect.h}; // Keep cancel as is
            renderer->DrawTextPango(m_text, textRect, "Inter 13", C_ON_SURFACE);
        }
    }

    // Add hover logic if MouseMove is passed
private:
    std::string m_text;
    bool m_primary;
    bool m_hovered;
};

// Simplified Dropdown
class Dropdown : public UIElement {
public:
    Dropdown(const std::string& selectedText) : m_selectedText(selectedText) {}

    void Draw(Renderer* renderer) override {
        renderer->SetColor(C_SURFACE_CONTAINER_LOW);
        renderer->FillRect(m_rect);
        renderer->SetColor(C_OUTLINE_VARIANT);
        renderer->DrawRect(m_rect, 1.0);

        Rect textRect = {m_rect.x + S_SM, m_rect.y + S_SM, m_rect.w, m_rect.h};
        renderer->DrawTextPango(m_selectedText, textRect, "Inter 13", C_ON_SURFACE);

        // Draw little arrow pseudo-icon
        Rect arrowRect = {m_rect.x + m_rect.w - 20, m_rect.y + S_SM, 10, 10};
        renderer->DrawTextPango("v", arrowRect, "Inter 12", C_ON_SURFACE_VARIANT);
    }
private:
    std::string m_selectedText;
};

// FileInput combo component
class FileInput : public UIElement {
public:
    FileInput() {}

    void Draw(Renderer* renderer) override {
        // Background input area
        Rect inputRect = m_rect;
        inputRect.w -= 80; // reserve space for Browse button
        renderer->SetColor(C_SURFACE_CONTAINER_LOW);
        renderer->FillRect(inputRect);
        renderer->SetColor(C_OUTLINE_VARIANT);
        renderer->DrawRect(inputRect, 1.0);

        Rect textRect = {inputRect.x + S_SM, inputRect.y + S_SM, inputRect.w, inputRect.h};
        renderer->DrawTextPango("No file selected", textRect, "Inter 13", C_ON_SURFACE_VARIANT);

        // Browse button
        Rect btnRect = {m_rect.x + m_rect.w - 80 + 4, m_rect.y, 76, m_rect.h};
        renderer->SetColor(C_SURFACE_CONTAINER_HIGHEST);
        renderer->FillRect(btnRect);
        renderer->SetColor(C_OUTLINE_VARIANT);
        renderer->DrawRect(btnRect, 1.0);

        Rect btnTextRect = {btnRect.x + S_SM, btnRect.y + S_SM, btnRect.w, btnRect.h};
        renderer->DrawTextPango("Browse...", btnTextRect, "Inter 13", C_ON_SURFACE);
    }
};
