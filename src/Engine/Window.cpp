#include "Window.hpp"
#include "EventBus.hpp"
#include <iostream>

Window::Window(const std::string& title, int width, int height)
    : m_title(title), m_width(width), m_height(height), m_window(nullptr) {}

Window::~Window() {
    if (m_window) {
        SDL_DestroyWindow(m_window);
    }
    SDL_Quit();
}

bool Window::Initialize() {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        std::cerr << "SDL could not initialize! SDL_Error: " << SDL_GetError() << std::endl;
        return false;
    }

    m_window = SDL_CreateWindow(m_title.c_str(),
                                SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                m_width, m_height,
                                SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    if (!m_window) {
        std::cerr << "Window could not be created! SDL_Error: " << SDL_GetError() << std::endl;
        return false;
    }

    return true;
}

void Window::PollEvents(bool& isRunning) {
    SDL_Event e;
    while (SDL_PollEvent(&e) != 0) {
        switch (e.type) {
            case SDL_QUIT:
                isRunning = false;
                break;
            case SDL_WINDOWEVENT:
                if (e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
                    m_width = e.window.data1;
                    m_height = e.window.data2;
                    WindowResizeEvent ev(m_width, m_height);
                    EventBus::GetInstance().Dispatch(ev);
                }
                break;
            case SDL_MOUSEMOTION:
                {
                    MouseEvent ev(EventType::MouseMove, e.motion.x, e.motion.y);
                    EventBus::GetInstance().Dispatch(ev);
                }
                break;
            case SDL_MOUSEBUTTONDOWN:
                {
                    MouseEvent ev(EventType::MouseClick, e.button.x, e.button.y, e.button.button);
                    EventBus::GetInstance().Dispatch(ev);
                }
                break;
            case SDL_MOUSEBUTTONUP:
                {
                    MouseEvent ev(EventType::MouseRelease, e.button.x, e.button.y, e.button.button);
                    EventBus::GetInstance().Dispatch(ev);
                }
                break;
            // Add key events if needed
        }
    }
}

void Window::SwapBuffers() {
    // With Cairo on SDL, we might need a specific update mechanism.
    // For pure SDL Renderer we'd use SDL_RenderPresent.
    // We will handle surface updating in the Renderer class.
}
