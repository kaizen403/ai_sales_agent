/*
 * Sample MCU application for Renode + Robot Framework demos.
 *
 * I/O map (see README):
 *   DI0..7  -> STM32F1 GPIO IDR bits 0..7 @ 0x40001008
 *   DO0..7  -> MiV CoreGPIO OUT bits 0..7 @ 0x400020A0
 *   LED0..3 -> MiV CoreGPIO OUT bits 8..11
 *   AI0..7  -> MMIO words @ 0x40003000 + 4*n (0..4095)
 *   UART    -> NS16550 @ 0x40000000
 *
 * Modes:
 *   MIRROR    : DO[i] = DI[i]
 *   THRESHOLD : DO[i] = DI[i] AND (AI[i] > threshold)
 *
 * LEDs:
 *   LED0 = any DI high
 *   LED1 = any DO high
 *   LED2 = mode is THRESHOLD
 *   LED3 = heartbeat (toggles each process cycle)
 */
#include <stdint.h>
#include <stdbool.h>

#define UART_BASE     0x40000000u
#define GPIO_IN_BASE  0x40001000u
#define GPIO_OUT_BASE 0x40002000u
#define AI_BASE       0x40003000u

#define UART_RBR  (*(volatile uint8_t *)(UART_BASE + 0x00))
#define UART_THR  (*(volatile uint8_t *)(UART_BASE + 0x00))
#define UART_IER  (*(volatile uint8_t *)(UART_BASE + 0x01))
#define UART_FCR  (*(volatile uint8_t *)(UART_BASE + 0x02))
#define UART_LCR  (*(volatile uint8_t *)(UART_BASE + 0x03))
#define UART_MCR  (*(volatile uint8_t *)(UART_BASE + 0x04))
#define UART_LSR  (*(volatile uint8_t *)(UART_BASE + 0x05))
#define UART_DLL  (*(volatile uint8_t *)(UART_BASE + 0x00))
#define UART_DLM  (*(volatile uint8_t *)(UART_BASE + 0x01))

#define LSR_DR   (1u << 0)
#define LSR_THRE (1u << 5)

#define GPIO_IDR (*(volatile uint32_t *)(GPIO_IN_BASE + 0x08))
#define GPIO_CFG(n) (*(volatile uint32_t *)(GPIO_OUT_BASE + 4u * (uint32_t)(n)))
#define GPIO_OUT (*(volatile uint32_t *)(GPIO_OUT_BASE + 0xA0))

#define AI_REG(n) (*(volatile uint32_t *)(AI_BASE + 4u * (uint32_t)(n)))

#define MODE_MIRROR    0
#define MODE_THRESHOLD 1

#define CFG_OUT (0x5u) /* OUTREG | OUTBUFF */

static uint32_t g_mode = MODE_MIRROR;
static uint32_t g_threshold = 2048;
static uint32_t g_heartbeat;
static uint32_t g_last_di;
static uint32_t g_last_do;
static char g_line[96];
static unsigned g_line_len;

void SysTick_Handler(void)
{
}

static void uart_init(void)
{
    UART_IER = 0;
    UART_FCR = 0x07; /* enable + clear FIFOs */
    UART_LCR = 0x80; /* DLAB */
    UART_DLL = 1;
    UART_DLM = 0;
    UART_LCR = 0x03; /* 8N1 */
    UART_MCR = 0x03; /* DTR+RTS */
}

static void uart_putc(char c)
{
    while ((UART_LSR & LSR_THRE) == 0) {
    }
    UART_THR = (uint8_t)c;
}

static void uart_write(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

static bool uart_try_getc(char *out)
{
    if ((UART_LSR & LSR_DR) == 0) {
        return false;
    }
    *out = (char)UART_RBR;
    return true;
}

static void gpio_out_init(void)
{
    for (uint32_t i = 0; i < 12; i++) {
        GPIO_CFG(i) = CFG_OUT;
    }
    GPIO_OUT = 0;
}

static uint32_t read_di(void)
{
    return GPIO_IDR & 0xFFu;
}

static uint32_t read_ai(unsigned ch)
{
    if (ch > 7) {
        return 0;
    }
    return AI_REG(ch) & 0xFFFu;
}

static void apply_outputs(uint32_t di, uint32_t dout)
{
    uint32_t leds = 0;

    if (di != 0) {
        leds |= (1u << 8); /* LED0 */
    }
    if (dout != 0) {
        leds |= (1u << 9); /* LED1 */
    }
    if (g_mode == MODE_THRESHOLD) {
        leds |= (1u << 10); /* LED2 */
    }
    if (g_heartbeat & 1u) {
        leds |= (1u << 11); /* LED3 */
    }

    GPIO_OUT = (dout & 0xFFu) | leds;
    g_last_di = di;
    g_last_do = dout;
}

static uint32_t compute_do(uint32_t di)
{
    uint32_t dout = 0;

    for (unsigned i = 0; i < 8; i++) {
        uint32_t bit = (di >> i) & 1u;
        if (g_mode == MODE_MIRROR) {
            dout |= bit << i;
        } else if (bit && (read_ai(i) > g_threshold)) {
            dout |= 1u << i;
        }
    }
    return dout;
}

static void process_io(void)
{
    uint32_t di = read_di();
    uint32_t dout = compute_do(di);
    g_heartbeat++;
    apply_outputs(di, dout);
}

static void print_u32(uint32_t v)
{
    char buf[11];
    int i = 0;

    if (v == 0) {
        uart_putc('0');
        return;
    }
    while (v > 0) {
        buf[i++] = (char)('0' + (v % 10u));
        v /= 10u;
    }
    while (i--) {
        uart_putc(buf[i]);
    }
}

static void print_hex8(uint32_t v)
{
    static const char *hex = "0123456789ABCDEF";
    uart_putc('0');
    uart_putc('x');
    uart_putc(hex[(v >> 4) & 0xF]);
    uart_putc(hex[v & 0xF]);
}

static int streq(const char *a, const char *b)
{
    while (*a && *b) {
        if (*a != *b) {
            return 0;
        }
        a++;
        b++;
    }
    return *a == *b;
}

static int startswith(const char *s, const char *prefix)
{
    while (*prefix) {
        if (*s++ != *prefix++) {
            return 0;
        }
    }
    return 1;
}

static uint32_t parse_u32(const char *s)
{
    uint32_t v = 0;
    while (*s == ' ') {
        s++;
    }
    while (*s >= '0' && *s <= '9') {
        v = v * 10u + (uint32_t)(*s - '0');
        s++;
    }
    return v;
}

static void cmd_help(void)
{
    uart_write("OK commands: HELP STATUS MODE MIRROR|THRESHOLD THRESHOLD <n> GETDI GETDO GETAI PING PROCESS\n");
}

static void cmd_status(void)
{
    uart_write("OK STATUS mode=");
    uart_write(g_mode == MODE_MIRROR ? "MIRROR" : "THRESHOLD");
    uart_write(" threshold=");
    print_u32(g_threshold);
    uart_write(" di=");
    print_hex8(g_last_di);
    uart_write(" do=");
    print_hex8(g_last_do);
    uart_write("\n");
}

static void cmd_getai(void)
{
    uart_write("OK AI");
    for (unsigned i = 0; i < 8; i++) {
        uart_putc(' ');
        print_u32(read_ai(i));
    }
    uart_write("\n");
}

static void handle_line(char *line)
{
    /* trim CR */
    for (char *p = line; *p; p++) {
        if (*p == '\r') {
            *p = 0;
            break;
        }
    }

    if (line[0] == 0) {
        return;
    }
    if (streq(line, "HELP")) {
        cmd_help();
    } else if (streq(line, "STATUS")) {
        process_io();
        cmd_status();
    } else if (streq(line, "PING")) {
        uart_write("OK PONG\n");
    } else if (streq(line, "PROCESS")) {
        process_io();
        uart_write("OK PROCESS\n");
    } else if (streq(line, "GETDI")) {
        process_io();
        uart_write("OK DI ");
        print_hex8(g_last_di);
        uart_write("\n");
    } else if (streq(line, "GETDO")) {
        process_io();
        uart_write("OK DO ");
        print_hex8(g_last_do);
        uart_write("\n");
    } else if (streq(line, "GETAI")) {
        cmd_getai();
    } else if (streq(line, "MODE MIRROR")) {
        g_mode = MODE_MIRROR;
        process_io();
        uart_write("OK MODE MIRROR\n");
    } else if (streq(line, "MODE THRESHOLD")) {
        g_mode = MODE_THRESHOLD;
        process_io();
        uart_write("OK MODE THRESHOLD\n");
    } else if (startswith(line, "THRESHOLD ")) {
        g_threshold = parse_u32(line + 10);
        if (g_threshold > 4095u) {
            g_threshold = 4095u;
        }
        process_io();
        uart_write("OK THRESHOLD ");
        print_u32(g_threshold);
        uart_write("\n");
    } else {
        uart_write("ERR unknown command\n");
    }
}

static void poll_uart(void)
{
    char c;
    while (uart_try_getc(&c)) {
        if (c == '\n') {
            g_line[g_line_len] = 0;
            handle_line(g_line);
            g_line_len = 0;
        } else if (c == '\r') {
            /* ignore; handled with LF */
        } else if (g_line_len + 1 < sizeof(g_line)) {
            g_line[g_line_len++] = c;
        }
    }
}

int main(void)
{
    uart_init();
    gpio_out_init();
    process_io();

    uart_write("READY SampleMCU DI/AI/DO/LED/UART\n");
    cmd_help();

    while (1) {
        poll_uart();
        process_io();
    }
}
