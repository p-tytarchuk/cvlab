## 1. Modern C++

### Memory management
- RAII, stack vs heap, object lifetime
- Smart pointers: `unique_ptr`, `shared_ptr`, `weak_ptr`, custom deleters, `make_unique` / `make_shared`
- Rule of 0 / 3 / 5, copy vs move constructors
- Move semantics, rvalue references, `std::move`, `std::forward`, perfect forwarding
- Memory leaks, dangling pointers, use-after-free; tools: ASan, Valgrind
- Memory pools / preallocated buffers for image frames, zero-copy design
- Memory alignment (important for SIMD and accelerators)
- Practise plan: `part1_modern_cpp/memory_management/practise.md` — 7
  warm-up tasks (stack vs heap, move semantics, `std::forward`, dangling
  pointer/UAF, leaks, memory pool, alignment); the integration project has
  its own `part1_modern_cpp/mini_frame_pipeline/practise.md`
- Theory for all of the above, including the macOS arm64 vs Ubuntu x86_64
  differences that affect tasks 4, 5 and 7:
  `part1_modern_cpp/memory_management/theory.pdf`

### STL and language features
- Containers and complexity: `vector`, `deque`, `list`, `map`, `unordered_map`, `array`
- Iterator invalidation, `reserve`, `emplace_back`
- Algorithms, lambdas, captures
- C++17: `optional`, `variant`, `string_view`, structured bindings, `std::filesystem`
- C++20: concepts, `std::span`, ranges, `jthread`, coroutines (awareness)
- Templates, SFINAE vs concepts, `constexpr`
- Virtual functions, vtable cost, `final`, `override`
- Undefined behavior — common cases

### Multithreading and concurrency
- `std::thread`, `std::async`, futures and promises
- `mutex`, `lock_guard`, `unique_lock`, `scoped_lock`, `shared_mutex`
- `condition_variable` and spurious wakeups
- `std::atomic`, lock-free basics, ABA problem (awareness)
- Deadlocks, race conditions, false sharing, priority inversion
- Thread pools, producer-consumer queues, pipeline parallelism
- Tools: ThreadSanitizer (TSan)

### SDK / library design
- Clean public API, header hygiene, PIMPL idiom
- ABI stability, C API wrappers for cross-language use
- Versioning (semantic versioning), backward compatibility
- Error handling strategy: exceptions vs error codes vs `expected`
- Thread-safety guarantees documented per API
- CMake: targets, install/export, `find_package`, toolchain files
- Cross-compiling: Android NDK, ARM64, JNI bindings
- Unit tests: GoogleTest; documentation: Doxygen

### Performance engineering
- Profiling: `perf`, VTune, Nsight Systems, Snapdragon Profiler, Android Studio profiler
- Cache locality, struct-of-arrays vs array-of-structs
- SIMD: SSE/AVX (Intel), NEON (ARM)
- Avoiding copies, in-place operations, reusing buffers
- Latency vs throughput, batching

---

## 2. Model Deployment and Inference Frameworks

### General deployment pipeline
- Training framework (PyTorch / TensorFlow) → ONNX → vendor format → C++ runtime
- ONNX: opsets, graph inspection (Netron), onnx-simplifier, ONNX Runtime as reference
- Static vs dynamic shapes, batch size decisions
- Unsupported operators: graph surgery, replacement, custom ops / plugins, model splitting
- Preprocessing / postprocessing correctness (color order, normalization, NCHW vs NHWC, NMS)
- Numerical validation: compare outputs to reference (cosine similarity, max error)

### Qualcomm SNPE / QNN (very relevant for mobile client)
- Conversion to DLC (SNPE) or QNN model / context binary
- Runtimes / backends: CPU, GPU, DSP, HTP (Hexagon NPU)
- Quantization for DSP/HTP (INT8 required for best speed)
- Performance profiles, burst vs power-saver modes
- AI Hub / AIMET for quantization (awareness)

### NVIDIA TensorRT
- ONNX parser → builder → serialized engine
- FP32, FP16, INT8 modes; INT8 calibrators (entropy, minmax)
- Optimization profiles for dynamic shapes
- Plugins for unsupported layers
- `trtexec` for benchmarking; engines are GPU/version specific
- CUDA streams, pinned memory, host-device copies

### Intel OpenVINO
- Model conversion to IR (xml + bin)
- Devices: CPU, GPU, NPU; AUTO plugin
- `benchmark_app`, performance hints (LATENCY / THROUGHPUT)
- NNCF for PTQ and QAT

### TensorFlow Lite
- TFLite converter, flatbuffer model
- Delegates: GPU, NNAPI, Hexagon, XNNPACK
- Full-integer quantization with representative dataset

---

## 3. Optimization and Quantization

### Quantization
- Why: smaller models, faster integer math, NPU/DSP requirements, lower power
- Scale and zero-point; symmetric vs asymmetric
- Per-tensor vs per-channel quantization
- PTQ: calibration dataset, fast, no retraining
- QAT: fake-quant nodes during training, better accuracy, costs training time
- Mixed precision: keep sensitive layers in FP16/FP32
- Debugging accuracy drops: layer-wise comparison, activation ranges, outliers
- INT4 / weight-only quantization (awareness, especially for Transformers)

### Other optimizations
- Layer / operator fusion (Conv + BN + ReLU)
- Pruning and knowledge distillation (awareness)
- Input resolution trade-offs
- Asynchronous inference, pipelining pre/post-processing
- Zero-copy buffers between camera, GPU and NPU

### Benchmarking correctly
- Warm-up runs before measuring
- Latency percentiles: p50, p95, p99 (not just average)
- Throughput (FPS), memory peak, model load time, power, thermal throttling
- Accuracy metrics on target device vs reference (mAP, top-1)
- Fixed test conditions, repeated runs, documented environment

---

## 4. Computer Vision Fundamentals

### Image formation and cameras
- Pinhole camera model, focal length, principal point, field of view
- Intrinsic and extrinsic parameters, projection matrix
- Lens distortion (radial, tangential) and undistortion
- Camera calibration: chessboard / charuco, reprojection error
- Rolling shutter vs global shutter, motion artifacts
- ISP pipeline on mobile: demosaic, auto exposure, auto white balance, denoise, tone mapping
- Exposure, gain / ISO, noise, low-light behavior, HDR
- Multi-camera setups: wide / tele / depth sensors, synchronization

### Image processing basics
- Color spaces: RGB, BGR, YUV / NV12, HSV, grayscale conversion
- Convolution filters: Gaussian blur, median, bilateral (edge preserving)
- Edge detection: Sobel, Laplacian, Canny
- Thresholding (Otsu, adaptive), morphology (erode, dilate, open, close)
- Histogram equalization / CLAHE for contrast
- Image pyramids, scale space
- Interpolation for resizing: nearest, bilinear, bicubic; letterbox resize to keep aspect ratio
- Why preprocessing must match training exactly (resize method, normalization, channel order)

### Features and multi-view geometry
- Corner / feature detectors: Harris, FAST, ORB, SIFT (patents / speed trade-offs)
- Descriptors and matching, ratio test, brute force vs FLANN
- RANSAC for robust estimation with outliers
- Homography (planar scenes, image stitching, AR overlays)
- Epipolar geometry, fundamental and essential matrix
- Stereo vision: rectification, disparity, depth from disparity
- PnP: estimating camera pose from 3D-2D correspondences
- Triangulation, bundle adjustment (awareness)
- SLAM / visual-inertial odometry basics (relevant for mobile AR)

### Motion, tracking and video
- Optical flow: Lucas-Kanade (sparse), Farneback / RAFT (dense)
- Background subtraction, frame differencing
- Single object trackers: KCF, CSRT, MOSSE
- Multi-object tracking: SORT, DeepSORT, ByteTrack
- Kalman filter for state prediction, Hungarian algorithm for assignment
- Re-identification embeddings for keeping IDs across frames
- Detection + tracking hybrid to save compute (detect every N frames, track between)
- Temporal smoothing to reduce flicker in outputs

### Modern CV tasks (deep learning based)
- Classification, object detection, semantic vs instance segmentation
- Keypoints / human pose estimation, hand tracking
- Face detection, landmarks, recognition embeddings, liveness (privacy considerations)
- OCR / text detection and recognition
- Monocular depth estimation, super-resolution, denoising
- Image / video enhancement on device (portrait mode, HDR fusion)

### Data, training concepts and evaluation
- Dataset splits, data distribution vs real deployment conditions (domain shift)
- Augmentation: flips, crops, color jitter, blur, synthetic data
- Loss functions: cross-entropy, focal loss, IoU / GIoU losses
- Overfitting, underfitting, regularization, transfer learning / fine-tuning
- Metrics: precision, recall, F1, confusion matrix, mAP, IoU / mIoU, PCK for keypoints
- Class imbalance and hard negative mining
- Labeling quality and golden test sets for release validation

### End-to-end CV pipeline on device
- Camera frame (NV12) → ISP → crop / resize → normalize → inference → decode → NMS → tracking → smoothing → UI
- Zero-copy buffer sharing between camera, GPU and NPU
- ROI cropping and cascaded models (detect then classify / landmark)
- Frame skipping, resolution scaling and adaptive quality under thermal load
- Where accuracy usually breaks in production: preprocessing mismatch, unusual lighting, motion blur, small objects

---

## 5. Deep Learning Fundamentals *(Nice to have)*

### CNNs
- Convolution, stride, padding, receptive field, pooling
- Batch normalization, activation functions
- Depthwise-separable convolutions (MobileNet) for mobile
- Backbones: ResNet, MobileNet, EfficientNet

### Object detection
- One-stage (YOLO, SSD) vs two-stage (Faster R-CNN)
- Anchors vs anchor-free
- IoU, NMS, confidence thresholds, mAP

### Transformers
- Self-attention, patches in Vision Transformers
- Why hard on edge: quadratic attention cost, memory, unsupported ops (LayerNorm, GELU in some runtimes)

### Classic computer vision
- OpenCV basics: resize, color conversion, filtering
- Image formats: RGB, BGR, YUV / NV12 (camera frames on mobile)
- Segmentation, keypoints, tracking (awareness)

---

## 6. Python, Automation, CI/CD and Docker

### Python
- Clean structure: modules, type hints, `argparse`, `logging`, `pathlib`
- NumPy for tensor comparison and data processing
- `pytest` for tests, `subprocess` for running tools
- Generating reports (JSON, CSV, HTML) from benchmarks

### CI/CD
- GitHub Actions / GitLab CI / Jenkins pipelines
- Pipeline stages: build SDK → convert model → run tests → benchmark on device → publish artifacts
- Performance regression gates (fail if latency > threshold)
- Device farms, running tests on real phones via ADB
- Artifact versioning: models, engines, SDK builds

### Docker
- Dockerfile, layers, caching, multi-stage builds
- Image size reduction
- NVIDIA Container Toolkit for GPU access
- Separate images per vendor toolchain (TensorRT, OpenVINO, QNN)
- Volumes, reproducible builds, dev containers

### Linux and Android basics

- Linux shell, permissions, environment variables, shared libraries (`LD_LIBRARY_PATH`)
- ADB: `push`, `shell`, `logcat`
- Git workflow, code review
