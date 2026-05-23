#include "render_worker.h"
#include <QPainter>
#include <QPainterPath>
#include <QFont>
#include <QFontMetrics>
#include <QColor>
#include <QLinearGradient>
#include <QRadialGradient>
#include <QRect>
#include <QDebug>
#include <cmath>
#include <vector>
#include <algorithm>

namespace ncktv {

RenderWorker::RenderWorker(TimelineManager* timelineManager,
                           AudioEngine* audioEngine,
                           const QString& outputPath,
                           int width,
                           int height,
                           int fps,
                           int videoBitrate,
                           int audioBitrate,
                           QObject* parent)
    : QThread(parent),
      m_timelineManager(timelineManager),
      m_audioEngine(audioEngine),
      m_outputPath(outputPath),
      m_width(width),
      m_height(height),
      m_fps(fps),
      m_videoBitrate(videoBitrate),
      m_audioBitrate(audioBitrate) {
}

RenderWorker::~RenderWorker() {
    if (isRunning()) {
        requestInterruption();
        wait();
    }
}

void RenderWorker::run() {
    emit statusTextChanged("Preparing render engine...");
    emit progressUpdated(0.0);

    qint64 totalDuration = m_timelineManager->totalDuration();
    if (totalDuration <= 0) {
        emit renderFailed("Timeline is empty. Cannot export a project with zero duration.");
        return;
    }

    int64_t totalFrames = (totalDuration * m_fps) / 1000000;
    if (totalFrames <= 0) {
        totalFrames = 1;
    }

    RenderEngine engine;
    if (!engine.startRender(m_outputPath, m_width, m_height, m_fps, m_videoBitrate, m_audioBitrate)) {
        emit renderFailed("Could not initialize FFmpeg render engine. Check file path or codec permissions.");
        return;
    }

    emit statusTextChanged(QString("Rendering with codec: %1...").arg(engine.chosenVideoCodec()));

    double audioSamplePlayhead = 0.0;
    bool success = true;

    // Pre-allocate a single persistent canvas buffer to eliminate megabytes of heap allocation per frame
    QImage frameImage(m_width, m_height, QImage::Format_RGBA8888);
    int lowW = std::max(60, m_width / 8);
    int lowH = std::max(34, m_height / 8);
    QImage lowResImage(lowW, lowH, QImage::Format_RGBA8888);

    for (int64_t frameIdx = 0; frameIdx < totalFrames; ++frameIdx) {
        if (isInterruptionRequested()) {
            success = false;
            break;
        }

        // Calculate timecode in microseconds for the current frame
        qint64 frameTimeUs = (frameIdx * 1000000) / m_fps;

        // 1. Render Video frame into persistent canvas
        renderFrameAtTime(frameImage, lowResImage, frameTimeUs);
        if (!engine.writeVideoFrame(frameImage, frameIdx)) {
            emit renderFailed("Failed to encode video frame. Export aborted.");
            return;
        }

        // 2. Mix sample-accurate Audio frame
        double nextAudioSamplePlayhead = (static_cast<double>(frameIdx + 1) * 48000.0) / m_fps;
        int samplesToMix = static_cast<int>(std::round(nextAudioSamplePlayhead)) - static_cast<int>(std::round(audioSamplePlayhead));
        
        if (samplesToMix > 0) {
            std::vector<float> mixBuffer(samplesToMix * 2, 0.0f);
            m_audioEngine->mixOffline(mixBuffer.data(), samplesToMix, static_cast<qint64>(std::round(audioSamplePlayhead)));
            if (!engine.writeAudioFrame(mixBuffer.data(), samplesToMix)) {
                emit renderFailed("Failed to encode audio stream. Export aborted.");
                return;
            }
        }
        audioSamplePlayhead = nextAudioSamplePlayhead;

        // 3. Emit progress updates (throttle to every 10 frames to avoid GUI thread saturation)
        if (frameIdx % 10 == 0 || frameIdx == totalFrames - 1) {
            double progressFraction = static_cast<double>(frameIdx + 1) / static_cast<double>(totalFrames);
            emit progressUpdated(progressFraction);
            emit statusTextChanged(QString("Encoding frame %1 of %2 (%3%)")
                                   .arg(frameIdx + 1)
                                   .arg(totalFrames)
                                   .arg(static_cast<int>(progressFraction * 100)));
        }
    }

    if (success) {
        emit statusTextChanged("Flushing buffers and closing container...");
        if (engine.finishRender()) {
            emit progressUpdated(1.0);
            emit statusTextChanged("Export completed successfully!");
            emit renderCompleted(m_outputPath, engine.chosenVideoCodec(), engine.chosenAudioCodec());
        } else {
            emit renderFailed("Failed to flush FFmpeg buffers. Output file might be corrupted.");
        }
    } else {
        emit renderFailed("Render cancelled by user.");
    }
}

void RenderWorker::renderFrameAtTime(QImage& image, QImage& lowResImage, qint64 timeUs) {
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::TextAntialiasing);

    // 1. Render slate background gradient and ambient glows on the persistent low-res canvas
    int lowW = lowResImage.width();
    int lowH = lowResImage.height();
    {
        QPainter lowPainter(&lowResImage);
        lowPainter.setRenderHint(QPainter::Antialiasing);

        QLinearGradient bgGradient(0, 0, lowW, lowH);
        bgGradient.setColorAt(0.0, QColor("#080711"));
        bgGradient.setColorAt(0.5, QColor("#120d24"));
        bgGradient.setColorAt(1.0, QColor("#040308"));
        lowPainter.fillRect(lowResImage.rect(), bgGradient);

        double phase = static_cast<double>(timeUs) / 1000000.0;
        
        // Slow moving glow 1
        int cx1 = static_cast<int>(lowW * (0.3 + 0.1 * std::sin(phase * 0.5)));
        int cy1 = static_cast<int>(lowH * (0.4 + 0.1 * std::cos(phase * 0.7)));
        QRadialGradient glow1(cx1, cy1, lowW * 0.4);
        glow1.setColorAt(0.0, QColor(99, 102, 241, 20)); // Indigo soft glow
        glow1.setColorAt(1.0, QColor(0, 0, 0, 0));
        lowPainter.fillRect(lowResImage.rect(), glow1);

        // Slow moving glow 2
        int cx2 = static_cast<int>(lowW * (0.7 + 0.15 * std::cos(phase * 0.6)));
        int cy2 = static_cast<int>(lowH * (0.6 + 0.08 * std::sin(phase * 0.4)));
        QRadialGradient glow2(cx2, cy2, lowW * 0.35);
        glow2.setColorAt(0.0, QColor(236, 72, 153, 16)); // Pink soft glow
        glow2.setColorAt(1.0, QColor(0, 0, 0, 0));
        lowPainter.fillRect(lowResImage.rect(), glow2);
    }

    // Upscale the soft background using smooth bilinear scaling
    painter.drawImage(image.rect(), lowResImage);

    // 2. Draw NC-KTV watermark (crisp full-resolution text)
    painter.setFont(QFont("Arial", 16, QFont::Medium));
    painter.setPen(QColor(255, 255, 255, 60)); // Subtle watermark
    painter.drawText(QRect(50, 50, 300, 50), Qt::AlignLeft | Qt::AlignVCenter, "NC-KTV Studio");

    // 3. Find active lyric clip
    Clip* activeClip = nullptr;
    for (Track* track : m_timelineManager->trackListModel()->tracks()) {
        if (track->trackType() == Track::Lyrics) {
            for (Clip* clip : track->clips()) {
                if (timeUs >= clip->startTime() && timeUs < clip->endTime()) {
                    activeClip = clip;
                    break;
                }
            }
        }
        if (activeClip) break;
    }

    if (activeClip) {
        QVariantList syllables = activeClip->syllables();
        if (!syllables.isEmpty()) {
            int fontSize = m_height / 18; // Size scaled relative to resolution
            QFont lyricFont("Arial", fontSize, QFont::Bold);
            painter.setFont(lyricFont);
            QFontMetrics fm(lyricFont);

            // Lay out syllables to compute metrics
            struct SylLayout {
                QString text;
                qint64 relativeStart;
                qint64 duration;
                int width;
                int xStart;
            };
            std::vector<SylLayout> layouts;
            int accumulatedWidth = 0;
            for (const QVariant& var : syllables) {
                QVariantMap map = var.toMap();
                SylLayout item;
                item.text = map["text"].toString();
                item.relativeStart = map["relativeStart"].toLongLong();
                item.duration = map["duration"].toLongLong();
                item.width = fm.horizontalAdvance(item.text);
                item.xStart = accumulatedWidth;
                accumulatedWidth += item.width;
                layouts.push_back(item);
            }

            int totalWidth = accumulatedWidth;
            int startX = (m_width - totalWidth) / 2;
            int textY = static_cast<int>(m_height * 0.75);

            // Draw translucent backing rounded card to protect legibility
            int paddingX = 40;
            int paddingY = 20;
            QRect backdropRect(startX - paddingX, textY - fm.ascent() - paddingY, totalWidth + paddingX * 2, fm.height() + paddingY * 2);
            painter.setBrush(QColor(15, 23, 42, 160)); // Translucent dark card
            painter.setPen(Qt::NoPen);
            painter.drawRoundedRect(backdropRect, 16, 16);

            // Create path representing the full sentence
            QPainterPath phrasePath;
            int currX = startX;
            for (const auto& item : layouts) {
                phrasePath.addText(currX, textY, lyricFont, item.text);
                currX += item.width;
            }

            // Draw standard inactive text outline (strokes a black frame first)
            QPen outlinePen(QColor("#020617"));
            outlinePen.setWidth(6);
            outlinePen.setCapStyle(Qt::RoundCap);
            outlinePen.setJoinStyle(Qt::RoundJoin);
            painter.strokePath(phrasePath, outlinePen);
            painter.fillPath(phrasePath, QColor("#E2E8F0")); // Sleek light-slate white

            // Draw swept active neon sweeps
            qint64 relativeClipTime = timeUs - activeClip->startTime();
            for (const auto& item : layouts) {
                double sweepFraction = 0.0;
                if (relativeClipTime >= item.relativeStart + item.duration) {
                    sweepFraction = 1.0;
                } else if (relativeClipTime <= item.relativeStart) {
                    sweepFraction = 0.0;
                } else {
                    sweepFraction = static_cast<double>(relativeClipTime - item.relativeStart) / item.duration;
                }

                if (sweepFraction > 0.0) {
                    int sylStartX = startX + item.xStart;
                    int sweepWidth = static_cast<int>(item.width * sweepFraction);

                    painter.save();
                    // Set clipping bounds to mask active sweep portion precisely
                    painter.setClipRect(sylStartX, textY - fm.ascent() - 20, sweepWidth, fm.height() + 40);

                    QPainterPath sylPath;
                    sylPath.addText(sylStartX, textY, lyricFont, item.text);

                    // Underlay neon green glow drop shadow
                    QPen glowPen(QColor(34, 197, 94, 120));
                    glowPen.setWidth(8);
                    glowPen.setCapStyle(Qt::RoundCap);
                    glowPen.setJoinStyle(Qt::RoundJoin);
                    painter.strokePath(sylPath, glowPen);

                    // Middle dark separation outline
                    QPen separatorPen(QColor(0, 0, 0));
                    separatorPen.setWidth(4);
                    separatorPen.setCapStyle(Qt::RoundCap);
                    separatorPen.setJoinStyle(Qt::RoundJoin);
                    painter.strokePath(sylPath, separatorPen);

                    // Fill active text with glowing gradient
                    QLinearGradient activeGrad(sylStartX, 0, sylStartX + item.width, 0);
                    activeGrad.setColorAt(0.0, QColor("#22C55E")); // Bright Neon Green
                    activeGrad.setColorAt(1.0, QColor("#06B6D4")); // Neon Cyan
                    painter.fillPath(sylPath, activeGrad);

                    painter.restore();
                }
            }
        }
    }
}

} // namespace ncktv
