#ifndef __LIB_KERNEL_PRINT_H
#define __LIB_KERNEL_PRINT_H

#include "stdint.h"

void put_char(uint8_t char_ascii);
void put_str(uint8_t* message);
void put_int(uint32_t num);
void put_hex(uint32_t hex);

#endif
