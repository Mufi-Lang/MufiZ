// Feature flags for MufiZ standard library modules
// These can be set at compile time to enable/disable functionality

pub const enable_fs = true;
pub const enable_net = false;
pub const enable_curl = false;
pub const enable_matrix = true;
pub const enable_debug = true;
pub const enable_profiling = false;

// Feature configuration struct
pub const FeatureConfig = struct {
    enable_fs: bool = true,
    enable_net: bool = false,
    enable_curl: bool = false,
    enable_matrix: bool = true,
    enable_debug: bool = true,
    enable_profiling: bool = false,
};

// Default configuration
pub const default_config = FeatureConfig{};

// Get feature status as string for debugging
pub fn getFeatureStatus() []const []const u8 {
    return &[_][]const u8{
        if (enable_fs) "filesystem: enabled" else "filesystem: disabled",
        if (enable_net) "network: enabled" else "network: disabled",
        if (enable_curl) "curl: enabled" else "curl: disabled",
        if (enable_matrix) "matrix: enabled" else "matrix: disabled",
        if (enable_debug) "debug: enabled" else "debug: disabled",
        if (enable_profiling) "profiling: enabled" else "profiling: disabled",
    };
}
