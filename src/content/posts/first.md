+++
title = "A Detour: winit + WGPU, coming soon ..."
date = 2025-05-19
+++

Sometimes I read some code that intuitively should not work, yet it is working fine and I just can't.
Once in a while, I go and dig deeper to see why.

I take some pride in these moments of inquisitiveness.

Maybe that's because nurturing the curiosity that enables them feels like a rebellion -- instead of working on items
from to-do lists, thinking about deliverables, milestones, KPIs, ROIs, synergies, and otherwise making the world a
better place, I take a scenic detour through the mountains of code.

This post documents one of these detours.

## Setting the scene

[winit](https://docs.rs/winit/latest/winit/) is a Rust crate (library) that help with creating windows on different
operating systems and platforms.

[wgpu](https://wgpu.rs) is a graphics library for Rust based on the [WebGPU API](https://www.w3.org/TR/webgpu/).
Applications using wgpu can run natively on Vulkan, Metal, DirectX 12, and OpenGL ES, and in browsers via WebAssembly.

You begin by creating a window, using winit. In order to draw something on it, you first need to create a wgpu surface.

This looks something like this:
```rust
let window = winit_event_loop.create_window(window_attributes).unwrap();
let surface = wgpu_instance.create_surface(&window).unwrap();
````

By looking directly at WGPU's `Cargo.toml` (where its dependencies are declared) we can see that wgpu does not have
winit as a dependecy. Winit does not 'know' about wgpu either.

*How is it possible that a method from one crate takes an instance of a struct from another (seemingly unrelated)
crate?*

So let's have a look starting from WGPU's perspective.

## Part One -- Surface Target

The signature of WGPU's `create_surface(...)` method from above is as follows:
```rust
pub fn create_surface<'window>(
    &self,
    target: impl Into<SurfaceTarget<'window>>,
) -> Result<Surface<'window>, CreateSurfaceError> 
```

Since we're feeding winit's window to wgpu's `create_surface(...)` it means that this mystery would be solved,
*if we could see that `winit::Window` is somehow related to `wgpu::SurfaceTarget`.*

Even not knowing much about Rust and ignoring the `'window`
[lifetimes](https://doc.rust-lang.org/book/ch10-03-lifetime-syntax.html), I hope it is intuitive enough that
`create_surface(...)` takes something that can be converted `Into` `SurfaceTarget`. So one might think that there must
be code somewhere that implements this `Into` trait (e.g. interface) or
[its counterpart](https://doc.rust-lang.org/rust-by-example/conversion/from_into.html), `From`, for `winit` `Window` 
allowing us to convert the winit window into `SurfaceTarget`.

But obviously, there's no point in searching for something like `impl From<winit::Window> for wgpu::SurfaceTarget` or
`impl Into<wgpu::SurfaceTarget> for winit::Window` in any of these libraries' codebases, because they don't "know"
about each other.

Yet, we can easily find this [blanket implementation](https://doc.rust-lang.org/book/ch10-02-traits.html) in wgpu's
codebase:

```rust
impl<'a, T> From<T> for SurfaceTarget<'a>
where
    T: WindowHandle + 'a,
{
    fn from(window: T) -> Self {
        Self::Window(Box::new(window))
    }
}
```

It says that we can convert _from_ anything that implements something called `WindowHandle` _into_ `SurfaceTarget` 
Given that Rust implements `Into` for us when it has `From`, it means that anything that implements `WindowHandle`
can be converted _into_ surface target. So behind the scenes, there is
`impl<T> Into<SurfaceTarget> for T where T: WindowHandle`.

So we now can cut the middleman called `SurfaceTarget` and our mystery would be solved *if we could prove that
`winit::Window` is somehow related to `wgpu::WindowHandle`.*

## Part Two -- Window Handle

So what kind of thing this `wgpu::WindowHandle` is? Let's go to its definition:

```rust
/// Super trait for window handles as used in [`SurfaceTarget`].
pub trait WiindowHandle: HasWindowHandle + HasDisplayHandle + WasmNotSendSync {}
impl<T> WindowHandle for T where T: HasWindowHandle + HasDisplayHandle + WasmNotSendSync {}
```

So this blanket implementation says that anything can be counted as a `WindowHandle` as long as it implements the other three traits.
Not much, but this is kind of a big thing here because while `WindowHandle` is coming from the crate `wgpu`,
`HasWindowHandle` is from another crate called `raw_window_handle`.

Now the `raw_window_handle` crate seems to be the bridge connecting these two crates (`winit` and `wgpu`) and the key
to solving this little mystery, because this dependency is included in both of these crates' `Cargo.toml` files

To have undeniable proofs we must now only see that `winit`s `Window` implements `HasWindowHandle` and
`HasDisplayHandle` and `WasmNotSendSync`

## Part Three -- winit and `raw_window_handle`

from the point of view of winit
```rust
#[cfg(feature = "rwh_06")]
impl rwh_06::HasWindowHandle for Window {
    fn window_handle(&self) -> Result<rwh_06::WindowHandle<'_>, rwh_06::HandleError> {
      // snip
    }
}

#[cfg(feature = "rwh_06")]
impl rwh_06::HasDisplayHandle for Window {
    fn display_handle(&self) -> Result<rwh_06::DisplayHandle<'_>, rwh_06::HandleError> {
      // snip
    }
}
```
