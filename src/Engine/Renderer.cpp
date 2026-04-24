#include "Renderer.hpp"
#include <iostream>

Renderer::Renderer(SDL_Window* window) : m_window(window), m_surface(nullptr), cairo_surface(nullptr), cr(nullptr) {}

Renderer::~Renderer() {
    if (cr) cairo_destroy(cr);
    if (cairo_surface) cairo_surface_destroy(cairo_surface);
}

bool Renderer::Initialize() {
    m_surface = SDL_GetWindowSurface(m_window);
    if (!m_surface) {
        std::cerr << "Could not get window surface! SDL_Error: " << SDL_GetError() << std::endl;
        return false;
    }

    cairo_surface = cairo_image_surface_create_for_data(
        (unsigned char*)m_surface->pixels,
        CAIRO_FORMAT_RGB24,
        m_surface->w,
        m_surface->h,
        m_surface->pitch
    );

    cr = cairo_create(cairo_surface);
    return true;
}

void Renderer::BeginFrame() {
    // Re-create surface if window resized
    SDL_Surface* currentSurface = SDL_GetWindowSurface(m_window);
    if (currentSurface != m_surface) {
        if (cr) cairo_destroy(cr);
        if (cairo_surface) cairo_surface_destroy(cairo_surface);

        m_surface = currentSurface;
        cairo_surface = cairo_image_surface_create_for_data(
            (unsigned char*)m_surface->pixels,
            CAIRO_FORMAT_RGB24,
            m_surface->w,
            m_surface->h,
            m_surface->pitch
        );
        cr = cairo_create(cairo_surface);
    }
}

void Renderer::EndFrame() {
    SDL_UpdateWindowSurface(m_window);
}

void Renderer::SetColor(const Color& color) {
    cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
}

void Renderer::FillRect(const Rect& rect) {
    cairo_rectangle(cr, rect.x, rect.y, rect.w, rect.h);
    cairo_fill(cr);
}

void Renderer::DrawRect(const Rect& rect, double lineWidth) {
    // To draw sharp 1px borders, we need to offset by 0.5px
    cairo_set_line_width(cr, lineWidth);
    cairo_rectangle(cr, rect.x + 0.5, rect.y + 0.5, rect.w, rect.h);
    cairo_stroke(cr);
}

void Renderer::DrawTextPango(const std::string& text, const Rect& rect, const std::string& fontDescStr, const Color& color) {
    SetColor(color);

    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_text(layout, text.c_str(), -1);

    PangoFontDescription* fontDesc = pango_font_description_from_string(fontDescStr.c_str());
    pango_layout_set_font_description(layout, fontDesc);
    pango_font_description_free(fontDesc);

    // Optional: center or align based on rect.
    // For now, just draw at rect.x, rect.y
    cairo_move_to(cr, rect.x, rect.y);
    pango_cairo_show_layout(cr, layout);

    g_object_unref(layout);
}

void Renderer::DrawImage(const std::string& path, const Rect& rect) {
    // Placeholder for drawing icons
}
