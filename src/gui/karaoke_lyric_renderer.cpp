#include "karaoke_lyric_renderer.h"
#include <QFontMetricsF>
#include <QPainterPath>
#include <QGuiApplication>
#include <QStyleHints>
#include <cmath>
#include <QDebug>

namespace ncktv {

// ─────────────────────────────────────────────────────────────────────────────
// Construction & Initialization
// ─────────────────────────────────────────────────────────────────────────────

KaraokeLyricRenderer::KaraokeLyricRenderer(QQuickItem* parent)
    : QQuickPaintedItem(parent)
{
    // Enable active drawing flags for premium responsiveness
    setFlag(ItemHasContents, true);
    setAntialiasing(true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Properties Setters
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::setDisplayMode(int mode)
{
    if (m_displayMode != mode) {
        m_displayMode = qBound(0, mode, 3);
        m_cacheDirty = true;
        emit displayModeChanged();
        update();
    }
}

void KaraokeLyricRenderer::setCurrentTimestamp(qint64 timestampMs)
{
    if (m_currentTimestamp != timestampMs) {
        m_currentTimestamp = timestampMs;
        emit currentTimestampChanged();
        update();
    }
}

void KaraokeLyricRenderer::setFontFamily(const QString& family)
{
    if (m_fontFamily != family) {
        m_fontFamily = family;
        m_cacheDirty = true;
        emit fontFamilyChanged();
        update();
    }
}

void KaraokeLyricRenderer::setFontSize(int size)
{
    if (m_fontSize != size) {
        m_fontSize = size;
        m_cacheDirty = true;
        emit fontSizeChanged();
        update();
    }
}

void KaraokeLyricRenderer::setFillColor(const QColor& color)
{
    if (m_fillColor != color) {
        m_fillColor = color;
        emit fillColorChanged();
        update();
    }
}

void KaraokeLyricRenderer::setActiveColor(const QColor& color)
{
    if (m_activeColor != color) {
        m_activeColor = color;
        emit activeColorChanged();
        update();
    }
}

void KaraokeLyricRenderer::setOutlineColor(const QColor& color)
{
    if (m_outlineColor != color) {
        m_outlineColor = color;
        emit outlineColorChanged();
        update();
    }
}

void KaraokeLyricRenderer::setOutlineWidth(int width)
{
    if (m_outlineWidth != width) {
        m_outlineWidth = width;
        emit outlineWidthChanged();
        update();
    }
}

void KaraokeLyricRenderer::setBackgroundColor(const QColor& color)
{
    if (m_backgroundColor != color) {
        m_backgroundColor = color;
        emit backgroundColorChanged();
        update();
    }
}

void KaraokeLyricRenderer::setShowGuideCursor(bool enable)
{
    if (m_showGuideCursor != enable) {
        m_showGuideCursor = enable;
        emit showGuideCursorChanged();
        update();
    }
}

void KaraokeLyricRenderer::setVignetteEnabled(bool enable)
{
    if (m_vignetteEnabled != enable) {
        m_vignetteEnabled = enable;
        emit vignetteEnabledChanged();
        update();
    }
}

void KaraokeLyricRenderer::setLyricEngine(LyricEngine* engine)
{
    if (m_lyricEngine != engine) {
        if (m_lyricEngine) {
            disconnect(m_lyricEngine, nullptr, this, nullptr);
        }
        m_lyricEngine = engine;
        if (m_lyricEngine) {
            connect(m_lyricEngine, &LyricEngine::activeLineChanged, this, &KaraokeLyricRenderer::syncWithEngine);
            connect(m_lyricEngine, &LyricEngine::upcomingLinesChanged, this, &KaraokeLyricRenderer::syncWithEngine);
            syncWithEngine();
        }
        emit lyricEngineChanged();
    }
}

void KaraokeLyricRenderer::syncWithEngine()
{
    m_lyrics.clear();
    if (!m_lyricEngine) {
        m_cacheDirty = true;
        update();
        return;
    }

    const auto& cache = m_lyricEngine->lineCache();
    m_lyrics.reserve(cache.size());

    for (const auto& srcLine : cache) {
        LyricTimingLine destLine;
        destLine.text = srcLine.text;
        destLine.startTime = srcLine.startTimeUs / 1000;
        destLine.endTime = srcLine.endTimeUs / 1000;
        destLine.words.reserve(srcLine.words.size());

        for (const auto& srcWord : srcLine.words) {
            LyricWordTiming destWord;
            destWord.text = srcWord.text;
            destWord.startTime = (srcLine.startTimeUs + srcWord.relativeStartUs) / 1000;
            destWord.endTime = (srcLine.startTimeUs + srcWord.relativeStartUs + srcWord.durationUs) / 1000;
            destLine.words.append(destWord);
        }
        m_lyrics.append(destLine);
    }

    m_cacheDirty = true;
    update();
}

// ─────────────────────────────────────────────────────────────────────────────
// Public Lyrics API
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::setLyrics(const QList<LyricTimingLine>& lines)
{
    m_lyrics = lines;
    m_cacheDirty = true;
    update();
}

void KaraokeLyricRenderer::clearLyrics()
{
    m_lyrics.clear();
    m_cachedLines.clear();
    m_cacheDirty = true;
    m_currentTimestamp = 0;
    update();
}

void KaraokeLyricRenderer::addLyricLine(const QString& text, qint64 startTimeMs, qint64 endTimeMs)
{
    LyricTimingLine line;
    line.text = text;
    line.startTime = startTimeMs;
    line.endTime = endTimeMs;
    m_lyrics.append(line);
    m_cacheDirty = true;
    update();
}

void KaraokeLyricRenderer::addWordTiming(int lineIndex, const QString& text, qint64 startTimeMs, qint64 endTimeMs)
{
    if (lineIndex >= 0 && lineIndex < m_lyrics.size()) {
        LyricWordTiming wt;
        wt.text = text;
        wt.startTime = startTimeMs;
        wt.endTime = endTimeMs;
        m_lyrics[lineIndex].words.append(wt);
        m_cacheDirty = true;
        update();
    }
}

void KaraokeLyricRenderer::updatePlaybackPosition(qint64 timestampMs)
{
    setCurrentTimestamp(timestampMs);
}

// ─────────────────────────────────────────────────────────────────────────────
// Painting Entry Point
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::paint(QPainter* painter)
{
    if (!painter) return;

    // 1. Build cache if dirty
    if (m_cacheDirty) {
        m_cachedLines.clear();
        m_cachedLines.reserve(m_lyrics.size());
        for (int i = 0; i < m_lyrics.size(); ++i) {
            const auto& src = m_lyrics[i];
            CachedLine line;
            line.index = i;
            line.text = src.text;
            line.startTime = src.startTime;
            line.endTime = src.endTime;
            line.cachedWords.reserve(src.words.size());
            for (const auto& w : src.words) {
                CachedWord cw;
                cw.text = w.text;
                cw.startTime = w.startTime;
                cw.endTime = w.endTime;
                line.cachedWords.append(cw);
            }
            m_cachedLines.append(line);
        }
        m_cacheDirty = false;
    }

    // 2. Clear canvas with custom background color
    painter->fillRect(boundingRect(), m_backgroundColor);

    // 3. Render according to the selected mode
    switch (m_displayMode) {
        case BottomTwoLine:
            renderBottomTwoLine(painter);
            break;
        case CenterScrollQueue:
            renderCenterScrollQueue(painter);
            break;
        case WordBounce:
            renderWordBounce(painter);
            break;
        case CinematicFullScreen:
            renderCinematicFullScreen(painter);
            break;
        default:
            renderBottomTwoLine(painter);
            break;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE 0: Bottom Two-Line (Timing sweep, bottom aligned)
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::renderBottomTwoLine(QPainter* painter)
{
    // Draw standard transparent backdrop or local background
    if (m_backgroundColor.alpha() > 0) {
        painter->fillRect(boundingRect(), m_backgroundColor);
    }

    int activeIdx = findActiveLineIndex(m_currentTimestamp);
    qreal width = boundingRect().width();
    qreal height = boundingRect().height();
    qreal midX = width / 2.0;

    QFont font(m_fontFamily, m_fontSize);
    font.setStyleHint(QFont::Serif);
    font.setBold(true);

    // If there is no active line, look for the first upcoming line to display
    if (activeIdx < 0) {
        int nextIdx = -1;
        for (int i = 0; i < m_cachedLines.size(); ++i) {
            if (m_cachedLines[i].startTime > m_currentTimestamp) {
                nextIdx = i;
                break;
            }
        }

        if (nextIdx >= 0) {
            CachedLine& line = m_cachedLines[nextIdx];
            // Draw upcoming lyric centered at the first line position in muted gray/white
            qreal firstLineY = height - m_fontSize * 2.8;
            drawStyledText(painter, &line, line.text, QPointF(midX, firstLineY), font, QColor(200, 200, 200, 180), m_outlineColor, m_outlineWidth);
        } else {
            qreal firstLineY = height - m_fontSize * 2.8;
            drawStyledText(painter, nullptr, "(Waiting for lyric cues)", QPointF(midX, firstLineY), font, QColor(128, 128, 128, 128), m_outlineColor, m_outlineWidth);
        }
        return;
    }

    // Active line
    CachedLine& line = m_cachedLines[activeIdx];
    const RenderCache& cache = line.getCache(font);

    // Calculate Sweep Position (pixel-perfect)
    qreal sweepX = 0;
    qreal startX = midX - (cache.totalWidth / 2.0);
    qreal endX = midX + (cache.totalWidth / 2.0);

    qint64 lineDuration = line.endTime - line.startTime;
    qint64 elapsed = m_currentTimestamp - line.startTime;

    if (cache.cachedWords.isEmpty()) {
        double progress = (lineDuration > 0) ? qBound(0.0, static_cast<double>(elapsed) / lineDuration, 1.0) : 1.0;
        sweepX = startX + progress * cache.totalWidth;
    } else {
        if (m_currentTimestamp < cache.cachedWords.first().startTime) {
            sweepX = startX;
        } else if (m_currentTimestamp >= cache.cachedWords.last().endTime) {
            sweepX = endX;
        } else {
            for (int i = 0; i < cache.cachedWords.size(); ++i) {
                const auto& w = cache.cachedWords[i];
                if (m_currentTimestamp >= w.startTime && m_currentTimestamp <= w.endTime) {
                    qint64 wDuration = w.endTime - w.startTime;
                    double wordProg = (wDuration > 0) ? qBound(0.0, static_cast<double>(m_currentTimestamp - w.startTime) / wDuration, 1.0) : 1.0;
                    sweepX = startX + w.leftX + wordProg * (w.rightX - w.leftX);
                    break;
                } else if (i < cache.cachedWords.size() - 1 && 
                           m_currentTimestamp > w.endTime && 
                           m_currentTimestamp < cache.cachedWords[i+1].startTime) {
                    const auto& nextW = cache.cachedWords[i+1];
                    qint64 gap = nextW.startTime - w.endTime;
                    double gapProg = (gap > 0) ? qBound(0.0, static_cast<double>(m_currentTimestamp - w.endTime) / gap, 1.0) : 1.0;
                    sweepX = startX + w.rightX + gapProg * (nextW.leftX - w.rightX);
                    break;
                }
            }
        }
    }

    qreal activeY = height - m_fontSize * 2.8;

    // Draw active line inactive backdrop (White/Light Gray)
    drawStyledText(painter, &line, line.text, QPointF(midX, activeY), font, QColor(220, 220, 220), m_outlineColor, m_outlineWidth);

    // Draw active portion (swept in Gold/Orange)
    painter->save();
    QRectF clipRect(startX - 10, activeY - cache.totalHeight, (sweepX - startX) + 10, cache.totalHeight * 2);
    painter->setClipRect(clipRect);
    QColor activeFillColor(255, 176, 0); // Gold
    drawStyledText(painter, &line, line.text, QPointF(midX, activeY), font, activeFillColor, m_outlineColor, m_outlineWidth);
    painter->restore();

    // Render Guide Cursor "|" with Glow
    if (m_showGuideCursor && sweepX > startX && sweepX < endX) {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing, true);

        // Radial glow behind cursor
        QRadialGradient glow(QPointF(sweepX, activeY), cache.totalHeight * 0.5);
        glow.setColorAt(0.0, QColor(255, 165, 0, 100)); // Gold/Orange glow
        glow.setColorAt(1.0, QColor(255, 165, 0, 0));
        painter->setBrush(glow);
        painter->setPen(Qt::NoPen);
        painter->drawEllipse(QPointF(sweepX, activeY), cache.totalHeight * 0.4, cache.totalHeight * 0.4);

        // Vertical Guide Line
        QPen cursorPen(QColor(255, 215, 0), 2.5);
        painter->setPen(cursorPen);
        painter->drawLine(QPointF(sweepX, activeY - cache.totalHeight * 0.4), 
                          QPointF(sweepX, activeY + cache.totalHeight * 0.4));
        painter->restore();
    }

    // Draw upcoming line at the bottom
    int upcomingIdx = activeIdx + 1;
    if (upcomingIdx < m_cachedLines.size()) {
        CachedLine& nextLine = m_cachedLines[upcomingIdx];
        QFont upcomingFont(m_fontFamily, m_fontSize * 0.85);
        upcomingFont.setStyleHint(QFont::Serif);
        upcomingFont.setBold(true);

        qreal upcomingY = height - m_fontSize * 1.2;
        drawStyledText(painter, &nextLine, nextLine.text, QPointF(midX, upcomingY), upcomingFont, QColor(160, 160, 160, 180), m_outlineColor, m_outlineWidth);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE 1: Center Scroll Queue (Classic Cinematic Block style)
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::renderCenterScrollQueue(QPainter* painter)
{
    int activeIdx = findActiveLineIndex(m_currentTimestamp);
    
    // Determine which line index to center around
    int centerIdx = activeIdx;
    if (centerIdx < 0) {
        // Fallback: look for the next upcoming line
        for (int i = 0; i < m_cachedLines.size(); ++i) {
            if (m_cachedLines[i].startTime > m_currentTimestamp) {
                centerIdx = i;
                break;
            }
        }
    }
    if (centerIdx < 0 && !m_cachedLines.isEmpty()) {
        centerIdx = m_cachedLines.size() - 1;
    }

    if (centerIdx < 0) {
        // Show waiting cues if list is empty
        QFont font(m_fontFamily, m_fontSize);
        font.setStyleHint(QFont::Serif);
        drawStyledText(painter, nullptr, "(Waiting for lyric cues)", 
                       boundingRect().center(), font, 
                       QColor(128, 128, 128, 128), m_outlineColor, m_outlineWidth);
        return;
    }

    // Setup base layout parameters
    qreal midY = boundingRect().height() / 2;
    qreal midX = boundingRect().width() / 2;
    qreal lineSpacing = m_fontSize * 2.0;

    QFont font(m_fontFamily, m_fontSize);
    font.setStyleHint(QFont::Serif);

    // Show up to 3 lines: Previous, Current, Next (paragraph block style)
    for (int offset = -1; offset <= 1; ++offset) {
        int idx = centerIdx + offset;
        if (idx < 0 || idx >= m_cachedLines.size()) continue;

        CachedLine& line = m_cachedLines[idx];
        qreal yPos = midY + offset * lineSpacing;
        
        // Colors & opacity calculations
        bool isActive = (idx == activeIdx);
        QColor fill = isActive ? QColor(255, 255, 255, 255) : QColor(128, 128, 128, 128); // 100% white vs 50% opacity gray

        drawStyledText(painter, &line, line.text, QPointF(midX, yPos), font, fill, m_outlineColor, m_outlineWidth);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE 2: Word Bounce (Centered Progressive timing sweep style)
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::renderWordBounce(QPainter* painter)
{
    // Background must be solid black for high contrast karaoke sweep
    painter->fillRect(boundingRect(), QColor(0, 0, 0));

    int activeIdx = findActiveLineIndex(m_currentTimestamp);

    QFont font(m_fontFamily, m_fontSize * 1.2); // Large centered serif font
    font.setStyleHint(QFont::Serif);
    font.setBold(true);

    qreal midY = boundingRect().height() / 2.0;
    qreal midX = boundingRect().width() / 2.0;

    if (activeIdx < 0) {
        // Find next upcoming line to show early
        int nextIdx = -1;
        for (int i = 0; i < m_cachedLines.size(); ++i) {
            if (m_cachedLines[i].startTime > m_currentTimestamp) {
                nextIdx = i;
                break;
            }
        }

        if (nextIdx >= 0) {
            CachedLine& line = m_cachedLines[nextIdx];
            // Draw upcoming lyrics early in muted white/light gray
            drawStyledText(painter, &line, line.text, QPointF(midX, midY), font, QColor(180, 180, 180, 150), m_outlineColor, m_outlineWidth);
        } else {
            drawStyledText(painter, nullptr, "(Waiting for lyric cues)", QPointF(midX, midY), font, QColor(128, 128, 128, 128), m_outlineColor, m_outlineWidth);
        }
        return;
    }

    // Active line rendering
    CachedLine& line = m_cachedLines[activeIdx];
    const RenderCache& cache = line.getCache(font);

    // Calculate Sweep Position (pixel-perfect)
    qreal sweepX = 0;
    qreal startX = midX - (cache.totalWidth / 2.0);
    qreal endX = midX + (cache.totalWidth / 2.0);

    qint64 lineDuration = line.endTime - line.startTime;
    qint64 elapsed = m_currentTimestamp - line.startTime;

    if (cache.cachedWords.isEmpty()) {
        // Linear fallback if no word timings
        double progress = (lineDuration > 0) ? qBound(0.0, static_cast<double>(elapsed) / lineDuration, 1.0) : 1.0;
        sweepX = startX + progress * cache.totalWidth;
    } else {
        // Calculate based on exact syllable/word timings
        if (m_currentTimestamp < cache.cachedWords.first().startTime) {
            sweepX = startX;
        } else if (m_currentTimestamp >= cache.cachedWords.last().endTime) {
            sweepX = endX;
        } else {
            // Find active word
            for (int i = 0; i < cache.cachedWords.size(); ++i) {
                const auto& w = cache.cachedWords[i];
                if (m_currentTimestamp >= w.startTime && m_currentTimestamp <= w.endTime) {
                    qint64 wDuration = w.endTime - w.startTime;
                    double wordProg = (wDuration > 0) ? qBound(0.0, static_cast<double>(m_currentTimestamp - w.startTime) / wDuration, 1.0) : 1.0;
                    sweepX = startX + w.leftX + wordProg * (w.rightX - w.leftX);
                    break;
                } else if (i < cache.cachedWords.size() - 1 && 
                           m_currentTimestamp > w.endTime && 
                           m_currentTimestamp < cache.cachedWords[i+1].startTime) {
                    // Transition between words
                    const auto& nextW = cache.cachedWords[i+1];
                    qint64 gap = nextW.startTime - w.endTime;
                    double gapProg = (gap > 0) ? qBound(0.0, static_cast<double>(m_currentTimestamp - w.endTime) / gap, 1.0) : 1.0;
                    sweepX = startX + w.rightX + gapProg * (nextW.leftX - w.rightX);
                    break;
                }
            }
        }
    }

    // Draw Inactive backdrop (White/Light Gray)
    drawStyledText(painter, &line, line.text, QPointF(midX, midY), font, QColor(220, 220, 220), m_outlineColor, m_outlineWidth);

    // Draw Active Swept overlay clipped to sweepX
    painter->save();
    
    // Set clipping bounds to sweep progress
    QRectF clipRect(startX - 10, midY - cache.totalHeight, (sweepX - startX) + 10, cache.totalHeight * 2);
    painter->setClipRect(clipRect);

    // Draw active portion in Gold/Orange (#FFB000 or #FFA500)
    QColor activeFillColor(255, 176, 0); // Gold
    drawStyledText(painter, &line, line.text, QPointF(midX, midY), font, activeFillColor, m_outlineColor, m_outlineWidth);
    painter->restore();

    // Render Guide Cursor "|" with Glow
    if (m_showGuideCursor && sweepX > startX && sweepX < endX) {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing, true);

        // Radial glow behind cursor
        QRadialGradient glow(QPointF(sweepX, midY), cache.totalHeight * 0.5);
        glow.setColorAt(0.0, QColor(255, 165, 0, 100)); // Gold/Orange glow
        glow.setColorAt(1.0, QColor(255, 165, 0, 0));
        painter->setBrush(glow);
        painter->setPen(Qt::NoPen);
        painter->drawEllipse(QPointF(sweepX, midY), cache.totalHeight * 0.4, cache.totalHeight * 0.4);

        // Vertical Guide Line
        QPen cursorPen(QColor(255, 215, 0), 2.5); // Golden cursor line
        painter->setPen(cursorPen);
        painter->drawLine(QPointF(sweepX, midY - cache.totalHeight * 0.4), 
                          QPointF(sweepX, midY + cache.totalHeight * 0.4));
        
        painter->restore();
    }

    // Show Upcoming lyrics early at the bottom
    int upcomingIdx = activeIdx + 1;
    if (upcomingIdx < m_cachedLines.size()) {
        CachedLine& nextLine = m_cachedLines[upcomingIdx];
        QFont upcomingFont(m_fontFamily, m_fontSize * 0.8);
        upcomingFont.setStyleHint(QFont::Serif);
        
        drawStyledText(painter, &nextLine, nextLine.text, QPointF(midX, midY + m_fontSize * 2.0), upcomingFont, QColor(140, 140, 140, 100), m_outlineColor, m_outlineWidth);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE 3: Cinematic Full-Screen Focus (Transitions + scaling)
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::renderCinematicFullScreen(QPainter* painter)
{
    // Apply Vignette and dark gradient background if enabled
    if (m_vignetteEnabled) {
        drawVignette(painter);
    } else {
        painter->fillRect(boundingRect(), QColor(15, 15, 20)); // Subtle dark blue-gray
    }

    int activeIdx = findActiveLineIndex(m_currentTimestamp);

    qreal midY = boundingRect().height() / 2.0;
    qreal midX = boundingRect().width() / 2.0;
    qreal spacing = m_fontSize * 2.2;

    QFont font(m_fontFamily, m_fontSize);
    font.setStyleHint(QFont::Serif);

    if (m_cachedLines.isEmpty()) {
        drawStyledText(painter, nullptr, "(Waiting for lyric cues)", QPointF(midX, midY), font, QColor(128, 128, 128, 128), m_outlineColor, m_outlineWidth);
        return;
    }

    // Determine the focus line index
    int focusIdx = activeIdx;
    if (focusIdx < 0) {
        for (int i = 0; i < m_cachedLines.size(); ++i) {
            if (m_cachedLines[i].startTime > m_currentTimestamp) {
                focusIdx = i;
                break;
            }
        }
    }
    if (focusIdx < 0) {
        focusIdx = m_cachedLines.size() - 1;
    }

    // Calculate transition progress (interpolator)
    double t = 1.0;
    const qint64 transitionDurationMs = 300; // Smooth 300ms transition

    if (focusIdx >= 0) {
        qint64 lineStart = m_cachedLines[focusIdx].startTime;
        qint64 diff = m_currentTimestamp - lineStart;
        if (diff >= 0 && diff < transitionDurationMs) {
            t = static_cast<double>(diff) / transitionDurationMs;
        }
    }

    // Smooth transition easing curve (Cubic Out / Quad In-Out)
    double tSmooth = t * t * (3.0 - 2.0 * t);

    // Dynamic scale pulse factor for focus lyric (gentle breathing pulse)
    double pulseFactor = 1.0;
    if (activeIdx >= 0) {
        pulseFactor = 1.0 + 0.025 * std::sin(2.0 * M_PI * (m_currentTimestamp % 2500) / 2500.0);
    }

    // Show Previous lyric
    int prevIdx = focusIdx - 1;
    if (prevIdx >= 0) {
        CachedLine& line = m_cachedLines[prevIdx];

        // Previous animates upwards and fades out
        qreal fromY = midY - spacing;
        qreal toY = midY - spacing * 1.5;
        qreal y = fromY + (toY - fromY) * (1.0 - tSmooth);

        double fromScale = 0.8;
        double toScale = 0.6;
        double scale = fromScale + (toScale - fromScale) * (1.0 - tSmooth);

        double fromOpacity = 0.35;
        double toOpacity = 0.0;
        double opacity = fromOpacity + (toOpacity - fromOpacity) * (1.0 - tSmooth);

        painter->save();
        painter->translate(midX, y);
        painter->scale(scale, scale);
        
        QColor fill = QColor(200, 200, 200, static_cast<int>(opacity * 255));
        drawStyledText(painter, &line, line.text, QPointF(0, 0), font, fill, m_outlineColor, m_outlineWidth);
        painter->restore();
    }

    // Show Current focused lyric
    if (focusIdx >= 0 && focusIdx < m_cachedLines.size()) {
        CachedLine& line = m_cachedLines[focusIdx];

        // Animates from upcoming position to center focus
        qreal fromY = midY + spacing;
        qreal toY = midY;
        qreal y = fromY + (toY - fromY) * tSmooth;

        double fromScale = 0.8;
        double toScale = 1.15 * pulseFactor;
        double scale = fromScale + (toScale - fromScale) * tSmooth;

        double fromOpacity = 0.35;
        double toOpacity = 1.0;
        double opacity = fromOpacity + (toOpacity - fromOpacity) * tSmooth;

        painter->save();
        painter->translate(midX, y);
        painter->scale(scale, scale);

        // Bright white active fill with subtle glow
        QColor fill = QColor(255, 255, 255, static_cast<int>(opacity * 255));
        drawStyledText(painter, &line, line.text, QPointF(0, 0), font, fill, m_outlineColor, m_outlineWidth);
        painter->restore();
    }

    // Show Upcoming lyric
    int nextIdx = focusIdx + 1;
    if (nextIdx < m_cachedLines.size()) {
        CachedLine& line = m_cachedLines[nextIdx];

        // Upcoming animates to center or slides into queue
        qreal fromY = midY + spacing * 2.0;
        qreal toY = midY + spacing;
        qreal y = fromY + (toY - fromY) * tSmooth;

        double fromScale = 0.0;
        double toScale = 0.8;
        double scale = fromScale + (toScale - fromScale) * tSmooth;

        double fromOpacity = 0.0;
        double toOpacity = 0.35;
        double opacity = fromOpacity + (toOpacity - fromOpacity) * tSmooth;

        painter->save();
        painter->translate(midX, y);
        painter->scale(scale, scale);

        QColor fill = QColor(180, 180, 180, static_cast<int>(opacity * 255));
        drawStyledText(painter, &line, line.text, QPointF(0, 0), font, fill, m_outlineColor, m_outlineWidth);
        painter->restore();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vignette Rendering Routine
// ─────────────────────────────────────────────────────────────────────────────

void KaraokeLyricRenderer::drawVignette(QPainter* painter)
{
    QRectF rect = boundingRect();
    
    // Create dark gradient background
    QLinearGradient bgGrad(rect.topLeft(), rect.bottomRight());
    bgGrad.setColorAt(0.0, QColor(10, 10, 15));
    bgGrad.setColorAt(0.5, QColor(20, 20, 30));
    bgGrad.setColorAt(1.0, QColor(10, 10, 15));
    painter->fillRect(rect, bgGrad);

    // Apply Radial Vignette Overlay (fades out at corners)
    QRadialGradient vignette(rect.center(), std::max(rect.width(), rect.height()) * 0.7);
    vignette.setColorAt(0.0, QColor(0, 0, 0, 0));
    vignette.setColorAt(0.7, QColor(0, 0, 0, 50));
    vignette.setColorAt(1.0, QColor(0, 0, 0, 220)); // Soft cinematic shadow frame
    
    painter->fillRect(rect, vignette);
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled Text Painter (Handles font, alignments, colors & precise vector outlines)
// ─────────────────────────────────────────────────────────────────────────────

const KaraokeLyricRenderer::RenderCache& KaraokeLyricRenderer::CachedLine::getCache(const QFont& font) const
{
    for (const auto& cache : caches) {
        if (cache.font == font) {
            return cache;
        }
    }
    
    // Create new cache
    RenderCache newCache;
    newCache.font = font;
    
    // Perform text layout metrics calculation
    QFontMetricsF fm(font);
    newCache.totalHeight = fm.height();
    newCache.totalWidth = fm.horizontalAdvance(text);
    
    if (!cachedWords.isEmpty()) {
        newCache.cachedWords = cachedWords;
        QTextLayout layout(text, font);
        layout.beginLayout();
        QTextLine textLine = layout.createLine();
        layout.endLayout();
        
        if (textLine.isValid()) {
            int charIndex = 0;
            for (auto& word : newCache.cachedWords) {
                int startPos = text.indexOf(word.text, charIndex);
                if (startPos == -1) startPos = charIndex;
                int endPos = startPos + word.text.length();
                charIndex = endPos;
                
                int pos = startPos;
                word.leftX = textLine.cursorToX(&pos);
                pos = endPos;
                word.rightX = textLine.cursorToX(&pos);
            }
        }
    }
    
    caches.append(newCache);
    return caches.last();
}

QImage KaraokeLyricRenderer::generateTextImage(const QString& text, const QFont& font, const QColor& fill, const QColor& outline, int outlineWidth, qreal totalWidth, qreal totalHeight)
{
    QFontMetricsF fm(font);
    qreal ascent = fm.ascent();
    
    int imgWidth = static_cast<int>(std::ceil(totalWidth + outlineWidth * 2.0 + 10.0));
    int imgHeight = static_cast<int>(std::ceil(totalHeight + outlineWidth * 2.0 + 10.0));
    
    if (imgWidth <= 0 || imgHeight <= 0) {
        return QImage();
    }
    
    QImage img(imgWidth, imgHeight, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    
    QPainter painter(&img);
    painter.setFont(font);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::TextAntialiasing, true);
    
    QPointF textPos(outlineWidth + 5.0, ascent + outlineWidth + 5.0);
    
    if (outlineWidth > 0) {
        QPainterPath path;
        path.addText(textPos, font, text);
        
        QPen pen(outline, outlineWidth * 2.0, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
        painter.strokePath(path, pen);
        painter.fillPath(path, fill);
    } else {
        painter.setPen(fill);
        painter.drawText(textPos, text);
    }
    
    return img;
}

void KaraokeLyricRenderer::drawStyledText(QPainter* painter, CachedLine* line, const QString& text, const QPointF& pos, const QFont& font, const QColor& fill, const QColor& outline, int outlineWidth, int alignFlags)
{
    if (!painter) return;

    if (!line) {
        painter->save();
        painter->setFont(font);
        painter->setRenderHint(QPainter::TextAntialiasing, true);

        QFontMetricsF fm(font);
        qreal textWidth = fm.horizontalAdvance(text);
        qreal textHeight = fm.height();
        qreal ascent = fm.ascent();

        QPointF textPos = pos;
        if (alignFlags & Qt::AlignHCenter) {
            textPos.setX(pos.x() - textWidth / 2.0);
        } else if (alignFlags & Qt::AlignRight) {
            textPos.setX(pos.x() - textWidth);
        }

        if (alignFlags & Qt::AlignVCenter) {
            textPos.setY(pos.y() - textHeight / 2.0 + ascent);
        } else if (alignFlags & Qt::AlignBottom) {
            textPos.setY(pos.y() - textHeight + ascent);
        } else {
            textPos.setY(pos.y() + ascent - textHeight / 2.0);
        }

        if (outlineWidth > 0) {
            QPainterPath path;
            path.addText(textPos, font, text);
            QPen pen(outline, outlineWidth * 2.0, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
            painter->strokePath(path, pen);
            painter->fillPath(path, fill);
        } else {
            painter->setPen(fill);
            painter->drawText(textPos, text);
        }
        painter->restore();
        return;
    }

    const RenderCache& cache = line->getCache(font);
    QRgb fillKey = fill.rgb();
    
    QImage img;
    auto it = cache.images.find(fillKey);
    if (it != cache.images.end()) {
        img = *it;
    } else {
        QColor solidFill = fill;
        solidFill.setAlpha(255);
        img = generateTextImage(text, font, solidFill, outline, outlineWidth, cache.totalWidth, cache.totalHeight);
        cache.images.insert(fillKey, img);
    }
    
    if (img.isNull()) return;
    
    painter->save();
    
    QFontMetricsF fm(font);
    qreal textWidth = cache.totalWidth;
    qreal textHeight = cache.totalHeight;
    qreal ascent = fm.ascent();
    
    QPointF textPos = pos;
    if (alignFlags & Qt::AlignHCenter) {
        textPos.setX(pos.x() - textWidth / 2.0);
    } else if (alignFlags & Qt::AlignRight) {
        textPos.setX(pos.x() - textWidth);
    }
    
    if (alignFlags & Qt::AlignVCenter) {
        textPos.setY(pos.y() - textHeight / 2.0 + ascent);
    } else if (alignFlags & Qt::AlignBottom) {
        textPos.setY(pos.y() - textHeight + ascent);
    } else {
        textPos.setY(pos.y() + ascent - textHeight / 2.0);
    }
    
    QPointF imgPos = textPos + QPointF(-outlineWidth - 5.0, -ascent - outlineWidth - 5.0);
    
    if (fill.alpha() < 255) {
        painter->setOpacity(painter->opacity() * fill.alphaF());
    }
    
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->drawImage(imgPos, img);
    painter->restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Lyric Line Finder
// ─────────────────────────────────────────────────────────────────────────────

int KaraokeLyricRenderer::findActiveLineIndex(qint64 timestampMs) const
{
    if (m_cachedLines.isEmpty()) return -1;

    // Binary search for the active line spanning current timestamp
    int lo = 0;
    int hi = m_cachedLines.size() - 1;

    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;
        const auto& line = m_cachedLines[mid];
        if (timestampMs >= line.startTime && timestampMs < line.endTime) {
            return mid;
        } else if (timestampMs < line.startTime) {
            hi = mid - 1;
        } else {
            lo = mid + 1;
        }
    }

    return -1;
}

} // namespace ncktv
