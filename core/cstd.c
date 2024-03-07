#include "../include/cstd.h"

Value array_nf(int argCount, Value *args)
{
    if (argCount == 0)
    {
        ObjArray *a = newArray();
        return OBJ_VAL(a);
    }
    else if (argCount == 1 && IS_FVECTOR(args[0]))
    {
        FloatVector *f = AS_FVECTOR(args[0]);
        ObjArray *a = newArrayWithCap(f->size, true);
        for (int i = 0; i < f->count; i++)
        {
            pushArray(a, DOUBLE_VAL(f->data[i]));
        }
        return OBJ_VAL(a);
    }
    else if (argCount >= 1)
    {
        if (!IS_INT(args[0]))
        {
            runtimeError("First argument must be an integer.");
            return NIL_VAL;
        }

        if (argCount == 2 && !IS_BOOL(args[1]))
        {
            runtimeError("Second argument must be a bool");
            return NIL_VAL;
        }

        ObjArray *a = newArrayWithCap(AS_INT(args[0]), AS_BOOL(args[1]));
        return OBJ_VAL(a);
    }
    else
    {
        runtimeError("array() takes 0 or 1 argument.");
        return NIL_VAL;
    }
}

Value linkedlist_nf(int argCount, Value *args)
{
    ObjLinkedList *l = newLinkedList();
    return OBJ_VAL(l);
}

Value hashtable_nf(int argCount, Value *args)
{
    ObjHashTable *h = newHashTable();
    return OBJ_VAL(h);
}

Value put_nf(int argCount, Value *args)
{
    if (!IS_HASH_TABLE(args[0]))
    {
        runtimeError("First argument must be a hash table.");
        return NIL_VAL;
    }
    if (!IS_STRING(args[1]))
    {
        runtimeError("Second argument must be a string.");
        return NIL_VAL;
    }
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    ObjString *key = AS_STRING(args[1]);
    return BOOL_VAL(putHashTable(h, key, args[2]));
}

Value get_nf(int argCount, Value *args)
{
    if (!IS_HASH_TABLE(args[0]))
    {
        runtimeError("First argument must be a hash table.");
        return NIL_VAL;
    }
    if (!IS_STRING(args[1]))
    {
        runtimeError("Second argument must be a string.");
        return NIL_VAL;
    }
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    ObjString *key = AS_STRING(args[1]);
    return getHashTable(h, key);
}

Value remove_nf(int argCount, Value *args)
{
    if (!IS_HASH_TABLE(args[0]))
    {
        runtimeError("First argument must be a hash table.");
        return NIL_VAL;
    }
    if (!IS_STRING(args[1]))
    {
        runtimeError("Second argument must be a string.");
        return NIL_VAL;
    }
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    ObjString *key = AS_STRING(args[1]);
    return BOOL_VAL(removeHashTable(h, key));
}

Value push_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]) && !IS_FVECTOR(args[0]))
    {
        runtimeError("First argument must be an array, linked list or vector.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {

        ObjArray *a = AS_ARRAY(args[0]);
        for (int i = 1; i < argCount; i++)
        {
            pushArray(a, args[i]);
        }
        return NIL_VAL;
    }
    else if (IS_FVECTOR(args[0]))
    {
        FloatVector *f = AS_FVECTOR(args[0]);
        for (int i = 1; i < argCount; i++)
        {
            if (!IS_DOUBLE(args[i]))
            {
                runtimeError("All elements of the vector must be doubles.");
                return NIL_VAL;
            }
            pushFloatVector(f, AS_DOUBLE(args[i]));
        }
        return NIL_VAL;
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        for (int i = 1; i < argCount; i++)
        {
            pushBack(l, args[i]);
        }
        return NIL_VAL;
    }
}

Value push_front_nf(int argCount, Value *args)
{
    if (!IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be a linked list.");
        return NIL_VAL;
    }
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    for (int i = 1; i < argCount; i++)
    {
        pushFront(l, args[i]);
    }
    return NIL_VAL;
}

Value pop_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be an array or linked list.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {

        ObjArray *a = AS_ARRAY(args[0]);
        return popArray(a);
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        return popBack(l);
    }
}

Value pop_front_nf(int argCount, Value *args)
{
    if (!IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be a linked list.");
        return NIL_VAL;
    }
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    return popFront(l);
}

Value nth_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]) && !IS_MATRIX(args[0]) && !IS_FVECTOR(args[0]))
    {
        runtimeError("First argument must be an array, matrix, linked list or Vector.");
        return NIL_VAL;
    }
    if (!IS_INT(args[1]))
    {
        runtimeError("Second argument must be an integer.");
        return NIL_VAL;
    }

    if (IS_MATRIX(args[0]) && argCount == 3)
    {
        if (!IS_INT(args[2]))
        {
            runtimeError("Third argument must be an integer.");
            return NIL_VAL;
        }

        ObjMatrix *m = AS_MATRIX(args[0]);
        // improve error handling here
        int row = AS_INT(args[1]);
        int col = AS_INT(args[2]);
        return getMatrix(m, row, col);
    }
    else if (IS_FVECTOR(args[0]))
    {
        FloatVector *f = AS_FVECTOR(args[0]);
        int index = AS_INT(args[1]);
        double value = getFloatVector(f, index);
        return DOUBLE_VAL(value);
    }
    else if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        int index = AS_INT(args[1]);
        if (index < 0 || index >= a->count)
        {
            runtimeError("Index out of bounds.");
            return NIL_VAL;
        }
        return a->values[index];
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        int index = AS_INT(args[1]);
        if (index < 0 || index >= l->count)
        {
            runtimeError("Index out of bounds.");
            return NIL_VAL;
        }
        struct Node *node = l->head;
        for (int i = 0; i < index; i++)
        {
            node = node->next;
        }

        return node->data;
    }
}

Value is_empty_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]) && !IS_HASH_TABLE(args[0]))
    {
        runtimeError("First argument must be an array, linked list, hash table or vector.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        return BOOL_VAL(a->count == 0);
    }
    else if (IS_HASH_TABLE(args[0]))
    {
        ObjHashTable *h = AS_HASH_TABLE(args[0]);
        return BOOL_VAL(h->table.count == 0);
    }
    else if (IS_FVECTOR(args[0]))
    {
        FloatVector *f = AS_FVECTOR(args[0]);
        return BOOL_VAL(f->count == 0);
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        return BOOL_VAL(l->count == 0);
    }
}

Value sort_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be an array or linked list.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {

        ObjArray *a = AS_ARRAY(args[0]);
        sortArray(a);
        return NIL_VAL;
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        mergeSort(l);
        return NIL_VAL;
    }
}

Value equal_list_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be an array, linked list or vector.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        if (!IS_ARRAY(args[1]))
        {
            runtimeError("Second argument must be an array.");
            return NIL_VAL;
        }
        ObjArray *a = AS_ARRAY(args[0]);
        ObjArray *b = AS_ARRAY(args[1]);
        return BOOL_VAL(equalArray(a, b));
    }
    else if (IS_FVECTOR(args[0]))
    {
        if (!IS_FVECTOR(args[1]))
        {
            runtimeError("Second argument must be a vector.");
            return NIL_VAL;
        }
        FloatVector *a = AS_FVECTOR(args[0]);
        FloatVector *b = AS_FVECTOR(args[1]);
        return BOOL_VAL(equalFloatVector(a, b));
    }
    else
    {
        if (!IS_LINKED_LIST(args[1]))
        {
            runtimeError("Second argument must be a linked list.");
            return NIL_VAL;
        }
        ObjLinkedList *a = AS_LINKED_LIST(args[0]);
        ObjLinkedList *b = AS_LINKED_LIST(args[1]);
        return BOOL_VAL(equalLinkedList(a, b));
    }
}

Value contains_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]) && !IS_HASH_TABLE(args[0]))
    {
        runtimeError("First argument must be an array, linked list or hash table.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        for (int i = 0; i < a->count; i++)
        {
            if (valuesEqual(a->values[i], args[1]))
            {
                return BOOL_VAL(true);
            }
        }
        return BOOL_VAL(false);
    }
    else if (IS_HASH_TABLE(args[0]))
    {
        ObjHashTable *h = AS_HASH_TABLE(args[0]);
        if (!valuesEqual(getHashTable(h, AS_STRING(args[1])), NIL_VAL))
        {
            return BOOL_VAL(true);
        }
        else
        {
            return BOOL_VAL(false);
        }
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        struct Node *current = l->head;
        while (current != NULL)
        {
            if (valuesEqual(current->data, args[1]))
            {
                return BOOL_VAL(true);
            }
            current = current->next;
        }
        return BOOL_VAL(false);
    }
}

Value insert_nf(int argCount, Value *args)
{
    if (argCount != 3)
    {
        runtimeError("insert() takes 3 arguments.");
        return NIL_VAL;
    }
    if (!IS_ARRAY(args[0]) && !IS_FVECTOR(args[0]))
    {
        runtimeError("First argument must be an array or vector.");
        return NIL_VAL;
    }
    if (!IS_INT(args[1]))
    {
        runtimeError("Second argument must be an integer.");
        return NIL_VAL;
    }
    if (IS_FVECTOR(args[0]))
    {
        FloatVector *f = AS_FVECTOR(args[0]);
        int index = AS_INT(args[1]);
        if (!IS_DOUBLE(args[2]))
        {
            runtimeError("Third argument must be a double.");
            return NIL_VAL;
        }
        insertFloatVector(f, index, AS_DOUBLE(args[2]));
        return NIL_VAL;
    }
    else
    {
        ObjArray *a = AS_ARRAY(args[0]);
        int index = AS_INT(args[1]);
        insertArray(a, index, args[2]);
        return NIL_VAL;
    }
}

Value len_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]) && !IS_HASH_TABLE(args[0]) && !IS_FVECTOR(args[0]))
    {
        runtimeError("First argument must be an array, vector, linked list or hash table.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        return INT_VAL(a->count);
    }
    else if (IS_HASH_TABLE(args[0]))
    {
        ObjHashTable *h = AS_HASH_TABLE(args[0]);
        return INT_VAL(h->table.count);
    }
    else if (IS_FVECTOR(args[0]))
    {
        FloatVector *f = AS_FVECTOR(args[0]);
        return INT_VAL(f->count);
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        return INT_VAL(l->count);
    }
}

Value range_nf(int argCount, Value *args)
{
    if (!IS_INT(args[0]) || !IS_INT(args[1]))
    {
        runtimeError("Both arguments must be integers.");
        return NIL_VAL;
    }
    int start = AS_INT(args[0]);
    int end = AS_INT(args[1]);
    ObjArray *a = newArray();
    for (int i = start; i < end; i++)
    {
        pushArray(a, INT_VAL(i));
    }
    return OBJ_VAL(a);
}

Value reverse_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be an array or linked list.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        reverseArray(a);
        return NIL_VAL;
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        reverseLinkedList(l);
        return NIL_VAL;
    }
}

Value search_nf(int argCount, Value *args)
{
    if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0]))
    {
        runtimeError("First argument must be an array or linked list.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        int result = searchArray(a, args[1]);
        if (result == -1)
            return NIL_VAL;
        return INT_VAL(result);
    }
    else
    {
        ObjLinkedList *l = AS_LINKED_LIST(args[0]);
        int result = searchLinkedList(l, args[1]);
        if (result == -1)
            return NIL_VAL;
        return INT_VAL(result);
    }
}

Value matrix_nf(int argCount, Value *args)
{
    if (!IS_INT(args[0]) || !IS_INT(args[1]))
    {
        runtimeError("Both arguments must be integers.");
        return NIL_VAL;
    }
    int rows = AS_INT(args[0]);
    int cols = AS_INT(args[1]);
    ObjMatrix *m = newMatrix(rows, cols);
    return OBJ_VAL(m);
}

Value set_row_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    if (!IS_INT(args[1]))
    {
        runtimeError("Second argument must be an integer.");
        return NIL_VAL;
    }
    if (!IS_ARRAY(args[2]))
    {
        runtimeError("Third argument must be an array.");
        return NIL_VAL;
    }

    ObjMatrix *matrix = AS_MATRIX(args[0]);
    int row = AS_INT(args[1]);
    ObjArray *array = AS_ARRAY(args[2]);

    setRow(matrix, row, array);
    return NIL_VAL;
}

Value set_col_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    if (!IS_INT(args[1]))
    {
        runtimeError("Second argument must be an integer.");
        return NIL_VAL;
    }
    if (!IS_ARRAY(args[2]))
    {
        runtimeError("Third argument must be an array.");
        return NIL_VAL;
    }

    ObjMatrix *matrix = AS_MATRIX(args[0]);
    int col = AS_INT(args[1]);
    ObjArray *array = AS_ARRAY(args[2]);

    setCol(matrix, col, array);
    return NIL_VAL;
}

Value set_nf(int argCount, Value *args)
{
    if (argCount != 4)
    {
        runtimeError("set() takes 4 arguments.");
        return NIL_VAL;
    }

    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    if (!IS_INT(args[1]))
    {
        runtimeError("Second argument must be an integer.");
        return NIL_VAL;
    }
    if (!IS_INT(args[2]))
    {
        runtimeError("Third argument must be an integer.");
        return NIL_VAL;
    }

    ObjMatrix *matrix = AS_MATRIX(args[0]);
    int row = AS_INT(args[1]);
    int col = AS_INT(args[2]);

    setMatrix(matrix, row, col, args[3]);
    return NIL_VAL;
}

Value kolasa_nf(int argCount, Value *args)
{
    if (argCount != 0)
    {
        runtimeError("kolasa() takes no arguments.");
        return NIL_VAL;
    }
    ObjMatrix *m = newMatrix(3, 3);
    for (int i = 0; i < m->len; i++)
    {
        m->data->values[i] = DOUBLE_VAL((double)(i + 1));
    }
    return OBJ_VAL(m);
}

Value rref_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    ObjMatrix *m = AS_MATRIX(args[0]);
    rref(m);
    return NIL_VAL;
}

Value rank_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    ObjMatrix *m = AS_MATRIX(args[0]);
    return INT_VAL(rank(m));
}

Value transpose_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    ObjMatrix *m = AS_MATRIX(args[0]);
    ObjMatrix *t = transposeMatrix(m);
    return OBJ_VAL(t);
}

Value determinant_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    ObjMatrix *m = AS_MATRIX(args[0]);
    return DOUBLE_VAL(determinant(m));
}

Value fvector_nf(int argCount, Value *args)
{
    if (argCount != 1)
    {
        runtimeError("fvec() takes 1 argument.");
        return NIL_VAL;
    }
    if (!IS_INT(args[0]) && !IS_ARRAY(args[0]))
    {
        runtimeError("First argument must be an integer or an array.");
        return NIL_VAL;
    }

    if (IS_ARRAY(args[0]))
    {
        ObjArray *a = AS_ARRAY(args[0]);
        FloatVector *f = newFloatVector(a->capacity);
        for (int i = 0; i < a->count; i++)
        {
            if (!IS_DOUBLE(a->values[i]))
            {
                runtimeError("All elements of the vector must be doubles.");
                return NIL_VAL;
            }
            pushFloatVector(f, AS_DOUBLE(a->values[i]));
        }
        return OBJ_VAL(f);
    }
    else
    {
        int n = AS_INT(args[0]);
        FloatVector *f = newFloatVector(n);
        return OBJ_VAL(f);
    }
}

Value merge_nf(int argCount, Value *args)
{
    if (argCount != 2)
    {
        runtimeError("merge() takes 2 arguments.");
        return NIL_VAL;
    }
    if (!IS_ARRAY(args[0]) || !IS_ARRAY(args[1]))
    {
        runtimeError("Both arguments must be arrays.");
        return NIL_VAL;
    }
    ObjArray *a = AS_ARRAY(args[0]);
    ObjArray *b = AS_ARRAY(args[1]);
    ObjArray *c = mergeArrays(a, b);
    return OBJ_VAL(c);
}

Value workspace_nf(int argCount, Value *args)
{
    if (argCount != 0)
    {
        runtimeError("workspace() takes no arguments.");
        return NIL_VAL;
    }
    struct Entry *e = entries_(&vm.globals);
    printf("Workspace:\n");
    for (int i = 0; i < vm.globals.capacity; i++)
    {
        if (e[i].key != NULL && !IS_NATIVE(e[i].value))
        {
            printf("%s: ", e[i].key->chars);
            if (IS_MATRIX(e[i].value))
            {
                printf("\n");
            }
            printValue(e[i].value);
            printf("\n");
        }
    }
    return NIL_VAL;
}

Value lu_nf(int argCount, Value *args)
{
    if (!IS_MATRIX(args[0]))
    {
        runtimeError("First argument must be a matrix.");
        return NIL_VAL;
    }
    ObjMatrix *m = AS_MATRIX(args[0]);
    ObjMatrix *result = lu(m);
    return OBJ_VAL(result);
}

Value linspace_nf(int argCount, Value *args)
{
    if (argCount != 3)
    {
        runtimeError("linspace() takes 3 arguments.");
        return NIL_VAL;
    }
    if (!IS_DOUBLE(args[0]) || !IS_DOUBLE(args[1]) || !IS_INT(args[2]))
    {
        runtimeError("First and second arguments must be doubles and the third argument must be an integer.");
        return NIL_VAL;
    }
    double start = AS_DOUBLE(args[0]);
    double end = AS_DOUBLE(args[1]);
    int n = AS_INT(args[2]);
    ObjArray *a = newArrayWithCap(n, true);
    double step = (end - start) / (n - 1);
    for (int i = 0; i < n; i++)
    {
        pushArray(a, DOUBLE_VAL(start + (double)i * step));
    }
    return OBJ_VAL(a);
}

Value interp1_nf(int argCount, Value *args)
{
    if (argCount != 3)
    {
        runtimeError("interp1() takes 3 arguments.");
        return NIL_VAL;
    }
    if (!IS_ARRAY(args[0]) || !IS_ARRAY(args[1]) || !IS_DOUBLE(args[2]))
    {
        runtimeError("First and second arguments must be arrays and the third argument must be a double.");
        return NIL_VAL;
    }
    ObjArray *x = AS_ARRAY(args[0]);
    ObjArray *y = AS_ARRAY(args[1]);
    double x0 = AS_DOUBLE(args[2]);

    if (x->count != y->count)
    {
        runtimeError("x and y must have the same length.");
        return NIL_VAL;
    }
    if (x0 < AS_DOUBLE(x->values[0]) || x0 > AS_DOUBLE(x->values[x->count - 1]))
    {
        runtimeError("x0 must be within the range of x.");
        return NIL_VAL;
    }
    double y0 = 0;
    for (int i = 0; i < x->count - 1; i++)
    {
        if (AS_DOUBLE(x->values[i]) <= x0 && x0 <= AS_DOUBLE(x->values[i + 1]))
        {
            y0 = AS_DOUBLE(y->values[i]) + (x0 - AS_DOUBLE(x->values[i])) * (AS_DOUBLE(y->values[i + 1]) - AS_DOUBLE(y->values[i])) / (AS_DOUBLE(x->values[i + 1]) - AS_DOUBLE(x->values[i]));
            break;
        }
    }
    return DOUBLE_VAL(y0);
}