#pragma once

#include <QString>
#include <QImage>
#include <vector>
#include <string>

// FFmpeg forward declarations
struct AVFormatContext;
struct AVCodecContext;
struct AVStream;
struct AVFrame;
struct SwsContext;
struct SwrContext;
struct AVPacket;

namespace ncktv {

class RenderEngine {
public:
    RenderEngine();
    ~RenderEngine();

    // Initializes the format context and open codecs
    bool startRender(const QString& outputPath, int width, int height, int fps, int videoBitrate, int audioBitrate);

    // Encodes a single video frame (takes a QImage, scales it to YUV420p)
    bool writeVideoFrame(const QImage& frameImage, int64_t frameIndex);

    // Decodes/resamples offline mixed audio float stream and writes to the AAC stream
    bool writeAudioFrame(const float* stereoSamples, int numFrames);

    // Flushes encoders, writes the trailer, and closes files
    bool finishRender();

    [[nodiscard]] QString chosenVideoCodec() const { return m_chosenVideoCodec; }
    [[nodiscard]] QString chosenAudioCodec() const { return m_chosenAudioCodec; }

private:
    bool initVideoEncoding(int width, int height, int fps, int bitrate);
    bool initAudioEncoding(int bitrate);
    bool writePacket(AVPacket* pkt, int streamIndex);
    void cleanup();

    QString m_chosenVideoCodec;
    QString m_chosenAudioCodec;

    AVFormatContext* m_fmtCtx = nullptr;
    
    // Video elements
    AVCodecContext* m_videoCodecCtx = nullptr;
    AVStream* m_videoStream = nullptr;
    AVFrame* m_videoFrame = nullptr;
    SwsContext* m_swsCtx = nullptr;
    int m_width = 1920;
    int m_height = 1080;
    int m_fps = 30;

    // Audio elements
    AVCodecContext* m_audioCodecCtx = nullptr;
    AVStream* m_audioStream = nullptr;
    AVFrame* m_audioFrame = nullptr;
    SwrContext* m_swrCtx = nullptr;
    int64_t m_nextAudioPts = 0;

    // Local accumulation buffer for AAC frames (AAC requires fixed frame size, typically 1024)
    std::vector<float> m_audioInputBuffer;
};

} // namespace ncktv
