#include "stem_resampler.h"
#include <iostream>

extern "C" {
#include <libswresample/swresample.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
}

namespace ncktv {

std::vector<float> StemResampler::resample(const std::vector<float>& inputSamples, int inRate, int outRate, int channels) {
    if (inputSamples.empty()) return {};
    if (inRate == outRate) return inputSamples;

    AVChannelLayout in_layout;
    av_channel_layout_default(&in_layout, channels);
    AVChannelLayout out_layout;
    av_channel_layout_default(&out_layout, channels);

    SwrContext* swr_ctx = nullptr;
    int ret = swr_alloc_set_opts2(&swr_ctx,
                                 &out_layout, AV_SAMPLE_FMT_FLT, outRate,
                                 &in_layout, AV_SAMPLE_FMT_FLT, inRate,
                                 0, nullptr);

    av_channel_layout_uninit(&in_layout);
    av_channel_layout_uninit(&out_layout);

    if (ret < 0 || !swr_ctx) {
        std::cerr << "[StemResampler] Error: swr_alloc_set_opts2 failed with code " << ret << "\n";
        return {};
    }

    if (swr_init(swr_ctx) < 0) {
        std::cerr << "[StemResampler] Error: swr_init failed\n";
        swr_free(&swr_ctx);
        return {};
    }

    // Estimate output sample count
    int64_t in_samples = inputSamples.size() / channels;
    int64_t max_out_samples = swr_get_out_samples(swr_ctx, in_samples);
    
    std::vector<float> outputSamples(max_out_samples * channels);

    const uint8_t* in_data[1] = { reinterpret_cast<const uint8_t*>(inputSamples.data()) };
    uint8_t* out_data[1] = { reinterpret_cast<uint8_t*>(outputSamples.data()) };

    int converted = swr_convert(swr_ctx, out_data, max_out_samples, in_data, in_samples);
    if (converted < 0) {
        std::cerr << "[StemResampler] Error: swr_convert failed with code " << converted << "\n";
        swr_free(&swr_ctx);
        return {};
    }

    outputSamples.resize(converted * channels);

    // Flush any buffered samples
    int64_t delay = swr_get_delay(swr_ctx, outRate);
    if (delay > 0) {
        std::vector<float> flush_buf(delay * channels);
        uint8_t* flush_data[1] = { reinterpret_cast<uint8_t*>(flush_buf.data()) };
        int extra = swr_convert(swr_ctx, flush_data, delay, nullptr, 0);
        if (extra > 0) {
            outputSamples.insert(outputSamples.end(), flush_buf.begin(), flush_buf.begin() + extra * channels);
        }
    }

    swr_free(&swr_ctx);
    return outputSamples;
}

} // namespace ncktv
