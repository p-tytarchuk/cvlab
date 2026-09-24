// Proves the GoogleTest harness itself works: it compiles, links against the
// locally built gtest_main, runs, and reports both assertions and fixtures.
// If this fails, nothing else in the repo can be trusted.

#include <gtest/gtest.h>

#include <string>
#include <vector>

TEST(GTestSmoke, AssertionsWork) {
  EXPECT_EQ(2 + 2, 4);
  EXPECT_NE(std::string{"cvlab"}, std::string{"clvab"});
  EXPECT_TRUE(true);
}

TEST(GTestSmoke, ContainerMatchersWork) {
  const std::vector<int> v{1, 2, 3};
  ASSERT_EQ(v.size(), 3u);
  EXPECT_EQ(v.front(), 1);
  EXPECT_EQ(v.back(), 3);
}

// A fixture, because gtest_discover_tests() must enumerate these correctly for
// ctest to list cases individually.
class GTestSmokeFixture : public ::testing::Test {
 protected:
  void SetUp() override { value_ = 42; }
  int value_{0};
};

TEST_F(GTestSmokeFixture, SetUpRan) { EXPECT_EQ(value_, 42); }

// C++20 must actually be on, not silently downgraded.
TEST(GTestSmoke, Cxx20IsEnabled) {
  static_assert(__cplusplus >= 202002L, "cvlab requires C++20");
  SUCCEED();
}
