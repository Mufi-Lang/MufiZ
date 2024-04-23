# MufiZ Standard Library

## Math

- [X] `log2`
  - Return Type: double
  - Parameters: double
- [X] `log10`
  - Return Type: double
  - Parameters: double
- [X] `sin`
  - Return Type: double
  - Parameters: double
- [X] `cos`
  - Return Type: double
  - Parameters: double
- [X] `tan`
  - Return Type: double
  - Parameters: double
- [X] `asin`
  - Return Type: double
  - Parameters: double
- [X] `acos`
  - Return Type: double
  - Parameters: double
- [X] `atan`
  - Return Type: double
  - Parameters: double
- [X] `pow`
  - Return Type: double
  - Parameters: double, integer, complex
- [X] `sqrt`
  - Return Type: double
  - Parameters: double
- [X] `abs`
  - Return Type: double or integer
  - Parameters: double, integer, complex
- [X] `phase`
  - Return Type: double
  - Parameters: complex
- [X] `ceil`
  - Return Type: integer
  - Parameters: double
- [X] `floor`
  - Return Type: integer
  - Parameters: double
- [X] `round`
  - Return Type: integer
  - Parameters: double
- [X] `pi`
  - Return Type: double
- [X] `rand`
  - Return Type: integer

## Conversions

- [X] `double`
  - Return Type: double
  - Parameters: integer
- [X] `int`
  - Return Type: integer
  - Parameters: double
- [X] `str`
  - Return Type: string
  - Parameters: integer, double

## Time

- [X] `now`
  - Return Type: seconds
- [X] `now_ns`
  - Return Type: ns
- [X] `now_ms`
  - Return Type: ms

## File System

- [X] `create_file`
  - Return Type: bool
  - Parameters: string
- [X] `write_file`
  - Return Type: bool
  - Parameters: string
- [X] `read_file`
  - Return Type: string
  - Parameters: string
- [X] `delete_file`
  - Return Type: bool
  - Parameters: string
- [X] `create_dir`
  - Return Type: bool
  - Parameters: string
- [X] `delete_dir`
  - Return Type: bool
  - Parameters: string

## Collections

- [X] `array`
  - Return Type: array
  - Parameters: nil
- [X] `linked_list`
  - Return Type: linked_list
  - Parameters: nil
- [X] `hash_table`
  - Return Type: hash_table
  - Parameters: nil
- [X] `push`
  - Return Type: nil
  - Parameters: array, linked_list
- [X] `push_front`
  - Return Type: nil
  - Parameters: linked_list
- [X] `pop`
  - Return Type: any
  - Parameters: array, linked_list
- [X] `pop_front`
  - Return Type: any
  - Parameters: linked_list
- [X] `nth`
  - Return Type: any
  - Parameters: array
- [X] `is_empty`
  - Return Type: bool
  - Parameters: array, linked_list
- [X] `sort`
  - Return Type: nil
  - Parameters: array, linked_list
- [X] `put`
  - Return Type: nil
  - Parameters: hash_table
- [X] `get`
  - Return Type: any
  - Parameters: hash_table
- [X] `remove`
  - Return Type: nil
  - Parameters: hash_table
- [X] `equal_list`
  - Return Type: bool
  - Parameters: array, linked_list
- [X] `contains`
  - Return Type: bool
  - Parameters: array, linked_list, hash_table
- [X] `len`
  - Return Type: integer
  - Parameters: array, linked_list, hash_table
- [X] `range`
  - Return Type: array
  - Parameters: integer, integer
- [X] `reverse`
  - Return Type: nil
  - Parameters: array, linked_list
- [X] `search`
  - Return Type: integer
  - Parameters: array, linked_list

## Net

- [X] `get_req`
  - Return Type: string
  - Parameters: string, int, string, string
- [ ] `post_req`
  - Return Type: string
  - Parameters: string, int, string, string
- [ ] `put_req`
  - Return Type: string
  - Parameters: string, int, string, string
- [ ] `delete_req`
  - Return Type: string
  - Parameters: string, int, string, string