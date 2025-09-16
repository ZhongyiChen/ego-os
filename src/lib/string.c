#include "string.h"
#include "global.h"
#include "debug.h"
#include "stdint.h"

/**
 * 将 dst 起始的 size 个字节均设置为 value
 */
void memset(void* dst, uint8_t value, uint32_t size) {
    ASSERT(dst != NULL);
    uint8_t* _dst = (uint8_t*)dst;
    while (size-- > 0) *_dst++ = value;
}

/**
 * 将 src 起始的 size 个字节复制到 dst
 */
void memcpy(void* dst, const void* src, uint32_t size) {
    ASSERT(dst != NULL);
    ASSERT(src != NULL);
    uint8_t* _dst = dst;
    const uint8_t* _src = src;
    while (size-- > 0) *_dst++ = *_src++;
}

/**
 * 比较 a 起始与 b 起始的 size 个字节
 * 
 * a == b 返回 0；a > b 返回 1；a < b 返回 -1
 */
int8_t memcmp(const void* a, const void* b, uint32_t size) {
    ASSERT(a != NULL);
    ASSERT(b != NULL);
    const uint8_t* _a = a;
    const uint8_t* _b = b;
    while (size-- > 0) {
        if (*_a != *_b) {
            return *_a > *_b ? 1 : -1;
        }
        _a++;
        _b++;
    }
    return 0;
}

/**
 * 将字符串从 src 复制到 dst
 */
char* strcpy(char* dst, const char* src) {
    ASSERT(dst != NULL);
    ASSERT(src != NULL);
    char* res = dst;
    while ((*dst++ = *src++));
    return res;
}

/**
 * 获取字符串长度
 */
uint32_t strlen(const char* str) {
    ASSERT(str != NULL);
    const char* p = str;
    while (*p++);
    return (p - str - 1);
}

/**
 * 比较字符串 a 与 b
 * 
 * a == b 返回 0；a > b 返回 1；a < b 返回 -1
 */
int8_t strcmp(const char* a, const char* b) {
    ASSERT(a != NULL);
    ASSERT(b != NULL);
    while (*a != 0 && *a == *b) {
        a++;
        b++;
    }
    return *a < *b ? -1 : (*a > *b);
}

/**
 * 从左到右查找字符串 str 中首次出现字符 ch 的地址（注意不是下标）
 */
char* strchr(const char* str, const uint8_t ch) {
    ASSERT(str != NULL);
    while (*str != 0) {
        if (*str == ch) {
            return (char*)str;
        }
        str++;
    }
    return NULL;
}

/**
 * 从右到左查找字符串 str 中首次出现字符 ch 的地址（注意不是下标）
 */
char* strrchr(const char* str, const uint8_t ch) {
    ASSERT(str != NULL);
    const char* last_ch = NULL;
    while (*str != 0) {
        if (*str == ch) {
            last_ch = str;
        }
        str++;
    }
    return (char*)last_ch;
}

/**
 * 将字符串 src 拼接到 dst 后，并返回 dst 的地址
 */
char* strcat(char* dst, const char* src) {
    ASSERT(dst != NULL);
    ASSERT(src != NULL);
    char* str = dst;
    while (*str++);
    --str;                          // 使 str 指向结尾字符 0
    while ((*str++ = *src++));
    return dst;
}

/**
 * 在字符串 str 中查找字符 ch 出现的次数
 */
uint32_t strchrs(const char* str, uint8_t ch) {
    ASSERT(str != NULL);
    uint32_t ch_n = 0;
    while (*str) {
        if (*str++ == ch) {
            ch_n++;
        }
    }
    return ch_n;
}
