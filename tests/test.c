#include "mylib.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main()
{
    mylib_hello_world("Hello, Nim");

    assert(mylib_do_thing(10, 20) == 30);

    struct mylib_string str = mylib_join("hello, ", "world");

    assert(strcmp("hello, world", str.data->data) == 0);
    mylib_free_string(str);

    struct mylib_MyObj* obj = mylib_new_my_obj(100);
    assert(strcmp("100", obj->b.data->data) == 0);
    assert(obj->a == 100);

    assert(mylib_do_stuff_int(100) == 100);
    assert(mylib_do_stuff_float((double)100) == (double)100);
    mylib_free_my_obj(obj);

    double vals[] = { 1, 2, 3, 4 };
    struct mylib_seq_float floats = mylib_new_float_seq(vals, 4);

    for (int i = 0; i < 4; i++)
        assert(vals[i] == floats.data->data[i]);
    assert(floats.len == 4);
    assert(memcmp(floats.data->data, &vals, floats.len * sizeof(double)) == 0);
    struct mylib_seq_float floats2 = mylib_do_stuff_seq_float(floats);
    assert(mylib_float_seq_cmp(floats, floats2));

    mylib_free_float_seq(floats);
    mylib_free_float_seq(floats2);

    intptr_t ints[] = { 1,
        2,
        3,
        4,
        5,
        6 };
    struct mylib_opaque_seq_int int_seq = mylib_make_opaque_seq_int(ints, 6);
    assert(memcmp(mylib_opaque_seq_int_index_mutable(&int_seq, 0), vals, int_seq.len * sizeof(intptr_t)));
    return 0;
}
