#pragma once
#include <SDL2/SDL.h>
#include <string>

class Window {
public:
    Window(const std::string& title, int width, int height);
    ~Window();

    bool Initialize();
    void PollEvents(bool& isRunning);
    void SwapBuffers();

    SDL_Window* GetSDLWindow() const { return m_window; }
    int GetWidth() const { return m_width; }
    int GetHeight() const { return m_height; }

private:
    std::string m_title;
    int m_width;
    int m_height;
    SDL_Window* m_window;
};
