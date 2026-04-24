#pragma once
#include <SDL2/SDL.h>
#include <cairo/cairo.h>
#include <pango/pangocairo.h>
#include <string>

struct Color {
    double r, g, b, a;
    Color() : r(0), g(0), b(0), a(1) {}
    Color(double _r, double _g, double _b, double _a = 1.0) : r(_r), g(_g), b(_b), a(_a) {}

    // Helper to parse hex like #131313
    static Color FromHex(const std::string& hex) {
        if (hex.length() < 7 || hex[0] != '#') return Color();
        int r, g, b;
        sscanf(hex.c_str(), "#%02x%02x%02x", &r, &g, &b);
        return Color(r / 255.0, g / 255.0, b / 255.0, 1.0);
    }
};

struct Rect {
    int x, y, w, h;
    Rect() : x(0), y(0), w(0), h(0) {}
    Rect(int _x, int _y, int _w, int _h) : x(_x), y(_y), w(_w), h(_h) {}
};

class Renderer {
public:
    Renderer(SDL_Window* window);
    ~Renderer();

    bool Initialize();
    void BeginFrame();
    void EndFrame();

    void SetColor(const Color& color);
    void FillRect(const Rect& rect);
    void DrawRect(const Rect& rect, double lineWidth = 1.0);
    void DrawTextPango(const std::string& text, const Rect& rect, const std::string& fontDesc, const Color& color);
    void DrawImage(const std::string& path, const Rect& rect); // Optional if needed for SVG/Icon later

    cairo_t* GetCairoContext() { return cr; }

private:
    SDL_Window* m_window;
    SDL_Surface* m_surface;
    cairo_surface_t* cairo_surface;
    cairo_t* cr;
};
