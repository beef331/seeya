#include <stdbool.h>
#include <stdint.h>

struct mylib_string_data {
  intptr_t capacity;
  char data[];
};

struct mylib_string {
  intptr_t len;
  struct mylib_string_data *data;
};

struct mylib_MyObj {
  intptr_t a;
  struct mylib_string b;
};

struct mylib_seq_data_float {
  intptr_t capacity;
  double data[];
};

struct mylib_seq_float {
  intptr_t len;
  struct mylib_seq_data_float *data;
};

extern intptr_t (*mylib_do_stuff_int)(intptr_t);
extern double (*mylib_do_stuff_float)(double);
extern struct mylib_seq_float (*mylib_do_stuff_seq_float)(
    struct mylib_seq_float);

// This prints the string passed in
void mylib_hello_world(char *msg);

// This is just simple math
intptr_t mylib_do_thing(intptr_t a, intptr_t b);

// This joins two cstrings and returns a Nim string
struct mylib_string mylib_join(char *a, char *b);

// This frees the Nim string
void mylib_free_string(struct mylib_string s);

// This allocates an object and sets the b field to a Nim string of i
struct mylib_MyObj *mylib_new_my_obj(intptr_t i);

// This frees `obj`
void mylib_free_my_obj(struct mylib_MyObj *obj);

// This frees `obj`
void mylib_free_float_seq(struct mylib_seq_float s);
struct mylib_seq_float mylib_new_float_seq(double *data_data,
                                           intptr_t data_len);
bool mylib_float_seq_cmp(struct mylib_seq_float a, struct mylib_seq_float b);
