#include "debug.h"
#include "print.h"
#include "interrupt.h"
#include "stdint.h"

/**
 * 打印文件名、行号、函数名、条件，并使程序悬停
 */
void panic_spin(char* filename, int line, const char* fn, const char* condition) {
    disable_intr();
    put_str("\n\n\n!!!!! Error Occur !!!!!\n");
    put_str("filename: ");
    put_str(filename);
    put_str("\n");
    put_str("line: ");
    put_int(line);
    put_str("\n");
    put_str("fn: ");
    put_str((char*)fn);
    put_str("\n");
    put_str("condition: ");
    put_str((char*)condition);
    put_str("\n");
}
