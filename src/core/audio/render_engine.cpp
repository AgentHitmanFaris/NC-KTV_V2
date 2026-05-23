#include "render_engine.h"
#include <iostream>
#include <algorithm>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/imgutils.h>
#include <libavutil/channel_layout.h>
}

namespace ncktv {

RenderEngine::RenderEngine() = default;

RenderEngine::~RenderEngine() {
    cleanup();
}

bool RenderEngine::startRender(const QString& outputPath, int width, int height, int fps, int videoBitrate, int audioBitrate) {
    cleanup();

    m_width = width;
    m_height = height;
    m_fps = fps;

    std::string outStr = outputPath.toStdString();
    
    // Allocate the output format context for MP4 container
    int ret = avformat_alloc_output_context2(&m_fmtCtx, nullptr, nullptr, outStr.c_str());
    if (ret < 0 || !m_fmtCtx) {
        std::cerr << "[RenderEngine] Error: Could not allocate output context. Code " << ret << "\n";
        return false;
    }

    // Initialize Video stream and encoder
    if (!initVideoEncoding(width, height, fps, videoBitrate)) {
        std::cerr << "[RenderEngine] Error: Video encoding initialization failed.\n";
        cleanup();
        return false;
    }

    // Initialize Audio stream and encoder
    if (!initAudioEncoding(audioBitrate)) {
        std::cerr << "[RenderEngine] Error: Audio encoding initialization failed.\n";
        cleanup();
        return false;
    }

    // Open the output file for writing
    if (!(m_fmtCtx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&m_fmtCtx->pb, outStr.c_str(), AVIO_FLAG_WRITE);
        if (ret < 0) {
            std::cerr << "[RenderEngine] Error: Could not open output file: " << outStr << ". Code " << ret << "\n";
            cleanup();
            return false;
        }
    }

    // Write container header
    ret = avformat_write_header(m_fmtCtx, nullptr);
    if (ret < 0) {
        std::cerr << "[RenderEngine] Error: Could not write container header. Code " << ret << "\n";
        cleanup();
        return false;
    }

    std::cout << "[RenderEngine] Muxing started successfully to: " << outStr << "\n";
    return true;
}

bool RenderEngine::initVideoEncoding(int width, int height, int fps, int bitrate) {
    // 1. Dynamic Hardware Cascade Probe
    const char* codecs[] = { "h264_nvenc", "h264_amf", "h264_qsv", "libx264" };
    const AVCodec* video_codec = nullptr;
    
    for (const char* name : codecs) {
        video_codec = avcodec_find_encoder_by_name(name);
        if (video_codec) {
            m_chosenVideoCodec = name;
            std::cout << "[RenderEngine] Selected hardware H.264 encoder: " << name << "\n";
            break;
        }
    }

    if (!video_codec) {
        // Ultimate fallback
        video_codec = avcodec_find_encoder(AV_CODEC_ID_H264);
        if (video_codec) {
            m_chosenVideoCodec = video_codec->name;
        }
    }

    if (!video_codec) {
        std::cerr << "[RenderEngine] Error: No H.264 encoder found on this system.\n";
        return false;
    }

    // Allocate Video stream inside the format context
    m_videoStream = avformat_new_stream(m_fmtCtx, nullptr);
    if (!m_videoStream) {
        return false;
    }
    m_videoStream->id = m_fmtCtx->nb_streams - 1;

    m_videoCodecCtx = avcodec_alloc_context3(video_codec);
    if (!m_videoCodecCtx) {
        return false;
    }

    m_videoCodecCtx->codec_id = AV_CODEC_ID_H264;
    m_videoCodecCtx->width = width;
    m_videoCodecCtx->height = height;
    m_videoCodecCtx->time_base = { 1, fps };
    m_videoCodecCtx->framerate = { fps, 1 };
    m_videoCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P; // Standard compatible format
    m_videoCodecCtx->bit_rate = bitrate;
    m_videoCodecCtx->gop_size = 12;
    m_videoCodecCtx->max_b_frames = 2;

    if (m_fmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
        m_videoCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    // Set hardware preset flags for NVENC/AMF if applicable
    if (m_chosenVideoCodec.contains("nvenc")) {
        av_opt_set(m_videoCodecCtx->priv_data, "preset", "p4", 0); // Medium speed preset
        av_opt_set(m_videoCodecCtx->priv_data, "tune", "hq", 0);
    } else if (m_chosenVideoCodec.contains("libx264")) {
        av_opt_set(m_videoCodecCtx->priv_data, "preset", "medium", 0);
    }

    int ret = avcodec_open2(m_videoCodecCtx, video_codec, nullptr);
    if (ret < 0) {
        std::cerr << "[RenderEngine] Error: Could not open video encoder. Code " << ret << "\n";
        return false;
    }

    // Link stream parameters
    ret = avcodec_parameters_from_context(m_videoStream->codecpar, m_videoCodecCtx);
    if (ret < 0) return false;

    m_videoStream->time_base = m_videoCodecCtx->time_base;

    // Allocate YUV420P frame buffer
    m_videoFrame = av_frame_alloc();
    if (!m_videoFrame) return false;

    m_videoFrame->format = m_videoCodecCtx->pix_fmt;
    m_videoFrame->width = m_videoCodecCtx->width;
    m_videoFrame->height = m_videoCodecCtx->height;

    ret = av_image_alloc(m_videoFrame->data, m_videoFrame->linesize, width, height, m_videoCodecCtx->pix_fmt, 32);
    if (ret < 0) {
        std::cerr << "[RenderEngine] Error: Could not allocate raw video frame buffers.\n";
        return false;
    }

    // SwsScale context: Converts from QML raw format (QImage::Format_ARGB32 -> AV_PIX_FMT_BGRA/AV_PIX_FMT_RGBA) to YUV420P
    m_swsCtx = sws_getContext(width, height, AV_PIX_FMT_RGBA,
                              width, height, m_videoCodecCtx->pix_fmt,
                              SWS_POINT, nullptr, nullptr, nullptr);
    if (!m_swsCtx) return false;

    return true;
}

bool RenderEngine::initAudioEncoding(int bitrate) {
    const AVCodec* audio_codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!audio_codec) {
        std::cerr << "[RenderEngine] Error: AAC audio encoder not found.\n";
        return false;
    }

    m_chosenAudioCodec = audio_codec->name;

    m_audioStream = avformat_new_stream(m_fmtCtx, nullptr);
    if (!m_audioStream) return false;
    m_audioStream->id = m_fmtCtx->nb_streams - 1;

    m_audioCodecCtx = avcodec_alloc_context3(audio_codec);
    if (!m_audioCodecCtx) return false;

    m_audioCodecCtx->codec_id = AV_CODEC_ID_AAC;
    m_audioCodecCtx->sample_rate = 48000;
    m_audioCodecCtx->sample_fmt = AV_SAMPLE_FMT_FLTP; // Float Planar
    m_audioCodecCtx->bit_rate = bitrate;
    
    AVChannelLayout out_layout;
    av_channel_layout_default(&out_layout, 2);
    m_audioCodecCtx->ch_layout = out_layout;
    m_audioCodecCtx->time_base = { 1, 48000 };

    if (m_fmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
        m_audioCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    int ret = avcodec_open2(m_audioCodecCtx, audio_codec, nullptr);
    if (ret < 0) {
        std::cerr << "[RenderEngine] Error: Could not open AAC encoder. Code " << ret << "\n";
        return false;
    }

    ret = avcodec_parameters_from_context(m_audioStream->codecpar, m_audioCodecCtx);
    if (ret < 0) return false;

    m_audioStream->time_base = m_audioCodecCtx->time_base;

    // Allocate audio frame structure
    m_audioFrame = av_frame_alloc();
    if (!m_audioFrame) return false;

    m_audioFrame->nb_samples = m_audioCodecCtx->frame_size > 0 ? m_audioCodecCtx->frame_size : 1024;
    m_audioFrame->format = m_audioCodecCtx->sample_fmt;
    m_audioFrame->ch_layout = m_audioCodecCtx->ch_layout;
    m_audioFrame->sample_rate = m_audioCodecCtx->sample_rate;

    ret = av_frame_get_buffer(m_audioFrame, 0);
    if (ret < 0) {
        std::cerr << "[RenderEngine] Error: Could not allocate audio frame buffers.\n";
        return false;
    }

    // Configure SwrContext (Converts interleaved Float to planar Float planar)
    AVChannelLayout in_layout;
    av_channel_layout_default(&in_layout, 2);
    ret = swr_alloc_set_opts2(&m_swrCtx,
                             &m_audioCodecCtx->ch_layout, m_audioCodecCtx->sample_fmt, m_audioCodecCtx->sample_rate,
                             &in_layout, AV_SAMPLE_FMT_FLT, 48000,
                             0, nullptr);
    if (ret < 0 || !m_swrCtx) return false;

    ret = swr_init(m_swrCtx);
    if (ret < 0) return false;

    m_nextAudioPts = 0;
    m_audioInputBuffer.clear();

    return true;
}

bool RenderEngine::writeVideoFrame(const QImage& frameImage, int64_t frameIndex) {
    if (!m_videoCodecCtx || !m_videoFrame || !m_swsCtx) return false;

    const QImage* imgPtr = &frameImage;
    QImage tempImg;
    if (frameImage.format() != QImage::Format_RGBA8888) {
        tempImg = frameImage.convertToFormat(QImage::Format_RGBA8888);
        imgPtr = &tempImg;
    }
    
    // Scale and convert from RGBA to YUV420P
    const uint8_t* srcSlice[1] = { imgPtr->constBits() };
    int srcStride[1] = { static_cast<int>(imgPtr->bytesPerLine()) };

    sws_scale(m_swsCtx, srcSlice, srcStride, 0, m_height, m_videoFrame->data, m_videoFrame->linesize);

    m_videoFrame->pts = frameIndex;

    // Send the frame to the encoder
    int ret = avcodec_send_frame(m_videoCodecCtx, m_videoFrame);
    if (ret < 0) {
        std::cerr << "[RenderEngine] Error sending video frame for encoding. Code " << ret << "\n";
        return false;
    }

    AVPacket* pkt = av_packet_alloc();
    if (!pkt) return false;

    while (ret >= 0) {
        ret = avcodec_receive_packet(m_videoCodecCtx, pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            break;
        } else if (ret < 0) {
            std::cerr << "[RenderEngine] Video encoding error. Code " << ret << "\n";
            av_packet_free(&pkt);
            return false;
        }

        // Rescale packet timestamps to stream base
        av_packet_rescale_ts(pkt, m_videoCodecCtx->time_base, m_videoStream->time_base);
        pkt->stream_index = m_videoStream->index;

        if (!writePacket(pkt, m_videoStream->index)) {
            av_packet_free(&pkt);
            return false;
        }
    }

    av_packet_free(&pkt);
    return true;
}

bool RenderEngine::writeAudioFrame(const float* stereoSamples, int numFrames) {
    if (!m_audioCodecCtx || !m_audioFrame || !m_swrCtx) return false;

    // Store incoming samples (stereo, interleaved)
    m_audioInputBuffer.insert(m_audioInputBuffer.end(), stereoSamples, stereoSamples + numFrames * 2);

    int targetFrameSize = m_audioFrame->nb_samples;
    AVPacket* pkt = av_packet_alloc();
    if (!pkt) return false;

    // Process all full accumulated frames
    while (static_cast<int>(m_audioInputBuffer.size() / 2) >= targetFrameSize) {
        std::vector<float> chunk(m_audioInputBuffer.begin(), m_audioInputBuffer.begin() + targetFrameSize * 2);
        m_audioInputBuffer.erase(m_audioInputBuffer.begin(), m_audioInputBuffer.begin() + targetFrameSize * 2);

        // Make sure audio frame is writable
        av_frame_make_writable(m_audioFrame);

        // Resample/convert Float (Interleaved) to Float Planar
        const uint8_t* in_data[1] = { reinterpret_cast<const uint8_t*>(chunk.data()) };
        int ret = swr_convert(m_swrCtx, m_audioFrame->data, targetFrameSize, in_data, targetFrameSize);
        if (ret < 0) {
            std::cerr << "[RenderEngine] SwrConvert failed. Code " << ret << "\n";
            av_packet_free(&pkt);
            return false;
        }

        m_audioFrame->pts = m_nextAudioPts;
        m_nextAudioPts += targetFrameSize;

        // Send to AAC encoder
        ret = avcodec_send_frame(m_audioCodecCtx, m_audioFrame);
        if (ret < 0) {
            std::cerr << "[RenderEngine] Error sending audio frame to encoder. Code " << ret << "\n";
            av_packet_free(&pkt);
            return false;
        }

        while (ret >= 0) {
            ret = avcodec_receive_packet(m_audioCodecCtx, pkt);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                break;
            } else if (ret < 0) {
                std::cerr << "[RenderEngine] Audio encoding error. Code " << ret << "\n";
                av_packet_free(&pkt);
                return false;
            }

            av_packet_rescale_ts(pkt, m_audioCodecCtx->time_base, m_audioStream->time_base);
            pkt->stream_index = m_audioStream->index;

            if (!writePacket(pkt, m_audioStream->index)) {
                av_packet_free(&pkt);
                return false;
            }
        }
    }

    av_packet_free(&pkt);
    return true;
}

bool RenderEngine::finishRender() {
    if (!m_fmtCtx) return false;

    // 1. Flush Video Encoder
    if (m_videoCodecCtx) {
        avcodec_send_frame(m_videoCodecCtx, nullptr);
        AVPacket* pkt = av_packet_alloc();
        if (pkt) {
            int ret = 0;
            while (ret >= 0) {
                ret = avcodec_receive_packet(m_videoCodecCtx, pkt);
                if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN)) break;
                av_packet_rescale_ts(pkt, m_videoCodecCtx->time_base, m_videoStream->time_base);
                pkt->stream_index = m_videoStream->index;
                writePacket(pkt, m_videoStream->index);
            }
            av_packet_free(&pkt);
        }
    }

    // 2. Flush remaining buffer and Audio Encoder
    if (m_audioCodecCtx && m_swrCtx) {
        // If there are still left-over samples in the buffer, pad with zeros and write them out
        int remainingFrames = m_audioInputBuffer.size() / 2;
        if (remainingFrames > 0) {
            int targetFrameSize = m_audioFrame->nb_samples;
            int paddingFrames = targetFrameSize - remainingFrames;
            m_audioInputBuffer.insert(m_audioInputBuffer.end(), paddingFrames * 2, 0.0f);
            
            av_frame_make_writable(m_audioFrame);
            const uint8_t* in_data[1] = { reinterpret_cast<const uint8_t*>(m_audioInputBuffer.data()) };
            swr_convert(m_swrCtx, m_audioFrame->data, targetFrameSize, in_data, targetFrameSize);
            
            m_audioFrame->pts = m_nextAudioPts;
            m_nextAudioPts += targetFrameSize;
            
            avcodec_send_frame(m_audioCodecCtx, m_audioFrame);
            AVPacket* pkt = av_packet_alloc();
            if (pkt) {
                int ret = 0;
                while (ret >= 0) {
                    ret = avcodec_receive_packet(m_audioCodecCtx, pkt);
                    if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN)) break;
                    av_packet_rescale_ts(pkt, m_audioCodecCtx->time_base, m_audioStream->time_base);
                    pkt->stream_index = m_audioStream->index;
                    writePacket(pkt, m_audioStream->index);
                }
                av_packet_free(&pkt);
            }
        }

        // Flush the audio encoder
        avcodec_send_frame(m_audioCodecCtx, nullptr);
        AVPacket* pkt = av_packet_alloc();
        if (pkt) {
            int ret = 0;
            while (ret >= 0) {
                ret = avcodec_receive_packet(m_audioCodecCtx, pkt);
                if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN)) break;
                av_packet_rescale_ts(pkt, m_audioCodecCtx->time_base, m_audioStream->time_base);
                pkt->stream_index = m_audioStream->index;
                writePacket(pkt, m_audioStream->index);
            }
            av_packet_free(&pkt);
        }
    }

    // Write final MP4 trailer
    av_write_trailer(m_fmtCtx);

    std::cout << "[RenderEngine] Render finished successfully.\n";
    cleanup();
    return true;
}

bool RenderEngine::writePacket(AVPacket* pkt, int streamIndex) {
    (void)streamIndex;
    int ret = av_interleaved_write_frame(m_fmtCtx, pkt);
    return ret >= 0;
}

void RenderEngine::cleanup() {
    if (m_swsCtx) {
        sws_freeContext(m_swsCtx);
        m_swsCtx = nullptr;
    }

    if (m_videoFrame) {
        if (m_videoFrame->data[0]) {
            av_freep(&m_videoFrame->data[0]);
        }
        av_frame_free(&m_videoFrame);
        m_videoFrame = nullptr;
    }

    if (m_videoCodecCtx) {
        avcodec_free_context(&m_videoCodecCtx);
        m_videoCodecCtx = nullptr;
    }

    if (m_audioFrame) {
        av_frame_free(&m_audioFrame);
        m_audioFrame = nullptr;
    }

    if (m_audioCodecCtx) {
        avcodec_free_context(&m_audioCodecCtx);
        m_audioCodecCtx = nullptr;
    }

    if (m_swrCtx) {
        swr_free(&m_swrCtx);
        m_swrCtx = nullptr;
    }

    if (m_fmtCtx) {
        if (!(m_fmtCtx->oformat->flags & AVFMT_NOFILE) && m_fmtCtx->pb) {
            avio_closep(&m_fmtCtx->pb);
        }
        avformat_free_context(m_fmtCtx);
        m_fmtCtx = nullptr;
    }

    m_audioInputBuffer.clear();
}

} // namespace ncktv
