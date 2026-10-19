# Third-party notices

DockPin is independently implemented in Swift. Its session-event suppression
approach and level-based Dock window detection were informed by Lockdock:

- Project: https://github.com/mishamyrt/lockdock
- Revision reviewed: f5f667ee0019c6ed1bf6f4f20a807d66fe462ee1
- Relevant files: `crates/lockdock-mouse/native/mouse.c`,
  `crates/lockdock-daemon/src/display_lock.rs`,
  `crates/lockdock-display/native/display.c`,
  `crates/lockdock-daemon/src/relocation.rs`.

The original notice is retained below. No Lockdock binary or Rust runtime is
bundled. No commercial DockLock code or assets are included.

## Lockdock — MIT

Copyright 2026 Mikhael Khrustik <misha@myrt.co>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
