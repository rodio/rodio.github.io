---
title: "Winit and WGPU"
...

[winit](https://docs.rs/winit/latest/winit/) is a Rust crate (library) that helps with creating windows on different
operating systems and platforms.

[wgpu](https://wgpu.rs) is a graphics library for Rust based on the [WebGPU API](https://www.w3.org/TR/webgpu/).
Applications built with it can run natively on Vulkan, Metal, DirectX 12, OpenGL ES, and in browsers via WebAssembly.

You begin by creating a window using winit. To draw something on it, you first need to create a wgpu surface.

This looks something like this:
```rust
let window = winit_event_loop.create_window(window_attributes).unwrap();
let surface = wgpu_instance.create_surface(&window).unwrap();
```

By looking directly at wgpu's `Cargo.toml` (where its dependencies are declared) we can see that wgpu does not have
winit as a dependency. Likewise, winit does not "know" about wgpu either.

*How is it possible that a method from one crate takes an instance of a struct from another (seemingly unrelated)
crate?*

So, let's have a look starting from wgpu's perspective.

## Part One: `SurfaceTarget`

Since we're feeding winit's window to wgpu's `create_surface(...)`, this mystery would be solved,
*if we could see that `winit::Window` is somehow related to `wgpu::SurfaceTarget`.*

The signature of wgpu's `create_surface(...)` method from above is as follows:
```rust
pub fn create_surface<'window>(
    &self,
    target: impl Into<SurfaceTarget<'window>>,
) -> Result<Surface<'window>, CreateSurfaceError> 
```

Even without knowing much about Rust—and ignoring the `'window`
[lifetimes](https://doc.rust-lang.org/book/ch10-03-lifetime-syntax.html)— it is hopefully intuitive that
`create_surface(...)` takes something that can be converted `Into` `SurfaceTarget`. So one might expect to find an
implementation of this `Into` trait (i.e. interface) for a winit `Window` (or
[its counterpart](https://doc.rust-lang.org/rust-by-example/conversion/from_into.html), `From`), 
allowing us to convert the winit window into `SurfaceTarget`.

But obviously, there's no point in searching for something like `impl From<winit::Window> for wgpu::SurfaceTarget` or
`impl Into<wgpu::SurfaceTarget> for winit::Window` in any of these libraries' codebases, because they don't "know"
about each other.

Yet we can easily find this [blanket implementation](https://doc.rust-lang.org/book/ch10-02-traits.html) in wgpu's
codebase:

```{.rust}
impl<'a, T> From<T> for SurfaceTarget<'a>
where
    T: WindowHandle + 'a,
{
    fn from(window: T) -> Self {
        // snip
    }
}
````

It says that we can convert _from_ anything that implements something called `WindowHandle` _into_ `SurfaceTarget`.
And because Rust implements `Into` for us when it has `From`, anything that implements `WindowHandle`
can be converted _into_ surface target. So behind the scenes, there is
`impl<T> Into<SurfaceTarget> for T where T: WindowHandle`.

So we now can cut out the middleman—`SurfaceTarget`—and our mystery would be solved *if we could see that
`winit::Window` is somehow related to `wgpu::WindowHandle`.*

## Part Two: `WindowHandle`

So what kind of thing is `wgpu::WindowHandle`? Let's go to its definition:

```rust
/// Super trait for window handles as used in [`SurfaceTarget`].
pub trait WindowHandle: HasWindowHandle + HasDisplayHandle + WasmNotSendSync {}
impl<T> WindowHandle for T where T: HasWindowHandle + HasDisplayHandle + WasmNotSendSync {}
```
This blanket implementation means that any type can be treated as a WindowHandle as long as it implements the three
required traits. That's a big thing because while `WindowHandle` comes from the `wgpu` create,
`HasWindowHandle` is from another crate called `raw_window_handle`.

Now the `raw_window_handle` crate seems to be the bridge connecting these two crates (`winit` and `wgpu`) and the key
to solving this little mystery—since both crates include it as a dependency in their Cargo.toml files.

We must now only verify that `winit`'s `Window` implements `HasWindowHandle` and `HasDisplayHandle` and
`WasmNotSendSync`

## Part Three: `HasWindowHandle` + `HasDisplayHandle` + `WasmNotSendSync`

`HasWindowHandle` and `HasDisplayHandle` are relatively straightforward to find in `winit`'s codebase'(`rwh_06` is an
alias for raw_window_handle version 0.6):

```rust
impl rwh_06::HasWindowHandle for Window {
    fn window_handle(&self) -> Result<rwh_06::WindowHandle<'_>, rwh_06::HandleError> {
      // snip
    }
}

impl rwh_06::HasDisplayHandle for Window {
    fn display_handle(&self) -> Result<rwh_06::DisplayHandle<'_>, rwh_06::HandleError> {
      // snip
    }
}
```
   
To examine the implementation for `WasmNotSendSync` we're going to need to go to go back to `wgpu`'s codebase' and
(ignoring the conditional compilation attributes for simplicity) there we can find this blanket implementations:
```rust 
// 1:
pub trait WasmNotSendSync: WasmNotSend + WasmNotSync {}
// 2:
impl<T: WasmNotSend + WasmNotSync> WasmNotSendSync for T {}

// 3:
pub trait WasmNotSend {}
// 4:
impl<T> WasmNotSend for T {}

// 5:
pub trait WasmNotSync {}
impl<T> WasmNotSync for T {}
```

So, we've got:
1. `WasmNotSendSync` is obviously `WasmNotSend + WasmNotSync`.
2. Anything that implements `WasmNotSend` and `WasmNotSync`
automatically implements `WasmNotSendSync`
3. `WasmNotSend` is just a marker trait 
4. Anything can be `WasmNotSend` since there is this blanket implementation.
5. Anything can be `WasmNotSync` for the same reasons.

Well, it seems like **every type** implements all these three traits...

