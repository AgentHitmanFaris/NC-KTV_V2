#pragma once

#include <QThread>
#include <QString>
#include <QImage>
#include <atomic>
#include "../timeline/timeline_manager.h"
#include "audio_engine.h"
#include "render_engine.h"

namespace ncktv {

class RenderWorker : public QThread {
    Q_OBJECT

public:
    RenderWorker(TimelineManager* timelineManager,
                 AudioEngine* audioEngine,
                 const QString& outputPath,
                 int width,
                 int height,
                 int fps,
                 int videoBitrate,
                 int audioBitrate,
                 QObject* parent = nullptr);
    
    ~RenderWorker() override;

signals:
    void progressUpdated(double fraction);
    void statusTextChanged(const QString& text);
    void renderCompleted(const QString& outputPath, const QString& videoCodec, const QString& audioCodec);
    void renderFailed(const QString& errorMessage);

protected:
    void run() override;

private:
    void renderFrameAtTime(QImage& image, QImage& lowResImage, qint64 timeUs);

    TimelineManager* m_timelineManager = nullptr;
    AudioEngine* m_audioEngine = nullptr;
    QString m_outputPath;
    int m_width;
    int m_height;
    int m_fps;
    int m_videoBitrate;
    int m_audioBitrate;
};

} // namespace ncktv
