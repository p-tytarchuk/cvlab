// Task 5: memory leak - reproduce and catch it. See practise.md.

#pragma once

namespace cvlab::memory {

// TODO: an intentional leak (e.g. an overwritten pointer, or an exception
// thrown before delete).
void leak_memory();

}  // namespace cvlab::memory
