#include <stddef.h>

void* memset(void* d, int s, size_t c) {
  void* t = d;
  __asm__ volatile (
    "rep stosb"
    :"=D"(d),"=c"(c)
    :"0"(d),"a"(s),"1"(c)
    :"memory"
  );
  return t;
}

void* memcpy(void* d, const void* s, size_t c) {
  void* t = d;
  __asm__ volatile (
    "rep movsb"
    :"=D"(d),"=S"(s),"=c"(c)
    :"0"(d),"1"(s),"2"(c)
    :"memory"
  );
  return t;
}

int memcmp(const void* s1, const void* s2, size_t c) {
  if(!c) return 0;
  __asm__ volatile (
    "repe cmpsb"
    :"=D"(s1),"=S"(s2),"=c"(c)
    :"0"(s1),"1"(s2),"2"(c)
    :"memory","cc"
  );
  return ((const unsigned char *)s1)[-1] - ((const unsigned char *)s2)[-1];
}
