#include "stem_separator.h"
#include "stem_resampler.h"
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <iostream>
#include <thread>
#include <algorithm>
#include <cmath>

extern "C" {
#include <libavutil/tx.h>
#include <libavutil/mem.h>
}

namespace ncktv {

StemSeparator::StemSeparator() = default;
StemSeparator::~StemSeparator() = default;

bool StemSeparator::initialize(const QString& modelPath) {
    m_initialized = false;
    m_modelName = "";
    m_executionProvider = "CPU";

    QString resolvedPath = modelPath;
    if (resolvedPath.isEmpty()) {
        // Find by default in Local AppData: Local/NC-KTV/models
        QString appLocal = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
        QString modelDir = QDir(appLocal).filePath("models");
        
        QDir dir(modelDir);
        if (dir.exists()) {
            QStringList filters;
            filters << "*.onnx";
            QStringList files = dir.entryList(filters, QDir::Files);
            if (!files.isEmpty()) {
                resolvedPath = dir.filePath(files.first());
            }
        }
    }

    if (resolvedPath.isEmpty() || !QFile::exists(resolvedPath)) {
        std::cerr << "[StemSeparator] Error: Model not found at path: " << resolvedPath.toStdString() << "\n";
        return false;
    }

    m_modelName = QFileInfo(resolvedPath).baseName();

    try {
        m_env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "NC-KTV-StemSeparation");

        m_sessionOptions = Ort::SessionOptions();

        // 1. Thread configuration (N - 2)
        int num_cores = std::max(1, static_cast<int>(std::thread::hardware_concurrency()));
        int intra_threads = std::max(1, num_cores - 2);
        m_sessionOptions.SetIntraOpNumThreads(intra_threads);
        m_sessionOptions.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);

        // 2. Hardware Cascade: DirectML -> CUDA -> CPU
#if defined(_WIN32)
        bool ep_registered = false;
        try {
            // Try registering DirectML execution provider
            std::unordered_map<std::string, std::string> dml_options;
            dml_options["device_id"] = "0";
            m_sessionOptions.AppendExecutionProvider("DML", dml_options);
            m_executionProvider = "DirectML";
            ep_registered = true;
            std::cout << "[StemSeparator] DirectML hardware acceleration registered successfully.\n";
        } catch (const std::exception& e) {
            std::cout << "[StemSeparator] DirectML not available, trying CUDA... Info: " << e.what() << "\n";
        }

        if (!ep_registered) {
            try {
                // Try registering CUDA execution provider
                OrtCUDAProviderOptions cuda_options;
                cuda_options.device_id = 0;
                m_sessionOptions.AppendExecutionProvider_CUDA(cuda_options);
                m_executionProvider = "CUDA";
                ep_registered = true;
                std::cout << "[StemSeparator] CUDA hardware acceleration registered successfully.\n";
            } catch (const std::exception& e) {
                std::cout << "[StemSeparator] CUDA not available, falling back to CPU. Info: " << e.what() << "\n";
            }
        }
#endif

        // Create the session
#if defined(_WIN32)
        std::wstring modelPathW = resolvedPath.toStdWString();
        m_session = std::make_unique<Ort::Session>(*m_env, modelPathW.c_str(), m_sessionOptions);
#else
        std::string modelPathStr = resolvedPath.toStdString();
        m_session = std::make_unique<Ort::Session>(*m_env, modelPathStr.c_str(), m_sessionOptions);
#endif

        m_initialized = true;
        std::cout << "[StemSeparator] Successfully loaded model: " << m_modelName.toStdString()
                  << " with Execution Provider: " << m_executionProvider.toStdString() << "\n";
        return true;
    } catch (const Ort::Exception& e) {
        std::cerr << "[StemSeparator] ONNX Runtime Error: " << e.what() << "\n";
        return false;
    } catch (const std::exception& e) {
        std::cerr << "[StemSeparator] Standard Error: " << e.what() << "\n";
        return false;
    }
}

bool StemSeparator::separate(const std::vector<float>& input48kStereo,
                             const QString& vocalsPath,
                             const QString& instrumentalPath,
                             std::function<void(double)> progressCallback) {
    if (!m_initialized || !m_session) {
        std::cerr << "[StemSeparator] Error: Separator not initialized.\n";
        return false;
    }

    if (input48kStereo.empty()) {
        std::cerr << "[StemSeparator] Error: Input samples vector is empty.\n";
        return false;
    }

    const int modelRate = 44100;
    const int audioChannels = 2;

    // Slide across audio in spectrogram frames rather than PCM samples
    Ort::TypeInfo input_type_info = m_session->GetInputTypeInfo(0);
    auto input_tensor_info = input_type_info.GetTensorTypeAndShapeInfo();
    std::vector<int64_t> input_shape = input_tensor_info.GetShape();

    // Detect model expected window size (fixed vs dynamic) on frame level
    // Expected shape: [1, 4, num_bins, W_frame]
    int64_t W_frame = 256; 
    if (input_shape.size() >= 4 && input_shape.back() > 0) {
        W_frame = input_shape.back();
    }

    int num_bins = 2048;
    if (input_shape.size() >= 3 && input_shape[2] > 0) {
        num_bins = static_cast<int>(input_shape[2]);
    }

    std::cout << "[StemSeparator] MDX-Net Model Detected. Shape: [";
    for (size_t i = 0; i < input_shape.size(); ++i) {
        std::cout << input_shape[i] << (i + 1 < input_shape.size() ? ", " : "");
    }
    std::cout << "], Frame Window: " << W_frame << ", Bins: " << num_bins << "\n";

    // Downsample input from 48kHz stereo to model target sample rate (stereo audio)
    std::vector<float> inputModelRate = StemResampler::resample(input48kStereo, 48000, modelRate, audioChannels);
    if (inputModelRate.empty()) {
        std::cerr << "[StemSeparator] Error: Downsampling failed.\n";
        return false;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // STFT SETUP
    // ─────────────────────────────────────────────────────────────────────────────
    const int n_fft = num_bins * 2;
    const int hop_size = 1024;
    const int pad_size = n_fft / 2;
    const size_t num_samples = inputModelRate.size() / audioChannels;

    // Calculate exact number of frames so that padding perfectly covers all samples
    const size_t num_frames = static_cast<size_t>(std::ceil(static_cast<double>(num_samples) / hop_size));
    const size_t padded_length = (num_frames - 1) * hop_size + n_fft;

    // De-interleave input samples
    std::vector<float> input_left(padded_length, 0.0f);
    std::vector<float> input_right(padded_length, 0.0f);
    for (size_t i = 0; i < num_samples; ++i) {
        input_left[i + pad_size] = inputModelRate[i * 2 + 0];
        input_right[i + pad_size] = inputModelRate[i * 2 + 1];
    }

    // Pre-calculate Hann Window
    const float PI = 3.141592653589793f;
    std::vector<float> hann(n_fft);
    for (int i = 0; i < n_fft; ++i) {
        hann[i] = 0.5f * (1.0f - std::cos(2.0f * PI * i / n_fft));
    }

    // Initialize FFmpeg AVTX RDFT context for STFT
    AVTXContext* stft_ctx = nullptr;
    av_tx_fn stft_fn = nullptr;
    float scale_fwd = 1.0f;
    int ret = av_tx_init(&stft_ctx, &stft_fn, AV_TX_FLOAT_RDFT, 0, n_fft, &scale_fwd, AV_TX_UNALIGNED);
    if (ret < 0) {
        std::cerr << "[StemSeparator] Error: Failed to initialize FFmpeg forward RDFT context: " << ret << "\n";
        return false;
    }

    // Create 4-channel complex spectrogram: flat layout of size [4 * num_bins * num_frames]
    // Channel mapping: 0 = L_re, 1 = L_im, 2 = R_re, 3 = R_im
    std::vector<float> spectrogram(4 * num_bins * num_frames, 0.0f);

    // Pre-allocate STFT loop temporary buffers to avoid 40,000+ heap allocations
    std::vector<float> windowed_left(n_fft);
    std::vector<AVComplexFloat> output_left(n_fft / 2 + 1);
    std::vector<float> windowed_right(n_fft);
    std::vector<AVComplexFloat> output_right(n_fft / 2 + 1);

    // Execute forward STFT on Left and Right channels
    for (size_t f = 0; f < num_frames; ++f) {
        size_t start_idx = f * hop_size;

        // 1. Process Left Channel
        for (int i = 0; i < n_fft; ++i) {
            windowed_left[i] = input_left[start_idx + i] * hann[i];
        }
        stft_fn(stft_ctx, output_left.data(), windowed_left.data(), sizeof(float));

        // 2. Process Right Channel
        for (int i = 0; i < n_fft; ++i) {
            windowed_right[i] = input_right[start_idx + i] * hann[i];
        }
        stft_fn(stft_ctx, output_right.data(), windowed_right.data(), sizeof(float));

        // Store first num_bins bins into flat complex spectrogram
        for (int b = 0; b < num_bins; ++b) {
            spectrogram[(0 * num_bins + b) * num_frames + f] = output_left[b].re;
            spectrogram[(1 * num_bins + b) * num_frames + f] = output_left[b].im;
            spectrogram[(2 * num_bins + b) * num_frames + f] = output_right[b].re;
            spectrogram[(3 * num_bins + b) * num_frames + f] = output_right[b].im;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // ONNX INFERENCE OVERLAP-ADD PIPELINE
    // ─────────────────────────────────────────────────────────────────────────────
    Ort::AllocatorWithDefaultOptions allocator;
    Ort::AllocatedStringPtr input_name = m_session->GetInputNameAllocated(0, allocator);
    Ort::AllocatedStringPtr output_name = m_session->GetOutputNameAllocated(0, allocator);

    std::vector<const char*> input_names = { input_name.get() };
    std::vector<const char*> output_names = { output_name.get() };

    Ort::MemoryInfo memory_info = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);

    std::vector<float> vocals_spectrogram(4 * num_bins * num_frames, 0.0f);
    std::vector<float> vocals_weights(num_frames, 0.0f);

    const size_t O_frame = 32; // Overlap size on frame level
    const size_t S_frame = W_frame - O_frame;

    for (size_t offset_frame = 0; offset_frame < num_frames; offset_frame += S_frame) {
        size_t chunk_len_frame = std::min<size_t>(W_frame, num_frames - offset_frame);
        if (chunk_len_frame == 0) break;

        // Build rank-4 tensor of shape [1, 4, num_bins, W_frame] with optimized memcpy copies
        std::vector<float> planarInput(1 * 4 * num_bins * W_frame, 0.0f);
        for (int c = 0; c < 4; ++c) {
            for (int b = 0; b < num_bins; ++b) {
                size_t src_start = (c * num_bins + b) * num_frames + offset_frame;
                size_t dest_start = (c * num_bins + b) * W_frame;
                std::memcpy(&planarInput[dest_start], &spectrogram[src_start], chunk_len_frame * sizeof(float));
            }
        }

        std::vector<int64_t> input_dims = {1, 4, static_cast<int64_t>(num_bins), static_cast<int64_t>(W_frame)};
        Ort::Value input_tensor = Ort::Value::CreateTensor<float>(
            memory_info, planarInput.data(), planarInput.size(), input_dims.data(), input_dims.size());

        try {
            auto output_tensors = m_session->Run(Ort::RunOptions{nullptr}, input_names.data(), &input_tensor, 1, output_names.data(), 1);
            if (!output_tensors.empty()) {
                float* out_data = output_tensors[0].GetTensorMutableData<float>();

                // Overlap-add vocals spectrogram using a cosine OLA window on the frame/time axis
                for (size_t t = 0; t < chunk_len_frame; ++t) {
                    float weight = 1.0f;
                    if (offset_frame > 0 && t < O_frame) {
                        float theta = (PI * t) / (2.0f * O_frame);
                        weight = std::sin(theta) * std::sin(theta);
                    }
                    else if (offset_frame + W_frame < num_frames && t >= W_frame - O_frame) {
                        size_t t_prime = t - (W_frame - O_frame);
                        float theta = (PI * t_prime) / (2.0f * O_frame);
                        weight = std::cos(theta) * std::cos(theta);
                    }

                    size_t global_frame = offset_frame + t;
                    if (global_frame < num_frames) {
                        vocals_weights[global_frame] += weight;
                        for (int c = 0; c < 4; ++c) {
                            for (int b = 0; b < num_bins; ++b) {
                                size_t idx = c * (num_bins * W_frame) + b * W_frame + t;
                                size_t dest_idx = (c * num_bins + b) * num_frames + global_frame;
                                vocals_spectrogram[dest_idx] += out_data[idx] * weight;
                            }
                        }
                    }
                }
            }
        }
        catch (const Ort::Exception& e) {
            std::cerr << "[StemSeparator] Inference session run failed: " << e.what() << "\n";
            av_tx_uninit(&stft_ctx);
            return false;
        }

        if (progressCallback) {
            double prog = static_cast<double>(offset_frame + chunk_len_frame) / num_frames;
            progressCallback(std::min(1.0, prog));
        }

        if (offset_frame + W_frame >= num_frames) {
            break;
        }
    }

    // Normalize vocals spectrogram by overlap weights (with cache-friendly loop order)
    for (int c = 0; c < 4; ++c) {
        for (int b = 0; b < num_bins; ++b) {
            size_t base_idx = (c * num_bins + b) * num_frames;
            for (size_t f = 0; f < num_frames; ++f) {
                float w = vocals_weights[f];
                if (w > 1e-5f) {
                    vocals_spectrogram[base_idx + f] /= w;
                }
            }
        }
    }

    // Compute instrumental complex spectrogram: instrumental = input - vocals (contiguous flat structure allows compiler vectorization)
    std::vector<float> instrumental_spectrogram(4 * num_bins * num_frames);
    for (size_t i = 0; i < spectrogram.size(); ++i) {
        instrumental_spectrogram[i] = spectrogram[i] - vocals_spectrogram[i];
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // ISTFT SETUP AND WAVEFORM RECONSTRUCTION
    // ─────────────────────────────────────────────────────────────────────────────
    AVTXContext* istft_ctx = nullptr;
    av_tx_fn istft_fn = nullptr;
    float scale_inv = 1.0f / n_fft;
    ret = av_tx_init(&istft_ctx, &istft_fn, AV_TX_FLOAT_RDFT, 1, n_fft, &scale_inv, AV_TX_UNALIGNED);
    if (ret < 0) {
        std::cerr << "[StemSeparator] Error: Failed to initialize FFmpeg inverse RDFT context: " << ret << "\n";
        av_tx_uninit(&stft_ctx);
        return false;
    }

    // Pre-calculate synthesis window normalization weights (WOLA)
    std::vector<float> window_sum(padded_length, 0.0f);
    for (size_t f = 0; f < num_frames; ++f) {
        size_t start_idx = f * hop_size;
        for (int i = 0; i < n_fft; ++i) {
            float w = hann[i];
            window_sum[start_idx + i] += w * w;
        }
    }

    // Pre-allocate synthesis loop temporary buffers to avoid another 80,000+ heap allocations
    std::vector<AVComplexFloat> v_left_complex(n_fft / 2 + 1);
    std::vector<float> v_left_frame(n_fft);
    std::vector<AVComplexFloat> v_right_complex(n_fft / 2 + 1);
    std::vector<float> v_right_frame(n_fft);

    // 1. Reconstruct Vocals Waveform
    std::vector<float> vocals_left_padded(padded_length, 0.0f);
    std::vector<float> vocals_right_padded(padded_length, 0.0f);
    for (size_t f = 0; f < num_frames; ++f) {
        size_t start_idx = f * hop_size;

        // Reconstruct Left Vocals Frame
        for (int b = 0; b < num_bins; ++b) {
            v_left_complex[b].re = vocals_spectrogram[(0 * num_bins + b) * num_frames + f];
            v_left_complex[b].im = vocals_spectrogram[(1 * num_bins + b) * num_frames + f];
        }
        v_left_complex[num_bins].re = 0.0f;
        v_left_complex[num_bins].im = 0.0f;
        istft_fn(istft_ctx, v_left_frame.data(), v_left_complex.data(), sizeof(AVComplexFloat));

        // Reconstruct Right Vocals Frame
        for (int b = 0; b < num_bins; ++b) {
            v_right_complex[b].re = vocals_spectrogram[(2 * num_bins + b) * num_frames + f];
            v_right_complex[b].im = vocals_spectrogram[(3 * num_bins + b) * num_frames + f];
        }
        v_right_complex[num_bins].re = 0.0f;
        v_right_complex[num_bins].im = 0.0f;
        istft_fn(istft_ctx, v_right_frame.data(), v_right_complex.data(), sizeof(AVComplexFloat));

        // Accumulate overlap-add
        for (int i = 0; i < n_fft; ++i) {
            vocals_left_padded[start_idx + i] += v_left_frame[i] * hann[i];
            vocals_right_padded[start_idx + i] += v_right_frame[i] * hann[i];
        }
    }

    // Reuse pre-allocated complex buffers for instrumental reconstruction to avoid reallocation
    std::vector<AVComplexFloat> i_left_complex(n_fft / 2 + 1);
    std::vector<float> i_left_frame(n_fft);
    std::vector<AVComplexFloat> i_right_complex(n_fft / 2 + 1);
    std::vector<float> i_right_frame(n_fft);

    // 2. Reconstruct Instrumental Waveform
    std::vector<float> inst_left_padded(padded_length, 0.0f);
    std::vector<float> inst_right_padded(padded_length, 0.0f);
    for (size_t f = 0; f < num_frames; ++f) {
        size_t start_idx = f * hop_size;

        // Reconstruct Left Instrumental Frame
        for (int b = 0; b < num_bins; ++b) {
            i_left_complex[b].re = instrumental_spectrogram[(0 * num_bins + b) * num_frames + f];
            i_left_complex[b].im = instrumental_spectrogram[(1 * num_bins + b) * num_frames + f];
        }
        i_left_complex[num_bins].re = 0.0f;
        i_left_complex[num_bins].im = 0.0f;
        istft_fn(istft_ctx, i_left_frame.data(), i_left_complex.data(), sizeof(AVComplexFloat));

        // Reconstruct Right Instrumental Frame
        for (int b = 0; b < num_bins; ++b) {
            i_right_complex[b].re = instrumental_spectrogram[(2 * num_bins + b) * num_frames + f];
            i_right_complex[b].im = instrumental_spectrogram[(3 * num_bins + b) * num_frames + f];
        }
        i_right_complex[num_bins].re = 0.0f;
        i_right_complex[num_bins].im = 0.0f;
        istft_fn(istft_ctx, i_right_frame.data(), i_right_complex.data(), sizeof(AVComplexFloat));

        // Accumulate overlap-add
        for (int i = 0; i < n_fft; ++i) {
            inst_left_padded[start_idx + i] += i_left_frame[i] * hann[i];
            inst_right_padded[start_idx + i] += i_right_frame[i] * hann[i];
        }
    }

    // Clean up FFmpeg context
    av_tx_uninit(&stft_ctx);
    av_tx_uninit(&istft_ctx);

    // Interleave, normalize and trim padding
    std::vector<float> vocalsAccumulated(num_samples * audioChannels, 0.0f);
    std::vector<float> instAccumulated(num_samples * audioChannels, 0.0f);
    for (size_t i = 0; i < num_samples; ++i) {
        size_t idx = i + pad_size;
        float w = window_sum[idx];
        float scale = (w > 1e-5f) ? (1.0f / w) : 1.0f;

        vocalsAccumulated[i * 2 + 0] = vocals_left_padded[idx] * scale;
        vocalsAccumulated[i * 2 + 1] = vocals_right_padded[idx] * scale;

        instAccumulated[i * 2 + 0] = inst_left_padded[idx] * scale;
        instAccumulated[i * 2 + 1] = inst_right_padded[idx] * scale;
    }

    // Upsample results from model target rate back to standard 48kHz (stereo)
    std::vector<float> vocals48k = StemResampler::resample(vocalsAccumulated, modelRate, 48000, audioChannels);
    std::vector<float> inst48k = StemResampler::resample(instAccumulated, modelRate, 48000, audioChannels);

    if (vocals48k.empty() || inst48k.empty()) {
        std::cerr << "[StemSeparator] Error: Upsampling failed.\n";
        return false;
    }

    // Write WAV files
    if (!writeWavFile(vocalsPath, vocals48k, 48000)) return false;
    if (!writeWavFile(instrumentalPath, inst48k, 48000)) return false;

    std::cout << "[StemSeparator] Completed separating stems. Outputs written to:\n"
              << "Vocals: " << vocalsPath.toStdString() << "\n"
              << "Instrumental: " << instrumentalPath.toStdString() << "\n";
    return true;
}

bool StemSeparator::writeWavFile(const QString& filePath, const std::vector<float>& samples, int sampleRate) {
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        std::cerr << "[StemSeparator] Error: Could not open WAV file for writing: " << filePath.toStdString() << "\n";
        return false;
    }

    // Write WAV header
    // RIFF header
    file.write("RIFF", 4);
    quint32 fileSize = 36 + samples.size() * sizeof(int16_t);
    file.write(reinterpret_cast<const char*>(&fileSize), 4);
    file.write("WAVE", 4);

    // fmt subchunk
    file.write("fmt ", 4);
    quint32 subchunk1Size = 16;
    file.write(reinterpret_cast<const char*>(&subchunk1Size), 4);
    quint16 audioFormat = 1; // PCM
    file.write(reinterpret_cast<const char*>(&audioFormat), 2);
    quint16 numChannels = 2; // Stereo
    file.write(reinterpret_cast<const char*>(&numChannels), 2);
    quint32 sRate = sampleRate;
    file.write(reinterpret_cast<const char*>(&sRate), 4);
    quint32 byteRate = sampleRate * 2 * sizeof(int16_t);
    file.write(reinterpret_cast<const char*>(&byteRate), 4);
    quint16 blockAlign = 2 * sizeof(int16_t);
    file.write(reinterpret_cast<const char*>(&blockAlign), 2);
    quint16 bitsPerSample = 16;
    file.write(reinterpret_cast<const char*>(&bitsPerSample), 2);

    // data subchunk
    file.write("data", 4);
    quint32 subchunk2Size = samples.size() * sizeof(int16_t);
    file.write(reinterpret_cast<const char*>(&subchunk2Size), 4);

    // Write samples converted to 16-bit PCM
    std::vector<int16_t> pcmSamples(samples.size());
    for (size_t i = 0; i < samples.size(); ++i) {
        float s = std::clamp(samples[i], -1.0f, 1.0f);
        pcmSamples[i] = static_cast<int16_t>(s * 32767.0f);
    }
    file.write(reinterpret_cast<const char*>(pcmSamples.data()), pcmSamples.size() * sizeof(int16_t));
    return true;
}

} // namespace ncktv
