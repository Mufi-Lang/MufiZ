/* 
 * File:   cstd.h
 * Author: Mustafif Khan
 * Brief:  The Standard Library from C 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_cstd_h
#define mufi_cstd_h

#include "value.h"
#include "object.h"
#include "vm.h"
#include <stdio.h>

Value assert_nf(int argCount, Value *args);

/* Collection Initializations  */
//> Initializes a new array 
//> Options: 
//> 1. array() -> []
//> 2. array(int, bool) -> array with cap and static flag
//> 3. array(int) -> array with cap
//> 4. array(fvec) -> converts fvec to static array
Value array_nf(int argCount, Value *args);
//> Initializes a new linked list
Value linkedlist_nf(int argCount, Value *args);
//> Initializes a new hashtable
Value hashtable_nf(int argCount, Value *args);
//> Initializes a new matrix with rows and columns and zeroes the matrix
Value matrix_nf(int argCount, Value *args);
//> Initializes a new fvec with a size 
Value fvector_nf(int argCount, Value *args);
//> Creates a new array with range [a, b)
Value range_nf(int argCount, Value *args);
Value slice_nf(int argCount, Value *args);
Value splice_nf(int argCount, Value *args);

/* Operations */
//> Pushes value(s) to a collection
//> Options:
//> 1. array: push(array, value, ...)
//> 2. linkedlist: push(linkedlist, value, ...)
//> 3. fvec: push(fvec, double, ...)
Value push_nf(int argCount, Value *args);
//> Pops a value from a collection
//> Options:
//> 1. array: pop(array) value
//> 2. linkedlist: pop(linkedlist) value 
//> 3. fvec: pop(fvec) double
Value pop_nf(int argCount, Value *args);
//> Returns the value at an index 
//> Options:
//> 1. array: nth(array, index) value
//> 2. linkedlist: nth(linkedlist, index) value
//> 3. fvec: nth(fvec, index) double
//> 4. matrix: nth(matrix, row, col) value
Value nth_nf(int argCount, Value *args);
//> Sorts the collection
//> Options:
//> 1. array (quick sort)
//> 2. linkedlist (merge sort)
//> 3. fvec (quick sort)
Value sort_nf(int argCount, Value *args);
//> Checks if the collection contains a value
Value contains_nf(int argCount, Value *args);
//> Inserts a value at an index
Value insert_nf(int argCount, Value *args);
//> Returns the length of the collection
Value len_nf(int argCount, Value *args);
//> Searches for a value in the collection and returns the index
Value search_nf(int argCount, Value *args);
//> Checks if the collection is empty
Value is_empty_nf(int argCount, Value *args);
//> Checks if two lists are equal
Value equal_list_nf(int argCount, Value *args);
//> Reverses the collection
Value reverse_nf(int argCount, Value *args);
//> Merges two collections
Value merge_nf(int argCount, Value *args);
//> Copies the collection
Value clone_nf(int argCount, Value *args);
//> Clears the collection
Value clear_nf(int argCount, Value *args);
//> Sums the list
Value sum_nf(int argCount, Value *args);
//> Averages the list
Value mean_nf(int argCount, Value *args);
//> Standard deviation of the list
Value std_nf(int argCount, Value *args);
//> Variance of the list
Value var_nf(int argCount, Value *args);
//> Maximum value in the list
Value maxl_nf(int argCount, Value *args);
//> Minimum value in the list
Value minl_nf(int argCount, Value *args);

/* Vec3 Specific Functions */
//> Dot product of two vectors
Value dot_nf(int argCount, Value *args);
//> Cross product of two vectors
Value cross_nf(int argCount, Value *args);
//> Normalizes the vector
Value norm_nf(int argCount, Value *args);
//> Projects one vector onto another
Value proj_nf(int argCount, Value *args);
//> Rejects one vector from another
Value reject_nf(int argCount, Value *args);
//> Reflects one vector from another
Value reflect_nf(int argCount, Value *args);
//> Refracts one vector from another
Value refract_nf(int argCount, Value *args);
//> Returns the angle between two vectors
Value angle_nf(int argCount, Value *args);

/* Hash Table Specific Functions */
//> Puts a key-value pair in the hashtable
Value put_nf(int argCount, Value *args);
//> Gets the value of a key in the hashtable
Value get_nf(int argCount, Value *args);
//> Removes a key-value pair from the hashtable
Value remove_nf(int argCount, Value *args);

/* Linked List Specific */
//> Pushes a value to the front of the linked list
Value push_front_nf(int argCount, Value *args);
//> Pops a value from the front of the linked list
Value pop_front_nf(int argCount, Value *args);

/* Matrix Specific */
//> Sets the values at a row in the matrix with an array
Value set_row_nf(int argCount, Value *args);
//> Sets the values at a column in the matrix with an array
Value set_col_nf(int argCount, Value *args);
//> Sets the value at a row and column in the matrix
Value set_nf(int argCount, Value *args);
//> A special matrix 
Value kolasa_nf(int argCount, Value *args);
//> Performs the Row Reduced Echelon Form (RREF) on the matrix
Value rref_nf(int argCount, Value *args);
//> Returns the rank of the matrix
Value rank_nf(int argCount, Value *args);
//> Returns the transpose of the matrix
Value transpose_nf(int argCount, Value *args);
//> Returns the determinant of the matrix
Value determinant_nf(int argCount, Value *args);
//> Returns the LU decomposition of the matrix as a 2 x 1 matrix
Value lu_nf(int argCount, Value *args);

/* Matlab Like */
//> Prints the current global values in the vm
Value workspace_nf(int argCount, Value *args);
Value linspace_nf(int argCount, Value *args);
Value interp1_nf(int argCount, Value *args);
/* TODO */
// //> Returns the inverse of the matrix
// Value inverse_nf(int argCount, Value *args);
// //> Returns the eigenvalues of the matrix
// Value eigenvalues_nf(int argCount, Value *args);
// //> Returns the eigenvectors of the matrix
// Value eigenvectors_nf(int argCount, Value *args);
// Value blsprice_nf(int argCount, Value *args);
//Value solve_nf(int argCount, Value *args);

#endif