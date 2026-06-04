#include "audio_reader.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QCryptographicHash>
#include <QStandardPaths>
#include <QDateTime>
#include <iostream>
#include <algorithm>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
}

namespace ncktv {

bool AudioReader::decodeFile(const QString& filePath, int targetSampleRate) {
    m_samples.clear();
    m_peaks256.clear();
    m_peaks4096.clear();

    AVFormatContext* format_ctx = nullptr;
    std::string pathStr = QDir::toNativeSeparators(filePath).toStdString();
    
    // Open media file
    if (avformat_open_input(&format_ctx, pathStr.c_str(), nullptr, nullptr) < 0) {
        std::cerr << "[AudioReader] Error: Could not open file: " << pathStr << "\n";
        return false;
    }

    // Find stream info
    if (avformat_find_stream_info(format_ctx, nullptr) < 0) {
        std::cerr << "[AudioReader] Error: Could not find stream info.\n";
        avformat_close_input(&format_ctx);
        return false;
    }

    // Find best audio stream index
    int audio_stream_idx = av_find_best_stream(format_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_stream_idx < 0) {
        std::cerr << "[AudioReader] Error: No audio stream found in file.\n";
        avformat_close_input(&format_ctx);
        return false;
    }

    // Prepare decoder
    const AVCodec* codec = avcodec_find_decoder(format_ctx->streams[audio_stream_idx]->codecpar->codec_id);
    if (!codec) {
        std::cerr << "[AudioReader] Error: Unsupported audio codec.\n";
        avformat_close_input(&format_ctx);
        return false;
    }

    AVCodecContext* codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        std::cerr << "[AudioReader] Error: Could not allocate codec context.\n";
        avformat_close_input(&format_ctx);
        return false;
    }

    if (avcodec_parameters_to_context(codec_ctx, format_ctx->streams[audio_stream_idx]->codecpar) < 0) {
        std::cerr << "[AudioReader] Error: Could not transfer parameters.\n";
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        return false;
    }

    if (avcodec_open2(codec_ctx, codec, nullptr) < 0) {
        std::cerr << "[AudioReader] Error: Could not open decoder.\n";
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        return false;
    }

    // Prepare swr context for resampling to Stereo Float at target sample rate
    SwrContext* swr_ctx = nullptr;
    AVChannelLayout out_layout = AV_CHANNEL_LAYOUT_STEREO;
    
    // Ensure we handle input layouts correctly
    AVChannelLayout in_layout;
    if (codec_ctx->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC) {
        av_channel_layout_default(&in_layout, codec_ctx->ch_layout.nb_channels);
    } else {
        av_channel_layout_copy(&in_layout, &codec_ctx->ch_layout);
    }

    int ret = swr_alloc_set_opts2(&swr_ctx,
                                 &out_layout, AV_SAMPLE_FMT_FLT, targetSampleRate,
                                 &in_layout, codec_ctx->sample_fmt, codec_ctx->sample_rate,
                                 0, nullptr);
    
    av_channel_layout_uninit(&in_layout);

    if (ret < 0 || !swr_ctx || swr_init(swr_ctx) < 0) {
        std::cerr << "[AudioReader] Error: Could not initialize resampler.\n";
        if (swr_ctx) swr_free(&swr_ctx);
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        return false;
    }

    // Pre-allocate structures
    AVPacket* packet = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    if (!packet || !frame) {
        std::cerr << "[AudioReader] Error: Struct allocation failure.\n";
        if (packet) av_packet_free(&packet);
        if (frame) av_frame_free(&frame);
        swr_free(&swr_ctx);
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        return false;
    }

    // Over-estimate buffer to allocate once
    m_samples.reserve(targetSampleRate * 2 * 60 * 5); // Reserve 5 mins of space

    // Read and decode frames
    while (av_read_frame(format_ctx, packet) >= 0) {
        if (packet->stream_index == audio_stream_idx) {
            ret = avcodec_send_packet(codec_ctx, packet);
            if (ret < 0) {
                av_packet_unref(packet);
                break;
            }

            while (ret >= 0) {
                ret = avcodec_receive_frame(codec_ctx, frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    break;
                } else if (ret < 0) {
                    break;
                }

                // Check maximum resampled buffer size needed
                int out_samples = swr_get_out_samples(swr_ctx, frame->nb_samples);
                std::vector<float> resample_buf(out_samples * 2);
                
                uint8_t* out_data[1] = { reinterpret_cast<uint8_t*>(resample_buf.data()) };
                int converted = swr_convert(swr_ctx, 
                                            out_data, out_samples, 
                                            const_cast<const uint8_t**>(frame->data), frame->nb_samples);
                if (converted > 0) {
                    m_samples.insert(m_samples.end(), resample_buf.begin(), resample_buf.begin() + converted * 2);
                }
            }
        }
        av_packet_unref(packet);
    }

    // Free resources
    av_frame_free(&frame);
    av_packet_free(&packet);
    swr_free(&swr_ctx);
    avcodec_free_context(&codec_ctx);
    avformat_close_input(&format_ctx);

    m_sampleRate = targetSampleRate;
    m_channels = 2;
    m_durationSeconds = static_cast<double>(m_samples.size() / 2.0) / targetSampleRate;

    // Precompute Peak Levels for Level of Details Waveform drawing
    precomputePeaks();

    // Save precomputed peaks to cache file
    savePeakCache(filePath);

    std::cout << "[AudioReader] Successfully decoded file: " << pathStr 
              << " (" << m_durationSeconds << "s, " << m_samples.size() << " raw float samples)\n";
    return true;
}

void AudioReader::precomputePeaks() {
    m_peaks256.clear();
    m_peaks4096.clear();

    qint64 frameCount = totalSamples();
    if (frameCount == 0) {
        return;
    }

    m_peaks256.reserve(frameCount / 256 + 1);
    m_peaks4096.reserve(frameCount / 4096 + 1);

    // Compute LOD 256 peaks
    for (qint64 i = 0; i < frameCount; i += 256) {
        float minVal = 0.0f;
        float maxVal = 0.0f;
        qint64 end = (std::min)(i + 256, frameCount);
        
        for (qint64 f = i; f < end; ++f) {
            float left = m_samples[f * 2];
            float right = m_samples[f * 2 + 1];
            if (left < minVal) minVal = left;
            if (right < minVal) minVal = right;
            if (left > maxVal) maxVal = left;
            if (right > maxVal) maxVal = right;
        }
        m_peaks256.push_back({minVal, maxVal});
    }

    // Compute LOD 4096 peaks
    for (qint64 i = 0; i < frameCount; i += 4096) {
        float minVal = 0.0f;
        float maxVal = 0.0f;
        qint64 end = (std::min)(i + 4096, frameCount);
        
        for (qint64 f = i; f < end; ++f) {
            float left = m_samples[f * 2];
            float right = m_samples[f * 2 + 1];
            if (left < minVal) minVal = left;
            if (right < minVal) minVal = right;
            if (left > maxVal) maxVal = left;
            if (right > maxVal) maxVal = right;
        }
        m_peaks4096.push_back({minVal, maxVal});
    }
}

struct PeakCacheHeader {
    char magic[4] = {'N', 'C', 'P', 'K'};
    uint32_t version = 1;
    qint64 sourceFileSize = 0;
    qint64 sourceLastModified = 0;
    uint32_t numPeaks256 = 0;
    uint32_t numPeaks4096 = 0;
    int sampleRate = 48000;
    int channels = 2;
    double durationSeconds = 0.0;
};

QString AudioReader::getCachePath(const QString& filePath) const {
    // Attempt 1: Next to original file
    QString primaryPath = filePath + ".pk";
    QFileInfo fi(primaryPath);
    QDir dir = fi.dir();
    if (dir.exists()) {
        QFile file(primaryPath);
        if (file.open(QIODevice::ReadWrite)) {
            file.close();
            return primaryPath;
        }
    }
    
    // Attempt 2: Fall back to local AppData cache folder
    QString appLocal = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QString cacheDir = QDir(appLocal).filePath("cache");
    QDir().mkpath(cacheDir);
    
    QByteArray hash = QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex();
    return QDir(cacheDir).filePath(QString::fromUtf8(hash) + ".pk");
}

bool AudioReader::loadPeakCache(const QString& filePath) {
    QString cachePath = getCachePath(filePath);
    QFile file(cachePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    QFileInfo sourceInfo(filePath);
    if (!sourceInfo.exists()) {
        return false;
    }
    qint64 expectedSize = sourceInfo.size();
    qint64 expectedMod = sourceInfo.lastModified().toMSecsSinceEpoch();

    PeakCacheHeader header;
    if (file.read(reinterpret_cast<char*>(&header), sizeof(header)) != sizeof(header)) {
        return false;
    }

    if (std::strncmp(header.magic, "NCPK", 4) != 0 ||
        header.version != 1 ||
        header.sourceFileSize != expectedSize ||
        header.sourceLastModified != expectedMod) {
        return false;
    }

    m_peaks256.resize(header.numPeaks256);
    if (file.read(reinterpret_cast<char*>(m_peaks256.data()), header.numPeaks256 * sizeof(Peak)) != static_cast<qint64>(header.numPeaks256 * sizeof(Peak))) {
        m_peaks256.clear();
        return false;
    }

    m_peaks4096.resize(header.numPeaks4096);
    if (file.read(reinterpret_cast<char*>(m_peaks4096.data()), header.numPeaks4096 * sizeof(Peak)) != static_cast<qint64>(header.numPeaks4096 * sizeof(Peak))) {
        m_peaks256.clear();
        m_peaks4096.clear();
        return false;
    }

    m_sampleRate = header.sampleRate;
    m_channels = header.channels;
    m_durationSeconds = header.durationSeconds;
    m_samples.clear(); // Loaded in background

    std::cout << "[AudioReader] Peak cache loaded successfully from: " << cachePath.toStdString() << "\n";
    return true;
}

bool AudioReader::savePeakCache(const QString& filePath) {
    if (m_peaks256.empty() || m_peaks4096.empty()) {
        return false;
    }

    QString cachePath = getCachePath(filePath);
    QFile file(cachePath);
    if (!file.open(QIODevice::WriteOnly)) {
        std::cerr << "[AudioReader] Warning: Could not open peak cache for writing at: " << cachePath.toStdString() << "\n";
        return false;
    }

    QFileInfo sourceInfo(filePath);
    if (!sourceInfo.exists()) {
        return false;
    }

    PeakCacheHeader header;
    std::memcpy(header.magic, "NCPK", 4);
    header.version = 1;
    header.sourceFileSize = sourceInfo.size();
    header.sourceLastModified = sourceInfo.lastModified().toMSecsSinceEpoch();
    header.numPeaks256 = static_cast<uint32_t>(m_peaks256.size());
    header.numPeaks4096 = static_cast<uint32_t>(m_peaks4096.size());
    header.sampleRate = m_sampleRate;
    header.channels = m_channels;
    header.durationSeconds = m_durationSeconds;

    if (file.write(reinterpret_cast<const char*>(&header), sizeof(header)) != sizeof(header)) {
        return false;
    }

    if (file.write(reinterpret_cast<const char*>(m_peaks256.data()), m_peaks256.size() * sizeof(Peak)) != static_cast<qint64>(m_peaks256.size() * sizeof(Peak))) {
        return false;
    }

    if (file.write(reinterpret_cast<const char*>(m_peaks4096.data()), m_peaks4096.size() * sizeof(Peak)) != static_cast<qint64>(m_peaks4096.size() * sizeof(Peak))) {
        return false;
    }

    std::cout << "[AudioReader] Peak cache saved successfully to: " << cachePath.toStdString() << "\n";
    return true;
}

} // namespace ncktv
