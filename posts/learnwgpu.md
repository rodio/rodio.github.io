---
title: "WebGPU Demo"
...

<small>Jan 21, 2026</small>

Move cursor (slide on mobile) over it:

<canvas id="canvas" style="background-color: black; width: 100%; max-width:400px; height: 20%; max-height: 100px; display: block; padding: 0;">
</canvas>
<script type="module">
      import init from "../static/learnwgpu.js";
      init()
      .catch((error) => {
        if (error.message.startsWith("Using exceptions for control flow,")) {
          console.log("This is not actually an error:", error);
        } else {
          throw error;
        }
      })
      .then(() => {
        console.log("WASM Loaded");
      });
</script>

This thing is done in Rust using the [wgpu](https://crates.io/crates/wgpu) crate.
[This is the tutorial I used](https://sotrh.github.io/learn-wgpu/) and here is
[the source code](https://github.com/rodio/rust-play/tree/main/learnwgpu)
