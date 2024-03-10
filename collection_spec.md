# Collections Specification

---

> This document describes the specification for the collections feature in the MufiZ language.

## Collections

- Arrays (Fixed and Dynamic)
- Doubly Linked Lists
- Hash Table
- Matrix (Multi-Dimensional Array)
- Float Vector (SIMD Array and Vec3 operations)

## Common Operations for Collections

- Insert
  - [X] Insert an element into an array
  - [X] Insert an element into a linked list
  - [X] Insert an element into a hash table
  - [X] Insert an element into a matrix
  - [X] Insert an element into a float vector
- Remove
  - [ ] Remove an element from an array
  - [X] Remove an element from a hash table
  - [X] Remove an element from a float vector
- Search
  - [X] Search for an element in an array
  - [X] Search for an element in a linked list
  - [X] Search for an element in a float vector
- Get Element
  - [X] Get an element from an array (nth_nf)
  - [X] Get an element from a hash table
  - [X] Get an element from a matrix
  - [X] Get an element from a float vector
- Sort
  - [X] Sort an array (Quick Sort)
  - [X] Sort a linked list (Merge Sort)
  - [X] Sort a float vector
- Print
  - [X] Print an array
  - [X] Print a linked list
  - [X] Print a hash table
  - [X] Print a matrix
  - [X] Print a float vector
- Push
  - [X] Push an element into an array
  - [X] Push an element into a linked list
  - [X] Push an element into a float vector
- Pop
  - [X] Pop an element from an array
  - [X] Pop an element from a linked list
  - [X] Pop an element from a float vector
- Merge
  - [X] Merge two arrays
  - [ ] Merge two linked lists
  - [ ] Merge two hash tables
  - [ ] Merge two float vectors
- Slice
  - [X] Slice an array
  - [ ] Slice a float vector

## Array Operations (Array, Matrix, Float Vector)

- Add
  - [X] Add two arrays together
  - [X] Add two matrices together
  - [X] Add two vectors together
  - [X] Add a scalar to a vector
- Subtract
  - [X] Subtract two arrays
  - [X] Subtract two matrices
  - [X] Subtract two vectors
  - [X] Subtract a scalar from a vector
- Multiply
  - [X] Multiply two arrays
  - [X] Multiply two matrices
  - [X] Multiply two vectors
  - [X] Multiply a scalar with a vector
- Divide
  - [X] Divide two arrays
  - [X] Divide two matrices
  - [X] Divide two vectors
  - [X] Divide a vector by a scalar
- Sum (Array/Vec)
  - [X] Sum of an array
  - [X] Sum of a vector
- Mean (Array/Vec)
  - [X] Mean of an array
  - [X] Mean of a vector
- Variance (Array/Vec)
  - [X] Variance of an array
  - [X] Variance of a vector
- Standard Deviation (Array/Vec)
  - [X] Standard Deviation of an array
  - [X] Standard Deviation of a vector
- Max Value (Array/Vec)
  - [X] Max value of an array
  - [X] Max value of a vector
- Min Value (Array/Vec)
  - [X] Min value of an array
  - [X] Min value of a vector