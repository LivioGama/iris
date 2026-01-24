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
    let config =
        cbindgen::Config::from_file("cbindgen.toml").expect("Failed to read cbindgen.toml");

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

    // Optional MediaPipe C++ bridge (feature-gated)
    if env::var("CARGO_FEATURE_MEDIAPIPE").is_ok() {
        let mp_dir = env::var("MEDIAPIPE_DIR")
            .expect("MEDIAPIPE_DIR must be set when building with --features mediapipe");
        let mp_include = PathBuf::from(&mp_dir).join("include");
        let mp_lib = PathBuf::from(&mp_dir).join("lib");

        cc::Build::new()
            .cpp(true)
            .file("mediapipe/mediapipe_bridge.cc")
            .include(mp_include)
            .flag_if_supported("-std=c++17")
            .define("MEDIAPIPE_AVAILABLE", None)
            .compile("mediapipe_bridge");

        println!("cargo:rustc-link-search=native={}", mp_lib.display());

        if let Ok(libs) = env::var("MEDIAPIPE_LINK_LIBS") {
            for lib in libs.split(',') {
                let trimmed = lib.trim();
                if !trimmed.is_empty() {
                    println!("cargo:rustc-link-lib={}", trimmed);
                }
            }
        } else {
            println!(
                "cargo:warning=MEDIAPIPE_LINK_LIBS not set; provide comma-separated libs to link"
            );
        }
    }

    // Link against macOS frameworks needed for camera access
    println!("cargo:rustc-link-lib=framework=AVFoundation");
    println!("cargo:rustc-link-lib=framework=CoreMedia");
    println!("cargo:rustc-link-lib=framework=CoreVideo");
    println!("cargo:rustc-link-lib=framework=Foundation");
}
