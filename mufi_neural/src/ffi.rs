//! C FFI — exposes `complete` and `diagnose` as `extern "C"` functions so
//! Swift (and any C-compatible caller) can link against `libmufi_neural.dylib`.
//!
//! # Swift usage (after building the dylib)
//!
//! ```swift
//! import Foundation
//!
//! // Bridging header must declare the C signatures from include/mufi_neural.h
//! let json = mufi_complete(
//!     "/path/to/tokenizer.json",
//!     "/path/to/epoch_020.safetensors",
//!     "var x = 10; var y = ",
//!     8
//! )!
//! let completions = String(cString: json)
//! mufi_free_string(json)
//! ```

#![allow(clippy::not_unsafe_ptr_arg_deref)]

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;

use crate::infer::{LoadedModel, complete, diagnose};

// ------------------------------------------------------------------ //
// Helpers
// ------------------------------------------------------------------ //

/// Convert a `*const c_char` to a Rust `&str`.  Returns `""` on null/invalid.
unsafe fn c_str<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        return "";
    }
    CStr::from_ptr(ptr).to_str().unwrap_or("")
}

/// Allocate a `CString` on the heap and return a raw pointer.
/// The caller **must** pass the pointer back to `mufi_free_string`.
fn to_c_string(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(cs) => cs.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

// ------------------------------------------------------------------ //
// Public C API
// ------------------------------------------------------------------ //

/// Return the top-`n` completion candidates for `source` as a JSON string.
///
/// # Parameters
/// - `tokenizer_path` — path to `tokenizer.json`
/// - `checkpoint_path` — path to `epoch_NNN.safetensors`
/// - `source`         — MufiZ source text (UTF-8)
/// - `top_n`          — number of candidates (1–32)
///
/// # Returns
/// Heap-allocated JSON string; free with `mufi_free_string`.
/// Returns NULL on error.
///
/// # Safety
/// All pointer arguments must be valid, null-terminated UTF-8 C strings (or NULL).
#[no_mangle]
pub unsafe extern "C" fn mufi_complete(
    tokenizer_path: *const c_char,
    checkpoint_path: *const c_char,
    source: *const c_char,
    top_n: u32,
) -> *mut c_char {
    let tok = PathBuf::from(c_str(tokenizer_path));
    let ckpt = PathBuf::from(c_str(checkpoint_path));
    let src = c_str(source).to_string();
    let n = top_n.max(1).min(32) as usize;

    let result = (|| -> anyhow::Result<String> {
        let model = LoadedModel::load(&tok, &ckpt, false)?;
        let items = complete(&model, &src, n)?;
        Ok(serde_json::to_string(&items)?)
    })();

    match result {
        Ok(json) => to_c_string(json),
        Err(e) => {
            eprintln!("[mufi_neural FFI] complete error: {e}");
            std::ptr::null_mut()
        }
    }
}

/// Return per-token diagnostic items for `source` as a JSON string.
///
/// # Parameters
/// - `tokenizer_path`  — path to `tokenizer.json`
/// - `checkpoint_path` — path to `epoch_NNN.safetensors`
/// - `source`          — MufiZ source text (UTF-8)
///
/// # Returns
/// Heap-allocated JSON string; free with `mufi_free_string`.
/// Returns NULL on error.
///
/// # Safety
/// All pointer arguments must be valid, null-terminated UTF-8 C strings (or NULL).
#[no_mangle]
pub unsafe extern "C" fn mufi_diagnose(
    tokenizer_path: *const c_char,
    checkpoint_path: *const c_char,
    source: *const c_char,
) -> *mut c_char {
    let tok = PathBuf::from(c_str(tokenizer_path));
    let ckpt = PathBuf::from(c_str(checkpoint_path));
    let src = c_str(source).to_string();

    let result = (|| -> anyhow::Result<String> {
        let model = LoadedModel::load(&tok, &ckpt, false)?;
        let items = diagnose(&model, &src)?;
        Ok(serde_json::to_string(&items)?)
    })();

    match result {
        Ok(json) => to_c_string(json),
        Err(e) => {
            eprintln!("[mufi_neural FFI] diagnose error: {e}");
            std::ptr::null_mut()
        }
    }
}

/// Free a string returned by `mufi_complete` or `mufi_diagnose`.
///
/// # Safety
/// `ptr` must be a pointer previously returned by one of the above functions,
/// or NULL (no-op).
#[no_mangle]
pub unsafe extern "C" fn mufi_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}
