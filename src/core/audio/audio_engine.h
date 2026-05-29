#pragma once

#include <QObject>
#include <QMap>
#include <QTimer>
#include <atomic>
#include "audio_reader.h"
#include "../timeline/timeline_manager.h"
#include <miniaudio.h>

namespace ncktv {

class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isPlaying READ isPlaying WRITE setIsPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(float masterVolume READ masterVolume WRITE setMasterVolume NOTIFY masterVolumeChanged)

public:
    explicit AudioEngine(TimelineManager* timelineManager, QObject* parent = nullptr);
    virtual ~AudioEngine() override;

    // Singleton access for visual waveform components to query loaded sample buffers
    static AudioEngine* instance();

    [[nodiscard]] bool isPlaying() const { return m_isPlaying; }
    void setIsPlaying(bool playing);

    [[nodiscard]] float masterVolume() const { return m_masterVolume; }
    void setMasterVolume(float vol);

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();

    // Cache management
    Q_INVOKABLE void preloadFile(const QString& filePath);
    Q_INVOKABLE void clearCache();

    // Returns loaded reader or nullptr
    Q_INVOKABLE ncktv::AudioReader* getReader(const QString& filePath) const;

    // For unit testing mixing and gain smoothing
    void setCachedReaderForTesting(const QString& filePath, AudioReader* reader) {
        if (m_audioCache.contains(filePath)) {
            delete m_audioCache.take(filePath);
        }
        m_audioCache[filePath] = reader;
    }

    // Real-time mixing callback (thread-safe, lock-free, called by miniaudio device)
    void mixAudio(float* pOutput, unsigned int frameCount);
    void mixOffline(float* pOutput, unsigned int frameCount, qint64 startSample);

signals:
    void isPlayingChanged();
    void masterVolumeChanged();

private slots:
    void updatePlayheadFromAudio();

private:
    static AudioEngine* s_instance;

    TimelineManager* m_timelineManager = nullptr;
    
    // miniaudio device struct
    ma_device m_device;
    bool m_deviceInitialized = false;

    // Playback control states
    std::atomic<bool> m_isPlaying{false};
    std::atomic<qint64> m_playbackSample{0}; // Playhead position in samples
    
    QTimer* m_syncTimer = nullptr;
    
    // Decoded audio cache
    QMap<QString, AudioReader*> m_audioCache;

    // Tracks volume state map for smoothing
    QMap<QString, float> m_prevVolumes;

    float m_masterVolume = 1.0f;
};

} // namespace ncktv
