# JSON Module Documentation

The JSON module provides comprehensive JSON parsing, stringification, and manipulation capabilities for the MufiZ programming language.

## Overview

The JSON module allows you to:
- Parse JSON strings into MufiZ data structures
- Convert MufiZ values to JSON strings
- Validate JSON syntax
- Access and modify JSON object properties
- Handle various JSON data types (strings, numbers, booleans, arrays, objects, null)

## Functions

### `json_parse(json_string: String) -> Any`

Parses a JSON string and converts it into MufiZ data structures.

**Parameters:**
- `json_string`: A valid JSON string to parse

**Returns:**
- The parsed value as the appropriate MufiZ type:
  - JSON objects become hash tables (`#{}`)
  - JSON arrays become float vectors (`{}`) for numeric arrays, or the first element for mixed arrays
  - JSON strings become MufiZ strings
  - JSON numbers become integers or doubles
  - JSON booleans become MufiZ booleans
  - JSON null becomes `nil`

**Examples:**
```mufi
# Parse a JSON object
let obj = json_parse("{\"name\": \"John\", \"age\": 30}")
print(obj)  # Output: #{"name": "John", "age": 30}

# Parse a JSON array
let arr = json_parse("[1, 2, 3, 4, 5]")
print(arr)  # Output: {1, 2, 3, 4, 5}

# Parse primitive values
let str_val = json_parse("\"hello\"")     # "hello"
let num_val = json_parse("42")           # 42
let bool_val = json_parse("true")        # true
let null_val = json_parse("null")        # nil
```

### `json_stringify(value: Any) -> String`

Converts a MufiZ value to a JSON string representation.

**Parameters:**
- `value`: Any MufiZ value to convert to JSON

**Returns:**
- A JSON string representation of the value

**Examples:**
```mufi
# Stringify a hash table
let obj = #{"name": "Alice", "age": 25}
let json_str = json_stringify(obj)
print(json_str)  # Output: {"name":"Alice","age":25}

# Stringify a float vector
let arr = {1, 2, 3}
let json_arr = json_stringify(arr)
print(json_arr)  # Output: [1,2,3]

# Stringify primitive values
print(json_stringify("hello"))  # Output: "hello"
print(json_stringify(42))       # Output: 42
print(json_stringify(true))     # Output: true
print(json_stringify(nil))      # Output: null
```

### `json_is_valid(json_string: String) -> Bool`

Validates whether a string contains valid JSON syntax.

**Parameters:**
- `json_string`: A string to validate as JSON

**Returns:**
- `true` if the string is valid JSON, `false` otherwise

**Examples:**
```mufi
print(json_is_valid("{\"valid\": true}"))      # true
print(json_is_valid("{invalid json}"))         # false
print(json_is_valid("42"))                     # true
print(json_is_valid("'single quotes'"))       # false
```

### `json_pretty(value: Any) -> String`

Converts a value to a pretty-printed JSON string. Currently functions the same as `json_stringify`.

**Parameters:**
- `value`: Any MufiZ value to convert to pretty-printed JSON

**Returns:**
- A formatted JSON string (currently same as regular stringify)

**Examples:**
```mufi
let obj = #{"name": "John", "data": #{"id": 123}}
print(json_pretty(obj))
# Future versions may include proper indentation and formatting
```

### `json_get(json_object: Object, key: String) -> Any`

Retrieves a value from a JSON object (hash table) by key.

**Parameters:**
- `json_object`: A hash table object (typically from `json_parse`)
- `key`: The key to look up in the object

**Returns:**
- The value associated with the key, or `nil` if the key doesn't exist

**Examples:**
```mufi
let person = json_parse("{\"name\": \"Bob\", \"age\": 35}")
let name = json_get(person, "name")     # "Bob"
let age = json_get(person, "age")       # 35
let missing = json_get(person, "city")  # nil
```

### `json_set(json_object: Object, key: String, value: Any) -> Object`

Sets a value in a JSON object (hash table) by key.

**Parameters:**
- `json_object`: A hash table object to modify
- `key`: The key to set in the object
- `value`: The value to associate with the key

**Returns:**
- The modified object (same as input)

**Examples:**
```mufi
let data = json_parse("{\"count\": 0}")
json_set(data, "count", 42)
json_set(data, "status", "active")
print(json_stringify(data))  # {"count":42,"status":"active"}
```

## Data Type Mapping

| JSON Type | MufiZ Type | Notes |
|-----------|------------|-------|
| `object` | Hash Table (`#{}`) | JSON objects become MufiZ hash tables |
| `array` | Float Vector (`{}`) | Numeric arrays only; mixed arrays return first element |
| `string` | String | Direct mapping |
| `number` | Int or Double | Integers for whole numbers, doubles for decimals |
| `boolean` | Bool | Direct mapping (`true`/`false`) |
| `null` | Nil | Direct mapping |

## Usage Examples

### Basic JSON Processing

```mufi
# Parse JSON from a string
let config_json = "{\"debug\": true, \"port\": 8080, \"name\": \"MyApp\"}"
let config = json_parse(config_json)

# Access values
let debug_mode = json_get(config, "debug")
let port = json_get(config, "port")
let app_name = json_get(config, "name")

print("Debug mode: " + debug_mode)
print("Port: " + port)
print("App name: " + app_name)
```

### Working with Arrays

```mufi
# Parse a numeric array
let numbers_json = "[1, 2, 3, 4, 5]"
let numbers = json_parse(numbers_json)
print("Numbers: " + json_stringify(numbers))

# Create and stringify an array
let fruits = {1.1, 2.2, 3.3}  # Float vector
let fruits_json = json_stringify(fruits)
print("Fruits JSON: " + fruits_json)
```

### Configuration Management

```mufi
# Load configuration
let config_str = "{\"database\": {\"host\": \"localhost\", \"port\": 5432}, \"logging\": true}"
let config = json_parse(config_str)

# Modify configuration
json_set(config, "version", "1.0.0")
json_set(config, "environment", "production")

# Save back to JSON
let updated_config = json_stringify(config)
print("Updated config: " + updated_config)
```

### API Response Processing

```mufi
# Simulate API response
let api_response = "{\"status\": \"success\", \"data\": {\"id\": 123, \"email\": \"user@example.com\"}, \"timestamp\": 1634567890}"

if json_is_valid(api_response) {
    let response = json_parse(api_response)
    
    let status = json_get(response, "status")
    let data = json_get(response, "data")
    
    print("Status: " + status)
    
    if status == "success" {
        let user_id = json_get(data, "id")
        let email = json_get(data, "email")
        print("User ID: " + user_id)
        print("Email: " + email)
    }
} else {
    print("Invalid API response")
}
```

## Error Handling

The JSON module handles various error conditions gracefully:

- **Invalid JSON syntax**: `json_parse` returns `nil` and may log an error
- **Missing keys**: `json_get` returns `nil` for non-existent keys
- **Type mismatches**: Functions that expect objects will return errors for other types
- **Memory allocation failures**: Handled internally with appropriate error messages

## Best Practices

1. **Always validate JSON before parsing**:
   ```mufi
   if json_is_valid(json_string) {
       let data = json_parse(json_string)
       # Process data...
   } else {
       print("Invalid JSON received")
   }
   ```

2. **Check for nil values when accessing properties**:
   ```mufi
   let value = json_get(obj, "key")
   if value != nil {
       # Use the value...
   }
   ```

3. **Use meaningful variable names for clarity**:
   ```mufi
   let user_data = json_parse(user_json)
   let username = json_get(user_data, "username")
   ```

4. **Handle different data types appropriately**:
   ```mufi
   let parsed_value = json_parse(json_str)
   let value_type = what_is(parsed_value)
   print("Parsed type: " + value_type)
   ```

## Limitations

- **Array handling**: Mixed-type arrays are not fully supported; only the first element is returned
- **Complex numbers**: Complex numbers are converted to string representations in JSON
- **Pretty printing**: Currently the same as regular stringify; future versions may include formatting
- **Deep nesting**: Very deeply nested objects may cause performance issues
- **Circular references**: Not detected or handled; may cause infinite loops

## Integration with MufiZ Features

The JSON module integrates seamlessly with other MufiZ features:

- **Hash tables**: JSON objects map directly to MufiZ hash tables
- **Float vectors**: JSON arrays of numbers become float vectors
- **Type system**: All MufiZ types can be converted to JSON representations
- **String operations**: JSON strings work with all MufiZ string functions
- **Error handling**: Follows MufiZ error handling conventions

## Future Enhancements

Planned improvements for future versions:

- **Pretty printing**: Proper indentation and formatting for `json_pretty`
- **Array support**: Better handling of mixed-type arrays
- **Streaming parsing**: Support for large JSON files
- **JSON Schema validation**: Validate JSON against schemas
- **Path-based access**: JSONPath-like syntax for nested access
- **Custom serialization**: Hooks for custom object serialization

For more information about the MufiZ language and its standard library, see the main documentation.