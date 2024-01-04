#include <stdbool.h>
#include <stdint.h>

struct test_MyType {
  intptr_t x;
  intptr_t y;
  double z;
};

enum test_Color {
  test_red = 0,
  test_green = 1,
  test_blue = 2,
  test_yellow = 3,
  test_orange = 4,
  test_purple = 5,
  test_indigo = 6
};

struct test_tuple_int_int_float_bool {
  intptr_t field0;
  intptr_t field1;
  double field2;
  bool field3;
};

struct test_MyOtherType {
  uint8_t x;
  uint8_t y;
  double z;
  struct test_MyType *u;
  struct test_MyType a;
  intptr_t dist;
  uint8_t bleh[32];
  uint16_t meh;
  uint8_t hmm;
  struct test_MyType test[6];
  test_Color color;
  struct test_tuple_int_int_float_bool blerg;
  uint8_t rng;
  uint32_t otherRange;
};

struct test_seq_data_float32 {
  intptr_t capacity;
  float data[];
};

struct test_seq_float32 {
  intptr_t len;
  struct test_seq_data_float32 *data;
};

struct test_string_data {
  intptr_t capacity;
  char data[];
};

struct test_string {
  intptr_t len;
  struct test_string_data *data;
};

struct test_MyRef {
  struct test_MyRef *child;
};

struct test_Child {
  double y;
  intptr_t x;
};

extern struct test_MyOtherType test_myGlobal;
extern struct test_Child *test_inheritance;

void test_bleh();
char *test_doThing(intptr_t *oa_data, intptr_t oa_len, char **otherOa_data,
                   intptr_t otherOa_len, struct test_MyOtherType *typ,
                   struct test_seq_float32 a, struct test_seq_float32 b);
void test_doOtherThing(struct test_string s);
void test_doThingy(intptr_t *i);
void test_doOtherStuff(struct test_MyRef *r);
