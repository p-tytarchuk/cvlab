# Mini real-time frame pipeline — practise

The integration project: everything from `memory_management`'s warm-up
tasks, combined. Do this after finishing (or at least attempting) tasks 1–7
there — see `../memory_management/practise.md`.

Goal: simulate a camera producing frames at a fixed rate, processed by a
consumer thread, using a pool instead of per-frame allocation. Follow the
repo's TDD workflow throughout: write the test, watch it fail, implement,
refactor.

The class shapes in `aligned_frame_pool.hpp`, `pooled_frame.hpp` and
`ring_buffer.hpp` are placeholders — declared, no bodies. `frame_pipeline.hpp`
declares `create<T, Args...>` (a template, define its body directly in the
header) and `process()`.

## Step 1 — AlignedFramePool + PooledFrame, no threads

Files: `aligned_frame_pool.hpp`/`.cpp`, `pooled_frame.hpp`/`.cpp`,
`mini_frame_pipeline_test.cpp`.

1. Write a test that constructs an `AlignedFramePool(frame_size, capacity)`,
   calls `acquire()`, and checks the returned `PooledFrame`'s `data()` is
   non-null and `size()` matches `frame_size`.
2. Implement `AlignedFramePool`: preallocate `capacity` buffers of
   `frame_size` bytes each with `std::aligned_alloc(32, ...)` (round
   `frame_size` up to a multiple of 32 first), track free ones, and free
   everything in the destructor.
3. Implement `PooledFrame`'s move ctor/assignment and destructor to call
   back into the pool's `release()` — mirror what you built for
   `FramePool`/`PooledFrame` in memory_management task 6, but type it out
   fresh rather than copy-pasting; the aligned allocation changes enough
   details (alignment, byte buffers vs ints) that copy-paste would hide
   what's different.
4. Write a test that prints every buffer's address and asserts
   `reinterpret_cast<std::uintptr_t>(ptr) % 32 == 0` for each.
5. Confirm the pool is leak-free before moving on. Valgrind and
   LeakSanitizer both only work on Linux (see
   `../memory_management/practise.md` task 5, and `theory.pdf` §5.3), so
   locally assert the balance instead: every buffer the pool allocated is
   freed in its destructor, and every slot handed out comes back. A
   counter on the pool, asserted at the end of the test, is enough.

## Step 2 — RingBuffer, single-threaded

Files: `ring_buffer.hpp`.

1. Write a test that constructs a `RingBuffer<PooledFrame, 4>` (or a
   `RingBuffer<int, 4>` first if you want a simpler type to debug with),
   pushes several values by move, pops them, and asserts they come out in
   the same order they went in.
2. Implement `push`/`pop` over the fixed `std::array<T, N>` with a head/tail
   index and a count (or a full/empty flag) — no threading yet, no
   allocation.
3. Confirm `push` moves its argument (no copy ctor call) — for
   `RingBuffer<PooledFrame, N>` this is enforced for you, since `PooledFrame`
   has no copy ctor; for `RingBuffer<Buffer, N>` (memory_management task 2)
   you could print from the copy ctor to double check nothing copies.

## Step 3 — producer/consumer threads

Add to `mini_frame_pipeline_test.cpp` (or a new function in
`frame_pipeline.hpp`/`.cpp` if you want it reusable).

1. Write a test that spins up a producer `std::thread` which acquires
   frames from the pool, fills them with a pattern, and pushes them into a
   shared `RingBuffer`; and a consumer `std::thread` which pops frames and
   records what it saw. Join both and assert the consumer saw every frame,
   in order, with the right pattern.
2. Make `push`/`pop` block when the buffer is full/empty using a
   `std::mutex` + `std::condition_variable`, instead of spinning or
   failing.
3. Watch for spurious wakeups: use the predicate form of
   `condition_variable::wait`.

## Step 4 — std::span processing

Files: `frame_pipeline.hpp`/`.cpp`.

1. Write a test that constructs a `PooledFrame`, wraps its buffer in a
   `std::span<uint8_t>`, and calls `process()` on it — check the buffer's
   contents changed as expected, in place (compare the span's `data()`
   pointer before and after to confirm no copy happened).
2. Implement `process()` to do something simple but observable in place
   (e.g. increment every byte, or apply a fixed XOR pattern).
3. Wire it into the consumer thread from step 3: pop a frame, build a span
   over its buffer via `std::span<uint8_t>(frame.data(), frame.size())`,
   call `process()`.

## Step 5 — the create<> helper

Files: `frame_pipeline.hpp`.

1. Use `create<T, Args...>` somewhere real — e.g. to construct a small
   config struct (frame width/height/pattern byte) that the producer thread
   reads, forwarding constructor arguments through it. This is the same
   exercise as memory_management task 3, applied here instead of duplicated.
2. Implement it with a forwarding reference and `std::forward`, same as
   task 3.

## Step 6 — zero warnings, then break something on purpose

1. Run the full test binary under `-fsanitize=address,undefined` (the `asan`
   preset). Zero warnings is the exit criterion. Add the
   stack-use-after-return flag — it is off by default, and step 6.2's
   second bug needs it:

       cmake --preset asan && cmake --build --preset asan
       ASAN_OPTIONS=detect_stack_use_after_return=1 \
         ./build/asan/part1_modern_cpp/mini_frame_pipeline/cvlab_mini_frame_pipeline_test

   Also run `cmake --preset tsan` — this is the first topic with real
   threading, and TSan is trustworthy here because the racing code is all
   yours (see `docs/setup.md` for why that caveat matters).

2. Deliberately break something. Pick from these, because the failures look
   nothing alike:
   - Drop a `std::move` on push. This will **not** compile — `PooledFrame`
     has no copy constructor. A compile error is the good outcome: the type
     system prevented the bug outright. That is the single most useful
     result in this project.
   - Return a `PooledFrame*` to a stack local — needs
     `detect_stack_use_after_return=1` to be caught at all.
   - Release a slot twice, or let a `PooledFrame` outlive its pool — ASan
     heap-use-after-free.
3. Fix it, and re-run step 6.1 to confirm you're back to zero warnings.

This last step is the most valuable one: seeing a sanitizer actually catch a
bug you inserted yourself builds far more intuition than reading about it.
