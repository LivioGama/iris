//! Build script for iris-gaze crate
//!
//! This script generates C headers using cbindgen for Swift FFI integration.

use std::env;
use std::path::PathBuf;

fn main() {
    // Get the crate directory
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    // Output directory for generated headers
    let out_dir = PathBuf::from(&crate_dir).join("include");
    std::fs::create_dir_all(&out_dir).ok();

    // Generate C header using cbindgen
    let config = cbindgen::Config::from_file("cbindgen.toml")
        .expect("Failed to read cbindgen.toml");

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_config(config)
        .generate()
        .expect("Failed to generate C bindings")
        .write_to_file(out_dir.join("iris_gaze.h"));

    // Tell Cargo to re-run if source files change
    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=src/types.rs");
    println!("cargo:rerun-if-changed=cbindgen.toml");

    // Link against macOS frameworks needed for camera access
    println!("cargo:rustc-link-lib=framework=AVFoundation");
    println!("cargo:rustc-link-lib=framework=CoreMedia");
    println!("cargo:rustc-link-lib=framework=CoreVideo");
    println!("cargo:rustc-link-lib=framework=Foundation");
}
