const std = @import("std");
const FloatVector = @import("../src/objects/fvec.zig").FloatVector;
const testing = std.testing;

test "FloatVector dynamic resizing" {
    // Initialize with small capacity
    var vec = FloatVector.init(2);
    defer vec.deinit();

    try testing.expectEqual(@as(usize, 2), vec.size);
    try testing.expectEqual(@as(usize, 0), vec.count);

    // Add elements to trigger resize
    vec.push(1.0);
    vec.push(2.0);
    vec.push(3.0); // This should trigger resize
    vec.push(4.0);
    vec.push(5.0);

    try testing.expectEqual(@as(usize, 5), vec.count);
    try testing.expect(vec.size >= 5);
    try testing.expectEqual(@as(f64, 1.0), vec.data[0]);
    try testing.expectEqual(@as(f64, 5.0), vec.data[4]);
}

test "FloatVector memory management" {
    // Test empty vector
    var empty = FloatVector.initEmpty();
    defer empty.deinit();
    
    try testing.expectEqual(@as(usize, 0), empty.size);
    
    // Add an element to trigger initial allocation
    empty.push(42.0);
    try testing.expectEqual(@as(usize, 1), empty.count);
    try testing.expect(empty.size >= 1);
    
    // Test shrinkToFit
    var vec = FloatVector.init(100);
    defer vec.deinit();
    
    try testing.expectEqual(@as(usize, 100), vec.size);
    
    // Add just a few elements
    vec.push(1.0);
    vec.push(2.0);
    vec.push(3.0);
    
    // Shrink capacity
    vec.shrinkToFit(2); // count(3) + 2 extra
    try testing.expectEqual(@as(usize, 5), vec.size);
}

test "FloatVector batch operations" {
    var vec = FloatVector.new();
    defer vec.deinit();
    
    // Test pushMany
    const values = [_]f64[ 1.0, 2.0, 3.0, 4.0, 5.0 ];
    vec.pushMany(&values);
    
    try testing.expectEqual(@as(usize, 5), vec.count);
    try testing.expectEqual(@as(f64, 1.0), vec.data[0]);
    try testing.expectEqual(@as(f64, 5.0), vec.data[4]);
    
    // Test reserve
    vec.reserve(20);
    try testing.expect(vec.size >= 20);
    
    // Ensure data is preserved
    try testing.expectEqual(@as(usize, 5), vec.count);
    try testing.expectEqual(@as(f64, 3.0), vec.data[2]);
}

test "FloatVector insert and remove" {
    var vec = FloatVector.init(4);
    defer vec.deinit();
    
    vec.push(1.0);
    vec.push(3.0);
    vec.push(4.0);
    
    // Insert at middle
    vec.insert(1, 2.0);
    
    try testing.expectEqual(@as(usize, 4), vec.count);
    try testing.expectEqual(@as(f64, 1.0), vec.data[0]);
    try testing.expectEqual(@as(f64, 2.0), vec.data[1]);
    try testing.expectEqual(@as(f64, 3.0), vec.data[2]);
    try testing.expectEqual(@as(f64, 4.0), vec.data[3]);
    
    // Insert when full to test resize
    vec.insert(4, 5.0);
    try testing.expectEqual(@as(usize, 5), vec.count);
    try testing.expect(vec.size >= 5);
    try testing.expectEqual(@as(f64, 5.0), vec.data[4]);
    
    // Test remove
    _ = vec.remove(1); // Remove 2.0
    try testing.expectEqual(@as(usize, 4), vec.count);
    try testing.expectEqual(@as(f64, 1.0), vec.data[0]);
    try testing.expectEqual(@as(f64, 3.0), vec.data[1]);
}