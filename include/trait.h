/* 
 * File:   trait.h
 * Author: Mustafif Khan
 * Brief:  Trait methods implementation in Mufi to better organize code
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_trait_h 
#define mufi_trait_h 

//> Collection Methods to be implemented by Collection Types 
typedef struct{
    void (*insert)(void* self, int index, void* data); // insert data at index
    void* (*remove)(void* self, int index); // remove data at index
    int (*search)(void* self, void* data); // search data in collection
    void* (*get)(void* self, int index); // get data at index
    void (*sort)(void* self); // sort collection
    void (*reverse)(void* self); // reverse collection
    void (*clear)(void* self); // clear collection
    int (*len)(void* self); // get size of collection
    void (*print)(void* self); // print collection
    void (*push)(void* self, void* data); // push data to collection
    void* (*pop)(void* self); // pop data from collection
    void* (*merge)(void* self, void* other); // merge two collections
    void* (*copy)(void* self); // copy collection
    void* (*clone)(void* self); // clone collection
    void* (*slice)(void* self, int start, int end); // slice collection
    void* (*splice)(void* self, int start, int end); // splice collection
    void* (*add)(void* self, void* other); // add two collections
    void* (*sub)(void* self, void* other); // subtract two collections
    void* (*mul)(void* self, void* other); // multiply two collections
    void* (*div)(void* self, void* other); // divide two collections
    void* (*sum)(void* self); // sum of collection
    void* (*min)(void* self); // min of collection
    void* (*max)(void* self); // max of collection
    void* (*mean)(void* self); // mean of collection
    void* (*std)(void* self); // standard deviation of collection
    void* (*var)(void* self); // variance of collection
} CollectionTrait;

#endif
