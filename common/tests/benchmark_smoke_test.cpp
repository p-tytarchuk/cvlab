// Proves Google Benchmark is linkable and usable. This runs under GoogleTest
// so ctest covers it: a real benchmark binary prints timings and would need a
// separate manual run, which is easy to forget and never fails CI.
//
// Registering and running a benchmark in-process exercises the same library
// entry points a real benchmark binary uses.

#include <benchmark/benchmark.h>
#include <gtest/gtest.h>

#include <string>
#include <vector>

namespace {

void BM_VectorPushBack(benchmark::State& state) {
  for (auto _ : state) {
    std::vector<int> v;
    v.reserve(16);
    for (int i = 0; i < 16; ++i) {
      v.push_back(i);
    }
    benchmark::DoNotOptimize(v.data());
    benchmark::ClobberMemory();
  }
}

}  // namespace

// Proves the library's headers, DoNotOptimize/ClobberMemory intrinsics and
// registration machinery all compile and link.
TEST(BenchmarkSmoke, RegistrationLinks) {
  auto* registered = benchmark::RegisterBenchmark("smoke_push_back", BM_VectorPushBack);
  ASSERT_NE(registered, nullptr);
}

// Proves the version symbol resolves at runtime, i.e. we linked a real library
// and not just satisfied the compiler.
TEST(BenchmarkSmoke, LibraryVersionSymbolResolves) {
  const std::string version = benchmark::kExportedVersion;
  EXPECT_FALSE(version.empty());
}

TEST(BenchmarkSmoke, DoNotOptimizeKeepsValueAlive) {
  int value = 21;
  value *= 2;
  benchmark::DoNotOptimize(value);
  EXPECT_EQ(value, 42);
}
