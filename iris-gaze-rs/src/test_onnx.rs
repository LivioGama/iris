use ort::{session::Session, value::Tensor};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Try fixed model
    let mut session = Session::builder()?.commit_from_file("models/face_mesh_192x192_fixed.onnx")?;
    
    println!("Model loaded (fixed batch), {} inputs", session.inputs().len());
    
    // Create test tensors
    let input_data: Vec<f32> = vec![0.5; 1 * 3 * 192 * 192];
    let input_tensor = Tensor::from_array(([1usize, 3, 192, 192], input_data.into_boxed_slice()))?;
    
    let crop_x1: i32 = 100;
    let crop_y1: i32 = 100;
    let crop_width: i32 = 200;
    let crop_height: i32 = 200;
    
    let crop_x1_tensor: Tensor<i32> = Tensor::from_array(([1i64, 1i64], vec![crop_x1].into_boxed_slice()))?;
    let crop_y1_tensor: Tensor<i32> = Tensor::from_array(([1i64, 1i64], vec![crop_y1].into_boxed_slice()))?;
    let crop_width_tensor: Tensor<i32> = Tensor::from_array(([1i64, 1i64], vec![crop_width].into_boxed_slice()))?;
    let crop_height_tensor: Tensor<i32> = Tensor::from_array(([1i64, 1i64], vec![crop_height].into_boxed_slice()))?;
    
    println!("Running inference...");
    let outputs = session.run(ort::inputs![
        "input" => input_tensor,
        "crop_x1" => crop_x1_tensor,
        "crop_y1" => crop_y1_tensor,
        "crop_width" => crop_width_tensor,
        "crop_height" => crop_height_tensor,
    ])?;
    
    println!("SUCCESS with fixed model!");
    println!("Outputs: {}", outputs.len());
    
    Ok(())
}
