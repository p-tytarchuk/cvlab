// Integration project - the pipeline glue. See practise.md.
//
// Producer/consumer std::thread wiring, and the deliberately introduced bug
// (step 6 in practise.md), belong in mini_frame_pipeline_test.cpp or a
// function you add here once AlignedFramePool, PooledFrame and RingBuffer
// work on their own.

#pragma once

#include <cstdint>
#include <span>
#include <utility>

namespace cvlab::pipeline {

// TODO: forward args into T's constructor with std::forward. A template
// must be defined where it is used, so define this here once you write it -
// there is deliberately no body yet.
template <typename T, typename... Args>
T create(Args&&... args);

// TODO: "processes" a frame in place - no raw new copies.
void process(std::span<uint8_t> frame);

}  // namespace cvlab::pipeline
