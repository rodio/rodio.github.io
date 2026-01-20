---
title: "Yet Another Explanation of Lifetimes in Rust"
...

This post is my attempt to understand Rust's lifetimes deeper.

## What is this all about?

At first glance, writing a piece of code to compare lengths of two strings can seem trivial. Yet, it is not
trivial in Rust, and if other non-garbage collected languages make it seem trivial, they're probably deceiving us a bit.

In fact, comparing two strings is used as a classic example to explain lifetimes, a fairly complex concept in Rust.

The task is to write a function to compare two strings and return the longer one. So how hard could it be? Let's
start with the function that makes the comparison:

```rust
// won't compile
fn longer(x: &str, y: &str) -> &str {
    if x.len() > y.len() { x } else { y }
}
```

We have two string slices (`&str`s) as arguments (references to string data) and return one of
them. Seems like a reasonable choice of argument and return types if we don't want to allocate any memory. We're just operating on
the references and the consumers of our function would need to allocate.

Yet, the Rust compiler would not let us compile it:

```rust
error[E0106]: missing lifetime specifier
 --> src/main.rs:1:32
  |
1 | fn longer(x: &str, y: &str) -> &str {
  |              ----     ----     ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value, but the signature does not say whether it is borrowed from `x` or `y`
help: consider introducing a named lifetime parameter
  |
1 | fn longer<'a>(x: &'a str, y: &'a str) -> &'a str {
  |          ++++     ++          ++          ++
```

The solution is to add a named lifetime parameter as the compiler clearly pointed out. But why do we need this
complication? Well, in garbage collected languages there's no such problem, but consider this:

```rust
fn longer<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

// won't compile
pub fn main() {
  let x = String::from("abc");
  let result;
  {
    let y = String::from("abcd");
    result = longer(&x, &y);
  } // y is dropped here, result is now a dangling pointer
  println!("The longer one is: {}", result); // could potentially print some garbage 
}
``` 

This one fails to compile with the following error:

```rust
error[E0597]: `y` does not live long enough
  --> src/main.rs:11:29
   |
10 |         let y = String::from("abcd");
   |             - binding `y` declared here
11 |         result = longer(&x, &y);
   |                             ^^ borrowed value does not live long enough
12 |     }
   |     - `y` dropped here while still borrowed
13 |     println!("The longer one is: {}", result); // could potentially print some garbage
   |                                       ------ borrow later used here
```

We get the dangling pointer because `y` was deallocated. We're not using `y` directly after the deallocation but the
compiler seems to be able to connect `result` and `y` because we added the lifetime parameter. 

When we were writing the `longer` function the compiler asked us to specify for how long should both the arguments and
the return value be alive. With these three `'a`s we said said that we want the arguments to live at least as long as the
return value. And indeed, we've already seen that they can't live less, and here is the example that they can live
longer (compiles):

```rust
fn longer<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

pub fn main() {
    let x = String::from("abc");
    {
        let y = String::from("abcd");
        let result = longer(&x, &y);
        println!("The longer one is: {}", result);
    } // y and result are dropped here
    println!("The first one is: {}", x); // x is still alive
}
```

## What else can we do with lifetimes? 

Let's say we want to change our comparison function so that it either returns the first argument if it is longer, or
a static string otherwise. We could just change the return value and everything would work:

```rust
fn longer<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        "the second one"
    }
}
```

But we can notice that the second parameter is only used for comparison, but never returned, so its lifetime does not
matter as long as the reference is valid at the time when this function is called. So we can remove the explicit
lifetime annotations for the second argument so that the callers of our function do not need to worry about the
lifetime of the second argument and have more freedom:

```rust
fn longer<'a>(x: &'a str, y: &str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        "the second one"
    }
}
```

The explicit lifetime of the return value stays because the function can potentially return the reference to the first
argument.

In fact, we could also add another lifetime `'b` like this (that's what Rust probably does under the hood anyway):

```rust
fn longer<'a, 'b>(x: &'a str, y: &'b str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        "the second one"
    }
}
```

The lifetime `'b` does not appear in the return value and this illustrates the fact that the return value does not
depend on the the lifetime of the second argument more explicitly.

## What is the beauty of it?

I probably can call this an example of the "shift-left" attitude. Rather than discovering problems at runtime (which
would be fully "shift-right"), we catch them at compile time.

But notice _how_ early these checks occur: the `longer` function would not even compile without explicit runtime
annotations, even before we write the main function. Lifetimes help us to think about the correctness and the consumers
of our code in advance.

Could innovations like this make our software safer, more robust and less annoying? I hope so.
