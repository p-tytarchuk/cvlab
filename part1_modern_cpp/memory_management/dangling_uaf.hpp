// Task 4: dangling pointer / use-after-free - reproduce it on purpose. See
// practise.md.

#pragma once

namespace cvlab::memory {

// TODO: return a pointer to a stack local - a dangling pointer bug.
int* dangling_pointer();

// TODO: delete then dereference - a use-after-free.
void use_after_free();

}  // namespace cvlab::memory
