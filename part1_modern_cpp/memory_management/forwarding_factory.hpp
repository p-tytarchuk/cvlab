// Task 3: std::forward - a generic factory. See practise.md.

#pragma once

#include <utility>

namespace cvlab::memory {

// TODO: forward args into T's constructor with std::forward and confirm the
// right overload (lvalue- vs rvalue-taking) gets called for each case.
// A template must be defined where it is used, so define this here once
// you write it - there is deliberately no body yet.
template <typename T, typename... Args>
T create(Args&&... args);

}  // namespace cvlab::memory
