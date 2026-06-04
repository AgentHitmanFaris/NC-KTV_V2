#pragma once

#include <QQuickPaintedItem>
#include <QString>
#include <QColor>
#include <QFont>
#include <QVector>
#include <QList>
#include <QTextLayout>
#include <QPainter>
#include <QLinearGradient>
#include <QRadialGradient>
#include <QElapsedTimer>
#include <QMap>
#include <QImage>

#include "timeline/lyric_engine.h"

namespace ncktv {

// ── Structured Timing Data for Karaoke Lyrics ────────────────────────────────

struct LyricWordTiming {
    QString text;
    qint64 startTime = 0; // Relative to line start or absolute timeline (in milliseconds)
    qint64 endTime = 0;
    double x1 = 0.25;
    double y1 = 0.25;
    double x2 = 0.75;
    double y2 = 0.75;
};

struct LyricTimingLine {
    QString text;
    qint64 startTime = 0; // Absolute timeline position (in milliseconds)
    qint64 endTime = 0;   // Absolute timeline position (in milliseconds)
    QVector<LyricWordTiming> words;
};

// ── KaraokeLyricRenderer ──────────────────────────────────────────────────────
// A high-performance, GPU-accelerated custom QML component that renders
// karaoke lyrics using QPainter.
// Supports three presentation modes:
//   - Mode A (Classic Cinematic Block Highlight): static block, fade transitions
//   - Mode B (Progressive Karaoke Fill Style): sweep highlighting, guide cursor, glow
//   - Mode C (Cinematic Focus Mode): 3-line scroll, scaling/focus pulse, vignette

class KaraokeLyricRenderer : public QQuickPaintedItem {
    Q_OBJECT

    // Display settings
    Q_PROPERTY(int displayMode READ displayMode WRITE setDisplayMode NOTIFY displayModeChanged)
    Q_PROPERTY(qint64 currentTimestamp READ currentTimestamp WRITE setCurrentTimestamp NOTIFY currentTimestampChanged)
    Q_PROPERTY(ncktv::LyricEngine* lyricEngine READ lyricEngine WRITE setLyricEngine NOTIFY lyricEngineChanged)

    // Typography & Styling
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontFamilyChanged)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY fontSizeChanged)
    Q_PROPERTY(QColor fillColor READ fillColor WRITE setFillColor NOTIFY fillColorChanged)
    Q_PROPERTY(QColor activeColor READ activeColor WRITE setActiveColor NOTIFY activeColorChanged)
    Q_PROPERTY(QColor outlineColor READ outlineColor WRITE setOutlineColor NOTIFY outlineColorChanged)
    Q_PROPERTY(int outlineWidth READ outlineWidth WRITE setOutlineWidth NOTIFY outlineWidthChanged)
    Q_PROPERTY(QColor backgroundColor READ backgroundColor WRITE setBackgroundColor NOTIFY backgroundColorChanged)

    // Mode-specific options
    Q_PROPERTY(bool showGuideCursor READ showGuideCursor WRITE setShowGuideCursor NOTIFY showGuideCursorChanged)
    Q_PROPERTY(bool vignetteEnabled READ vignetteEnabled WRITE setVignetteEnabled NOTIFY vignetteEnabledChanged)

public:
    enum DisplayMode {
        BottomTwoLine = 0,
        CenterScrollQueue = 1,
        WordBounce = 2,
        CinematicFullScreen = 3
    };
    Q_ENUM(DisplayMode)

    explicit KaraokeLyricRenderer(QQuickItem* parent = nullptr);
    virtual ~KaraokeLyricRenderer() override = default;

    // Getters
    [[nodiscard]] int displayMode() const { return m_displayMode; }
    [[nodiscard]] qint64 currentTimestamp() const { return m_currentTimestamp; }
    [[nodiscard]] QString fontFamily() const { return m_fontFamily; }
    [[nodiscard]] int fontSize() const { return m_fontSize; }
    [[nodiscard]] QColor fillColor() const { return m_fillColor; }
    [[nodiscard]] QColor activeColor() const { return m_activeColor; }
    [[nodiscard]] QColor outlineColor() const { return m_outlineColor; }
    [[nodiscard]] int outlineWidth() const { return m_outlineWidth; }
    [[nodiscard]] QColor backgroundColor() const { return m_backgroundColor; }
    [[nodiscard]] bool showGuideCursor() const { return m_showGuideCursor; }
    [[nodiscard]] bool vignetteEnabled() const { return m_vignetteEnabled; }
    [[nodiscard]] ncktv::LyricEngine* lyricEngine() const { return m_lyricEngine; }

    // Setters
    void setDisplayMode(int mode);
    void setCurrentTimestamp(qint64 timestampMs);
    void setFontFamily(const QString& family);
    void setFontSize(int size);
    void setFillColor(const QColor& color);
    void setActiveColor(const QColor& color);
    void setOutlineColor(const QColor& color);
    void setOutlineWidth(int width);
    void setBackgroundColor(const QColor& color);
    void setShowGuideCursor(bool enable);
    void setVignetteEnabled(bool enable);
    void setLyricEngine(ncktv::LyricEngine* engine);

    // API to set lyrics from C++
    void setLyrics(const QList<LyricTimingLine>& lines);

    // Q_INVOKABLE APIs for QML usage
    Q_INVOKABLE void clearLyrics();
    Q_INVOKABLE void addLyricLine(const QString& text, qint64 startTimeMs, qint64 endTimeMs);
    Q_INVOKABLE void addWordTiming(int lineIndex, const QString& text, qint64 startTimeMs, qint64 endTimeMs);
    Q_INVOKABLE void updatePlaybackPosition(qint64 timestampMs);
    Q_INVOKABLE double solveBezier(double x, double x1, double y1, double x2, double y2) const;

    // Core painting override
    virtual void paint(QPainter* painter) override;

signals:
    void displayModeChanged();
    void currentTimestampChanged();
    void fontFamilyChanged();
    void fontSizeChanged();
    void fillColorChanged();
    void activeColorChanged();
    void outlineColorChanged();
    void outlineWidthChanged();
    void backgroundColorChanged();
    void showGuideCursorChanged();
    void vignetteEnabledChanged();
    void lyricEngineChanged();

private:
    struct CachedWord {
        QString text;
        qint64 startTime = 0;
        qint64 endTime = 0;
        qreal leftX = 0;
        qreal rightX = 0;
        double x1 = 0.25;
        double y1 = 0.25;
        double x2 = 0.75;
        double y2 = 0.75;
    };

    struct RenderCache {
        QFont font;
        qreal totalWidth = 0;
        qreal totalHeight = 0;
        QList<CachedWord> cachedWords;
        mutable QMap<QRgb, QImage> images;
    };

    struct CachedLine {
        int index = -1;
        QString text;
        qint64 startTime = 0;
        qint64 endTime = 0;
        QList<CachedWord> cachedWords;
        
        mutable QList<RenderCache> caches;
        
        const RenderCache& getCache(const QFont& font) const;
    };

    // Helper rendering routines
    void renderBottomTwoLine(QPainter* painter);
    void renderCenterScrollQueue(QPainter* painter);
    void renderWordBounce(QPainter* painter);
    void renderCinematicFullScreen(QPainter* painter);

    void drawVignette(QPainter* painter);
    void drawStyledText(QPainter* painter, CachedLine* line, const QString& text, const QPointF& pos, const QFont& font, const QColor& fill, const QColor& outline, int outlineWidth, int alignFlags = Qt::AlignCenter);
    QImage generateTextImage(const QString& text, const QFont& font, const QColor& fill, const QColor& outline, int outlineWidth, qreal totalWidth, qreal totalHeight);
    
    // Layout helpers
    int findActiveLineIndex(qint64 timestampMs) const;
    double getContinuousFocusPosition(qint64 timestampMs) const;
    void syncWithEngine();
    qreal calculateSweepX(const CachedLine& line, const QFont& font) const;

    // Component configuration
    int m_displayMode = BottomTwoLine;
    qint64 m_currentTimestamp = 0;

    QString m_fontFamily = "Georgia";
    int m_fontSize = 28;
    QColor m_fillColor = QColor(128, 128, 128, 128); // Muted gray default
    QColor m_activeColor = QColor(255, 255, 255);     // White active
    QColor m_outlineColor = QColor(0, 0, 0);          // Black outline
    int m_outlineWidth = 2;
    QColor m_backgroundColor = QColor(0, 0, 0);       // Solid black default

    bool m_showGuideCursor = true;
    bool m_vignetteEnabled = true;

    QList<LyricTimingLine> m_lyrics;
    mutable QList<CachedLine> m_cachedLines;
    mutable bool m_cacheDirty = true;
    ncktv::LyricEngine* m_lyricEngine = nullptr;
};

} // namespace ncktv
