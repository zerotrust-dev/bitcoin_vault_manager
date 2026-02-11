use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use crate::error::CoreError;

/// Convert Rust string to C string pointer
pub fn to_c_string(s: &str) -> *mut c_char {
    match CString::new(s) {
        Ok(cs) => cs.into_raw(),
        Err(_) => CString::new("error: invalid string").unwrap().into_raw(),
    }
}

/// Convert C string pointer to Rust string
pub fn from_c_string(ptr: *const c_char) -> Result<String, CoreError> {
    if ptr.is_null() {
        return Err(CoreError::InvalidInput("null pointer".to_string()));
    }
    unsafe {
        CStr::from_ptr(ptr)
            .to_str()
            .map(|s| s.to_string())
            .map_err(|e| CoreError::InvalidInput(e.to_string()))
    }
}

/// Create JSON error response
pub fn error_response(error: CoreError) -> *mut c_char {
    let response = serde_json::json!({
        "error": true,
        "code": error.code(),
        "message": error.to_string(),
    });
    to_c_string(&response.to_string())
}

/// Create JSON success response
pub fn success_response<T: serde::Serialize>(data: T) -> *mut c_char {
    match serde_json::to_string(&data) {
        Ok(json) => to_c_string(&json),
        Err(e) => error_response(CoreError::SerializationError(e.to_string())),
    }
}
