#include <cstdio>
#include <cassert>

#define p_assert(x) do {    \
  printf("%60s", #x);       \
  assert(x);                \
  printf(" - PASS :)\n");   \
} while (0)

#define p_header(s) do {    \
  printf("\n");             \
  printf("- %s\n", s);      \
} while (0)

#define p_file_header(FILE) do {                  \
  printf("\n" FILE ":\n");                        \
  printf("--------------------------------\n");   \
} while (0)

