# Memory management — practise

Step-by-step for the warm-up tasks. Each task isolates one concept; do them
in order, since later tasks lean on earlier ones. The class/function shapes
already declared in each header are placeholders — the special members and
functions have no bodies yet, so nothing works until you write them.

Follow the repo's TDD workflow for every task: write the test, run it,
**watch it fail** (a compile error, a link error, or a failing assertion all
count), then write the minimum implementation to make it pass, then refactor
with the test green.

`theory.pdf` in this directory covers everything these tasks assume, and
flags the places where macOS arm64 behaves differently from Linux. Tasks 4,
5 and 7 each have a platform trap that will waste an hour if you meet it
unprepared — they are called out inline below, and in full in the PDF.

## 1. Stack vs heap — measure it (done)

`memory_management.hpp` / `memory_management.cpp` / `memory_management_test.cpp`

Already implemented: allocates the same-sized array 10 million times, once
on the stack, once with `new`/`delete`, and times both. Run it to see the
numbers:

    ./build/debug/part1_modern_cpp/memory_management/cvlab_memory_management_test --gtest_filter=MemoryManagement.*

## 2. Move semantics — Buffer class

Files: `buffer.hpp` (class shape already declared) / `buffer.cpp` (empty —
fill in) / `buffer_test.cpp` (empty — write the test).

1. In `buffer_test.cpp`, write a test that constructs a `Buffer`, copies it,
   moves it, and checks the resulting state (e.g. that a moved-from
   `Buffer`'s pointer is null, or that a copy has independent memory). Run
   `ctest --preset debug -R MemoryManagement` and watch it fail to link —
   `Buffer`'s members are declared but not defined yet.
2. Implement the constructor, destructor, copy ctor/assignment and move
   ctor/assignment in `buffer.cpp`. Print a message from each (e.g. to
   `std::cerr`) so the call sequence is visible when you run the test with
   `--gtest_filter` directly (not through `ctest`, which hides stdout/stderr
   on success).
3. Add a test that pushes several `Buffer`s into a `std::vector<Buffer>` and
   triggers a reallocation (push past its current capacity). Watch which
   special member gets called during the reallocation.
4. Mark the move ctor `noexcept` (already done in the declaration) vs. not,
   and compare: `std::vector` only uses the move ctor during reallocation
   if it is `noexcept` (or the type has no copy ctor) — otherwise it falls
   back to copying for the strong exception guarantee. Confirm you can see
   the difference by temporarily removing `noexcept` and re-running.

## 3. std::forward — generic factory

Files: `forwarding_factory.hpp` (declared, no body — templates must be
defined where used, so write the body directly in this header) /
`forwarding_factory_test.cpp` (empty — write the test).

1. In the test, declare a small class with two constructor overloads: one
   taking `const std::string&` (or similar lvalue-taking type), one taking
   `std::string&&`. Add a way to observe which one ran (a member flag, or a
   print).
2. Write a test that calls `cvlab::memory::create<YourClass>(lvalue)` and
   `create<YourClass>(std::move(rvalue))`, asserting the right overload ran
   in each case. Watch it fail — `create` has no body yet.
3. Implement `create` in `forwarding_factory.hpp` using a forwarding
   reference and `std::forward<Args>(args)...`. Re-run until green.
4. Break it on purpose: implement it with `args...` instead of
   `std::forward<Args>(args)...` and confirm the rvalue case now silently
   calls the lvalue overload — then put `std::forward` back.

## 4. Dangling pointer / UAF — reproduce it on purpose

Files: `dangling_uaf.hpp` (declared, no body) / `dangling_uaf.cpp` (empty —
fill in) / `dangling_uaf_test.cpp` (empty — write the test).

1. Implement `dangling_pointer()` in `dangling_uaf.cpp` to return the
   address of a local variable.
2. Implement `use_after_free()` to `new` an object, `delete` it, then
   dereference the freed pointer.
3. Write tests that call both (a gtest assertion isn't really the point
   here — even just calling them and reading/writing through the returned
   pointer is enough to trigger the bug under a sanitizer).
4. Rebuild under the `asan` preset and run the test binary directly, not
   through ctest, so you see the full report. **ASan does not detect
   stack-use-after-return by default** — without this environment variable
   the dangling-pointer case runs cleanly and reports nothing:

       cmake --preset asan && cmake --build --preset asan
       ASAN_OPTIONS=detect_stack_use_after_return=1 \
         ./build/asan/part1_modern_cpp/memory_management/cvlab_memory_management_test \
         --gtest_filter='*DanglingUaf*'

   The use-after-free case *is* caught by default; only the stack case
   needs the flag. Seeing one work and the other stay silent is itself the
   lesson.

5. Read the ASan report and note the exact file/line it blames in a comment
   next to the bug. `theory.pdf` §4.4 annotates a real report line by line.

## 5. Memory leak — reproduce and catch it

Files: `memory_leak.hpp` (declared, no body) / `memory_leak.cpp` (empty —
fill in) / `memory_leak_test.cpp` (empty — write the test).

1. Implement `leak_memory()` with an intentional leak — e.g. allocate,
   overwrite the only pointer to it before freeing, or `throw` between
   `new` and the matching `delete`.
2. Write a test that calls it.
3. **Neither leak tool runs on macOS arm64.** `ASAN_OPTIONS=detect_leaks=1`
   aborts with "detect_leaks is not supported on this platform", and
   Valgrind has no arm64 macOS port at all. Do the tool comparison on the
   Ubuntu machine, or in a container — Valgrind supports arm64 Linux, so
   this runs natively on Apple Silicon:

       docker run --rm -it -v "$PWD":/src -w /src ubuntu:24.04 bash
       apt-get update && apt-get install -y build-essential cmake ninja-build valgrind

   Then, inside, build as usual and run both:

       ASAN_OPTIONS=detect_leaks=1 ./build/asan/.../cvlab_memory_management_test \
         --gtest_filter='*MemoryLeak*'
       valgrind --leak-check=full --show-leak-kinds=all \
         ./build/debug/.../cvlab_memory_management_test --gtest_filter='*MemoryLeak*'

4. Note in a comment how the two reports differ (stack trace detail,
   "definitely lost" vs "still reachable" categories, etc.).

5. Locally on the Mac, you can still prove the leak without either tool:
   task 1 already replaces global `operator new`, so count allocations
   against deallocations inside the test and assert the balance. That is
   portable and the fastest feedback loop of the three.

## 6. Memory pool — the free-list pool

Files: `frame_pool.hpp` (`FramePool`/`PooledFrame` shapes already declared)
/ `frame_pool.cpp` (empty — fill in) / `frame_pool_test.cpp` (empty — write
the test) / `frame_pool_bench.cpp` (empty — write the benchmark).

1. Write a test that constructs a `FramePool`, calls `acquire()` twice, and
   checks the two `PooledFrame`s have distinct, non-null `data()`.
2. Implement `FramePool`: preallocate `capacity` slots of `frame_size`
   bytes each and track free ones (a free list — a `std::vector<void*>` of
   free slots is enough to start). `acquire()` pops a free slot and wraps it
   in a `PooledFrame`; the pool's destructor frees the underlying storage.
3. Implement `PooledFrame`'s move ctor/assignment and destructor: on
   destruction (if it still owns a slot) it should call
   `pool_->release(data_)`, returning the slot to the free list.
4. Write a test that acquires all slots, releases one (by letting a
   `PooledFrame` go out of scope), and confirms a subsequent `acquire()`
   reuses that same address.
5. Write `frame_pool_bench.cpp`: acquire/release 100,000 times, and compare
   against a benchmark that does 100,000 `new`/`delete` of the same size.
   Run it:

       ./build/debug/part1_modern_cpp/memory_management/cvlab_memory_management_bench

6. Run the test under Valgrind or ASan and confirm zero leak warnings.

## 7. Alignment — verify and misuse it

Files: `alignment.hpp` (declared, no body) / `alignment.cpp` (empty — fill
in) / `alignment_test.cpp` (empty — write the test).

1. Implement `is_aligned(ptr, alignment)`: `reinterpret_cast<std::uintptr_t>(ptr) % alignment == 0`.
2. Implement `allocate_unaligned_floats(count)` with plain `new float[count]`,
   and `allocate_aligned_floats(count)` with `std::aligned_alloc(32, ...)`
   (remember the size passed to `aligned_alloc` must be a multiple of the
   alignment).
3. Write a test that allocates both and checks `is_aligned(ptr, 32)`.
   **Do not assert that the plain `new` buffer is misaligned** — measured
   on this machine, `new float[]` came back 32-byte aligned 16 times out
   of 16, so that assertion fails here, and it would be wrong anyway:
   nothing stops an allocator being *more* aligned than required. Assert
   what is actually guaranteed — the `aligned_alloc` buffer is 32-aligned,
   and `new` only promises `__STDCPP_DEFAULT_NEW_ALIGNMENT__` (16 here).
   To get a reliably misaligned pointer for the negative case, make one:
   `reinterpret_cast<float*>(reinterpret_cast<char*>(buf) + 4)`.
4. Remember to free the aligned buffer with `std::free`, not `delete[]`.
   Also round the size up: `std::aligned_alloc(32, 100)` returns **nullptr**
   on macOS (the C standard wants a multiple of the alignment), while glibc
   usually lets it through — a real portability difference between your two
   target machines.
5. Optional: the AVX step **cannot run on this machine** — `_mm256_load_ps`
   and `<immintrin.h>` are x86-only, and this is arm64. Either do it on the
   Ubuntu x86_64 box (compile with `-mavx`, watch the aligned load fault on
   a misaligned pointer), or use NEON locally (`<arm_neon.h>`,
   `vld1q_f32`) and note that it does *not* crash: on ARM, alignment is a
   performance concern for ordinary loads, not a correctness one. See
   `theory.pdf` §7.4.
